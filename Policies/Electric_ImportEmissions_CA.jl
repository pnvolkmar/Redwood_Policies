#
# Electric_ImportEmissions_CA.jl
#

using SmallModel

module Electric_ImportEmissions_CA

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
  NodeX::SetArray = ReadDisk(db,"E2020DB/NodeXKey")
  NodeXDS::SetArray = ReadDisk(db,"E2020DB/NodeXDS")
  NodeXs::Vector{Int} = collect(Select(NodeX))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  POCXOthImports::VariableArray{4} = ReadDisk(db,"EGInput/POCXOthImports") # [Poll,NodeX,Area,Year] Imported Emissions Coefficients (Tonnes/GWh)

  # Scratch Variables
  Multiplier::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Import Emission Multiplier (Tonnes/GWh/(Tonnes/GWh))
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area) = data 
  (; POCXOthImports) = data
  
  # *
  # * Dampen import emissions in future to match CEC 2022 Scoping Plan Forecast.
  # * Per Jeff. 09/26/23 R.Levesque
  # *
  
  CA = Select(Area,"CA")
  @. POCXOthImports[:,:,:,Yr(2030)] = POCXOthImports[:,:,:,Yr(2030)]*0.20
  @. POCXOthImports[:,:,:,Yr(2050)] = POCXOthImports[:,:,:,Yr(2045)]*0.20
  
  # *
  # * Interpolate from 2021
  # *
  
  years = collect(Yr(2022):Yr(2029))
  for year in years
    @. POCXOthImports[:,:,:,year] = POCXOthImports[:,:,:,year-1] + 
    (POCXOthImports[:,:,:,Yr(2030)]-POCXOthImports[:,:,:,Yr(2021)])/(2030-2021)
  end

  years = collect(Yr(2031):Yr(2044))
  for year in years
    @. POCXOthImports[:,:,:,year] = POCXOthImports[:,:,:,year-1] + 
    (POCXOthImports[:,:,:,Yr(2045)]-POCXOthImports[:,:,:,Yr(2030)])/(2045-2030)
  end
  
  WriteDisk(db,"EGInput/POCXOthImports",POCXOthImports)
end

function PolicyControl(db)
  @info "Electric_ImportEmissions_CA.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
