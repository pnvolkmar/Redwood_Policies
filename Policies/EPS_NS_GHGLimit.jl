#
# EPS_NS_GHGLimit.jl - Electric Generation GHG Performance 
# Standards for NS coal which reduces coal generation instead
# of retiring - Jeff Amlin 8/7/2013
# Revised to incorporate new dispatch method - Jeff Amlin 11/12/14
#

using SmallModel

module EPS_NS_GHGLimit

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
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  PollLimitGHGFlag::VariableArray{2} = ReadDisk(db,"EGInput/PollLimitGHGFlag") # [Area,Year] Pollution Limit GHG Flag (1=GHG Limit)
  PollutionLimit::VariableArray{3} = ReadDisk(db,"EGInput/PollutionLimit") # [Poll,Area,Year] Electric Utility Pollution Limit (Tonnes)

  # Scratch Variables
  PLGrowth::VariableArray{2} = zeros(Float64,length(Poll),length(Area)) # [Poll,Area] Pollution Limit Growth Rate (Tonnes/Tonnes)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Poll) = data
  (; PollLimitGHGFlag,PollutionLimit) = data

  # 
  # NS Limit on Electric Utility GHG Emissions
  # Sources:
  # NS GHG Limit on Electricty Sector -- http://www.gov.ns.ca/just/regulations/regs/envgreenhouse.htm
  # Draft Equivlancy Agreement with Federal Government -- http://www.ec.gc.ca/lcpe-cepa/default.asp?lang=En&n=1ADECEDE-1  
  # 
  NS = Select(Area,"NS")
  years = collect(Yr(2010):Yr(2050))
  for year in years
    PollLimitGHGFlag[NS,year] = 1
  end
  
  WriteDisk(db,"EGInput/PollLimitGHGFlag",PollLimitGHGFlag)

  # 
  # GHG Emissions Limit stored in CO2
  # 
  CO2 = Select(Poll,"CO2")
  PollutionLimit[CO2,NS,Yr(2010):Yr(2035)] = [9.600,9.600,9.250,9.250,8.700,8.700,8.700,8.000,8.000,8.000,7.500,6.875,6.875,6.875,6.875,6.000,5.375,5.375,5.375,5.375,4.500,4.500,4.500,4.500,4.500,4.500]
  PollutionLimit[CO2,NS,Yr(2010):Yr(2035)] = PollutionLimit[CO2,NS,Yr(2010):Yr(2035)] * 1e6
  years = collect(Yr(2036):Yr(2050))
  for year in years
    PollutionLimit[CO2,NS,year] = PollutionLimit[CO2,NS,Yr(2035)]
  end
  
  WriteDisk(db,"EGInput/PollutionLimit",PollutionLimit)
end

function PolicyControl(db)
  @info "EPS_NS_GHGLimit.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
