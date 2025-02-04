#
# Com_PeakSavings.jl
#

using SmallModel

module Com_PeakSavings

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  ECCMap::VariableArray{2} = ReadDisk(db,"$Input/ECCMap") # [EC,ECC] # EC TO ECC Map
  SecMap::VariableArray{1} = ReadDisk(db,"SInput/SecMap") #[ECC]  Map Between the Sector and ECC Sets
  xPkSav::VariableArray{4} = ReadDisk(db,"$Input/xPkSav") # [Enduse,EC,Area,Year] Peak Savings from Programs (MW)
  xPkSavECC::VariableArray{3} = ReadDisk(db,"SInput/xPkSavECC") # [ECC,Area,Year] Peak Savings from Programs (MW)

  # Scratch Variables
  DmdTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Demand (TBtu/Yr)
  DmFrac::VariableArray{4} = zeros(Float64,length(Enduse),length(EC),length(Area),length(Year)) # [Enduse,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  TotPkSav::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sector Demand Reductions (MW)
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area,ECs,Enduses,Tech) = data 
  (; DmdRef,DmdTotal,DmFrac,ECCMap,SecMap,TotPkSav,xPkSav,xPkSavECC) = data

  # 
  # Input Commercial Electric Peak Savings for British Columbia
  #  
  area = Select(Area,"BC")
  TotPkSav[area,Yr(2025)] = 44.9
  TotPkSav[area,Yr(2026)] = 50.7
  TotPkSav[area,Yr(2027)] = 59.5
  TotPkSav[area,Yr(2028)] = 68.7
  TotPkSav[area,Yr(2029)] = 73.1
  TotPkSav[area,Yr(2030)] = 74.1
  TotPkSav[area,Yr(2031)] = 74.8
  TotPkSav[area,Yr(2032)] = 75.1
  TotPkSav[area,Yr(2033)] = 75.8
  TotPkSav[area,Yr(2034)] = 76.2
  TotPkSav[area,Yr(2035)] = 76.5
  TotPkSav[area,Yr(2036)] = 77.2
  TotPkSav[area,Yr(2037)] = 77.5
  TotPkSav[area,Yr(2038)] = 78.2
  TotPkSav[area,Yr(2039)] = 78.5
  TotPkSav[area,Yr(2040)] = 79.2

  years = collect(Yr(2041):Final)
  for year in years
    TotPkSav[area,year] =  79.2
  end

  # 
  # Commercial Electric Peak Savings for Quebec
  #  
  area = Select(Area,"QC")
  TotPkSav[area,Yr(2024)] = 121.0
  TotPkSav[area,Yr(2025)] = 242.1
  TotPkSav[area,Yr(2026)] = 363.1
  TotPkSav[area,Yr(2027)] = 484.2
  TotPkSav[area,Yr(2028)] = 605.2
  TotPkSav[area,Yr(2029)] = 726.3
  TotPkSav[area,Yr(2030)] = 847.3
  TotPkSav[area,Yr(2031)] = 968.3
  TotPkSav[area,Yr(2032)] = 1089.4
  TotPkSav[area,Yr(2033)] = 1210.4
  TotPkSav[area,Yr(2034)] = 1331.5
  TotPkSav[area,Yr(2035)] = 1452.5
  TotPkSav[area,Yr(2036)] = 1452.5
  TotPkSav[area,Yr(2037)] = 1452.5
  TotPkSav[area,Yr(2038)] = 1452.5
  TotPkSav[area,Yr(2039)] = 1452.5
  TotPkSav[area,Yr(2040)] = 1452.5

  years = collect(Yr(2041):Final)
  for year in years
    TotPkSav[area,year] =  1452.5
  end
  
  #
  # Allocate Demand Reduction to all Enduses
  #  
  # Calculate the total demand across all enduses and commercial sectors for electric tech
  # 
  areas = Select(Area,["QC","BC"])
  years = collect(Yr(2024):Yr(2050))
  tech = Select(Tech,"Electric")
  #
  # Using SecMap == 2 instead of Com since unsure if latter is global in Julia code - Ian 02/03/25
  #
  eccs = findall(SecMap[:] .== 2)
  #
  # Total across enduses
  #
  for area in areas, year in years
    DmdTotal[area,year] = sum(DmdRef[enduse,tech,ec,area,year] for enduse in Enduses,ec in ECs)
  end

  #
  # Calcuate the fraction of electric tech's enduse demand served in each sector
  #
  for enduse in Enduses, ec in ECs, area in areas, year in years
    @finite_math DmFrac[enduse,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/
                                               DmdTotal[area,year] 
    xPkSav[enduse,ec,area,year] = DmFrac[enduse,ec,area,year]*TotPkSav[area,year]
  end
  
  for ecc in eccs, area in areas, year in years
    xPkSavECC[ecc,area,year] = sum(xPkSav[enduse,ec,area,year]*ECCMap[ec,ecc] for enduse in Enduses, ec in ECs)
  end

  WriteDisk(db,"$Input/xPkSav",xPkSav)
  WriteDisk(db,"SInput/xPkSavECC",xPkSavECC)
end

function PolicyControl(db)
  @info "Com_PeakSavings.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
