#
# ElectricDeliveryCharge_Switch.jl
#
# This policy file sets a switch that decides if PEDC 
# will be calculated in an alternative way:
# PEDC(ECC,ReCo,Y)=PEDC(ECC,ReCo,Y-1)*PDP(Area,Y)/PDP(Area,Y-1)
# 5/6/24

using SmallModel

module ElectricDeliveryCharge_Switch

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
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

  PEDCSwitch::VariableArray{2} = ReadDisk(db,"EGInput/PEDCSwitch") # [Area,Year]  Switch to execute alternative PEDC calculation (1=execute)
  
end

function ElecPolicy(db)
  data = EControl(; db)
  (;Area,Areas,Year) = data
  (;PEDCSwitch) = data

  #
  # Calibration is being done through year Last + 6
  #
  Future6 = Last+6
  years = collect(Future6:Final)
  for year in years, area in Areas
    PEDCSwitch[area,year] = 1
  end

  WriteDisk(db,"EGInput/PEDCSwitch",PEDCSwitch)
end

function PolicyControl(db)
  @info "ElectricDeliveryCharge_Switch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
