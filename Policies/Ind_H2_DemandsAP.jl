#
# Ind_H2_DemandsAP.jl
#
# Adjusted by RST 16Sept2022, keep H2 production from AP facility at 2024 levels for 
# projection period to 2050
#

using SmallModel

module Ind_H2_DemandsAP

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

  H2CD::VariableArray{1} = ReadDisk(db,"SpInput/H2CD") # [Year] Hydrogen Production Construction Delay (Years)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduses,Fuel,Tech) = data
  (; DmFracMax,DmFracMin,H2CD,xDmFrac) = data
  
  Hydrogen =      Select(Fuel,"Hydrogen")
  NaturalGas =    Select(Fuel,"NaturalGas")
  NaturalGasRaw = Select(Fuel,"NaturalGasRaw")
  RNG =           Select(Fuel,"RNG")
  StillGas =      Select(Fuel,"StillGas")

  Gas = Select(Tech,"Gas")

  Petrochemicals =    Select(EC,"Petrochemicals")
  Petroleum =         Select(EC,"Petroleum")
  OilSandsUpgraders = Select(EC,"OilSandsUpgraders")

  AB = Select(Area,"AB")
  years = collect(Yr(2024):Yr(2030))
  for year in years, enduse in Enduses
    xDmFrac[enduse,Hydrogen,     Gas,Petrochemicals,   AB,year] = 0.0567
    xDmFrac[enduse,NaturalGas,   Gas,Petrochemicals,   AB,year] = 0.9432
    xDmFrac[enduse,NaturalGasRaw,Gas,Petrochemicals,   AB,year] = 0.0000
    xDmFrac[enduse,RNG,          Gas,Petrochemicals,   AB,year] = 0.0000
    xDmFrac[enduse,StillGas,     Gas,Petrochemicals,   AB,year] = 0.0000
  
    xDmFrac[enduse,Hydrogen,     Gas,Petroleum,        AB,year] = 0.1333
    xDmFrac[enduse,NaturalGas,   Gas,Petroleum,        AB,year] = 0.1584
    xDmFrac[enduse,NaturalGasRaw,Gas,Petroleum,        AB,year] = 0.0000
    xDmFrac[enduse,RNG,          Gas,Petroleum,        AB,year] = 0.0000
    xDmFrac[enduse,StillGas,     Gas,Petroleum,        AB,year] = 0.7083
  
    xDmFrac[enduse,Hydrogen,     Gas,OilSandsUpgraders,AB,year] = 0.0080
    xDmFrac[enduse,NaturalGas,   Gas,OilSandsUpgraders,AB,year] = 0.2352
    xDmFrac[enduse,NaturalGasRaw,Gas,OilSandsUpgraders,AB,year] = 0.0000
    xDmFrac[enduse,RNG,          Gas,OilSandsUpgraders,AB,year] = 0.0000
    xDmFrac[enduse,StillGas,     Gas,OilSandsUpgraders,AB,year] = 0.7568
  end

  ecs = Select(EC,["Petrochemicals","Petroleum","OilSandsUpgraders"])
  fuels = Select(Fuel,["Hydrogen","NaturalGas","NaturalGasRaw","RNG","StillGas"])
  [xDmFrac[Enduses,fuels,Gas,ecs,AB,year] = xDmFrac[Enduses,fuels,Gas,ecs,AB,year-1] * 
    1.00 for year in Yr(2031):Final]

  DmFracMax[Enduses,fuels,Gas,ecs,AB,Yr(2024):Final] = 
    xDmFrac[Enduses,fuels,Gas,ecs,AB,Yr(2024):Final] * 1.01
  DmFracMin[Enduses,fuels,Gas,ecs,AB,Yr(2024):Final] = 
    xDmFrac[Enduses,fuels,Gas,ecs,AB,Yr(2024):Final] * 0.99

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  
  # 
  # Hydrogen Production Construction Delay
  # Preliminary value - Jeff Amlin 10/22/19
  # 
  
  years = collect(Yr(2022):Yr(2030))
  for year in years
    H2CD[year] = 1
  end
  
  years = collect(Yr(2031):Final)
  for year in years
    H2CD[year] = 2
  end
  
  WriteDisk(db,"SpInput/H2CD",H2CD)
end

function PolicyControl(db)
  @info "Ind_H2_DemandsAP.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
