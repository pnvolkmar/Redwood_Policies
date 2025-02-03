#
# Ind_Conv_Initialize.jl
#

using SmallModel

module Ind_Conv_Initialize

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
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
  CTech::SetArray = ReadDisk(db,"$Input/CTechKey")
  CTechDS::SetArray = ReadDisk(db,"$Input/CTechDS")
  CTechs::Vector{Int} = collect(Select(CTech))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  PI::SetArray = ReadDisk(db,"$Input/PIKey")
  PIDS::SetArray = ReadDisk(db,"$Input/PIDS")
  PIs::Vector{Int} = collect(Select(PI))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  CFraction::VariableArray{5} = ReadDisk(db,"$Input/CFraction") # [Enduse,Tech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
  CnvrtEU::VariableArray{4} = ReadDisk(db,"$Input/CnvrtEU") # Conversion Switch [Enduse,EC,Area,Year]
  xProcSw::VariableArray{2} = ReadDisk(db,"$Input/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xProcSwS::VariableArray{2} = ReadDisk(db,"SInput/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch

  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Areas,ECs,Enduses) = data 
  (; PI,Techs) = data
  (; CFraction,CnvrtEU,Endogenous) = data
  (; xProcSw,xProcSwS,xXProcSw) = data

  years = collect(Future:Final);
  Conversion = Select(PI,"Conversion")
  for year in years
    xProcSw[Conversion,year] = Endogenous
    xProcSwS[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end

  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"$Input/xProcSw",xProcSw)
  WriteDisk(db,"SInput/xProcSw",xProcSwS)

  for year in years, area in Areas, ec in ECs, enduse in Enduses
    CnvrtEU[enduse,ec,area,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU);

  #
  # Conversion Opportunities
  #  
  for year in years, area in Areas, ec in ECs, tech in Techs, enduse in Enduses
    CFraction[enduse,tech,ec,area,year] = 0.0
  end
  
  WriteDisk(db,"$Input/CFraction",CFraction)
end

function PolicyControl(db)
  @info "Ind_Conv_Initialize.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
