#
# Electric_BC_Gas_Retire.jl
#
# In its clean electricity policy, in 2030, BC wants to stop using natural gas
# to generate electricity in utility power plants ("cogen" still allowed)
# Author: Thomas Dandres
# Date: Nov 2021
#
# Based on a new conversation with BC, it appears the existing plant would be allowed
# to continue to generate. Only new plants would not be allowed to be added to the grid
# This TXP should be deactivated in Ref24.
# Thomas Dandres, January 2024
#

using SmallModel

module Electric_BC_Gas_Retire

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String
  
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")

  UnCode::SetArray = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnRetire::VariableArray{2} = ReadDisk(db,"EGInput/UnRetire") # [Unit,Year] Retirement Date (Year)
  UnF1::SetArray = ReadDisk(db,"EGInput/UnF1") # [Unit] Fuel Source 1
  UnArea::SetArray = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Generation Flag (1 or 2 is Industrial Generation)
end

function update_retirements!(unit_code::String, unit_name::String, retire_year::Int, Un)
  # Find unit index matching code
  unit_idx = findfirst(x -> x == unit_code, Un.UnCode)
  
  if isnothing(unit_idx)
    @warn "Could not match UnCode $unit_code"
    return
  end
  
  old_retire = Un.UnRetire[unit_idx,Future]
  
  if retire_year < old_retire
    Un.UnRetire[unit_idx,:] .= retire_year
  end
end

function ElecPolicy(db)
  data = EControl(; db)
  (; UnCode,UnRetire,UnF1,UnArea,UnOnLine,UnCogen) = data

  # Retirement data for BC natural gas units
  retirements = [
    ("BC_Group_03",       "Duke_Eng_Taylor",      2030),
    ("BC00002500201",     "Prince Rupert",        2030),
    ("BC00002500202",     "Prince Rupert",        2030), 
    ("BC_Endo080308",     "Endo OtherGeneration", 2030)
  ]

  for (code, name, year) in retirements
    update_retirements!(code, name, year, data)
  end

  WriteDisk(db,"EGInput/UnRetire",UnRetire)
end

function PolicyControl(db)
  @info "Electric_BC_Gas_Retire.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
