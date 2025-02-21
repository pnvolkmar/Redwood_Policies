#
# Com_MS_ConvElectric_CA.jl - Existing commercial buildings:  
# 80% of appliance sales are electric by 2030 and 100% of appliance 
# sales are electric by 2045. Appliances are replaced at end of life
#

using SmallModel

module Com_MS_ConvElectric_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
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
  MMSM02021::VariableArray{4} = ReadDisk(db,"$CalDB/MMSM0",Yr(2021)) # [Enduse,Tech,EC,Area] Non-price Factors. ($/$)
  xCMSF::VariableArray{6} = ReadDisk(db,"$Input/xCMSF") # [Enduse,Tech,CTech,EC,Area,Year] Conversion Market Share by Device ($/$)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"SInput/xProcSw") #[PI,Year] "Procedure on/off Switch"
  xXProcSw::VariableArray{2} = ReadDisk(db,"$Input/xXProcSw") # [PI,Year] Procedure on/off Switch
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0
  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; Area,CTechs,ECs) = data 
  (; Enduse,Enduses) = data
  (; PI,Tech,Years) = data
  (; CFraction,CMSM0,CnvrtEU,Endogenous,Exogenous) = data
  (; MMSM02021,xCMSF,xMMSF) = data
  (; xProcSw,xXProcSw) = data
  
  CA = Select(Area,"CA")
  Conversion = Select(PI,"Conversion")
  for year in Years
    xProcSw[Conversion,year] = Endogenous
    xXProcSw[Conversion,year] = Endogenous
  end
  
  WriteDisk(db,"$Input/xXProcSw",xXProcSw)
  WriteDisk(db,"SInput/xProcSw",xProcSw)

  # *
  # * Apply exogenous conversions to target Tech. Use CMSM0 to reduce
  # * other conversion market shares
  # *
  
  years = collect(Future:Final)
  for year in years, ec in ECs, enduse in Enduses
    CnvrtEU[enduse,ec,CA,year] = Exogenous
  end
  
  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)
  
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","LPG"])
  for year in years, ec in ECs, tech in techs, enduse in Enduses
    CFraction[enduse,tech,ec,CA,year] = 1.0
  end
  
  WriteDisk(db,"$Input/CFraction",CFraction)

  #
  # Base initial CMSM0 on MMSM0 in 2021, before it is adjusted by marginal
  # market share policies in CMB case
  #  
  for year in years, tech in techs, enduse in Enduses, ec in ECs, ctech in CTechs       
    if CFraction[enduse,tech,ec,CA,year] == 1.0
      CMSM0[enduse,tech,ctech,ec,CA,year] = MMSM02021[enduse,tech,ec,CA]
    else
      CMSM0[enduse,tech,ctech,ec,CA,year] = -170.39
    end       
    
  end
  CMSM0[abs.(CMSM0) .< 1e-8] .= 0
  WriteDisk(db,"$CalDB/CMSM0",CMSM0)
  
  # *
  # * Space Heat - Assume switch to Heat Pump
  # *
  
  Heat = Select(Enduse,"Heat")
  years = collect(Yr(2030):Final)
  HeatPump = Select(Tech,"HeatPump")
  for year in years, ec in ECs, ctech in CTechs
    xCMSF[Heat,HeatPump,ctech,ec,CA,year] = 0.8
  end
  
  years = collect(Yr(2045):Final)
  for year in years, ec in ECs, ctech in CTechs
    xCMSF[Heat,HeatPump,ctech,ec,CA,year] = 1.0
  end
  
  #
  # Interpolate from 2021
  #  
  for ec in ECs, ctech in CTechs
    xCMSF[Heat,HeatPump,ctech,ec,CA,Yr(2021)] = xMMSF[Heat,HeatPump,ec,CA,Yr(2021)]
  end
  
  years = collect(Yr(2022):Yr(2029))
  for ctech in CTechs, ec in ECs, year in years
    xCMSF[Heat,HeatPump,ctech,ec,CA,year] = xCMSF[Heat,HeatPump,ctech,ec,CA,year-1]+
      (xCMSF[Heat,HeatPump,ctech,ec,CA,Yr(2030)]-
        xCMSF[Heat,HeatPump,ctech,ec,CA,Yr(2021)])/(2030-2021)
  end
  
  years = collect(Yr(2031):Yr(2044))
  for ctech in CTechs, ec in ECs, year in years
    xCMSF[Heat,HeatPump,ctech,ec,CA,year] = xCMSF[Heat,HeatPump,ctech,ec,CA,year-1]+
      (xCMSF[Heat,HeatPump,ctech,ec,CA,Yr(2045)]-
        xCMSF[Heat,HeatPump,ctech,ec,CA,Yr(2030)])/(2045-2030)
  end
  
  enduses = Select(Enduse,["HW","OthSub"])
  Electric = Select(Tech,"Electric")
  
  years = collect(Yr(2030):Final)
  for year in years, ec in ECs, ctech in CTechs, enduse in enduses
    xCMSF[enduse,Electric,ctech,ec,CA,year] = 0.8
  end
  
  years = collect(Yr(2045):Final)
  for year in years, ec in ECs, ctech in CTechs, enduse in enduses
    xCMSF[enduse,Electric,ctech,ec,CA,year] = 1.0
  end
  
  #
  # Interpolate from 2021
  #  
  for ec in ECs, ctech in CTechs, enduse in enduses
    xCMSF[enduse,Electric,ctech,ec,CA,Yr(2021)] = 
      xMMSF[enduse,Electric,ec,CA,Yr(2021)]
  end
  
  years = collect(Yr(2022):Yr(2029))
  for ctech in CTechs, ec in ECs, year in years, enduse in enduses
    xCMSF[enduse,Electric,ctech,ec,CA,year] = 
      xCMSF[enduse,Electric,ctech,ec,CA,year-1]+
        (xCMSF[enduse,Electric,ctech,ec,CA,Yr(2030)]-
          xCMSF[enduse,Electric,ctech,ec,CA,Yr(2021)])/(2030-2021)
  end
  
  years = collect(Yr(2031):Yr(2044))
  for ctech in CTechs, ec in ECs, year in years, enduse in enduses
    xCMSF[enduse,Electric,ctech,ec,CA,year] = 
      xCMSF[enduse,Electric,ctech,ec,CA,year-1]+
        (xCMSF[enduse,Electric,ctech,ec,CA,Yr(2045)]-
          xCMSF[enduse,Electric,ctech,ec,CA,Yr(2030)])/(2045-2030)
  end

WriteDisk(db,"$Input/xCMSF",xCMSF)
end

function PolicyControl(db)
  @info "Com_MS_ConvElectric_CA.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
