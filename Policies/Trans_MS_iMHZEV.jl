#
# Trans_MS_iMHZEV.jl (from ZEV_HDV.jl)
#
# Targets for ZEV market shares representing Transport Canada analysis on iMHZEV program.
# To Modify, adjust EVInput below
#
# 
# To be run after Trans_MS_HDV_Electric_BC
# 
# Brock Batey - October 7th 2022.
#
# Extended Electrification to reflect Liberal Party platform BB-Nov 18 2021
#

using SmallModel

module Trans_MS_iMHZEV

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String
  
  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  MSFTarget::VariableArray{3} = zeros(Float64,length(Tech),length(Area),length(Year)) # [Tech,Area,Year] Target Market Share for Policy Vehicles (Driver/Driver)
  MSFTrucksBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Truck Market Shares in Base
  TTMSChange::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Trucks Market Share factor (Driver/Driver)
  TTMSNew::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Trucks Market Share New,after shift to Transit (Driver/Driver)
  TTMSOld::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Trucks Market Share Old,before shift to Transit(Driver/Driver)
  ZEVInput::VariableArray{3} = zeros(Float64,length(Tech),length(Area),length(Year)) # [Tech,Area,Year] Target ZEV fractions of truck class (Driver/Driver)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC,Enduse) = data 
  (; Nation,Tech,) = data
  (; ANMap,MSFTarget) = data
  (; TTMSChange,TTMSNew,TTMSOld,xMMSF,ZEVInput) = data

  ON = Select(Area,"ON");
  Freight = Select(EC,"Freight");
  Carriage = Select(Enduse,"Carriage");
  years = collect(Yr(2023):Yr(2040));
  techs = Select(Tech,["HDV2B3Electric","HDV45Electric","HDV67Electric","HDV8Electric"]);

  # 
  # Read in EVInput, fractional market share of on road freight trucks
  # * EVInput represents the fraction of the Tech to switch to ZEV
  # 

  ZEVInput[techs,ON,years] .=[
    # Electric Shares       2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040
                            0.0489  0.0787  0.1133  0.1185  0.0732  0.0768  0.0810  0.0859  0.0933  0.1012  0.1099  0.1201  0.1319  0.1489  0.1693  0.1957  0.2328  0.2892 # HDV2B3
                            0.0120  0.0190  0.0240  0.0290  0.0110  0.0130  0.0150  0.0180  0.0200  0.0240  0.0270  0.0320  0.0390  0.0460  0.0560  0.0770  0.0880  0.1030 # HDV45
                            0.0192  0.0227  0.0198  0.0234  0.0144  0.0174  0.0230  0.0275  0.0316  0.0371  0.0428  0.0498  0.0589  0.0706  0.0867  0.1067  0.1411  0.2089 # HDV67
                            0.0290  0.0310  0.0290  0.0320  0.0180  0.0210  0.0320  0.0380  0.0440  0.0500  0.0570  0.0670  0.0800  0.0960  0.1180  0.1450  0.1920  0.2780 # HDV8
  ]

  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1);
  for year in years, area in areas, tech in techs
    ZEVInput[tech,area,year] = ZEVInput[tech,ON,year];
  end;

  #
  # Scale down NT and NU by half since it is triggering emergency generation around 2040.
  #  
  areas = Select(Area,["NT","NU"]);
  for year in years, area in areas, tech in techs
    ZEVInput[tech,area,year] = ZEVInput[tech,area,year] * 0.5;
  end;

  areas = findall(ANMap[:,CN] .== 1);
  
  # 
  # * Select fraction of on road freight trucks of total freight
  # * and Scale EVInput using TTMSOld. This should maintain truck
  # * market share vs trains and boats
  # 
  
  techs = Select(Tech,(from="HDV2B3Gasoline",to="HDV2B3Propane"))
  for area in areas, year in years
    TTMSOld[area,year] = sum(xMMSF[Carriage,tech,Freight,area,year] for tech in techs)
  end
  
  HDV2B3Electric = Select(Tech,"HDV2B3Electric");
  for area in areas, year in years
    MSFTarget[HDV2B3Electric,area,year] = ZEVInput[HDV2B3Electric,area,year]*
      TTMSOld[area,year]
    TTMSNew[area,year] = TTMSOld[area,year]-MSFTarget[HDV2B3Electric,area,year]
    @finite_math TTMSChange[area,year] = TTMSNew[area,year] / TTMSOld[area,year]
  end
  
  techs = Select(Tech,["HDV2B3Gasoline","HDV2B3Diesel","HDV2B3NaturalGas","HDV2B3Propane"])
  for area in areas, tech in techs, year in years
    MSFTarget[tech,area,year] = xMMSF[Carriage,tech,Freight,area,year] * 
      TTMSChange[area,year]
  end

  techs = Select(Tech,(from="HDV45Gasoline",to="HDV45Propane"))
  for area in areas, year in years
    TTMSOld[area,year] = sum(xMMSF[Carriage,tech,Freight,area,year] for tech in techs)
  end
  
  HDV45Electric = Select(Tech,"HDV45Electric");
  for area in areas, year in years
    MSFTarget[HDV45Electric,area,year] = 
      ZEVInput[HDV45Electric,area,year]*TTMSOld[area,year]
    TTMSNew[area,year] = TTMSOld[area,year]-MSFTarget[HDV45Electric,area,year]
    @finite_math TTMSChange[area,year] = TTMSNew[area,year] / TTMSOld[area,year]
  end
  
  techs = Select(Tech,["HDV45Gasoline","HDV45Diesel","HDV45NaturalGas","HDV45Propane"])
  for area in areas, tech in techs, year in years
    MSFTarget[tech,area,year] = xMMSF[Carriage,tech,Freight,area,year] * 
      TTMSChange[area,year]
  end


  techs = Select(Tech,(from="HDV67Gasoline",to="HDV67Propane"))
  for area in areas, year in years
    TTMSOld[area,year] = sum(xMMSF[Carriage,tech,Freight,area,year] for tech in techs)
  end
  
  HDV67Electric = Select(Tech,"HDV67Electric");
  for area in areas, year in years
    MSFTarget[HDV67Electric,area,year] = ZEVInput[HDV67Electric,area,year]*
      TTMSOld[area,year]
    TTMSNew[area,year] = TTMSOld[area,year]-MSFTarget[HDV67Electric,area,year]
    @finite_math TTMSChange[area,year] = TTMSNew[area,year] / TTMSOld[area,year]
  end
  
  techs = Select(Tech,["HDV67Gasoline","HDV67Diesel","HDV67NaturalGas","HDV67Propane"])
  for area in areas, tech in techs, year in years
    MSFTarget[tech,area,year] = xMMSF[Carriage,tech,Freight,area,year] * 
      TTMSChange[area,year]
  end
  
  techs = Select(Tech,(from="HDV8Gasoline",to="HDV8Propane"))
  for area in areas, year in years
    TTMSOld[area,year] = sum(xMMSF[Carriage,tech,Freight,area,year] for tech in techs)
  end
  
  HDV8Electric = Select(Tech,"HDV8Electric");
  for area in areas, year in years
    MSFTarget[HDV8Electric,area,year] = ZEVInput[HDV8Electric,area,year]*
      TTMSOld[area,year]
    TTMSNew[area,year] = TTMSOld[area,year]-MSFTarget[HDV8Electric,area,year]
    @finite_math TTMSChange[area,year] = TTMSNew[area,year] / TTMSOld[area,year]
  end
  
  techs = Select(Tech,["HDV8Gasoline","HDV8Diesel","HDV8NaturalGas","HDV8Propane"])
  for area in areas, tech in techs, year in years
    MSFTarget[tech,area,year] = xMMSF[Carriage,tech,Freight,area,year] * 
      TTMSChange[area,year]
  end

  years = collect(Yr(2041):Final);
  techs = Select(Tech,(from="HDV2B3Gasoline",to="HDV8Propane"))
  for year in years, area in areas, tech in techs
    MSFTarget[tech,area,year] = MSFTarget[tech,area,Yr(2040)]
  end

  years = collect(Yr(2023):Final);
  for year in years, tech in techs, area in areas
    xMMSF[Carriage,tech,Freight,area,year] = MSFTarget[tech,area,year]
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF);
end

function PolicyControl(db)
  @info ("Trans_MS_iMHZEV.jl - PolicyControl");
  TransPolicy(db);
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
