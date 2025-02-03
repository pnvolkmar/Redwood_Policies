#
# FossilGeneration_CA.jl - Constrain Fossil Generation in California
#

using SmallModel

module FossilGeneration_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String

  CalDB::String = "ECalDB"
  Input::String = "EInput"
  Outpt::String = "EOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))

  PjMax::VariableArray{2} = ReadDisk(db,"EGInput/PjMax") # [Plant,Area] Maximum Project Size (MW)

  # Scratch Variables
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Plant) = data
  (; PjMax) = data

  #
  # No new fossil capacity constructed in California
  #
  CA = Select(Area,"CA")
  plants = Select(Plant,["OGCT","OGCC","SmallOGCC","NGCCS","OGSteam","Coal","CoalCCS"])
  # years = collect(Yr(2023):Final)
  for plant in plants
    PjMax[plant,CA]=0
  end

  WriteDisk(db,"EGInput/PjMax",PjMax)
end

function PolicyControl(db)
  @info "FossilGeneration_CA.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
