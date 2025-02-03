#
# Trans_MS_LDV_CA.jl - Executive Order N-79-20: 100% of
# LDV sales are ZEV by 2035
#

using SmallModel

module Trans_MS_LDV_CA

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
  MSFPVBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sum of Personal Vehicle Market Shares in Base
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC) = data 
  (; Tech) = data
  (; xMMSF) = data
  (; MSFPVBase) = data
  
  #
  # Baseline MarketShare for Personal Vehicles
  #
  # Assuming this policy covers E2020 LDT techs. Target is 100% by
  # 2035 split using ratio of LDV/LDV Techs in Base. Assuming switch
  # to Electric, leaving any existing H2 vehicles out of policy for 
  # now - Ian
  #
  # LDV
  #  
  CA = Select(Area,"CA")
  Passenger = Select(EC,"Passenger")
  
  techs = Select(Tech,(from="LDVGasoline",to="LDVHybrid"))
  years = collect(Yr(2035):Final)
  
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[1,tech,Passenger,CA,year] for tech in techs)
  end
  
  LDVElectric = Select(Tech,"LDVElectric")
  
  for year in years
    xMMSF[1,LDVElectric,Passenger,CA,year] = MSFPVBase[CA,year]
  end
  
  techs = Select(Tech,["LDVGasoline","LDVDiesel","LDVNaturalGas",
    "LDVPropane","LDVEthanol","LDVHybrid"])
  
    for tech in techs, year in years
      xMMSF[1,tech,Passenger,CA,year] = 0
    end
 
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="LDVGasoline",to="LDVHybrid"))
  years = collect(Yr(2022):Yr(2034))
    
  for tech in techs, year in years
    xMMSF[1,tech,Passenger,CA,year] = xMMSF[1,tech,Passenger,CA,year-1]+
      (xMMSF[1,tech,Passenger,CA,Yr(2035)]-xMMSF[1,tech,Passenger,CA,Yr(2021)])/
        (2035-2021)
  end

  #
  # LDT
  #
  years = collect(Yr(2035):Final)
  techs = Select(Tech,(from="LDTGasoline",to="LDTHybrid"))
  
  for year in years
    MSFPVBase[CA,year] = sum(xMMSF[1,tech,Passenger,CA,year] for tech in techs)
  end
  
  LDTElectric = Select(Tech,"LDTElectric")
  
  for year in years
    xMMSF[1,LDTElectric,Passenger,CA,year] = MSFPVBase[CA,year]
  end
  
  techs = Select(Tech,["LDTGasoline","LDTDiesel","LDTNaturalGas","LDTPropane",
  "LDTEthanol","LDTHybrid"])
  
  for tech in techs, year in years
    xMMSF[1,tech,Passenger,CA,year] = 0
  end
  
  #
  # Interpolate from 2021
  #
  techs = Select(Tech,(from="LDTGasoline",to="LDTHybrid"))
  years = collect(Yr(2022):Yr(2034))
  
  for tech in techs, year in years
    xMMSF[1,tech,Passenger,CA,year] = xMMSF[1,tech,Passenger,CA,year-1]+
      (xMMSF[1,tech,Passenger,CA,Yr(2035)]-xMMSF[1,tech,Passenger,CA,Yr(2021)])/
        (2035-2021)
  end
   
  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)  
end

function PolicyControl(db)
  @info ("Trans_MS_LDV_CA.jl - PolicyControl")
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
