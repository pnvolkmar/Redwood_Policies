#
# Res_MS_Conversions.jl
#

using SmallModel

module Res_MS_Conversions

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
  CTech::SetArray = ReadDisk(db,"$Input/CTechKey")
  CTechDS::SetArray = ReadDisk(db,"$Input/CTechDS")
  CTechs::Vector{Int} = collect(Select(CTech))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  PI::SetArray = ReadDisk(db,"$Input/PIKey")
  PIDS::SetArray = ReadDisk(db,"$Input/PIDS")
  PIs::Vector{Int} = collect(Select(PI))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  CFraction::VariableArray{5} = ReadDisk(db,"$Input/CFraction") # [Enduse,Tech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
  CMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/CMSM0") # [Enduse,Tech,CTech,EC,Area,Year] Conversion Market Share Multiplier ($/$)
  CnvrtEU::VariableArray{4} = ReadDisk(db,"$Input/CnvrtEU") # Conversion Switch [Enduse,EC,Area]
  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors. ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"$Input/xProcSw") # [PI,Year] Procedure on/off Switch
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch\
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; CTechs,ECs) = data 
  (; Enduses,Nation) = data
  (; PI,Techs,Years) = data
  (; ANMap,CFraction,CMSM0,CnvrtEU,Endogenous) = data
  (; MMSM0,xProcSw,xXProcSw) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)
  
  Conversion = Select(PI,"Conversion")
  
  for year in Years
    xProcSw[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"$Input/xProcSw",xProcSw)

  years = collect(Future:Final)
   
  for year in years, ec in ECs, area in areas, enduse in Enduses
    CnvrtEU[enduse,ec,area,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)

  for year in years, ec in ECs, area in areas, enduse in Enduses, tech in Techs
    CFraction[enduse,tech,ec,area,year] = 1.0
  end
  
  WriteDisk(db,"$Input/CFraction",CFraction)
  
  for year in years, ec in ECs, area in areas, enduse in Enduses, tech in Techs, ctech in CTechs
    if CFraction[enduse,tech,ec,area,year] > 0.0
      CMSM0[enduse,tech,ctech,ec,area,year] = MMSM0[enduse,tech,ec,area,year]
    else
      CMSM0[enduse,tech,ctech,ec,area,year] = -170.39
    end
    
  end
  CMSM0[abs.(CMSM0) .< 1e-8] .= 0
  WriteDisk(db,"$CalDB/CMSM0",CMSM0)
end

function PolicyControl(db)
  @info "Res_MS_Conversions.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
