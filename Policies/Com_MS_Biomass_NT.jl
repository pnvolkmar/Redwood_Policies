#
# Com_MS_Biomass_NT.jl - MS file based on Biomass_NT.jl Ian - 08/23/21
#
# This file models the provincial electric vehicles policies for Quebec
#
# Policy Targets for FuelShares - Jeff Amlin 5/10/16
# Updated for Transportation by Matt Lewis 5/18/16
#

using SmallModel

module Com_MS_Biomass_NT

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
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  BCMult::VariableArray{4} = ReadDisk(db,"SInput/BCMult") # [Fuel,ECC,Area,Year] Fuel Emission Multipler between Black Carbon and PM 2.5 (Tonnes/Tonnes)
  BCMultProcess::VariableArray{3} = ReadDisk(db,"SInput/BCMultProcess") # [ECC,Area,Year] Process Emission Multipler between Black Carbon and PM 2.5 (Tonnes/Tonnes)
  POCX::VariableArray{6} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,EC,Poll,Area,Year] Pollution Coefficient (Tonnes/TBtu)
  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/Economic Driver)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  BiomassTarget::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Percentage Market Share Target
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,ECC,ECCs,ECs ) = data
  (; Enduse) = data
  (; Fuel,FuelEP) = data
  (; Poll) = data
  (; Tech) = data
  (; BCMult,BCMultProcess,BiomassTarget) = data
  (; MEPOCX,POCX,xMMSF) = data

  @. BiomassTarget = 0.0

  NT = Select(Area,"NT")
  years = collect(Future:Yr(2030))
  Heat = Select(Enduse,"Heat")

  #
  # Biomass is expected to be 30% of Heat market share by 2030 per e-mail from
  # Glasha - Ian 11/03/16
  #
  for year in years
    BiomassTarget[year] = 0.3
  end

  Biomass = Select(Tech,"Biomass")
  for year in years, ec in ECs
    xMMSF[Heat,Biomass,ec,NT,year] = BiomassTarget[year]
  end
  
  years = collect(Yr(2031):Final)
  for year in years, ec in ECs
    xMMSF[Heat,Biomass,ec,NT,year] = xMMSF[Heat,Biomass,ec,NT,Yr(2030)]
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
  
  #
  ####################
  #
  
  #
  # Assign NT Biomass emissions coefficients from BC MultiFamily
  # per 11/22/16 e-mail from Lifang. Current code temporarily
  # stores this in MEPOCX from Residential sector above - Ian
  #  
  years = collect(Future:Final)
  BiomassEP = Select(FuelEP,"Biomass")
  BiomassFuel = Select(Fuel,"Biomass")
  PM25 = Select(Poll,"PM25")
  BC = Select(Area,"BC")
  WholesaleECC = Select(ECC,"Wholesale")
  MultiFamilyECC = Select(ECC,"MultiFamily")

  for ec in ECs, year in years
    POCX[Heat,BiomassEP,ec,PM25,NT,year] = MEPOCX[WholesaleECC,PM25,NT,year]
  end      

  for year in years, ecc in ECCs, ec in ECs
    if EC[ec] == ECC[ecc]
      MEPOCX[ecc,PM25,NT,year] = MEPOCX[MultiFamilyECC,PM25,BC,year]
      BCMult[BiomassFuel,ecc,NT,year] = BCMult[BiomassFuel,MultiFamilyECC,BC,year]
      BCMultProcess[ecc,NT,year] = BCMultProcess[MultiFamilyECC,BC,year]
    end
    
  end
  
  WriteDisk(DB,"$Input/POCX",POCX)
  WriteDisk(DB,"MEInput/MEPOCX",MEPOCX)
  WriteDisk(DB,"SInput/BCMult",BCMult)
  WriteDisk(DB,"SInput/BCMultProcess",BCMultProcess)
end

function PolicyControl(db=DB)
  @info "Com_MS_Biomass_NT.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
