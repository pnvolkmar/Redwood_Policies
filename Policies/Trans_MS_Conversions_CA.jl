#
# Trans_MS_Conversions_CA.jl
#

using SmallModel

module Trans_MS_Conversions_CA

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
  DPL::VariableArray{5} = ReadDisk(db,"$Outpt/DPL") # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment (Years) 
  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors. ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"$Input/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xProcSwS::VariableArray{2} = ReadDisk(db,"SInput/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch

  #
  # Scratch Variables
  #
  
  CFrac::VariableArray{6} = zeros(Float64,length(Enduse),length(Tech),length(CTech),length(EC),length(Area),length(Year)) # [Enduse,Tech,CTech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
  CMSM0Max::VariableArray{5} = zeros(Float64,length(Enduse),length(CTech),length(EC),length(Area),length(Year)) # [Enduse,CTech,EC,Area,Year] Maximum Conversion Non-Price Factor ($/$)
  DPLGoal::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment Goal (Years)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Input,Outpt) = data
  (; Area,CTech,CTechs,EC) = data 
  (; Enduses) = data
  (; PI,Tech,Techs) = data
  (; CFrac,CFraction,CMSM0,CMSM0Max,CnvrtEU) = data
  (; Endogenous,DPL) = data
  (; DPLGoal,MMSM0,xProcSw,xXProcSw) = data
  
  CA = Select(Area,"CA")
  Passenger = Select(EC,"Passenger")
  years = collect(Future:Final)
  Conversion = Select(PI,"Conversion")
  
  for year in years
    xProcSw[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"$Input/xProcSw",xProcSw)
  
  for year in years, enduse in Enduses
    CnvrtEU[enduse,Passenger,CA,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)
  
  # *
  # * Conversion Opportunities
  # *
  
  for year in years, tech in Techs, enduse in Enduses
    CFraction[enduse,tech,Passenger,CA,year] = 0.0
  end
  
  for year in years, ctech in CTechs, tech in Techs, enduse in Enduses
    CFrac[enduse,tech,ctech,Passenger,CA,year] = 0.0
  end
  
  techs = Select(Tech,["LDVGasoline","LDVDiesel","LDVElectric",
  "LDVNaturalGas","LDVPropane","LDVEthanol","LDVHybrid","LDVFuelCell"])
  
  ctechs = Select(CTech,["LDVGasoline","LDVDiesel","LDVNaturalGas",
  "LDVHybrid","LDVPropane"])
  
  for year in years, tech in techs, enduse in Enduses 
    CFraction[enduse,tech,Passenger,CA,year] = 1.0
  end
  
  for year in years, ctech in ctechs, tech in techs, enduse in Enduses
    CFrac[enduse,tech,ctech,Passenger,CA,year] = 1.0
  end
  
  techs = Select(Tech,["LDTGasoline","LDTDiesel","LDTElectric",
  "LDTNaturalGas","LDTPropane","LDTEthanol","LDTHybrid","LDTFuelCell"])
  
  ctechs = Select(CTech,["LDTGasoline","LDTDiesel","LDTNaturalGas",
  "LDTHybrid","LDTPropane"])
  
  for year in years, tech in techs, enduse in Enduses
    CFraction[enduse,tech,Passenger,CA,year] = 1.0
  end
  
  for year in years, ctech in ctechs, tech in techs, enduse in Enduses
    CFrac[enduse,tech,ctech,Passenger,CA,year] = 1.0
  end
  
  WriteDisk(db,"$Input/CFraction",CFraction)
  
  # *
  # * Conversion Coefficients
  # *
  
  for enduse in Enduses,tech in Techs,ctech in CTechs,year in years
    if CFraction[enduse,tech,Passenger,CA,year] == 1.0
      CMSM0[enduse,tech,ctech,Passenger,CA,year] = MMSM0[enduse,tech,Passenger,CA,year]
    else
      CMSM0[enduse,tech,ctech,Passenger,CA,year] = -170.39
    end
    
  end
  
  #
  # Normalize Coefficients
  #
  for enduse in Enduses,ctech in CTechs,year in years
    CMSM0Max[enduse,ctech,Passenger,CA,year] = 
      maximum(CMSM0[enduse,Techs,ctech,Passenger,CA,year])
  end

  for enduse in Enduses,tech in Techs,ctech in CTechs,year in years
    CMSM0[enduse,tech,ctech,Passenger,CA,year] = 
      CMSM0[enduse,tech,ctech,Passenger,CA,year]-CMSM0Max[enduse,ctech,Passenger,CA,year]
  end
  CMSM0[abs.(CMSM0) .< 1e-8] .= 0
  WriteDisk(db,"$CalDB/CMSM0",CMSM0)
  
  #
  # Decrease lifetime to target zero market share by 2050
  # 
  techs = Select(Tech,["LDVGasoline","LDTGasoline","LDVDiesel","LDTDiesel",
  "LDVNaturalGas","LDTNaturalGas","LDVPropane","LDTPropane"])
  @. DPLGoal[Enduses,techs,Passenger,CA,years] = DPL[Enduses,techs,Passenger,CA,years]

  years = collect(Yr(2045):Yr(2050))
  for year in years, tech in techs, enduse in Enduses
    DPLGoal[enduse,tech,Passenger,CA,year] = 1.0
  end

  years = collect(Yr(2036):Yr(2044))
  for year in years, tech in techs, enduse in Enduses
      DPLGoal[enduse,tech,Passenger,CA,year] = DPLGoal[enduse,tech,Passenger,CA,year-1] +
        (DPLGoal[enduse,tech,Passenger,CA,Yr(2045)] - 
          DPLGoal[enduse,tech,Passenger,CA,Yr(2035)] )/(2045-2035)
  end
  
  # years = collect(Future:Final) # TODO Promula this should probably be for all
  # years but the PROMULA code just has 2036-2044
  for year in years, tech in techs, enduse in Enduses
    DPL[enduse,tech,Passenger,CA,year] = DPLGoal[enduse,tech,Passenger,CA,year]
  end
  
  WriteDisk(db,"$Outpt/DPL",DPL)  
end

function PolicyControl(db)
  @info "Trans_MS_Conversions_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
