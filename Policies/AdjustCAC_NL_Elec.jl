#
# AdjustCAC_NB_Elec.jl
# 


using SmallModel

module AdjustCAC_NB_Elec

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String

  CalDB::String = "ECalDB"
  Input::String = "EInput"
  Outpt::String = "EOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB")

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnPOCX::VariableArray{4} = ReadDisk(db,"EGInput/UnPOCX") # [Unit,FuelEP,Poll,Year] Pollution Coefficient (Tonnes/TBtu)end

end

function ElecPolicy(db)
  data = EControl(; db)
  (; FuelEP,Poll) = data
  (; UnCode,UnPOCX) = data

  years = collect(Future:Final)

  #
  # NOX
  #
  poll = Select(Poll,"NOX")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 284.5827
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 284.5827
    end
  end

  #
  # BC
  #
  poll = Select(Poll,"BC")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 1.1485
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 1.1485
    end
  end

  #
  # COX
  #
  poll = Select(Poll,"COX")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 27.7467
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 27.7467
    end
  end

  #
  # VOC
  #
  poll = Select(Poll,"VOC")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 2.4787
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 2.4787
    end
  end

  #
  # PMT
  #
  poll = Select(Poll,"PMT")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 15.6549
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 15.6549
    end
  end

  #
  # PM25
  #
  poll = Select(Poll,"PM25")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 10.2807
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 10.2807
    end
  end

  #
  # PM10
  #
  poll = Select(Poll,"PM10")
  fueleps = Select(FuelEP,["Diesel","LFO"])
  
  units = findall(UnCode .== "LB_Group_01")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 12.2000
    end
  end

  units = findall(UnCode .== "NL_Group_03")
  if units != []
    for unit in units, fuelep in fueleps, year in years
      UnPOCX[unit,fuelep,poll,year] = 12.2000
    end
  end

  WriteDisk(db,"EGInput/UnPOCX",UnPOCX)

end

function PolicyControl(db)
  @info "AdjustCAC_NB_Elec.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
