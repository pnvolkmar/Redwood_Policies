#
# CCS_Stelco_ON.jl - Carbon Sequestration Price Signal -
# Exogenous CCS reductions from Stelco CCS facility in Ontario. The off-gases are captured and converted into hydrogen
# using the EXERO technology from Utility Global. This is not being modelled as hydrogen substitution because E2020
# does not model the EXERO solid oxide technology used to produce hydrogen. Reductions are assumed to come from the
# capture instead. In the future either the EXERO technology could be introduced or hydrogen substitution could
# be implemented if this is determined to be the preferred approach
#

using SmallModel

module CCS_Stelco_ON

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")

  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xSqPrice::VariableArray{3} = ReadDisk(db,"MEInput/xSqPrice") # [ECC,Area,Year] Exogenous Sequestering Cost Curve Price ($/tonne CO2e)
  xSqPol::VariableArray{4} = ReadDisk(db,"MEInput/xSqPol") # [ECC,Poll,Area,Year] Sequestering Emissions (Tonnes/Year)
end

function MPolicy(db)
  data = MControl(; db)
  (; Area,ECC,Poll,Year) = data
  (; xInflation,xSqPrice,xSqPol) = data

  #
  # Set sequestration prices for ON IronSteel
  #
  area = Select(Area,"ON")
  ecc = Select(ECC,"IronSteel")
  poll = Select(Poll,"CO2")

  # Set price through 2050
  years = collect(Yr(2025):Final)
  for year in years
    xSqPrice[ecc,area,year] = 278.0/xInflation[area,Yr(2016)]
  end

  # Set emissions from 2029 onward  
  years = collect(Yr(2029):Final)
  for year in years
    xSqPol[ecc,poll,area,year] = 1.00e6
  end

  WriteDisk(db,"MEInput/xSqPrice",xSqPrice)
  # WriteDisk(db,"MEInput/xSqPol",xSqPol) # TODO Promula xSqPol is assigned but not written
end

function PolicyControl(db)
  @info "CCS_Stelco_ON.jl - PolicyControl"
  MPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
