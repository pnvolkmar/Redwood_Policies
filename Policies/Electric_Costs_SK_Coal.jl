#
# Electric_Costs_SK_Coal.jl
#

using SmallModel

module Electric_Costs_SK_Coal

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

  CDYear::Int = ReadDisk(db,"SInput/CDYear")[1] # Constant Dollar Year for Model Outputs (Year)

  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnUFOMC::VariableArray{2} = ReadDisk(db,"EGInput/UnUFOMC") # [Unit,Year] Fixed O&M Costs ($/Kw/Yr)
  UnUOMC::VariableArray{2} = ReadDisk(db,"EGInput/UnUOMC") # [Unit,Year] Variable O&M Costs (Real $/MWH)
  xInflationUnit::VariableArray{2} = ReadDisk(db,"MInput/xInflationUnit") # [Unit,Year] Inflation Index ($/$)
  xUnGCCC::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCC") # [Unit,Year] Generating Unit Capital Cost (Real $/KW)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Years) = data
  (; UnCode,UnUFOMC,xUnGCCC,UnUOMC,xInflationUnit) = data

  #
  #   Capital Costs (xUnGCCC) are as follows ($2011):
  #   Boundary Dam 3 with CCS: $11,291/KW
  #   Boundary Dam 4 with CCS: $8,600/KW
  #   Boundary Dam 5 with CCS: $8,600/KW
  #   Boundary Dam 6 with CCS: $7,500/KW
  #   BD 3 - Reduce CCS capital costs for EOR use of CO2: $6162
  #   BD 4,5,6 - Reduce CCS capital costs for EOR use of CO2: $4143
  #
  # Fixed O&M Costs (UnUFOMC) for CCS are expected to be 30% higher
  # than non-CCS coal units ($2010):
  #   Boundary Dam 3 with CCS: $27.38/KW
  #   Boundary Dam 4 with CCS: $27.38/KW
  #   Boundary Dam 5 with CCS: $27.38/KW
  #   Boundary Dam 6 with CCS: $22.27/KW
  #
  # Variable O&M Costs (UnUOMC) for CCS are expected to be 30% higher
  # than non-CCS coal units ($2010):
  #   Boundary Dam 3 with CCS: $5.69/KW
  #   Boundary Dam 4 with CCS: $5.69/KW
  #   Boundary Dam 5 with CCS: $5.69/KW
  #   Boundary Dam 6 with CCS: $5.69/KW
  #
  # Source: Email from Milica Boskovic on March 15, 2012.
  #

  #
  # Boundary Dam 3
  #  
  units = Select(UnCode,filter(x -> x in UnCode,["SK_Boundry3_CCS"]))
  for year in Years, unit in units
    xUnGCCC[unit,year] = (11291-6162) / xInflationUnit[unit,Yr(2011)]
    UnUFOMC[unit,year] =        27.38 / xInflationUnit[unit,Yr(2010)]
    UnUOMC[unit,year]  =         5.69 / xInflationUnit[unit,Yr(2010)]
  end

  #
  # Boundary Dam 4 and 5
  #  
  units = Select(UnCode,filter(x -> x in UnCode,["SK_Boundry4_CCS","SK_Boundry5_CCS"]))
  for year in Years, unit in units
    xUnGCCC[unit,year] =  (8600-4143) / xInflationUnit[unit,Yr(2011)]
    UnUFOMC[unit,year] =        27.38 / xInflationUnit[unit,Yr(2010)]
    UnUOMC[unit,year]  =         5.69 / xInflationUnit[unit,Yr(2010)]
  end

  #
  # Boundary Dam 6
  #  
  unit = Select(UnCode,filter(x -> x in UnCode,["SK_Boundry6_CCS"]))
  for year in Years, unit in units
    xUnGCCC[unit,year] =  (7500-4143) / xInflationUnit[unit,Yr(2011)]
    UnUFOMC[unit,year] =        27.27 / xInflationUnit[unit,Yr(2010)]
    UnUOMC[unit,year]  =         5.69 / xInflationUnit[unit,Yr(2010)]
  end

  WriteDisk(db,"EGInput/UnUFOMC",UnUFOMC)
  WriteDisk(db,"EGInput/xUnGCCC",xUnGCCC)
  WriteDisk(db,"EGInput/UnUOMC",UnUOMC)
end

function PolicyControl(db)
  @info "Electric_Costs_SK_Coal.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
