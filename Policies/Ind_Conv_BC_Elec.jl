#
# Ind_Conv_BC_Elec.jl
#

using SmallModel

module Ind_Conv_BC_Elec

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
  CMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/CMSM0") # [Enduse,Tech,CTech,EC,Area,Year] Conversion Non-Price Factor  ($/$)
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors ($/$)
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch

  # Scratch Variables
  CFrac::VariableArray{6} = zeros(Float64,length(Enduse),length(Tech),length(CTech),length(EC),length(Area),length(Year)) # [Enduse,Tech,CTech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
  CMSM0Max::VariableArray{5} = zeros(Float64,length(Enduse),length(CTech),length(EC),length(Area),length(Year)) # [Enduse,CTech,EC,Area,Year] Maximum Conversion Non-Price Factor ($/$)
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input) = data
  (; Area,CTech,CTechs) = data
  (; EC,Enduses) = data
  (; Tech,Techs) = data
  (; CFrac,CFraction,CMSM0,CMSM0Max,MMSM0) = data

  BC = Select(Area,"BC")
  ec = Select(EC,"OtherMetalMining")
  years = collect(Future:Final)

  #
  # Conversion Opportunities
  #
  for year in years, tech in Techs, enduse in Enduses
    CFraction[enduse,tech,ec,BC,year] = 0.0
  end
  for year in years, ctech in CTechs, tech in Techs, enduse in Enduses
    CFrac[enduse,tech,ctech,ec,BC,year] = 0.0
  end

  techs = Select(Tech,["Electric","Gas","Biomass","Solar","LPG","FuelCell"])
  ctechs = Select(CTech,["Gas","Coal","Oil","LPG"])
  for year in years, ctech in ctechs, tech in techs, enduse in Enduses
    CFrac[enduse,tech,ctech,ec,BC,year] = 1.0
  end

  techs = Select(Tech,["Gas","Coal","Oil","LPG"])
  for year in years, tech in techs, enduse in Enduses
    CFraction[enduse,tech,ec,BC,year] = 1.0
  end

  WriteDisk(db,"$Input/CFraction",CFraction)

  #
  # Conversion Coefficients
  #  
  for enduse in Enduses,tech in Techs,ctech in CTechs,year in years
    if CFrac[enduse,tech,ctech,ec,BC,year] == 1.0
      CMSM0[enduse,tech,ctech,ec,BC,year] = MMSM0[enduse,tech,ec,BC,year]
    else
      CMSM0[enduse,tech,ctech,ec,BC,year] = -170.39
    end
  end

  #
  # Normalize Coefficients
  #  
  for enduse in Enduses,ctech in CTechs,year in years
    CMSM0Max[enduse,ctech,ec,BC,year] = maximum(CMSM0[enduse,Techs,ctech,ec,BC,year])
  end

  for enduse in Enduses,tech in Techs,ctech in CTechs,year in years
    CMSM0[enduse,tech,ctech,ec,BC,year] = CMSM0[enduse,tech,ctech,ec,BC,year]-
      CMSM0Max[enduse,ctech,ec,BC,year]
  end

  WriteDisk(db,"$CalDB/CMSM0",CMSM0);
end

function PolicyControl(db)
  @info "Ind_Conv_BC_Elec.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
