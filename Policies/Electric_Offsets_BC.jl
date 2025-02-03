#
# Electric_Offsets_BC.jl -   Activates OffRq for BC Generation
#

using SmallModel

module Electric_Offsets_BC

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
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  OffSw::VariableArray{2} = ReadDisk(db,"EGInput/OffSw") # [Area,Year] GHG Electric Utility Offsets Required Switch (1=Required)

  # Scratch Variables
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area) = data
  (; OffSw) = data

  BC = Select(Area,"BC")
  years = collect(Future:Final)
  for year in years
    OffSw[BC,year] = 1
  end
  
  WriteDisk(db,"EGInput/OffSw",OffSw)
end

function PolicyControl(db)
  @info "Electric_Offsets_BC.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
