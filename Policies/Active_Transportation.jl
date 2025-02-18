#
# Active_Transportation.jl - Adjustments to reflect Active Transportation Investments
#
# Adjustment represents impact of $500 million dollars into
# bike lanes and other Active Transportation measures
# estimated at 240 KT of reductions in 2030 by Infrastructure
#
# Edited for REF24, $400 million was the final quantity, so
# must confirm the reductions and target 192 KT
# Matt Lewis June 7, 2024
#

using SmallModel

module Active_Transportation

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
 db::String
 
 CalDB::String = "TCalDB"
 Input::String = "TInput"
 
 Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
 AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
 Areas::Vector{Int} = collect(Select(Area))
 EC::SetArray = ReadDisk(db,"$Input/ECKey")
 ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
 ECs::Vector{Int} = collect(Select(EC))
 Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
 EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
 Enduses::Vector{Int} = collect(Select(Enduse))
 Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
 NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
 Nations::Vector{Int} = collect(Select(Nation))
 Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
 YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
 Years::Vector{Int} = collect(Select(Year))
 
 ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
 CERSM::VariableArray{4} = ReadDisk(db,"$CalDB/CERSM") # [Enduse,EC,Area,Year] Capital Energy Requirement (Btu/Btu)
 
 # Scratch Variables
 Adjust::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Adjustment Factor
end

function TransPolicy(db)
 data = TControl(; db)
 (; CalDB) = data
 (; Area,EC,Enduse,Nation,Years) = data
 (; ANMap,CERSM) = data
 (; Adjust) = data

 #
 # Apply adjustment factors to capital energy requirements
 #
 CN = Select(Nation,"CN")
 areas = findall(ANMap[:,CN] .== 1.0)
 ec = Select(EC,"Passenger")
 eu = Select(Enduse,"Carriage")

 @. Adjust = 1.0000
 Adjust[Yr(2026)] = 0.9995
 Adjust[Yr(2027)] = 0.9990
 Adjust[Yr(2028)] = 0.9985
 Adjust[Yr(2029)] = 0.9975
 years = collect(Yr(2030):Final)
 for year in years
   Adjust[year] = 0.9967
 end

 for area in areas, year in Years
   CERSM[eu,ec,area,year] = CERSM[eu,ec,area,year] .* Adjust[year]
 end

 WriteDisk(db,"$CalDB/CERSM",CERSM)
end

function PolicyControl(db)
 @info "Active_Transportation.jl - PolicyControl"
 TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
 PolicyControl(DB)
end

end
