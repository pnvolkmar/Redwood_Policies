#
# Electricity_ITCs.jl
#
# Ref24 - Updated with the Ref23AshCER version, removed impacts to the last historical year 2022 - RST 06Aug2024
#

using SmallModel

module Electricity_ITCs

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
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  GCCCN::VariableArray{3} = ReadDisk(db,"EGInput/GCCCN") # [Plant,Area,Year] Overnight Construction Costs ($/KW)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Unit Area
  xUnGCCC::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCC") # [Unit,Year] Generating Unit Capital Cost (Real $/KW)

  # Scratch Variables
  Reduction::VariableArray{3} = zeros(Float64,length(Plant),length(Area),length(Year)) # [Plant,Area,Year] Reduction fraction
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,Plant,Plants,Units) = data
  (; Years) = data
  (; GCCCN,Reduction,UnPlant,UnArea,xUnGCCC) = data

  # 
  # To simulate Investment Tax Credits Impacting Electricity generation, including ITC's announced in Budget 2023:
  # 1. Atlantic Tax Credit (Existing)
  # 2. CCUS (Budget 2022/23)
  # 3. Clean Electricity (Budget 2023)
  # 4. Clean Technology (FES 2022 / Budget 2023)
  # RST 31May2023
  # 
  # v2: Updated after alignment exercise with NextGrid, as well as add in Biomass (Waste) eligiblity for the CT/CE ITCs from FES 2023 - RST 11Jan2024
  # 
  # GCCCN Modification
  # CCUS ITC : Target CCS plant types,assume an average of 50% ITC applied on 
  # the CCS-portion of the Plant,
  # Full Rate 2022-2030,Half Rate 2031-2040,ITC gone in 2041 onward.  
  # Also assume that 50% of the total cost of the CCS Electric Unit is CCS-related equipment.
  #
  # Area coverage: BC/AB/SK (NextGrid Alignment)
  #
  areas = Select(Area,["AB","BC","SK"])
  plants = Select(Plant,["NGCCS","CoalCCS","BiomassCCS"])
  years = collect(Yr(2023):Yr(2030))
  for year in years, area in areas, plant in plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.5*0.5
  end
  years = collect(Yr(2031):Yr(2040))
  for year in years, area in areas, plant in plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.25*0.5
  end
  # 
  # Clean Technology ITC : Target non-emitting plant types,assume all units are private-owned 
  # (so Units can claim the Clean Tech rate (30%) rather than the lower Clean Electricity rate (15%),
  # Full Rate 2023-2033,Half Rate 2034,ITC gone in 2035 onward.
  #
  # Only let PeakHydro be eligible for CE ITC (NextGrid Alignment)
  #
  # Add Biomass (50% of BiomassCCS) and Waste eligible (FES 2023)
  #
  areas = Select(Area, ["AB","BC","MB","ON","QC","SK","NS","NL","NB","PE","YT","NT","NU"])
  plants = Select(Plant,["FuelCell","Battery","Nuclear","SMNR","BaseHydro","PumpedHydro","SmallHydro","OnshoreWind","OffshoreWind","SolarPV","SolarThermal","Geothermal","Wave","Tidal","Biomass","Waste"])
  years = collect(Yr(2023):Yr(2033))
  for year in years, area in areas, plant in plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.3
  end
  
  for area in areas, plant in plants
    Reduction[plant,area,Yr(2034)] = Reduction[plant,area,Yr(2034)] + 0.15
  end

  # 
  # Clean Electricity ITC : Target NGCCS, Full 15% Rate 2024-2034, ITC gone in 2035 onward.
  #
  NGCCS = Select(Plant,"NGCCS")
  years = collect(Yr(2024):Yr(2034))
  for year in years, area in areas
    Reduction[NGCCS,area,year] = Reduction[NGCCS,area,year] + 0.15
  end
  # 
  plants = Select(Plant,"BiomassCCS")
  years = collect(Yr(2023):Yr(2030))
  for year in years, area in areas, plant in plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.3*0.5
  end
  years = collect(Yr(2031):Yr(2040))
  for year in years, area in areas, plant in plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.25*0.5
  end


  # 
  # Atlantic ITCs : Target all units types, 10% Rate,Coverage for Atlantic provinces,
  # Assume all of Quebec not eligible for Credit (Gaspe Region is covered in reality).
  # 
  areas = Select(Area,["PE","NS","NL","NB"])
  years = collect(Yr(2012):Final)
  for year in years, area in areas, plant in Plants
    Reduction[plant,area,year] = Reduction[plant,area,year] + 0.1
  end

  # 
  # Apply calculated reductions to existing overnight construction costs 
  # to create the new costs minus eligible ITC's by Plant Type / Area / Year.
  # 
  
  @. GCCCN = GCCCN * (1 - Reduction)

  # 
  # xUnGCCC Modification
  # 
  
  areas = Select(Area,["AB","BC","MB","ON","QC","SK","NS","NL","NB","PE","YT","NT","NU"])
  @. [xUnGCCC[unit,Years] = xUnGCCC[unit,Years] * (1 - Reduction[plant,area,Years]) for unit in Units,plant in Plants,area in Areas
    if UnArea[unit] == Area[area] && UnPlant[unit] == Plant[plant]]

  WriteDisk(db,"EGInput/GCCCN",GCCCN)
  WriteDisk(db,"EGInput/xUnGCCC",xUnGCCC)
end

function PolicyControl(db)
  @info "Electricity_ITCs.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
