#
# Res_MS_ConvElectric_CA.jl - Existing residential buildings: 80%
# of appliance sales are electric by 2030 and 100% of appliance sales
# are electric by 2035 Appliances are replaced at end of life.
#

using SmallModel

module Res_MS_ConvElectric_CA

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
  CnvrtEU::VariableArray{4} = ReadDisk(db,"$Input/CnvrtEU") # Conversion Switch [Enduse,EC,Area,Year]
  DPL::VariableArray{5} = ReadDisk(db,"$Outpt/DPL") # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment (Years)
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors. ($/$)
  xCMSF::VariableArray{6} = ReadDisk(db,"$Input/xCMSF") # [Enduse,Tech,CTech,EC,Area,Year] Conversion Market Share by Device ($/$)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"$Input/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xProcSwS::VariableArray{2} = ReadDisk(db,"SInput/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch

  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0

  # Scratch Variables
  DPLGoal::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment Goal (Years)
  LnInfinity::Float64 = 85.19565 # Value from Promula
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input,Outpt) = data
  (; Area,CTechs,ECs) = data
  (; Enduse,Enduses) = data
  (; PI,Tech,Techs,Years) = data
  (; CFraction,CMSM0,CnvrtEU,DPL,DPLGoal,LnInfinity) = data
  (; Endogenous,Exogenous,MMSM0,xCMSF,xMMSF,xProcSw,xProcSwS,xXProcSw) = data

  CA = Select(Area,"CA")

  Conversion = Select(PI,"Conversion")

  for year in Years
    xProcSw[Conversion,year] = Endogenous
    xProcSwS[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end

  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"$Input/xProcSw",xProcSw)
  WriteDisk(db,"SInput/xProcSw",xProcSwS)

  #
  # Apply exogenous conversions to target Tech. Use CMSM0 to reduce
  # other conversion market shares
  #  
  years = collect(Future:Final)
  for year in years, ec in ECs, enduse in Enduses
    CnvrtEU[enduse,ec,CA,year] = Exogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)

  techs = Select(Tech,["Gas","Coal","Oil","Biomass","LPG"]);
  for year in years, ec in ECs, tech in techs, enduse in Enduses
    CFraction[enduse,tech,ec,CA,year] = 1.0
  end
  
  WriteDisk(db,"$Input/CFraction",CFraction);

  #
  # Base initial CMSM0 on MMSM0 in 2021, before it is adjusted by marginal
  # market share policies in CMB case
  # 
  years = collect(Future:Final)
  for enduse in Enduses, tech in Techs, ctech in CTechs, ec in ECs, year in years
    if CFraction[enduse,tech,ec,CA,year] == 1
      CMSM0[enduse,tech,ctech,ec,CA,year] = MMSM0[enduse,tech,ec,CA,Yr(2021)]
    else 
      CMSM0[enduse,tech,ctech,ec,CA,year] = -2*LnInfinity
    end
    
  end
  CMSM0[abs.(CMSM0) .< 1e-8] .= 0
  WriteDisk(db,"$CalDB/CMSM0",CMSM0);

  #
  # Space Heat - Assume switch to Heat Pump
  #
  enduses = Select(Enduse,"Heat")
  tech = Select(Tech,"HeatPump")
  #
  for enduse in enduses, ctech in CTechs, ec in ECs
    years = Yr(2030)
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = 0.8
    end
    
    years = collect(Yr(2035):Final)
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = 1.0
    end   
  end
    
  #
  # Interpolate from 2021
  #  
  for enduse in enduses, ctech in CTechs, ec in ECs
    xCMSF[enduse,tech,ctech,ec,CA,Yr(2021)] = xMMSF[enduse,tech,ec,CA,Yr(2021)]
    years = collect(Yr(2022):Yr(2029))
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = xCMSF[enduse,tech,ctech,ec,CA,year-1]+
        ((xCMSF[enduse,tech,ctech,ec,CA,Yr(2030)]-
          xCMSF[enduse,tech,ctech,ec,CA,Yr(2021)])/(2030-2021))
    end
    
    years = collect(Yr(2031):Yr(2034));
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = xCMSF[enduse,tech,ctech,ec,CA,year-1] +
        ((xCMSF[enduse,tech,ctech,ec,CA,Yr(2035)]-
          xCMSF[enduse,tech,ctech,ec,CA,Yr(2030)])/(2035-2030))
    end
    
  end

  #
  # Water Heat and OthSub switch to Electric
  #
  tech = Select(Tech,"Electric")
  enduses = Select(Enduse,["HW","OthSub"])
  #
  for enduse in enduses, ctech in CTechs, ec in ECs
    years = Yr(2030)
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = 0.8
    end
    
    years = collect(Yr(2035):Final)
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = 1.0
    end  
  end
  
  #
  # Interpolate from 2021
  #   
  for enduse in enduses, ctech in CTechs, ec in ECs
    xCMSF[enduse,tech,ctech,ec,CA,Yr(2021)] = xMMSF[enduse,tech,ec,CA,Yr(2021)]
    years = collect(Yr(2022):Yr(2029))
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = xCMSF[enduse,tech,ctech,ec,CA,year-1]+
        ((xCMSF[enduse,tech,ctech,ec,CA,Yr(2030)]-
          xCMSF[enduse,tech,ctech,ec,CA,Yr(2021)])/(2030-2021))
    end
    
    years = collect(Yr(2031):Yr(2034));
    for year in years
      xCMSF[enduse,tech,ctech,ec,CA,year] = xCMSF[enduse,tech,ctech,ec,CA,year-1] +
        ((xCMSF[enduse,tech,ctech,ec,CA,Yr(2035)]-
          xCMSF[enduse,tech,ctech,ec,CA,Yr(2030)])/(2035-2030))
    end
    
  end

  WriteDisk(db,"$Input/xCMSF",xCMSF);

  #
  # Decrease lifetime to target zero market share by 2050
  #  
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","LPG"])
  #
  for enduse in Enduses, tech in techs, ec in ECs
  
    for year in Years
      DPLGoal[enduse,tech,ec,CA,year] = DPL[enduse,tech,ec,CA,year]
    end
  
    years = collect(Yr(2045):Yr(2050))
    for year in years
      DPLGoal[enduse,tech,ec,CA,year] = 1.0
    end

    years = collect(Yr(2036):Yr(2044))
    for year in years
      DPLGoal[enduse,techs,ec,CA,year] = DPLGoal[enduse,techs,ec,CA,year-1] +
        ((DPLGoal[enduse,techs,ec,CA,Yr(2045)]-DPLGoal[enduse,techs,ec,CA,Yr(2035)])/
          (2045-2035))
    end
    
    for year in years
      DPL[enduse,tech,ec,CA,year] = DPLGoal[enduse,tech,ec,CA,year]
    end  
    
  end

  WriteDisk(db,"$Outpt/DPL",DPL)
end

function PolicyControl(db)
  @info "Res_MS_ConvElectric_CA.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
     PolicyControl(DB)
end

end
