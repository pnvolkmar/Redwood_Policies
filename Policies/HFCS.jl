#
# HFCS.jl
#
# This file implements the HFC reduction policy
# This file accounts for both the phasedown in bulk imports and product specific controls
# Reductions are calibrated in the HFC database to apply to the endogenous process forecast
# This file was developed in 2017, and edited on 2019
#
# Updated to reflect CG2 policy emission reductions
# - Matt Lewis June 20, 2023
#

using SmallModel

module HFCS

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
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/$B-Output)

  #
  # Scratch Variables
  #
  
  Target::VariableArray{1} = zeros(Float64,length(Year)) # [Year] HFC Reduction Target (tonnes/tonnes)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Areas,ECC,Nation) = data
  (; Poll) = data
  (; ANMap,MEPOCX) = data
  (; Target) = data

  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))
  HFC = Select(Poll,"HFC")
  @. Target = 1
 
  years = collect(Yr(2018):Yr(2050))
  #                  2018   2019   2020   2021   2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050
  Target[years] = [0.9990 0.9955 0.8767 0.8122 0.7874 0.7596 0.7211 0.6829 0.6464 0.6124 0.5767 0.5480 0.5119 0.4865 0.4773 0.4403 0.3960 0.3494 0.2988 0.2884 0.2777 0.2679 0.2560 0.2502 0.2349 0.1391 0.1389 0.1385 0.1274 0.1288 0.1302 0.1316 0.1276]
  
  years = collect(Future:Final)

  eccs = Select(ECC,"Food")
  for ecc in eccs, area in areas, year in years
    MEPOCX[ecc,HFC,area,year] = MEPOCX[ecc,HFC,area,year]*Target[year]
  end

  #
  # Others excluding Food
  # Industrial
  #  
  eccs = Select(ECC,["Furniture","OtherChemicals","IronOreMining",
                     "TransportEquipment","OtherManufacturing"])
  for ecc in eccs, area in areas, year in years
    MEPOCX[ecc,HFC,area,year] = MEPOCX[ecc,HFC,area,year]*Target[year]
  end
  
  #
  # Residential
  #  
  eccs = Select(ECC,["SingleFamilyDetached","SingleFamilyAttached","MultiFamily","OtherResidential"])
  for ecc in eccs, area in areas, year in years
    MEPOCX[ecc,HFC,area,year] = MEPOCX[ecc,HFC,area,year]*Target[year]
  end
  
  #
  # Commercial
  #  
  eccs = Select(ECC,["Wholesale","Retail","Warehouse","Information",
                     "Offices","Education","Health","OtherCommercial"])
  for ecc in eccs, area in areas, year in years
    MEPOCX[ecc,HFC,area,year] = MEPOCX[ecc,HFC,area,year]*Target[year]
  end
  
  WriteDisk(db,"MEInput/MEPOCX",MEPOCX)
end

Base.@kwdef struct TControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  vArea::SetArray = ReadDisk(db,"E2020DB/vAreaKey")
  vAreaDS::SetArray = ReadDisk(db,"E2020DB/vAreaDS")
  vAreas::Vector{Int} = collect(Select(vArea))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))
  
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  vAreaMap::VariableArray{2} = ReadDisk(db,"E2020DB/vAreaMap") # [Area,vArea] Map between Area and and VBInput Areas
  vTrMEPol::VariableArray{5} = ReadDisk(db,"VBInput/vTrMEPol") # [Tech,EC,Poll,vArea,Year] Non-Energy Pollution (Tonnes/Yr)
  xTrMEPol::VariableArray{5} = ReadDisk(db,"$Input/xTrMEPol") # [Tech,EC,Poll,Area,Year] Non-Energy Pollution (Tonnes/Yr)

  #
  # Scratch Variables
  #
  
  Target::VariableArray{1} = zeros(Float64,length(Year)) # [Year] HFC Reduction Target (tonnes/tonnes)
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,Areas,EC,ECs,Nation) = data
  (; Poll,Polls,Tech,Techs,vArea) = data
  (; Years,) = data
  (; ANMap,Target,vTrMEPol,xTrMEPol) = data
  
  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))

  #
  # Restore original values to xTrMEPol
  #  
  for area in areas, ec in ECs, tech in Techs, poll in Polls, year in Years
    varea = Select(vArea,Area[area])
    xTrMEPol[tech,ec,poll,area,year] = vTrMEPol[tech,ec,poll,varea,year]
  end

  #
  # Reduce xTrMEPol based on policy
  #  
  years = collect(Yr(2018):Future)
  for year in years
    Target[year] = 1.0
  end
  
  Target[Yr(2030)] = 0.9688
  Target[Yr(2031)] = 0.7592
  Target[Yr(2032)] = 0.7743  
  
  years = collect(Yr(2019):Yr(2029))
  for year in years
    Target[year] = Target[year-1]+(Target[Yr(2030)]-Target[Yr(2018)])/(2030-2018)
  end
 
  years = collect(Yr(2033):Final)
  for year in years
    Target[year] = 0.002797
  end
  
  #years = collect(Yr(2018):Yr(2033))    
  #for year in years
  #  loc1 = Target[year]
  #  loc2=YearDS[year]      
  #  @info "HFCS.jl - Target[$loc2] = $loc1"
  #end    
  
  #
  HFC = Select(Poll,"HFC")
  
  #
  techs1 = Select(Tech,"TrainDiesel")
  techs2 = Select(Tech,(from = "HDV2B3Gasoline",to = "HDV8FuelCell"))
  techs = union(techs1,techs2)
  ec = Select(EC,"Freight")
  years = collect(Future:Final)
  for tech in techs, area in areas, year in years      
    xTrMEPol[tech,ec,HFC,area,year] = xTrMEPol[tech,ec,HFC,area,year]*Target[year]
  end
  
  #
  techs = Select(Tech,"OffRoad")
  ec = Select(EC,"AirPassenger")
  years = collect(Future:Final)
  for tech in techs, area in areas, year in years      
    xTrMEPol[tech,ec,HFC,area,year] = xTrMEPol[tech,ec,HFC,area,year]*Target[year]
  end
  
  #
  techs1 = Select(Tech,(from = "LDVGasoline",to = "LDTFuelCell"))
  techs2 = Select(Tech,(from = "BusGasoline",to = "BusPropane"))
  techs = union(techs1,techs2)
  ec = Select(EC,"Passenger")
  years = collect(Future:Final)
  for tech in techs, area in areas, year in years
    xTrMEPol[tech,ec,HFC,area,year] = xTrMEPol[tech,ec,HFC,area,year]*Target[year]
  end
  
  WriteDisk(db,"$Input/xTrMEPol",xTrMEPol)
end

function PolicyControl(db)
  @info "HFCS.jl - PolicyControl"
  MacroPolicy(db)
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
