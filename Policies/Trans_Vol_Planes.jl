#
# Trans_Vol_Planes.jl
#
# This file implements the voluntary emission reduction initiatives for planes
# Domestic aviation has seen annual improvements of energy demand per
# revenue tonne km of 1.9% between 2005-2019 and 2.25% annual improvements
# between 2019 and 2023. This is a combination of fuel efficiency and 
# operational efficiency, which is difficult to unpack. With continued gains
# in fuel efficiency and fleet turnover, improvements in efficiency are expected
# to continue into the forseable future. Set it to 1.6% annual gains.
# For additional measures, there are no policies or commitments beings considered.
# Christian Martin - CSED - ECCC - Aug 28, 2024
# This policy is intended to reduce emissions from Foreign Transportation as well as domestic.
# Policy file implemented by Matt Lewis, Aug 30, 2024
#

using SmallModel

module Trans_Vol_Planes

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
  
  #
  # Planes
  #  
  techs = Select(Tech,["PlaneJetFuel","PlaneGasoline"])
  for area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,Future] = DEEBase[enduse,tech,ec,area,Last]*1.06
  end
  
  years = collect(FutureY:Final)
  for year in years, area in areas, ec in ECs, tech in techs
    DEStdP[enduse,tech,ec,area,year] = DEStdP[enduse,tech,ec,area,year-1]*1.016
  end
  
  year = Future
  for area in areas, ec in ECs, tech in techs  
    @finite_math  DEMM[enduse,tech,ec,area,year] = 
      DEMM[enduse,tech,ec,area,year-1]*DEStdP[enduse,tech,ec,area,year]/
      DEEBase[enduse,tech,ec,area,Last]
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
  @info "Trans_Vol_Planes.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
