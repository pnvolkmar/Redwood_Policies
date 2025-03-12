#
# SetAsReferenceCase.jl
#

using SmallModel

module SetAsReferenceCase

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  BaseSw::Float64 = ReadDisk(db,"SInput/BaseSw")[1] #[tv]  Base Case Switch (1=Base Case)
  RefSwitch::Float64 = ReadDisk(db,"SInput/RefSwitch")[1] #[tv] Reference Case Switch (1=Reference Case) 
end

function SPolicy(db)
  data = SControl(; db)
  (; BaseSw,RefSwitch) = data

  BaseSw = 0
  RefSwitch = 1
  WriteDisk(db,"SInput/BaseSw",BaseSw)
  WriteDisk(db,"SInput/RefSwitch",RefSwitch)
end

function PolicyControl(db)
  @info "SetAsReferenceCase.jl - PolicyControl"
  SPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
