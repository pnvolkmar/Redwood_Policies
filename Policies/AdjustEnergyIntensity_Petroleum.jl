#
# AdjustEnergyIntensity_Petroleum.jl
#

using SmallModel

module AdjustEnergyIntensity_Petroleum

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String
  
  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
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
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DEE::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency,from Base Case (Btu/Btu)
  DEEA::VariableArray{4} = ReadDisk(db,"$Outpt/DEEA",Last) # [Enduse,Tech,EC,Area] Average Device Efficiency,from last historical year (Btu/Btu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Maximum Device Efficiency Multiplier (Btu/Btu)
  PEE::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Process Efficiency,from Base Case ($/Btu)
  PEEA::VariableArray{4} = ReadDisk(db,"$Outpt/PEEA",Last) # [Enduse,Tech,EC,Area] Average Process Efficiency,from last historical year ($/Btu)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Process Efficiency Max. Mult. ($/Btu/($/Btu))
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB) = data
  (; Area,Areas,EC,Enduses,Nation,Techs) = data
  (; ANMap,DEE,DEEA,DEMM,PEE,PEEA,PEMM) = data
  
  # 
  # All Petroleum Refining in Canada
  # Set Efficiency Mulipliers so the Marginal Efficiency equals
  # Average Efficiency in the last historical year.
  #   
  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")], ==(1))
  years = collect(Yr(2022):Yr(2050))
  Petroleum = Select(EC,"Petroleum")
  for eu in Enduses, tech in Techs, area in cn_areas, year in years
    if PEEA[eu,tech,Petroleum,area] > 0
      @finite_math PEMM[eu,tech,Petroleum,area,year] = 
        PEMM[eu,tech,Petroleum,area,year]*PEEA[eu,tech,Petroleum,area]/
          PEE[eu,tech,Petroleum,area,year]
    end
    
  end
  
  for eu in Enduses, tech in Techs, area in cn_areas, year in years
    if DEEA[eu,tech,Petroleum,area] > 0
      @finite_math DEMM[eu,tech,Petroleum,area,year] = 
        DEMM[eu,tech,Petroleum,area,year]*DEEA[eu,tech,Petroleum,area]/
          DEE[eu,tech,Petroleum,area,year]
    end
    
  end
  
  # 
  # Temporary patch for NL to allow for TIM to run - Ian 08/29/16
  # 
  NL = Select(Area,"NL")
  years = collect(Future:Final)
  for year in years, tech in Techs, enduse in Enduses
    DEMM[enduse,tech,Petroleum,NL,year] = DEMM[enduse,tech,Petroleum,NL,Last]
  end
  
  for year in years, tech in Techs, enduse in Enduses
    PEMM[enduse,tech,Petroleum,NL,year] = PEMM[enduse,tech,Petroleum,NL,Last]
  end

  WriteDisk(db,"$CalDB/DEMM",DEMM)
  WriteDisk(db,"$CalDB/PEMM",PEMM)
end

function PolicyControl(db=DB)
  @info "AdjustEnergyIntensity_Petroleum.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
