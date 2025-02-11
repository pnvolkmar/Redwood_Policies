#
# Trans_MarineOffRoad_CA.jl - 100% of cargo handling equipment (CHE)
# is zero-emission by 2037 100% of drayage trucks are zero emission
# by 2035
#

using SmallModel

module Trans_MarineOffRoad_CA

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
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  # Scratch Variables
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,EC) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMin,xDmFrac) = data

  CA = Select(Area,"CA")

  #
  ########################
  #
  # Foreign Freight
  # I added Freight. In California all OffRoad is in Foreign Passenger, not Foreign Freight.
  # 09/20/23 R.Levesque
  #
  ecs = Select(EC,["ForeignFreight","Freight"])

  OffRoad = Select(Tech,"OffRoad")
  years = collect(Yr(2035):Final)

  Electric = Select(Fuel,"Electric")
  for year in years, ec in ecs
    DmFracMin[1,Electric,OffRoad,ec,CA,year] = 1.0
  end

  #
  # Interpolate from 2021
  #
  years = collect(Yr(2022):Yr(2034))
  for year in years, ec in ecs
    DmFracMin[1,Electric,OffRoad,ec,CA,year] = DmFracMin[1,Electric,OffRoad,ec,CA,year-1]+
      (DmFracMin[1,Electric,OffRoad,ec,CA,Yr(2035)]-
        DmFracMin[1,Electric,OffRoad,ec,CA,Yr(2021)])/(2035-2021)
  end

  for year in years, ec in ecs
    xDmFrac[1,Electric,OffRoad,ec,CA,year] = DmFracMin[1,Electric,OffRoad,ec,CA,year]
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

function PolicyControl(db)
  @info "Trans_MarineOffRoad_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
