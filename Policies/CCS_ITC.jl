#
# CCS_ITC.jl - Investment Tax Credit (ITC) for Carbon Sequestration
#

using SmallModel

module CCS_ITC

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  SqIVTC::VariableArray{2} = ReadDisk(db,"MEInput/SqIVTC") # [Area,Year] Sequestering CO2 Reduction Investment Tax Credit ($/$)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Areas,Years) = data
  (; SqIVTC) = data

  for area in Areas, year in Years
    SqIVTC[area,year] = 0.5
  end

  WriteDisk(db,"MEInput/SqIVTC",SqIVTC)
end

function PolicyControl(db)
  @info "CCS_ITC.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
