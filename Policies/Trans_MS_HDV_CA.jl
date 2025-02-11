#
# Trans_MS_HDV_CA.jl - 100% of MD/HDV sales are ZEV by 2040
#

using SmallModel

module Trans_MS_HDV_CA

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
  DPL::VariableArray{5} = ReadDisk(db,"$Outpt/DPL") # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment (Years)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
  
  # Scratch Variables
  DPLGoal::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment Goal (Years)
  MSFPVBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sum of Personal Vehicle Market Shares in Base
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Outpt) = data
  (; Area,EC,Enduse) = data 
  (; Tech,Techs) = data
  (; Years) = data
  (; xMMSF,DPL) = data
  (; DPLGoal,MSFPVBase) = data
  
  CA = Select(Area,"CA")
  Freight = Select(EC,"Freight")
  enduse = Select(Enduse,"Carriage")
  
  #
  # Assuming Freight switches to tech of same size. Small sizes
  # switch to Electric and large switch to H2 - Ian
  
  #
  # HDV2B3
  #
  techs = Select(Tech,(from="HDV2B3Gasoline",to="HDV2B3FuelCell"))
  years = collect(Yr(2040):Final)
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[enduse,tech,Freight,CA,year] for tech in Techs)
  end
  #
  HDV2B3Electric = Select(Tech,"HDV2B3Electric")
  for year in years
    xMMSF[enduse,HDV2B3Electric,Freight,CA,year] = MSFPVBase[CA,year]
  end
  #
  techs = Select(Tech,["HDV2B3Gasoline","HDV2B3Diesel","HDV2B3NaturalGas",
                       "HDV2B3Propane","HDV2B3FuelCell"])
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = 0.0
  end
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="HDV2B3Gasoline",to="HDV2B3FuelCell"))
  years = collect(Yr(2022):Yr(2039))
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = xMMSF[enduse,tech,Freight,CA,year-1]+
      (xMMSF[enduse,tech,Freight,CA,Yr(2040)]-xMMSF[enduse,tech,Freight,CA,Yr(2021)])/
        (2040-2021)
  end
  
  #
  # HDV45
  #
  techs = Select(Tech,(from="HDV45Gasoline",to="HDV45FuelCell"))
  years = collect(Yr(2040):Final)
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[enduse,tech,Freight,CA,year] for tech in Techs)
  end
  #
  HDV45Electric = Select(Tech,"HDV45Electric")
  for year in years
    xMMSF[enduse,HDV45Electric,Freight,CA,year] = MSFPVBase[CA,year]
  end
  #
  techs = Select(Tech,["HDV45Gasoline","HDV45Diesel","HDV45NaturalGas",
                       "HDV45Propane","HDV45FuelCell"])
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = 0.0
  end
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="HDV45Gasoline",to="HDV45FuelCell"))
  years = collect(Yr(2022):Yr(2039))
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = xMMSF[enduse,tech,Freight,CA,year-1]+
      (xMMSF[enduse,tech,Freight,CA,Yr(2040)]-xMMSF[enduse,tech,Freight,CA,Yr(2021)])/
        (2040-2021)
  end
  
  #
  # HDV67
  #
  techs = Select(Tech,(from="HDV67Gasoline",to="HDV67FuelCell"))
  years = collect(Yr(2040):Final)
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[enduse,tech,Freight,CA,year] for tech in Techs)
  end
  #
  HDV67FuelCell = Select(Tech,"HDV67FuelCell")
  for year in years
    xMMSF[enduse,HDV67FuelCell,Freight,CA,year] = MSFPVBase[CA,year]
  end
  #
  techs = Select(Tech,["HDV67Gasoline","HDV67Diesel","HDV67NaturalGas",
                       "HDV67Propane","HDV67Electric"])
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = 0.0
  end
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="HDV67Gasoline",to="HDV67FuelCell"))
  years = collect(Yr(2022):Yr(2039))
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = xMMSF[enduse,tech,Freight,CA,year-1]+
      (xMMSF[enduse,tech,Freight,CA,Yr(2040)]-xMMSF[enduse,tech,Freight,CA,Yr(2021)])/
        (2040-2021)
  end
  
  #
  # HDV8
  #
  techs = Select(Tech,(from="HDV8Gasoline",to="HDV8FuelCell"))
  years = collect(Yr(2040):Final)
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[enduse,tech,Freight,CA,year] for tech in Techs)
  end
  #
  HDV8FuelCell = Select(Tech,"HDV8FuelCell")
  for year in years
    xMMSF[enduse,HDV8FuelCell,Freight,CA,year] = MSFPVBase[CA,year]
  end
  #
  techs = Select(Tech,["HDV8Gasoline","HDV8Diesel","HDV8NaturalGas",
                       "HDV8Propane","HDV8Electric"])
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = 0.0
  end
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="HDV8Gasoline",to="HDV8FuelCell"))
  years = collect(Yr(2022):Yr(2039))
  for year in years, tech in techs
    xMMSF[enduse,tech,Freight,CA,year] = xMMSF[enduse,tech,Freight,CA,year-1]+
      (xMMSF[enduse,tech,Freight,CA,Yr(2040)]-xMMSF[enduse,tech,Freight,CA,Yr(2021)])/
        (2040-2021)
  end
  
  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
  
  #
  # Decrease lifetime to target zero market share by 2050
  #
  techs = Select(Tech,
    ["HDV2B3Gasoline","HDV2B3Diesel","HDV2B3NaturalGas","HDV2B3Propane","HDV2B3FuelCell",
     "HDV45Gasoline", "HDV45Diesel", "HDV45NaturalGas", "HDV45Propane", "HDV45FuelCell",
     "HDV67Gasoline", "HDV67Diesel", "HDV67NaturalGas", "HDV67Propane", "HDV67Electric",
     "HDV8Gasoline",  "HDV8Diesel",  "HDV8NaturalGas",  "HDV8Propane",  "HDV8Electric"])
  
  for year in Years, tech in techs
    DPLGoal[enduse,tech,Freight,CA,year] = DPL[enduse,tech,Freight,CA,year]
  end
  
  years = collect(Yr(2045):Yr(2050))
  for year in years, tech in techs
    DPLGoal[enduse,tech,Freight,CA,year] = 1.0
  end
  
  years = collect(Yr(2030):Yr(2044))
  for year in years, tech in techs
    DPLGoal[enduse,tech,Freight,CA,year] = DPLGoal[enduse,tech,Freight,CA,year-1]+
      (DPLGoal[enduse,tech,Freight,CA,Yr(2045)]-DPLGoal[enduse,tech,Freight,CA,Yr(2029)])/
        (2045-2029)
  end
    
  years = collect(Yr(2030):Yr(2050))
  for year in years, tech in techs
    DPL[enduse,tech,Freight,CA,year] = DPLGoal[enduse,tech,Freight,CA,year]
  end
  
  WriteDisk(db,"$Outpt/DPL",DPL)
end

function PolicyControl(db)
  @info "Trans_MS_HDV_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
