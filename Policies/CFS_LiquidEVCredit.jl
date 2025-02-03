#
# CFS_LiquidEVCredit.jl
#

using SmallModel

module CFS_LiquidEVCredit

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  # CalDB::String = "SCalDB"
  # Input::String = "SInput"
  # Outpt::String = "SOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ES::SetArray = ReadDisk(db,"E2020DB/ESKey")
  ESDS::SetArray = ReadDisk(db,"E2020DB/ESDS")
  ESs::Vector{Int} = collect(Select(ES))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation 
  xFPCFSCredit::VariableArray{4} = ReadDisk(db,"SInput/xFPCFSCredit") # [Fuel,ES,Area,Year] CFS Credit Price ($/Tonnes)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  CreditPrice::VariableArray{1} = zeros(Float64,length(Year)) # [Year] CFS Credit Price ($/Tonnes)
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Areas,ES,Fuel) = data 
  (; xFPCFSCredit) = data

  Transport = Select(ES,"Transport")
  Electric = Select(Fuel,"Electric")
  Gasoline = Select(Fuel,"Gasoline")
  years = collect(Yr(2023):Final)
  for year in years, area in Areas
    xFPCFSCredit[Electric,Transport,area,year] = 
      xFPCFSCredit[Gasoline,Transport,area,year]
  end

  WriteDisk(db,"SInput/xFPCFSCredit",xFPCFSCredit)    
end

function PolicyControl(db)
  @info "CFS_LiquidEVCredit.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
