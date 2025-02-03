#
# Trans_MS_Conversions.jl
#

using SmallModel

module Trans_MS_Conversions

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
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors. ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"$Input/xProcSw") # [PI,Year] Procedure on/off Switch
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch

  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  
  #
  # Scratch Variables
  #
  
  CFrac::VariableArray{6} = zeros(Float64,length(Enduse),length(Tech),length(CTech),length(EC),length(Area),length(Year)) # [Enduse,Tech,CTech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Input) = data
  (; CTechs,EC) = data 
  (; Enduses,Nation) = data
  (; PI,Techs) = data
  (; ANMap,CFraction,CMSM0,CnvrtEU,Endogenous,MMSM0) = data
  (; xProcSw,xXProcSw) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)
  
  Conversion = Select(PI,"Conversion")
  years = collect(Future:Final)
  for year in years
    xProcSw[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end

  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"$Input/xProcSw",xProcSw)

  Passenger = Select(EC,"Passenger")

  for year in years, area in areas, enduse in Enduses
    CnvrtEU[enduse,Passenger,area,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)

  for year in years, area in areas, enduse in Enduses, tech in Techs, ctech in CTechs
    if CFraction[enduse,tech,Passenger,area,year] > 0.0
      CMSM0[enduse,tech,ctech,Passenger,area,year] = MMSM0[enduse,tech,Passenger,area,year]
    else
      CMSM0[enduse,tech,ctech,Passenger,area,year] = -170.39
    end
    
  end
  
  WriteDisk(db,"$CalDB/CMSM0",CMSM0)
end

function PolicyControl(db)
  @info "Trans_MS_Conversions.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
