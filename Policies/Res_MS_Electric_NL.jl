#
# Res_MS_Electric_NL.jl 
#

using SmallModel

module Res_MS_Electric_NL

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
  db::String
  
  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
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
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))
  
  MMSFBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/MMSF") # Market Share Fraction from Base Case ($/$) [Enduse,Tech,EC,Area]
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction (Driver/Driver)
end

function PolicyControl(db)
  @info "Res_MS_Electric_NL - PolicyControl"
  data = RControl(; db)
  (; CalDB) = data
  (; Area,ECs,Enduses,Tech,Years) = data
  (; xMMSF) = data
  
  Years = collect(Future:Final)
  NL = Select(Area,"NL")
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","LPG","Steam"])
  Electric = Select(Tech,"Electric")
  
  for year in Years, enduse in Enduses, tech in techs, ec in ECs
    xMMSF[enduse,tech,ec,NL,year] = 0
  end

  for year in Years, enduse in Enduses, ec in ECs
    xMMSF[enduse,Electric,ec,NL,year] = 1
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
end

if abspath(PROGRAM_FILE) == @__FILE__
     PolicyControl(DB)
end  
  
end



