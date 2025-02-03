#
# Electric_Fed_Coal_Amendment.jl
#
# Formerly AccCoalRetire_2030.jl
#
# 2018 federal coal-fired electricity regulation amendment requiring all coal units to meet a
# 420 tonnes/GWh emissions intensity standardor shut down by 2030 (Jan 1).
# (defined by vintage in the regulation).
# Assume all coal units shut down. No units except Boundary Dam 3 are expected to meet
# the EI standard of 420 tonnes/GWh
#
# Re-written to be sensitive to earlier retirements defined in other jl files or the vData.
# Hilary Paulin 18.07.03
#

using SmallModel

module Electric_Fed_Coal_Amendment

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String

  CalDB::String = "ECalDB"
  Input::String = "EInput"
  Outpt::String = "EOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnNation::Array{String} = ReadDisk(db,"EGInput/UnNation") # [Unit] Nation
  UnName::Array{String} = ReadDisk(db,"EGInput/UnName") # [Unit] Plant Name
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnRetire::VariableArray{2} = ReadDisk(db,"EGInput/UnRetire") # [Unit,Year] Retirement Date (Year)

  # Scratch Variables
  # UCode    'Unit Code of Unit with New Retirement Date',Type = String(20)
  # UName 'Unit Name',Type = String(20)
  # URetire  'New Retirement Date (Year)'
  # URetireOld     'Old Retirement Date (Year)'
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Years) = data
  (; UnCogen,UnNation) = data
  (; UnPlant,UnRetire) = data

  units1 = findall(UnNation .== "CN")
  units2 = Select(UnCogen,==(0))
  units3 = findall(UnPlant .== "Coal")
  units = intersect(intersect(units1,units2),units3)

  for unit in units
    if UnRetire[unit,Yr(2030)] > 2030
      for year in Years
        UnRetire[unit,year] = 2030
      end
      
    end
    
  end

  WriteDisk(db,"EGInput/UnRetire",UnRetire)
end

function PolicyControl(db)
  @info "Electric_Fed_Coal_Amendment.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
