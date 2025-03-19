#
# Com_MS_NewElectric_CA.jl - New residential and commercial 
# buildings:  All electric appliances beginning 2026 (residential) 
# and 2029 (commercial)
#

using SmallModel

module Com_MS_NewElectric_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
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

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB) = data
  (; Area,ECs,Enduse) = data 
  (; Tech,Techs) = data
  (; xMMSF) = data
  
  CA = Select(Area,"CA")
    
  #
  # Space Heat - Assume switch to Heat Pump
  #  
  Heat = Select(Enduse,"Heat")
  years = collect(Yr(2029):Final)
  HeatPump = Select(Tech,"HeatPump")
  for year in years, ec in ECs
    xMMSF[Heat,HeatPump,ec,CA,year] = 1.0
  end
  
  techs = Select(Tech,!=("HeatPump"))
  for year in years, ec in ECs, tech in techs
    xMMSF[Heat,tech,ec,CA,year] = 0.0    
  end
  
  #
  # Interpolate from 2021
  #  
  years = collect(Yr(2022):Yr(2028))
  for tech in Techs, ec in ECs, year in years
    xMMSF[Heat,tech,ec,CA,year] = xMMSF[Heat,tech,ec,CA,year-1]+
      (xMMSF[Heat,tech,ec,CA,Yr(2029)]-xMMSF[Heat,tech,ec,CA,Yr(2021)])/
        (2029-2021)
  end
  

  # *
  # * Water Heat and OthSub switch to Electric
  # *
  
  enduses = Select(Enduse,["HW","OthSub"])
  Electric = Select(Tech,"Electric")
  
  years = collect(Yr(2029):Final)
  for year in years, ec in ECs, enduse in enduses
    xMMSF[enduse,Electric,ec,CA,year] = 1.0
  end
  
  for year in years, ec in ECs, tech in Techs
    if tech != "Electric"
      xMMSF[Heat,tech,ec,CA,year] = 0.0
    end
    
  end
  
  years = collect(Yr(2022):Yr(2028))
  for tech in Techs, ec in ECs, year in years, enduse in enduses
    xMMSF[enduse,Electric,ec,CA,year] = xMMSF[enduse,Electric,ec,CA,year-1]+
      (xMMSF[enduse,Electric,ec,CA,Yr(2029)]-xMMSF[enduse,Electric,ec,CA,Yr(2021)])/
        (2029-2021)
  end
  
  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
  end

function PolicyControl(db)
  @info ("Com_MS_NewElectric_CA.jl - PolicyControl")
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
