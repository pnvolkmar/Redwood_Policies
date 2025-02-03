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
  NaturalGas = Select(Fuel,"NaturalGas")
  NaturalGasRaw = Select(Fuel,"NaturalGasRaw")
  RNG = Select(Fuel,"RNG")
  StillGas = Select(Fuel,"StillGas")

  Gas = Select(Tech,"Gas")

  Petrochemicals =    Select(EC,"Petrochemicals")
  Petroleum =         Select(EC,"Petroleum")
  OilSandsUpgraders = Select(EC,"OilSandsUpgraders")

  AB = Select(Area,"AB")
  years = collect(Yr(2024):Yr(2030))
  for year in years
    xFsFrac[Hydrogen,     Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[NaturalGas,   Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[NaturalGasRaw,Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[RNG,          Gas,Petrochemicals,   AB,year] = 0.0000
    xFsFrac[StillGas,     Gas,Petrochemicals,   AB,year] = 0.0000
  
    xFsFrac[Hydrogen,     Gas,Petroleum,        AB,year] = 0.1993
    xFsFrac[NaturalGas,   Gas,Petroleum,        AB,year] = 0.7948
    xFsFrac[NaturalGasRaw,Gas,Petroleum,        AB,year] = 0.0000
    xFsFrac[RNG,          Gas,Petroleum,        AB,year] = 0.0000
    xFsFrac[StillGas,     Gas,Petroleum,        AB,year] = 0.0000
  
    xFsFrac[Hydrogen,     Gas,OilSandsUpgraders,AB,year] = 0.0111
    xFsFrac[NaturalGas,   Gas,OilSandsUpgraders,AB,year] = 0.9888
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
end

function PolicyControl(db)
  @info "Ind_H2_FeedstocksAP.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
