#
# Ag_Methane_reduction_CA.jl
# Animal Production CH4 is exogenous, this jl is aiming to reduce emissions in line with CMB.
#

using SmallModel

module Ag_Methane_Reduction_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  CalDB::String = "MCalDB"
  Input::String = "MInput"
  Outpt::String = "MOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/Economic Driver)

  # Scratch Variables
  Animal_CH4_Target::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Target CH4 reduction (kt) from animal production (total 0.24Mt CO2e in 2030)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,ECC,ECCs,Poll) = data 
  (; Animal_CH4_Target,MEPOCX) = data
  
  CA = Select(Area,"CA")
  ECCs = Select(ECC,["AnimalProduction","CropProduction"])
  CH4 = Select(Poll,"CH4")

  Animal_CH4_Target[CA,Yr(2025)] = 1.0
  Animal_CH4_Target[CA,Yr(2030)] = 0.3333
  
  years = collect(Yr(2045):Yr(2050))
  for year in years
    Animal_CH4_Target[CA,year] = 0.1667
  end
  
  years = collect(Yr(2031):Yr(2044))
  for year in years
  Animal_CH4_Target[CA,year] = Animal_CH4_Target[CA,year-1] +
    (Animal_CH4_Target[CA,Yr(2045)] - Animal_CH4_Target[CA,Yr(2030)])/(2045-2030)
  end
  
  years = collect(Yr(2026):Yr(2029))
  for year in years
  Animal_CH4_Target[CA,year] = Animal_CH4_Target[CA,year-1] +
    (Animal_CH4_Target[CA,Yr(2030)] - Animal_CH4_Target[CA,Yr(2025)]) / 
      (2030-2025)
  end
  
  years = collect(Yr(2025):Yr(2050))
  for year in years, ecc in ECCs
    MEPOCX[ecc,CH4,CA,year] = MEPOCX[ecc,CH4,CA,year]*Animal_CH4_Target[CA,year]
  end
  
  WriteDisk(db,"MEInput/MEPOCX",MEPOCX)
end

function PolicyControl(db)
  @info "Ag_Methane_Reduction_CA.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
