#
# CCS_FedCoop_2.jl - Carbon Sequestration Price Signal - 
# Exogenous CCS reductions from FedCoop CCS plant; 400 kt in Refinery, 75 kt in OtherChem
#

using SmallModel

module CCS_FedCoop_2

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
 db::String
 
 MEInput::String = "MEInput"
 MInput::String = "MInput"
 
 Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
 ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
 Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
 Year::SetArray = ReadDisk(db,"E2020DB/YearKey")

 xInflation::VariableArray{2} = ReadDisk(db,"$MInput/xInflation") # [Area,Year] Inflation Index ($/$)
 xSqPrice::VariableArray{3} = ReadDisk(db,"$MEInput/xSqPrice") # [ECC,Area,Year] Exogenous Sequestering Cost Curve Price ($/tonne CO2e)
end

function MPolicy(db)
 data = MControl(; db)
 (; MEInput,MInput) = data
 (; Area,ECC,Poll,Year) = data
 (; xInflation,xSqPrice) = data

 #
 # Set sequestration prices for SK OtherChemicals
 #
 area = Select(Area,"SK")
 ecc = Select(ECC,"OtherChemicals")
 poll = Select(Poll,"CO2")

 xSqPrice[ecc,area,Yr(2024)] = 158.92/xInflation[area,Yr(2020)]
 
 years = collect(Yr(2025):Final)
 for year in years
   xSqPrice[ecc,area,year] = 121.10/xInflation[area,Yr(2020)]
 end

 WriteDisk(db,"$MEInput/xSqPrice",xSqPrice)
end

function PolicyControl(db)
 @info "CCS_FedCoop_2.jl - PolicyControl"
 MPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
 PolicyControl(DB)
end

end
