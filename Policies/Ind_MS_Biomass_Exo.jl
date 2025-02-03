#
# Ind_MS_Biomass_Exo.jl
#

using SmallModel

module Ind_MS_Biomass_Exo

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
  PI::SetArray = ReadDisk(db,"$Input/PIKey")
  PIDS::SetArray = ReadDisk(db,"$Input/PIDS")
  PIs::Vector{Int} = collect(Select(PI))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  AMSF::VariableArray{5} = ReadDisk(db,"$Outpt/AMSF") # [Enduse,Tech,EC,Area,Year] Average Market Share
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
  xProcSw::VariableArray{2} = ReadDisk(db,"SInput/xProcSw") #[PI,Year] "Procedure on/off Switch"
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0
  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB) = data
  (; ECs,Enduse) = data 
  (; Nation,PI,Tech) = data
  (; Years) = data  
  (; AMSF,ANMap,Exogenous) = data
  (; xMMSF,xProcSw) = data

  #
  # Allow for exogneous market shares
  #  
  years = collect(Future:Final);
  MShare = Select(PI,"MShare");
  for year in years
    xProcSw[MShare,year] = Exogenous
  end

  WriteDisk(db,"SInput/xProcSw",xProcSw);
  
  #
  # Initialize most Techs to be endogenous
  #  
  @. xMMSF = -99;
  
  #
  # Biomass in Canada is exogenous
  #  
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1);

  Heat = Select(Enduse,"Heat");
  Biomass = Select(Tech,"Biomass");

  for year in Years, area in areas, ec in ECs
    xMMSF[Heat,Biomass,ec,area,year] = AMSF[Heat,Biomass,ec,area,year]
  end
  
  WriteDisk(db,"$CalDB/xMMSF",xMMSF);    
end

function PolicyControl(db)
  @info "Ind_MS_Biomass_Exo.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
