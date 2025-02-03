#
# Adjust_TR_Covid.jl
#
# Adjustment represents impact of Covid on Passenger and Air Passenger.
# Estimated using EIA weekly gasoline and jet fuel demand for 2023 (partial)
# 2022, 2021, 2020 and 2019, assuming 2019 is 100% and adjusting for population growth.
# 
# For Ref23 Air Passenger, 2021 has CERSM = 1 and adjustment must 
# be rebased and applied to 2022 onwards
# For REF23, Passenger seems ok without adjustments
# 
# Freight is covered in macro model and GDP.
#

using SmallModel

module Adjust_TR_Covid

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
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  CERSM::VariableArray{4} = ReadDisk(db,"$CalDB/CERSM") # [Enduse,EC,Area,Year] Capital Energy Requirement (Btu/Btu)

  # Scratch Variables
  Adjust::VariableArray{1} = zeros(Float64,length(Year)) # [Year]
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Areas,EC,Enduses) = data 
  (; Nation,Years) = data
  (; Adjust,ANMap,CERSM) = data

  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))
  ecs = Select(EC,["AirPassenger","ForeignPassenger"])
  # 
  for year in Years
    Adjust[year] = 1.00
  end
  Adjust[Yr(2022)] = 1.20
  Adjust[Yr(2023)] = 1.35
  Adjust[Yr(2024)] = 1.50
  years = collect(Yr(2025):Final)
  for year in years
    Adjust[year] = 1.60
  end

  for eu in Enduses, ec in ecs, area in cn_areas, year in Years
    CERSM[eu,ec,area,year] = CERSM[eu,ec,area,year] * Adjust[year]
  end
  
  WriteDisk(db,"$CalDB/CERSM",CERSM)
end

function PolicyControl(db)
  @info "Adjust_TR_Covid.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
