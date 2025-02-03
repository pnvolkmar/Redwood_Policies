#
# EIP_CCS_2.jl - Carbon Sequestration Price Signal -
# 0.4 MT in Emissions sequestering from EIP Programs
#

using SmallModel

module EIP_CCS_2

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  CalDB::String = "MCalDB"
  Input::String = "MInput"
  Outpt::String = "MOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xSqPrice::VariableArray{3} = ReadDisk(db,"MEInput/xSqPrice") # [ECC,Area,Year] Exogenous Sequestering Cost Curve Price ($/tonne CO2e)

  # Scratch Variables
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,ECC) = data
  (; xInflation,xSqPrice) = data
  
  area = Select(Area,"SK")     
  HeavyOilMining = Select(ECC,"HeavyOilMining")
  years = collect(Yr(2022):Yr(2026)) 
  for year in years
   xSqPrice[HeavyOilMining,area,year] = 235/xInflation[area,Yr(2016)]
  end

  WriteDisk(db,"MEInput/xSqPrice",xSqPrice)
end

function PolicyControl(db)
  @info "EIP_CCS_2.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
