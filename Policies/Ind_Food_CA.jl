#
# Ind_Food_CA.jl - Food products: 7.5% energy demand electrified
# directly and/or indirectly by 2030; 75% by 2045
#

using SmallModel

module Ind_Food_CA

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

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMin,xDmFrac) = data

  CA = Select(Area,"CA")

  #
  ########################
  #
  # Food
  #
  ec = Select(EC,"Food")

  enduses = Select(Enduse,["Heat","OthSub"])
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","OffRoad"])

  Electric = Select(Fuel,"Electric")
  for tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,Yr(2030)] = 
      max(DmFracMin[enduse,Electric,tech,ec,CA,Yr(2030)],0.075)
  end

  years = collect(Yr(2045):Final)
  for year in years, tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,year] = 
      max(DmFracMin[enduse,Electric,tech,ec,CA,year],0.75)
  end

  #
  # Interpolate from 2021
  #
  years = collect(Yr(2022):Yr(2029))
  for year in years, tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,year] = 
      DmFracMin[enduse,Electric,tech,ec,CA,year-1]+
        (DmFracMin[enduse,Electric,tech,ec,CA,Yr(2030)]-
          DmFracMin[enduse,Electric,tech,ec,CA,Yr(2021)])/(2030-2021)
  end

  years = collect(Yr(2031):Yr(2044))
  for year in years, tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,year] = DmFracMin[enduse,Electric,tech,ec,CA,year-1]+
      (DmFracMin[enduse,Electric,tech,ec,CA,Yr(2045)]-
        DmFracMin[enduse,Electric,tech,ec,CA,Yr(2030)])/(2045-2030)
  end

  years = collect(Yr(2022):Final)
  for year in years, tech in techs, enduse in enduses
    xDmFrac[enduse,Electric,tech,ec,CA,year] = 
      DmFracMin[enduse,Electric,tech,ec,CA,year]
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin);
end

function PolicyControl(db)
  @info "Ind_Food_CA.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
