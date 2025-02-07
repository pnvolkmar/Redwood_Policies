#
# Res_PeakSavings.jl
#

using SmallModel

module Res_PeakSavings


import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
 db::String

 CalDB::String = "RCalDB"
 Input::String = "RInput"
 Outpt::String = "ROutput"
 BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") # Base Case Name

 Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
 AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
 Areas::Vector{Int} = collect(Select(Area))
 EC::SetArray = ReadDisk(db,"$Input/ECKey")
 ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
 ECs::Vector{Int} = collect(Select(EC))
 ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
 ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
 ECCs::Vector{Int} = collect(Select(ECC))
 Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
 EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
 Enduses::Vector{Int} = collect(Select(Enduse))
 Tech::SetArray = ReadDisk(db,"$Input/TechKey")
 TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
 Techs::Vector{Int} = collect(Select(Tech))
 Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
 YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
 Years::Vector{Int} = collect(Select(Year))

 DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"ROutput/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
 ECCMap = ReadDisk(db, "$Input/ECCMap") # (EC,ECC) 'Map between EC and ECC'
 SecMap::VariableArray{1} = ReadDisk(db,"SInput/SecMap") #[ECC]  Map Between the Sector and ECC Sets
 xPkSav::VariableArray{4} = ReadDisk(db,"$Input/xPkSav") # [Enduse,EC,Area,Year] Peak Savings from Programs (MW)
 xPkSavECC::VariableArray{3} = ReadDisk(db,"SInput/xPkSavECC") # [ECC,Area,Year] Peak Savings from Programs (MW)

 # Scratch variables
 DmFrac::VariableArray{4} = zeros(Float64,length(Enduse),length(EC),length(Area),length(Year))
 DmdTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year))
 TotPkSav::VariableArray{2} = zeros(Float64,length(Area),length(Year))
end

function ResPolicy(db)
 data = RControl(; db)
 (; Input) = data
 (; Area,Areas,EC,ECs,ECC,ECCs,Enduse,Enduses,Tech,Techs,Year,Years) = data
 (; ECCMap,DmdRef,xPkSav,xPkSavECC,DmFrac,DmdTotal,SecMap,TotPkSav) = data

 # BC peak savings
 area = Select(Area, "BC")
 TotPkSav[area,Yr(2025)] = 58.1
 TotPkSav[area,Yr(2026)] = 65.6
 TotPkSav[area,Yr(2027)] = 77.0
 TotPkSav[area,Yr(2028)] = 88.9 
 TotPkSav[area,Yr(2029)] = 94.6
 TotPkSav[area,Yr(2030)] = 95.9
 TotPkSav[area,Yr(2031)] = 96.8
 TotPkSav[area,Yr(2032)] = 97.2
 TotPkSav[area,Yr(2033)] = 98.1
 TotPkSav[area,Yr(2034)] = 98.6
 TotPkSav[area,Yr(2035)] = 99.0
 TotPkSav[area,Yr(2036)] = 99.9
 TotPkSav[area,Yr(2037)] = 100.3
 TotPkSav[area,Yr(2038)] = 101.2
 TotPkSav[area,Yr(2039)] = 101.6
 TotPkSav[area,Yr(2040)] = 102.5

 years = collect(Yr(2041):Final)
 for year in years
   TotPkSav[area,year] = 102.5
 end

 # QC peak savings  
 area = Select(Area, "QC")
 TotPkSav[area,Yr(2024)] = 109.4
 TotPkSav[area,Yr(2025)] = 218.8
 TotPkSav[area,Yr(2026)] = 328.1
 TotPkSav[area,Yr(2027)] = 437.5
 TotPkSav[area,Yr(2028)] = 546.9
 TotPkSav[area,Yr(2029)] = 656.3
 TotPkSav[area,Yr(2030)] = 765.6
 TotPkSav[area,Yr(2031)] = 875.0
 TotPkSav[area,Yr(2032)] = 984.4
 TotPkSav[area,Yr(2033)] = 1093.8
 TotPkSav[area,Yr(2034)] = 1203.1
 TotPkSav[area,Yr(2035)] = 1312.5

 years = collect(Yr(2036):Final)
 for year in years
   TotPkSav[area,year] = 1312.5
 end

 # Allocate demand reduction
 areas = Select(Area, ["QC","BC"])
 years = collect(Yr(2024):Yr(2050))
 tech = Select(Tech, "Electric")
 
 for area in areas, year in years
   # Total across enduses
   DmdTotal[area,year] = sum(DmdRef[enduse,tech,ec,area,year] 
                            for enduse in Enduses, ec in ECs)
   
   # Calculate fraction of electric tech's enduse demand per sector
   for enduse in Enduses, ec in ECs
     DmFrac[enduse,ec,area,year] = DmdRef[enduse,tech,ec,area,year] / 
                                  DmdTotal[area,year]
     xPkSav[enduse,ec,area,year] = DmFrac[enduse,ec,area,year] * 
                                  TotPkSav[area,year]
   end
   
   # Calculate ECC values
   for ec in ECs
    ecc = Select(ECC,EC[ec])
    xPkSavECC[ecc,area,year] = sum(xPkSav[enduse,ec,area,year] for enduse in Enduses)
   end
 end

 WriteDisk(db,"$Input/xPkSav",xPkSav)
 WriteDisk(db,"SInput/xPkSavECC",xPkSavECC)
end

function PolicyControl(db)
 @info "Res_PeakSavings.jl - PolicyControl"
 ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
 PolicyControl(DB)
end

end
