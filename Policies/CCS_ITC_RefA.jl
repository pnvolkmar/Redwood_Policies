#
# CCS_ITC_RefA.jl - Investment Tax Credit (ITC) for Carbon Sequestration. The tax credit is designed to provide a discount on
# capital costs associated with the installation of carbon capture and storage facilities in Canada. Legislation was finalized in June 2024.
# Alberta introduced their own CCUS investment tax credit to complement the federal tax credit which increaes
# the total amount that can be claimed in Alberta throughout the projection period. The Alberta version can be
# claimed on top of the federal credit, with eligible projects back dated to 2022.
#

using SmallModel

module CCS_ITC_RefA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
 db::String
 
 MEInput::String = "MEInput"
 
 Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
 Areas::Vector{Int} = collect(Select(Area))
 Year::SetArray = ReadDisk(db,"E2020DB/YearKey")

 SqIVTC::VariableArray{2} = ReadDisk(db,"$MEInput/SqIVTC") # [Area,Year] Sequestering CO2 Reduction Investment Tax Credit ($/$)
end

function MPolicy(db)
 data = MControl(; db)
 (; MEInput) = data
 (; Area,Areas,Year) = data
 (; SqIVTC) = data

 #
 # Set default ITC rates for all areas
 #
 years = collect(Yr(2023):Yr(2030))
 for year in years, area in Areas
   SqIVTC[area,year] = 0.50
 end
 
 years = collect(Yr(2031):Yr(2040))
 for year in years, area in Areas
   SqIVTC[area,year] = 0.25
 end
 
 years = collect(Yr(2041):Final)
 for year in years, area in Areas
   SqIVTC[area,year] = 0.00
 end

 #
 # Set Alberta-specific ITC rates
 #
 area = Select(Area,"AB")
 
 years = collect(Yr(2023):Yr(2030))
 for year in years
   SqIVTC[area,year] = 0.62
 end
 
 years = collect(Yr(2031):Yr(2040))
 for year in years
   SqIVTC[area,year] = 0.37
 end

 WriteDisk(db,"$MEInput/SqIVTC",SqIVTC)
end

function PolicyControl(db)
 @info "CCS_ITC_RefA.jl - PolicyControl"
 MPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
 PolicyControl(DB)
end

end
