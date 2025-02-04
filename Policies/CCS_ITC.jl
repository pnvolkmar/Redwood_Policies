#
# CCS_ITC.jl - Investment Tax Credit (ITC) for Carbon Sequestration. The tax credit is designed to provide a discount on
# capital costs associated with the installation of carbon capture and storage facilities in Canada. Legislation was finalized in June 2024.
# Alberta introduced their own CCUS investment tax credit to complement the federal tax credit which increaes
# the total amount that can be claimed in Alberta throughout the projection period. The Alberta version can be
# claimed on top of the federal credit, with eligible projects back dated to 2022.
#





using SmallModel

module CCS_ITC

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  SqIVTC::VariableArray{2} = ReadDisk(db,"MEInput/SqIVTC") # [Area,Year] Sequestering CO2 Reduction Investment Tax Credit ($/$)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Areas,Years) = data
  (; SqIVTC) = data
  
  years = Select(Years, from = "2023", to = "2030")
  for area in Areas, year in years
    SqIVTC[area,year] = 0.5
  end
  years = Select(Years, from = "2031", to = "2040")
  for area in Areas, year in years
    SqIVTC[area,year] = 0.25
  end
  years = Select(Years, from = "2041", to = "2050")
  for area in Areas, year in years
    SqIVTC[area,year] = 0.0
  end

  WriteDisk(db,"MEInput/SqIVTC",SqIVTC)
end

function PolicyControl(db)
  @info "CCS_ITC.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
