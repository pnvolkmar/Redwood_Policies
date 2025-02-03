#
# Trans_MS_HDV_Electric_BC.jl (from ZEV_HDV_BC.jl)
# 
# Targets for ZEV market shares in BC Freight Sector by Matt Lewis 19/09/26
# target is 16% powered by LNG and 10% are electric, excluding buses
# Note, this jl should be run in place of Trans_Railshift.jl
# and ZEV_HDV_BC.jl as it supercedes both
# Revised structure Jeff Amlin 07/20/21
#

using SmallModel

module Trans_MS_HDV_Electric_BC

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
  MSFTarget::VariableArray{3} = zeros(Float64,length(Tech),length(Area),length(Year)) # [Tech,Area,Year] Target Market Share for Policy Vehicles (Driver/Driver)
  MSFTrucksBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Truck Market Shares in Base
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC,Enduse) = data 
  (; Tech) = data
  (; MSFTarget,MSFTrucksBase) = data
  (; xMMSF) = data

  BC = Select(Area,"BC");
  Freight = Select(EC,"Freight");
  Carriage = Select(Enduse,"Carriage");
  techs = Select(Tech,["HDV2B3Electric","HDV45Electric","HDV67Electric",
    "HDV2B3NaturalGas","HDV45NaturalGas","HDV67NaturalGas","HDV8NaturalGas"]);
  years = collect(Yr(2020):Yr(2030));
  # TODOJulia - create an equation for each tech for example MSFTarget[HDV2B3Electric,BC,years] = {
  MSFTarget[techs,BC,years] .=[
              # 2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030
                0.010 0.016 0.022 0.028 0.034 0.040 0.046 0.052 0.058 0.064 0.070 # HDV2B3
                0.005 0.006 0.007 0.008 0.009 0.010 0.011 0.012 0.013 0.014 0.015 # HDV45
                0.005 0.006 0.007 0.008 0.009 0.010 0.011 0.012 0.013 0.014 0.015 # HDV67
                0.005 0.007 0.008 0.001 0.011 0.013 0.014 0.016 0.017 0.019 0.0206 # HDV2B3NaturalGas
                0.005 0.007 0.008 0.001 0.011 0.013 0.014 0.016 0.017 0.019 0.020 # HDV45NaturalGas
                0.005 0.007 0.008 0.001 0.011 0.013 0.014 0.016 0.017 0.019 0.020 # HDV67NaturalGas
                0.010 0.019 0.028 0.037 0.046 0.055 0.064 0.073 0.082 0.091 0.100 # HDV8NaturalGas
  ]

  # 
  # * Compute the baseline market share by class of truck (MSFTrucksBase),
  # * then apply the market share of ZEV (MSFTarget) to that class of truck.
  # * This reduces shifts between truck classes and shifts to non-road freight
  # 

  years = collect(Future:Yr(2030));

  techs = Select(Tech,(from="HDV2B3Gasoline",to="HDV2B3Propane"))
  for year in years
    MSFTrucksBase[BC,year] = sum(xMMSF[Carriage,tech,Freight,BC,year] for tech in techs)
  end
  
  techs = Select(Tech,["HDV2B3Electric","HDV2B3NaturalGas"])
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = MSFTrucksBase[BC,year] * 
      MSFTarget[tech,BC,year];
  end

  techs = Select(Tech,(from="HDV45Gasoline",to="HDV45Propane"))
  for year in years
    MSFTrucksBase[BC,year] = sum(xMMSF[Carriage,tech,Freight,BC,year] for tech in techs)
  end
  
  techs = Select(Tech,["HDV45Electric","HDV45NaturalGas"])
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = MSFTrucksBase[BC,year] * 
      MSFTarget[tech,BC,year];
  end

  techs = Select(Tech,(from="HDV67Gasoline",to="HDV67Propane"))
  for year in years
    MSFTrucksBase[BC,year] = sum(xMMSF[Carriage,tech,Freight,BC,year] for tech in techs)
  end
  
  techs = Select(Tech,["HDV67Electric","HDV67NaturalGas"])
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = MSFTrucksBase[BC,year] * 
      MSFTarget[tech,BC,year];
  end

  techs = Select(Tech,(from="HDV8Gasoline",to="HDV8Propane"))
  for year in years
    MSFTrucksBase[BC,year] = sum(xMMSF[Carriage,tech,Freight,BC,year] for tech in techs)
  end
  
  # techs = Select(Tech,["HDV8Electric","HDV8NaturalGas"])
  techs = Select(Tech,"HDV8NaturalGas")
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = MSFTrucksBase[BC,year] * 
      MSFTarget[tech,BC,year];
  end

  techs = Select(Tech,["HDV2B3Diesel","HDV2B3Gasoline","HDV2B3Propane"]);
  HDV2B3NaturalGas = Select(Tech,"HDV2B3NaturalGas");
  HDV2B3Electric = Select(Tech,"HDV2B3Electric");
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = max(0.0,
      (xMMSF[Carriage,tech,Freight,BC,year]*(1-(MSFTarget[HDV2B3NaturalGas,BC,year]-
        MSFTarget[HDV2B3Electric,BC,year]))))
  end

  techs = Select(Tech,["HDV45Diesel","HDV45Gasoline","HDV45NaturalGas","HDV45Propane"]);
  HDV45NaturalGas = Select(Tech,"HDV45NaturalGas");
  HDV45Electric = Select(Tech,"HDV45Electric");
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = max(0.0,
      (xMMSF[Carriage,tech,Freight,BC,year]*(1-(MSFTarget[HDV45NaturalGas,BC,year]-
        MSFTarget[HDV45Electric,BC,year]))))
  end

  techs = Select(Tech,["HDV67Diesel","HDV67Gasoline","HDV67NaturalGas","HDV67Propane"]);
  HDV67NaturalGas = Select(Tech,"HDV67NaturalGas");
  HDV67Electric = Select(Tech,"HDV67Electric");
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = max(0.0,
      (xMMSF[Carriage,tech,Freight,BC,year]*(1-(MSFTarget[HDV67NaturalGas,BC,year]-
        MSFTarget[HDV67Electric,BC,year]))))
  end

  techs = Select(Tech,["HDV8Diesel","HDV8Gasoline","HDV8Propane"]);
  HDV8NaturalGas = Select(Tech,"HDV8NaturalGas");
  # HDV2B3Electric = Select(Tech,"HDV2B3Electric");
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = max(0.0,
      (xMMSF[Carriage,tech,Freight,BC,year]*(1-(MSFTarget[HDV8NaturalGas,BC,year]))))
  end

  years = collect(Yr(2031):Final);
  techs = Select(Tech,(from="HDV2B3Electric",to="HDV8Propane"))
  for year in years, tech in techs
    xMMSF[Carriage,tech,Freight,BC,year] = xMMSF[Carriage,tech,Freight,BC,Yr(2030)]
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF);
end

function PolicyControl(db)
  @info "Trans_MS_HDV_Electric_BC.jl - PolicyControl";
  TransPolicy(db);
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
