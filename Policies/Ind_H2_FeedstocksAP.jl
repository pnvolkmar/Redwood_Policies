#
# Ind_H2_FeedstocksAP.jl
#

using SmallModel

module Ind_H2_FeedstocksAP

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  FsFracMax::VariableArray{5} = ReadDisk(db,"$Input/FsFracMax") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  FsFracMin::VariableArray{5} = ReadDisk(db,"$Input/FsFracMin") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xFsFrac::VariableArray{5} = ReadDisk(db,"$Input/xFsFrac") # [Fuel,Tech,EC,Area,Year] Feedstock Demands Fuel/Tech Split (Fraction)

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Fuel) = data 
  (; Tech,Years) = data
  (; xFsFrac,FsFracMin,FsFracMax) = data
  
  Hydrogen = Select(Fuel,"Hydrogen")
  LPG = Select(Fuel,"LPG")
  NaturalGas = Select(Fuel,"NaturalGas")
  NaturalGasRaw = Select(Fuel,"NaturalGasRaw")
  RNG = Select(Fuel,"RNG")
  StillGas = Select(Fuel,"StillGas")

  Gas = Select(Tech,"Gas")

  Petrochemicals =    Select(EC,"Petrochemicals")
  Petroleum =         Select(EC,"Petroleum")
  OilSandsUpgraders = Select(EC,"OilSandsUpgraders")

  AB = Select(Area,"AB")
  #
  # Originally AirProducts was scheduled to come online in 2024. It appears that this is no longer the case
  # and that expected timeline for the completion of the project has been pushed back.
  # With this in mind the original year that hydrogen feedstock demand will be accepted in Alberta is in
  # 2025. This assumption may need to be revisited throughout the Ref24 update cycle.
  # 
  years = collect(Yr(2025):Yr(2030))
  for year in years
    xFsFrac[Hydrogen,     Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[NaturalGas,   Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[NaturalGasRaw,Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[RNG,          Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[StillGas,     Gas,Petrochemicals,   AB,year] = 0.0000
  
    xFsFrac[Hydrogen,     Gas,Petroleum,        AB,year] = 0.5861
    xFsFrac[NaturalGas,   Gas,Petroleum,        AB,year] = 0.4122
    xFsFrac[NaturalGasRaw,Gas,Petroleum,        AB,year] = 0.0000
    xFsFrac[RNG,          Gas,Petroleum,        AB,year] = 0.0000
    xFsFrac[StillGas,     Gas,Petroleum,        AB,year] = 0.0000
  
    xFsFrac[Hydrogen,     Gas,OilSandsUpgraders,AB,year] = 0.2000
    xFsFrac[NaturalGas,   Gas,OilSandsUpgraders,AB,year] = 0.8000
    xFsFrac[NaturalGasRaw,Gas,OilSandsUpgraders,AB,year] = 0.0000
    xFsFrac[RNG,          Gas,OilSandsUpgraders,AB,year] = 0.0000
    xFsFrac[StillGas,     Gas,OilSandsUpgraders,AB,year] = 0.0000
  end

  ecs = Select(EC,["Petrochemicals","Petroleum","OilSandsUpgraders"])
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas"])
  [xFsFrac[fuels,Gas,ecs,AB,year] = xFsFrac[fuels,Gas,ecs,AB,year-1] * 
    1.00 for year in Yr(2031):Final]

  FsFracMax[fuels,Gas,ecs,AB,Years] = xFsFrac[fuels,Gas,ecs,AB,Years]
  FsFracMin[fuels,Gas,ecs,AB,Years] = xFsFrac[fuels,Gas,ecs,AB,Years]

  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  #
  # Process multiple facilities with specific fuel fraction profiles
  #
  
  # Irving Oil Refinery in NB: data from NRCan
  area = Select(Area,"NB") 
  ec = Select(EC,"Petroleum")
  tech = Select(Tech,"Gas")
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas"])
  
  # Set 2024 fractions for NB facility
  xFsFrac[Hydrogen,tech,ec,area,Yr(2024)] = 0.0392
  xFsFrac[NaturalGas,tech,ec,area,Yr(2024)] = 0.9608
  xFsFrac[NaturalGasRaw,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[RNG,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[StillGas,tech,ec,area,Yr(2024)] = 0.0000
  
  # Apply 2024 values through 2030
  years = collect(Yr(2025):Yr(2030))
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,Yr(2024)]
  end
  
  # Keep constant post-2030
  years = collect(Yr(2031):Final)
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year-1]*1.00
  end
  
  # Set min/max constraints
  for year in Years, fuel in fuels
    FsFracMax[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
    FsFracMin[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  
  # Varennes Biofuel Facility in QC 
  # This facility falls under the OtherChemicals NAICS classification
  area = Select(Area,"QC")
  ec = Select(EC,"OtherChemicals")
  tech = Select(Tech,"LPG")
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas","LPG"])
  
  # Set 2026 fractions for QC facility
  xFsFrac[Hydrogen,tech,ec,area,Yr(2026)] = 0.1632
  xFsFrac[NaturalGas,tech,ec,area,Yr(2026)] = 0.0000  
  xFsFrac[NaturalGasRaw,tech,ec,area,Yr(2026)] = 0.0000
  xFsFrac[RNG,tech,ec,area,Yr(2026)] = 0.0000
  xFsFrac[StillGas,tech,ec,area,Yr(2026)] = 0.0000
  xFsFrac[LPG,tech,ec,area,Yr(2026)] = 0.8168
  
  # Apply declining factor through 2030
  years = collect(Yr(2027):Yr(2030))
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,Yr(2026)]*0.985
  end
  
  # Continue decline post-2030
  years = collect(Yr(2031):Final)
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year-1]*0.982
  end
  
  # Set min/max constraints
  for year in Years, fuel in fuels
    FsFracMax[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
    FsFracMin[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  
  # Braya Facility in NL
  # This facility falls under the OtherChemicals NAICS classification
  area = Select(Area,"NL")
  ec = Select(EC,"OtherChemicals") 
  tech = Select(Tech,"LPG")
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas","LPG"])
  
  # Set 2024 fractions for NL facility
  xFsFrac[Hydrogen,tech,ec,area,Yr(2024)] = 0.9674
  xFsFrac[NaturalGas,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[NaturalGasRaw,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[RNG,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[StillGas,tech,ec,area,Yr(2024)] = 0.0000
  xFsFrac[LPG,tech,ec,area,Yr(2024)] = 0.0126
  
  # Apply 2024 values through 2030
  years = collect(Yr(2025):Yr(2030))
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,Yr(2024)]
  end
  
  # Keep constant post-2030
  years = collect(Yr(2031):Final)
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year-1]*1.00
  end
  
  # Set min/max constraints
  for year in Years, fuel in fuels
    FsFracMax[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
    FsFracMin[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  
  # SK OtherChemicals Facility
  area = Select(Area,"SK")
  ec = Select(EC,"OtherChemicals")
  tech = Select(Tech,"LPG")
  fuels = Select(Fuel,["Hydrogen","LPG"])
  
  # Set 2030 fractions for SK facility
  xFsFrac[Hydrogen,tech,ec,area,Yr(2030)] = 0.3122
  xFsFrac[LPG,tech,ec,area,Yr(2030)] = 0.6742
  
  # Keep constant post-2030
  years = collect(Yr(2031):Final)
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year-1]
  end
  
  # Set min/max constraints
  for year in Years, fuel in fuels
    FsFracMax[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
    FsFracMin[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  
  # QC Petroleum Facility
  area = Select(Area,"QC")
  ec = Select(EC,"Petroleum")
  tech = Select(Tech,"Gas")
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas","LPG"])
  
  # Set 2025 fractions for QC facility
  xFsFrac[Hydrogen,tech,ec,area,Yr(2025)] = 0.1069
  xFsFrac[NaturalGas,tech,ec,area,Yr(2025)] = 0.8931
  xFsFrac[NaturalGasRaw,tech,ec,area,Yr(2025)] = 0.0000
  xFsFrac[RNG,tech,ec,area,Yr(2025)] = 0.0000
  xFsFrac[StillGas,tech,ec,area,Yr(2025)] = 0.0000
  xFsFrac[LPG,tech,ec,area,Yr(2025)] = 0.0000
  
  # Apply 2025 values through 2030
  years = collect(Yr(2026):Yr(2030))
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,Yr(2025)]
  end
  
  # Keep constant post-2030
  years = collect(Yr(2031):Final)
  for year in years, fuel in fuels
    xFsFrac[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year-1]*1.00
  end
  
  # Set min/max constraints
  for year in Years, fuel in fuels
    FsFracMax[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
    FsFracMin[fuel,tech,ec,area,year] = xFsFrac[fuel,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
end

function PolicyControl(db)
  @info "Ind_H2_FeedstocksAP.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
