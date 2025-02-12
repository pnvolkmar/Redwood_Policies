#
# TransElectric_Parameters.jl - Assign parameters for electric vehicles
#

using SmallModel

module TransElectric_Parameters

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
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Fuels::Vector{Int} = collect(Select(Fuel))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)

end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Areas,EC,Enduse) = data 
  (; Fuel,Poll,Tech) = data
  (; POCX) = data
  
  enduse = Select(Enduse,["Carriage"])
  fuelep = Select(Fuel,["Gasoline"])
  ec = Select(EC,["Passenger"])
  years = collect(Future:Final)
  CACs = Select(Poll,["PMT","PM10","PM25","SOX","NOX","VOC","COX","NH3","Hg","BC"])

  techToUse = Select(Tech,["LDVGasoline"])
  techToAssign = Select(Tech,["LDVHybrid"])
  POCX[enduse,fuelep,techToAssign,ec,CACs,Areas,years] = 
    POCX[enduse,fuelep,techToUse,ec,CACs,Areas,years]

  techToAssign = Select(Tech,["LDTHybrid"])
  techToUse = Select(Tech,["LDTGasoline"])
  POCX[enduse,fuelep,techToAssign,ec,CACs,Areas,years] = 
    POCX[enduse,fuelep,techToUse,ec,CACs,Areas,years]
end

function PolicyControl(db)
  @info "TransElectric_Parameters.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
