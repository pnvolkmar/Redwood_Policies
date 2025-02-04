#
# CCS_Heidelberg_AB.jl -  Carbon Sequestration Price Signal
# 
# Exogenous CCS reductions from CCS facility (Lehigh/Heidelberg facility in Edmonton AB)
# Projecting the Exshaw facility from Lafarge to come on line in 2029
#

using SmallModel

module CCS_Heidelberg_AB

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
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # Map between Area and Nation [Area,Nation]
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xSqPrice::VariableArray{3} = ReadDisk(db,"MEInput/xSqPrice") # [ECC,Area,Year] Exogenous Sequestering Cost Curve Price ($/tonne CO2e)

end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,ECC,Poll) = data
  (; xInflation,xSqPrice) = data

  ecc = Select(ECC,"Cement")
  poll = Select(Poll,"CO2")
  area = Select(Area,"AB")

  xSqPrice[ecc,area,Yr(2022)] = 130.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2023)] = 130.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2024)] = 131.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2025)] = 131.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2026)] = 132.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2027)] = 132.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2028)] = 133.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2029)] = 133.0/xInflation[area,Yr(2016)]
  xSqPrice[ecc,area,Yr(2030)] = 134.0/xInflation[area,Yr(2016)]

  years = collect(Yr(2031):Final)
  for year in years
    xSqPrice[ecc,area,year] = 134.0/xInflation[area,Yr(2016)]
  end
  WriteDisk(db,"MEInput/xSqPrice",xSqPrice)
  
end

function PolicyControl(db)
  @info "CCS_Heidelberg_AB.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
