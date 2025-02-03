#
# Res_MS_Biomass_NT.jl - MS file based on Biomass_NT.jl Ian - 08/23/21
#
# This file models the provincial electric vehicles policies for Quebec
#
# Policy Targets for FuelShares - Jeff Amlin 5/10/16
# Updated for Transportation by Matt Lewis 5/18/16
#

using SmallModel

module Res_MS_Biomass_NT

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
  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/Economic Driver)
  POCX::VariableArray{6} = ReadDisk(db,"$Input/POCX") # [] Pollution Coefficient (Tonnes/TBtu)
  SecMap::VariableArray{1} = ReadDisk(db,"SInput/SecMap") #[ECC]  Map Between the Sector and ECC Sets
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  BiomassTarget::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Percentage Market Share Target
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,ECC,ECs) = data
  (; Enduse,Fuel,FuelEP) = data
  (; Poll,Tech) = data
  (; BCMult,BCMultProcess,BiomassTarget,MEPOCX,POCX) = data
  (; SecMap,xMMSF) = data

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
    xMMSF[Heat,Biomass,ec,NT,year] = 0.3  # xMMSF(EU,T,EC,A,Y)=BiomassTarget(Y)
  end
  
  years = collect(Yr(2031):Final)
  for year in years, ec in ECs
    xMMSF[Heat,Biomass,ec,NT,year] = 0.3 # xMMSF(EU,T,EC,A,Y) = xMMSF(EU,T,EC,A,2030)
  end

  #
  # Assign NT Biomass emissions coefficients from BC per 11/22/16 e-mail
  # from Lifang - Ian
  # 
  years = collect(Future:Final)
  BiomassEP = Select(FuelEP,"Biomass")
  BiomassFuel = Select(Fuel,"Biomass")
  PM25 = Select(Poll,"PM25")
  BC = Select(Area,"BC")
  for year in years, ec in ECs, area in NT
    ecc = Select(ECC,EC[ec])
    # POCX[ec,PM25,area,year] = POCX[ec,PM25,BC,year]
      POCX[Heat,BiomassEP,ec,PM25,area,year] = POCX[Heat,BiomassEP,ec,PM25,BC,year]
    if SecMap[ecc] == 1
        MEPOCX[ecc,PM25,area,year] = MEPOCX[ecc,PM25,BC,year]
        BCMult[BiomassFuel,ecc,area,year] = BCMult[BiomassFuel,ecc,BC,year]
        BCMultProcess[ecc,area,year] = BCMultProcess[ecc,BC,year]
    end
    
  end

  #
  # Use MEPOCX Wholesale to store Res MultiFamily coefficient for use in
  # Commercial sector below
  #  
  Wholesale = Select(ECC,"Wholesale")
  MultiFamily = Select(EC,"MultiFamily")

  for year in years, area in NT
      MEPOCX[Wholesale,PM25,area,year] = POCX[Heat,BiomassEP,MultiFamily,PM25,BC,year]
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
  WriteDisk(DB,"$Input/POCX",POCX)
  WriteDisk(DB,"MEInput/MEPOCX",MEPOCX)
  WriteDisk(DB,"SInput/BCMult",BCMult)
  WriteDisk(DB,"SInput/BCMultProcess",BCMultProcess)
end

function PolicyControl(db)
  @info "Res_MS_Biomass_NT - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
