#
# Trans_Vol_Rail.jl
#
# An MOU was renewed between Transport Canada and the Railway Association of Canada December 2023.
# Class 1 railway intensity based 2030 targets provided by TC (Christian Martin and Jacob McBane).
# CPKC 38.3% emissions intensity reductions from 2019
# CN 43% emissions intensity reductions from 2018.
# Track share used to weight targets.
# Brock Batey - September 20, 2024.
#

using SmallModel

module Trans_Vol_Rail

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String
  
  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name
  FutureY=Future+1
  
  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  
  DEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency in Base Case (Mile/mmBtu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Maximum Device Efficiency Multiplier (Btu/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standards Policy (Btu/Btu)
 end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduse) = data
  (; Tech) = data
  (; DEEBase,DEMM,DEStdP,FutureY) = data
  
  FutureY = Future+1
  
  areas = Select(Area,(from = "ON",to = "NU"))
  enduse = Select(Enduse,"Carriage")
  
  techs = Select(Tech,"TrainDiesel")
  
  year = Yr(2023)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063
  end
  
  year = Yr(2024)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063
  end

  year = Yr(2025)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063
  end

  year = Yr(2026)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063*1.063
  end

  year = Yr(2027)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063*1.063*1.063
  end

  year = Yr(2028)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063*1.063*1.063*1.063
  end

  year = Yr(2029)
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063*1.063*1.063*1.063*1.063
  end
  years = collect(Yr(2030):Final)
  for year in years, area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEEBase[enduse,tech,ec,area,Last]*1.063*1.063*1.063*1.063*1.063*1.063*1.063*1.063
  end
  
  year = Future
  for area in areas, ec in ECs, tech in techs 
    @finite_math DEMM[enduse,tech,ec,area,year] = 
      DEMM[enduse,tech,ec,area,year-1]*DEStdP[enduse,tech,ec,area,year]/
        DEEBase[enduse,tech,ec,area,year-1]
  end
     
  years = collect(FutureY:Final)   
  for area in areas, ec in ECs, tech in techs, year in years   
    @finite_math DEMM[enduse,tech,ec,area,year] = 
      DEMM[enduse,tech,ec,area,year-1]*DEStdP[enduse,tech,ec,area,year]/
        DEStdP[enduse,tech,ec,area,year-1]
  end
      
  WriteDisk(db,"$Input/DEStdP",DEStdP)
  WriteDisk(db,"$CalDB/DEMM",DEMM) 
end

function PolicyControl(db)
  @info "Trans_Vol_Rail.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
