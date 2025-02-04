#
# Electric_Renew_NS.jl - Nova Scotia Renewable Portfolio Standard (RPS) for electric generation
#
# July 2023, Thomas: Numbers updated according to new info:
# https://novascotia.ca/news/release/?id=20221219003#:~:text=renewable%20electricity%20standards%20require%20a,cent%20of%20electricity%20from%20renewables
#

using SmallModel

module Electric_Renew_NS

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

  RnFr::VariableArray{2} = ReadDisk(db,"EGInput/RnFr") # [Area,Year] Renewable Fraction (GWh/GWh)
  RnGoalSwitch::VariableArray{2} = ReadDisk(db,"EGInput/RnGoalSwitch") # [Area,Year] Renewable Generation Goal Switch (0=Sales,1=New Capacity)
  RnOption::VariableArray{2} = ReadDisk(db,"EGInput/RnOption") # [Area,Year] Renewable Expansion Option (1=Local RPS,2=Regional RPS,3=FIT)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,Years) = data
  (; RnFr,RnGoalSwitch,RnOption) = data

  NS = Select(Area,"NS")

  #
  # Nova Scotia standard is 25% by 2015 with 40% by 2020.
  #  
  for year in Years
    RnFr[NS,year] = 0
  end
  RnFr[NS,Yr(2015)] = 0.25
  RnFr[NS,Yr(2016)] = 0.25
  RnFr[NS,Yr(2017)] = 0.25
  RnFr[NS,Yr(2018)] = 0.25
  RnFr[NS,Yr(2019)] = 0.25
  RnFr[NS,Yr(2020)] = 0.25
  RnFr[NS,Yr(2021)] = 0.25
  RnFr[NS,Yr(2022)] = 0.25
  RnFr[NS,Yr(2023)] = 0.40
  RnFr[NS,Yr(2024)] = 0.40
  RnFr[NS,Yr(2025)] = 0.40
  RnFr[NS,Yr(2026)] = 0.70
  RnFr[NS,Yr(2027)] = 0.70
  RnFr[NS,Yr(2028)] = 0.70
  RnFr[NS,Yr(2029)] = 0.70
  RnFr[NS,Yr(2030)] = 0.80
  years = collect(Yr(2031):Final)
  for year in years
    RnFr[NS,year] = RnFr[NS,Yr(2020)]
  end
  
  WriteDisk(db,"EGInput/RnFr",RnFr)

  #
  # Renewable Goal is fraction of Sales (RnGoalSwitch=1)
  #  
  years = collect(Yr(2015):Final)
  for year in years
    RnGoalSwitch[NS,year] = 1
  end
  
  WriteDisk(db,"EGInput/RnGoalSwitch",RnGoalSwitch)

  #
  # Renewable Capacity is built exogenously (RnOption=0)
  #  
  years = collect(Yr(2015):Final)
  for area in Areas, year in years
    RnOption[area,year] = 0
  end
  
  WriteDisk(db,"EGInput/RnOption",RnOption)
end

function PolicyControl(db)
  @info "Electric_Renew_NS.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
