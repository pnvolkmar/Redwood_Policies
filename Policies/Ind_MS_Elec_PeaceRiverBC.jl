#
# Ind_MS_Elec_PeaceRiverBC.jl - MS file based on 'Industrial_Elec_PeaceRiverBC.jl' 
#
# Ian - 08/23/21
#
# Target 1.5 Mt reduction in UnconventionalGasProduction
# 

using SmallModel

module Ind_MS_Elec_PeaceRiverBC

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
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  PCCN::VariableArray{4} = ReadDisk(db,"$Outpt/PCCN") # [Enduse,Tech,EC,Area] Normalized Process Capital Cost ($/mmBtu)
  PCTC::VariableArray{5} = ReadDisk(db,"$Outpt/PCTC") # [Enduse,Tech,EC,Area,Year] Process Capital Trade Off Coefficient (DLESS)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # Process Efficiency Max. Mult. ($/Btu/($/Btu)) [Enduse,Tech,EC,Area,Year]
  PEPM::VariableArray{5} = ReadDisk(db,"$Input/PEPM") # [Enduse,Tech,EC,Area,Year] Process Energy Price Mult. ($/$)
  PFPN::VariableArray{4} = ReadDisk(db,"$Outpt/PFPN") # [Enduse,Tech,EC,Area] Process Normalized Fuel Price ($/mmBtu)
  PFTC::VariableArray{5} = ReadDisk(db,"$Outpt/PFTC") # [Enduse,Tech,EC,Area,Year] Process Fuel Trade Off Coefficient
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
  
  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input,Outpt) = data
  (; Area,EC,Enduse) = data 
  (; Tech,Techs) = data
  (; PCCN,PCTC,PEMM,PEPM,PFPN,PFTC,xMMSF) = data

  #
  # Electric Process Efficiency is set equal to Natural Gas
  #

  #
  # The following lines have no impact; revisit policy. Jeff Amlin 6/6/24
  #
  # Select Area(BC)
  # Select EC(SweetGasProcessing)
  # Select Enduse(Heat)
  # Select Tech(Electric)
  # Select Year(Future-Final)
  #
  # Select Area(BC)
  # Select EC(SourGasProcessing)
  # Select Enduse(Heat)
  # Select Tech(Electric)
  # Select Year(Future-Final)
  #
  
  #
  # Write Julia code to enable adding Sweet Gas Processing and Sour Gas Processing
  # - Jeff Amlin 6/6/24
  #  
  BC = Select(Area,"BC");
  ecs = Select(EC,"UnconventionalGasProduction");
  Heat = Select(Enduse,"Heat");
  Electric = Select(Tech,"Electric")
  years = collect(Future:Final);
  Gas = Select(Tech,"Gas");

  for ec in ecs, year in years
    PCCN[Heat,Electric,ec,BC]      = PCCN[Heat,Gas,ec,BC]
    PCTC[Heat,Electric,ec,BC,year] = PCTC[Heat,Gas,ec,BC,year]
    PEMM[Heat,Electric,ec,BC,year] = PEMM[Heat,Gas,ec,BC,year]
    PEPM[Heat,Electric,ec,BC,year] = PEPM[Heat,Gas,ec,BC,year]
    PFPN[Heat,Electric,ec,BC]      = PFPN[Heat,Gas,ec,BC]
    PFTC[Heat,Electric,ec,BC,year] = PFTC[Heat,Gas,ec,BC,year]
  end

  WriteDisk(db,"$Outpt/PCCN",PCCN);
  WriteDisk(db,"$Outpt/PCTC",PCTC);
  WriteDisk(db,"$CalDB/PEMM",PEMM);
  WriteDisk(db,"$Input/PEPM",PEPM);
  WriteDisk(db,"$Outpt/PFPN",PFPN);
  WriteDisk(db,"$Outpt/PFTC",PFTC);

  #
  # Specify values for desired fuel shares (xMMSF)
  #  
  years = collect(Yr(2021):Yr(2027));

  for ec in ecs, year in years
    xMMSF[Heat,Electric,ec,BC,year] = 0.95
  end
  
  for tech in Techs, ec in ecs, year in years
    if tech != Electric
      xMMSF[Heat,tech,ec,BC,year] = xMMSF[Heat,tech,ec,BC,year]*(1-0.95)
    end
    
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Ind_MS_Elec_PeaceRiverBC - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end