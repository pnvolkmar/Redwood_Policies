#
# KPIA_Biofuels_Prov.jl - Provincial Biofuels Policy
#

using SmallModel

module KPIA_Biofuels_Prov

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

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
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DmFrac::VariableArray{6} = ReadDisk(BCNameDB,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  # Scratch Variables
  BBlend::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Biodiesel Blend %,not equal to DMFRAC
  BDGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Biodiesel Goal (Btu/Btu)
  DPoolDmFrac::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Diesel Pool DmFrac,ie Biod + Diesel
  EBlend::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Ethanol Blend %,not equal to DMFRAC
  ETGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Ethanol Goal (Btu/Btu)
  GPoolDmFrac::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Gasoline Pool DmFrac,ie Ethanol + Gasoline
end

function EthanolBlend(data,area,tech,ec,year)
  (; Enduses,Fuel) = data
  (; DmFrac,DmFracMin) = data
  (; EBlend,ETGoal,GPoolDmFrac) = data

  Gasoline = Select(Fuel,"Gasoline")
  Ethanol = Select(Fuel,"Ethanol")
  
  for enduse in Enduses
    GPoolDmFrac[enduse,tech,ec,area] = DmFrac[enduse,Gasoline,tech,ec,area,year]+ 
      DmFrac[enduse,Ethanol,tech,ec,area,year]

    @finite_math EBlend[enduse,tech,ec,area] = max(0,DmFrac[enduse,Ethanol,tech,ec,area,year]/
      GPoolDmFrac[enduse,tech,ec,area])

    EBlend[enduse,tech,ec,area] = max(EBlend[enduse,tech,ec,area],ETGoal[year])
    
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = EBlend[enduse,tech,ec,area]*
      GPoolDmFrac[enduse,tech,ec,area]
  end
end

function HybridBlend(data,area,tech,ec,year)
  (; Enduses,Fuel) = data
  (; EBlend,ETGoal,GPoolDmFrac,DmFrac,DmFracMin) = data   
  
  Electric = Select(Fuel,"Electric")
  Gasoline = Select(Fuel,"Gasoline")
  Ethanol = Select(Fuel,"Ethanol")

  for enduse in Enduses
    GPoolDmFrac[enduse,tech,ec,area] = DmFrac[enduse,Gasoline,tech,ec,area,year]+
      DmFrac[enduse,Ethanol,tech,ec,area,year]
    EBlend[enduse,tech,ec,area] = max(DmFrac[enduse,Ethanol,tech,ec,area,year]/
      GPoolDmFrac[enduse,tech,ec,area],0)
    EBlend[enduse,tech,ec,area] = max(EBlend[enduse,tech,ec,area],ETGoal[year])
    DmFracMin[enduse,Electric,tech,ec,area,year] = 0.65
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = EBlend[enduse,tech,ec,area]*0.35
    DmFracMin[enduse,Gasoline,tech,ec,area,year] = (1-EBlend[enduse,tech,ec,area])*0.35
  end
end

function BiodieselBlend(data,area,tech,ec,year)
  (; Enduses,Fuel) = data
  (; BBlend,BDGoal,DmFrac,DmFracMin) = data
  (; DPoolDmFrac,xDmFrac) = data   

  Diesel = Select(Fuel,"Diesel")
  Biodiesel = Select(Fuel,"Biodiesel")
  
  for enduse in Enduses
    DPoolDmFrac[enduse,tech,ec,area] = DmFrac[enduse,Diesel,tech,ec,area,year]+ 
      DmFrac[enduse,Biodiesel,tech,ec,area,year]
    @finite_math BBlend[enduse,tech,ec,area] = max(0,DmFrac[enduse,Biodiesel,tech,ec,area,year]/
      DPoolDmFrac[enduse,tech,ec,area])
    BBlend[enduse,tech,ec,area] = max(BBlend[enduse,tech,ec,area],BDGoal[year])
    DmFracMin[enduse,Biodiesel,tech,ec,area,year] = BBlend[enduse,tech,ec,area]*
      DPoolDmFrac[enduse,tech,ec,area]
  end
end

function BiofuelBlend(data,area,years)
  (; EC,Fuel,Tech) = data
  
  #
  # FreightEthanolBlend
  # 
  ecs = Select(EC,"Freight")
  techs = Select(Tech,["HDV2B3Gasoline","HDV45Gasoline","HDV67Gasoline","HDV8Gasoline"])

  for year in years, ec in ecs, tech in techs
    EthanolBlend(data,area,tech,ec,year)
  end

  #
  # PassengerEthanolBlend
  #  
  ecs = Select(EC,"Passenger")
  techs = Select(Tech,["LDVGasoline","LDTGasoline","Motorcycle","BusGasoline"])
  
  for year in years, ec in ecs, tech in techs
    EthanolBlend(data,area,tech,ec,year)
  end

  #
  # PassengerHybridEthanolBlend
  #
  ecs = Select(EC,"Passenger")
  techs = Select(Tech,["LDVHybrid","LDTHybrid"])

  for year in years, ec in ecs, tech in techs
    HybridBlend(data,area,tech,ec,year)
  end

  #
  # OffRoadEthanolBlend
  #  
  ecs = Select(EC,["AirPassenger","ResidentialOffRoad","CommercialOffRoad"])
  techs = Select(Tech,"OffRoad")
  
  for year in years, ec in ecs, tech in techs
    EthanolBlend(data,area,tech,ec,year)
  end

  # 
  # FreightBiodieselBlend
  #  
  ecs = Select(EC,"Freight")
  techs = Select(Tech,["HDV2B3Diesel","HDV45Diesel","HDV67Diesel","HDV8Diesel","TrainDiesel","MarineLight"])
  
  for year in years, ec in ecs, tech in techs
    BiodieselBlend(data,area,tech,ec,year)
  end  

  #
  # PassengerBiodieselBlend
  #  
  ecs = Select(EC,"Passenger")
  techs = Select(Tech,["LDVDiesel","LDTDiesel","BusDiesel","TrainDiesel"])
  
  for year in years, ec in ecs, tech in techs
    BiodieselBlend(data,area,tech,ec,year)
  end  

  #
  # OffRoadBiodieselBlend
  #  
  ecs = Select(EC,["AirPassenger","ResidentialOffRoad","CommercialOffRoad"])
  techs = Select(Tech,"OffRoad")
  
  for year in years, ec in ecs, tech in techs
    BiodieselBlend(data,area,tech,ec,year)
  end
  
end
  
function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data   
  (; Area,EC,Enduse,Enduses,Fuel,Tech,Techs) = data
  (; BDGoal,DmFracMin,ETGoal,xDmFrac) = data
  
  years = collect(Future:Final)
  
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.07524
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.08892
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
  end
  
  years = collect(Future:Final)
  for year in years
    BDGoal[year] = 0.0372
  end
  BiofuelBlend(data,Select(Area,"ON"),years)
  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0186
  end
  BiofuelBlend(data,Select(Area,"AB"),years)

  #
  # Manitoba from 2008 to 2020 is 8.50% volume (5.89% energy).
  # Requirement grows to 9.25% volume (6.33% energy) in 2021 and to
  # 10% volume (6.84% energy) in 2022 onwards.
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0465
  end
  BiofuelBlend(data,Select(Area,"MB"),years)

  #
  # Saskatchewan from 2006 onwards is 7.50% volume (5.18% energy), but
  # start in first year of the forecast.
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0518
    BDGoal[year] = 0.0186
  end
  BiofuelBlend(data,Select(Area,"SK"),years)

  #
  # Quebec from 2012 onwards is 5.00% volume (3.42% energy)
  # new regs in 2021, 10% in 2023,12% in 2025, 14% in 2028, 15% in 2030
  #  
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0279
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.08208
  end
  
  years = collect(Yr(2025):Yr(2029))
  for year in years
    BDGoal[year] = 0.0465
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.09576
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
    BDGoal[year] = 0.093
  end
  
  years = collect(Future:Final)
  BiofuelBlend(data,Select(Area,"QC"),years)

  #
  # BC Ethanol from 2010 onwards is 5.00% volume (3.42% energy)
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0372
  end
  BiofuelBlend(data,Select(Area,"BC"),years)

  #
  # The following section sets minimum levels of biofuel blending in NB,NS,PE,NL
  # to 'goose' biofuel blending in these provinces to low levels anticipated in
  # response to the Clean Fuel Regulation. Use ~5% by volume for both biofuels.
  # Matt Lewis - August 23, 2024
  #
  areas = Select(Area,["NS","PE","NL"])
  years = collect(Future:Yr(2024))
  ecs = Select(EC,["Passenger","Freight"])
  techs = Select(Tech,["LDVGasoline","LDTGasoline","LDVHybrid","LDTHybrid","BusGasoline","Motorcycle","HDV2B3Gasoline","HDV45Gasoline","HDV67Gasoline","HDV8Gasoline"])
  Ethanol = Select(Fuel,"Ethanol")

  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.01
  end

  years = collect(Yr(2025):Yr(2026))
  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.03
  end

  years = collect(Yr(2027):Final)
  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.05
  end

  areas = Select(Area,["NB","NS","PE","NL"])
  years = collect(Future:Yr(2024))
  ecs = Select(EC,["Passenger","Freight"])
  techs = Select(Tech,["BusDiesel","LDVDiesel","LDTDiesel","HDV2B3Diesel","HDV45Diesel","HDV67Diesel","HDV8Diesel"])
  Biodiesel = Select(Fuel,"Biodiesel")

  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.01
  end

  years = collect(Yr(2025):Yr(2026))
  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.05
  end

  years = collect(Yr(2027):Final)
  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = 0.09
  end
  
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DmFrac::VariableArray{6} = ReadDisk(BCNameDB,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  #
  # Scratch Variables
  #
  BBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Biodiesel Blend %,not equal to DMFRAC
  BDGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Biodiesel Goal (Btu/Btu)
  DPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Diesel Pool DmFrac,ie Biod + Diesel
  EBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Ethanol Blend %,not equal to DMFRAC
  ETGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Ethanol Goal (Btu/Btu)
  GPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Gasoline Pool DmFrac,ie Ethanol + Gasoline
end

function IndustrialBiofuelBlend(data,area,years)
  (; EC,Enduse,Enduses) = data
  (; Fuel,Tech,Techs) = data
  (; BBlend,BDGoal,DmFrac,DmFracMin) = data
  (; DPoolDmFrac,EBlend,ETGoal,GPoolDmFrac,xDmFrac) = data

  #
  # EthanolBlend
  #  
  ecs = Select(EC,(from = "Food",to = "OnFarmFuelUse"))
  techs = Select(Tech,["Oil","OffRoad"])
  Gasoline = Select(Fuel,"Gasoline")
  Ethanol = Select(Fuel,"Ethanol")

  for year in years, ec in ecs, tech in techs, enduse in Enduses
    GPoolDmFrac[enduse,tech,ec,area,year] = 
      DmFrac[enduse,Gasoline,tech,ec,area,year]+ 
        DmFrac[enduse,Ethanol,tech,ec,area,year]

    @finite_math EBlend[enduse,tech,ec,area,year] = 
      max(0,DmFrac[enduse,Ethanol,tech,ec,area,year]/
        GPoolDmFrac[enduse,tech,ec,area,year])
  end
      
  for year in years, ec in ecs, tech in techs, enduse in Enduses
    EBlend[enduse,tech,ec,area,year] = max(EBlend[enduse,tech,ec,area,year],ETGoal[year])
    xDmFrac[enduse,Ethanol,tech,ec,area,year] = EBlend[enduse,tech,ec,area,year]* 
      GPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Gasoline,tech,ec,area,year] = (1-EBlend[enduse,tech,ec,area,year])* 
      GPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = xDmFrac[enduse,Ethanol,tech,ec,area,year]
 end
 
  #
  # BiodieselBlend
  #  
  Diesel = Select(Fuel,"Diesel")
  Biodiesel = Select(Fuel,"Biodiesel")

  for year in years, ec in ecs, tech in Techs, enduse in Enduses
    DPoolDmFrac[enduse,tech,ec,area,year] = 
      DmFrac[enduse,Diesel,tech,ec,area,year]+ 
        DmFrac[enduse,Biodiesel,tech,ec,area,year]

    @finite_math BBlend[enduse,tech,ec,area,year] = 
      max(0,DmFrac[enduse,Biodiesel,tech,ec,area,year]/
        DPoolDmFrac[enduse,tech,ec,area,year])
  end

  for year in years, ec in ecs, tech in Techs, enduse in Enduses
    BBlend[enduse,tech,ec,area,year] = max(BBlend[enduse,tech,ec,area,year],BDGoal[year])
    xDmFrac[enduse,Biodiesel,tech,ec,area,year] = BBlend[enduse,tech,ec,area,year]* 
      DPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Diesel,tech,ec,area,year] = 
      (1-BBlend[enduse,tech,ec,area,year])*DPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Biodiesel,tech,ec,area,year] = xDmFrac[enduse,Biodiesel,tech,ec,area,year]
  end
  
  return
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area) = data
  (; BDGoal,DmFracMin) = data
  (; ETGoal,xDmFrac) = data

  #
  # Ethanol to energy multiplier = 0.684
  # Biodiesel to energy multiplier = 0.93
  # 
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.07524
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.08892
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
  end
  
  years = collect(Future:Final)
  for year in years
    BDGoal[year] = 0.0372
  end
  IndustrialBiofuelBlend(data,Select(Area,"ON"),years)

  #
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0186
  end
  IndustrialBiofuelBlend(data,Select(Area,"AB"),years)

  #
  # Manitoba from 2008 to 2020 is 8.50% volume (5.89% energy).
  # Requirement grows to 9.25% volume (6.33% energy) in 2021 and to
  # 10% volume (6.84% energy) in 2022 onwards.
  # 
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0465
  end
  IndustrialBiofuelBlend(data,Select(Area,"MB"),years)

  #
  # Saskatchewan from 2006 onwards is 7.50% volume (5.18% energy), but
  # start in first year of the forecast.
  # 
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0518
    BDGoal[year] = 0.0186
  end
  IndustrialBiofuelBlend(data,Select(Area,"SK"),years)

  #
  # Quebec from 2012 onwards is 5.00% volume (3.42% energy)
  # new regs in 2021, 10% in 2023, 12% in 2025, 14% in 2028, 15% in 2030
  #  
  years = collect(Future:Yr(2022))
  for year in years
    ETGoal[year] = 0.0342
  end
  
  years = collect(Yr(2023):Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0279
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.08208
  end  
  
  years = collect(Yr(2025):Yr(2029))
  for year in years
    BDGoal[year] = 0.0465
  end
   
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.09576
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
    BDGoal[year] = 0.093
  end
  
  years = collect(Future:Final)
  IndustrialBiofuelBlend(data,Select(Area,"QC"),years)

  #
  # BC Ethanol from 2010 onwards is 5.00% volume (3.42% energy)
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0372
  end
  IndustrialBiofuelBlend(data,Select(Area,"BC"),years)

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

Base.@kwdef struct RControl
  db::String

  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DmFrac::VariableArray{6} = ReadDisk(BCNameDB,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  # DmFrac::VariableArray{6} = ReadDisk(db,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  # Scratch Variables
  BBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Biodiesel Blend %,not equal to DMFRAC
  BDGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Biodiesel Goal (Btu/Btu)
  DPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Diesel Pool DmFrac,ie Biod + Diesel
  EBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Ethanol Blend %,not equal to DMFRAC
  ETGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Ethanol Goal (Btu/Btu)
  GPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Gasoline Pool DmFrac,ie Ethanol + Gasoline
end

function ResBiofuelBlend(data,area,years)
  (; EC,Enduse) = data
  (; Fuel,Techs) = data
  (; BBlend,BDGoal,DmFrac,DmFracMin) = data
  (; DPoolDmFrac,EBlend,ETGoal,GPoolDmFrac,xDmFrac) = data

  #
  # EthanolBlend
  #  
  ecs = Select(EC,(from = "SingleFamilyDetached",to = "OtherResidential"))
  enduses = Select(Enduse,["Heat","HW"])
  Gasoline = Select(Fuel,"Gasoline")
  Ethanol = Select(Fuel,"Ethanol")
  
  for year in years, ec in ecs, tech in Techs, enduse in enduses
    GPoolDmFrac[enduse,tech,ec,area,year] = 
      DmFrac[enduse,Gasoline,tech,ec,area,year] + 
        DmFrac[enduse,Ethanol,tech,ec,area,year]
        
    @finite_math EBlend[enduse,tech,ec,area,year] = 
      max(0,DmFrac[enduse,Ethanol,tech,ec,area,year]/
        GPoolDmFrac[enduse,tech,ec,area,year])
  end
  
  for year in years, ec in ecs, tech in Techs, enduse in enduses
    EBlend[enduse,tech,ec,area,year] = max(EBlend[enduse,tech,ec,area,year],ETGoal[year])
    xDmFrac[enduse,Ethanol,tech,ec,area,year] = 
      EBlend[enduse,tech,ec,area,year]*GPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Gasoline,tech,ec,area,year] = (1-EBlend[enduse,tech,ec,area,year])* 
      GPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = xDmFrac[enduse,Ethanol,tech,ec,area,year]
  end
  
  #
  # BiodieselBlend
  #  
  Diesel = Select(Fuel,"Diesel")
  Biodiesel = Select(Fuel,"Biodiesel")

  for year in years, ec in ecs, tech in Techs, enduse in enduses
    DPoolDmFrac[enduse,tech,ec,area,year] = 
      DmFrac[enduse,Diesel,tech,ec,area,year]+ 
        DmFrac[enduse,Biodiesel,tech,ec,area,year]

    @finite_math BBlend[enduse,tech,ec,area,year] = 
       max(0,DmFrac[enduse,Biodiesel,tech,ec,area,year]/
        DPoolDmFrac[enduse,tech,ec,area,year])
  end
  
  for year in years, ec in ecs, tech in Techs, enduse in enduses
    BBlend[enduse,tech,ec,area,year] = max(BBlend[enduse,tech,ec,area,year],BDGoal[year])
    xDmFrac[enduse,Biodiesel,tech,ec,area,year] = 
      BBlend[enduse,tech,ec,area,year]*DPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Diesel,tech,ec,area,year] = 
      (1-BBlend[enduse,tech,ec,area,year])*DPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Biodiesel,tech,ec,area,year] = 
      xDmFrac[enduse,Biodiesel,tech,ec,area,year]
  end
  
  return
end

function ResPolicy(db)
  data = RControl(; db)
  (; Input) = data
  (; Area) = data
  (; BDGoal,DmFracMin,ETGoal,xDmFrac) = data

  #
  # Ethanol to energy multiplier = 0.684
  # Biodiesel to energy multiplier = 0.93
  #  
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.07524
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.08892
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
  end
  
  years = collect(Future:Final)
  for year in years
    BDGoal[year] = 0.0372
  end
  ResBiofuelBlend(data,Select(Area,"ON"),years)

  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0186
  end
  ResBiofuelBlend(data,Select(Area,"AB"),years)

  #
  # Manitoba from 2008 to 2020 is 8.50% volume (5.89% energy).
  # Requirement grows to 9.25% volume (6.33% energy) in 2021 and to
  # 10% volume (6.84% energy) in 2022 onwards.
  #  
  ETGoal[Yr(2021)] = 0.0633
  BDGoal[Yr(2021)] = 0.0326
  
  years = collect(Yr(2022):Final)
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0465
  end
  
  years = collect(Future:Final)
  ResBiofuelBlend(data,Select(Area,"MB"),years)

  #
  # Saskatchewan from 2006 onwards is 7.50% volume (5.18% energy), but
  # start in first year of the forecast.
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0518
    BDGoal[year] = 0.0186
  end
  ResBiofuelBlend(data,Select(Area,"SK"),years)

  #
  # Quebec from 2012 onwards is 5.00% volume (3.42% energy)
  # new regs in 2021, 10% in 2023, 12% in 2025, 14% in 2028, 15% in 2030
  #  
  years = collect(Future:Yr(2022))
  for year in years
    ETGoal[year] = 0.0342
  end
  
  years = collect(Yr(2023):Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0279
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.08208
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.09576
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
    BDGoal[year] = 0.093
  end
  
  years = collect(Yr(2025):Yr(2029))
  for year in years 
   BDGoal[year] = 0.0465
  end
  years = collect(Future:Final)
  ResBiofuelBlend(data,Select(Area,"QC"),years)

  #
  # BC Ethanol from 2010 onwards is 5.00% volume (3.42% energy)
  # 
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0372
  end
  ResBiofuelBlend(data,Select(Area,"BC"),years)

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

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
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DmFrac::VariableArray{6} = ReadDisk(BCNameDB,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
 # DmFrac::VariableArray{6} = ReadDisk(db,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  #
  # Scratch Variables
  #
  BBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Biodiesel Blend %,not equal to DMFRAC
  BDGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Biodiesel Goal (Btu/Btu)
  DPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Diesel Pool DmFrac,ie Biod + Diesel
  EBlend::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Ethanol Blend %,not equal to DMFRAC
  ETGoal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Ethanol Goal (Btu/Btu)
  GPoolDmFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Gasoline Pool DmFrac,ie Ethanol + Gasoline
end

function ComBiofuelBlend(data,area,years)
  (; EC,Enduse) = data
  (; Fuel,Tech,Techs) = data
  (; BBlend,BDGoal,DmFrac,DmFracMin) = data
  (; DPoolDmFrac,EBlend,ETGoal,GPoolDmFrac,xDmFrac) = data

  #
  # EthanolBlend
  #  
  ecs = Select(EC,(from = "Wholesale",to = "NGPipeline"))
  enduses = Select(Enduse,["Heat","HW"])
  Gasoline = Select(Fuel,"Gasoline")
  Ethanol = Select(Fuel,"Ethanol")

  for year in years, ec in ecs, tech in Techs, enduse in enduses
    GPoolDmFrac[enduse,tech,ec,area,year] = 
    DmFrac[enduse,Gasoline,tech,ec,area,year]+ 
      DmFrac[enduse,Ethanol,tech,ec,area,year]

    @finite_math EBlend[enduse,tech,ec,area,year] = 
      max(0,DmFrac[enduse,Ethanol,tech,ec,area,year]/
        GPoolDmFrac[enduse,tech,ec,area,year])
  end
      
  for year in years, ec in ecs, tech in Techs, enduse in enduses
    EBlend[enduse,tech,ec,area,year] = max(EBlend[enduse,tech,ec,area,year],ETGoal[year])
    xDmFrac[enduse,Ethanol,tech,ec,area,year] = EBlend[enduse,tech,ec,area,year]* 
      GPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Gasoline,tech,ec,area,year] = (1-EBlend[enduse,tech,ec,area,year])* 
      GPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Ethanol,tech,ec,area,year] = xDmFrac[enduse,Ethanol,tech,ec,area,year]
  end

  #
  # BiodieselBlend
  #  
  Diesel = Select(Fuel,"Diesel")
  Biodiesel = Select(Fuel,"Biodiesel")

  for year in years, ec in ecs, tech in Techs, enduse in enduses
    DPoolDmFrac[enduse,tech,ec,area,year] = 
      DmFrac[enduse,Diesel,tech,ec,area,year]+ 
        DmFrac[enduse,Biodiesel,tech,ec,area,year]
  
    @finite_math BBlend[enduse,tech,ec,area,year] = 
      max(0,DmFrac[enduse,Biodiesel,tech,ec,area,year]/
        DPoolDmFrac[enduse,tech,ec,area,year])
  end
        
  for year in years, ec in ecs, tech in Techs, enduse in enduses
    BBlend[enduse,tech,ec,area,year] = max(BBlend[enduse,tech,ec,area,year],BDGoal[year])
    xDmFrac[enduse,Biodiesel,tech,ec,area,year] = BBlend[enduse,tech,ec,area,year]* 
      DPoolDmFrac[enduse,tech,ec,area,year]
    xDmFrac[enduse,Diesel,tech,ec,area,year] = (1-BBlend[enduse,tech,ec,area,year])* 
      DPoolDmFrac[enduse,tech,ec,area,year]
    DmFracMin[enduse,Biodiesel,tech,ec,area,year] = 
      xDmFrac[enduse,Biodiesel,tech,ec,area,year]
  end
  
  return
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area) = data
  (; BDGoal,DmFracMin,ETGoal,xDmFrac) = data

  #
  # Ethanol to energy multiplier = 0.684
  # Biodiesel to energy multiplier = 0.93
  #  
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
  end
  
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.07524
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years
    ETGoal[year] = 0.08892
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
  end
  
  years = collect(Future:Final)
  for year in years
    BDGoal[year] = 0.0372
  end
  ComBiofuelBlend(data,Select(Area,"ON"),years)

  #
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
    BDGoal[year] = 0.0186
  end
  ComBiofuelBlend(data,Select(Area,"AB"),years)

  #
  # Manitoba from 2008 to 2020 is 8.50% volume (5.89% energy).
  # Requirement grows to 9.25% volume (6.33% energy) in 2021 and to
  # 10% volume (6.84% energy) in 2022 onwards.
  #
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0684
    BDGoal[year] = 0.0465
  end
  ComBiofuelBlend(data,Select(Area,"MB"),years)

  #
  # Saskatchewan from 2006 onwards is 7.50% volume (5.18% energy), but
  # start in first year of the forecast.
  #  
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0518
    BDGoal[year] = 0.0186
  end
  ComBiofuelBlend(data,Select(Area,"SK"),years)

  #
  # Quebec from 2012 onwards is 5.00% volume (3.42% energy)
  # new regs in 2021, 10% in 2023, 12% in 2025, 14% in 2028, 15% in 2030
  #  
  years = collect(Future:Yr(2024))
  for year in years
    ETGoal[year] = 0.0684
  end
 
  years = collect(Yr(2025):Yr(2027))
  for year in years
    ETGoal[year] = 0.08208
  end
  
  years = collect(Yr(2028):Yr(2029))
  for year in years 
    ETGoal[year] = 0.09576
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    ETGoal[year] = 0.1026
  end
  
  years = collect(Future:Yr(2024))
  for year in years
    BDGoal[year] = 0.0279
  end
  
  years = collect(Yr(2025):Yr(2029))
  for year in years
    BDGoal[year] = 0.0465
  end
  
  years = collect(Yr(2030):Final)
  for year in years
    BDGoal[year] = 0.093
  end
  
  years = collect(Future:Final)
  ComBiofuelBlend(data,Select(Area,"QC"),years)

  #
  # BC ethanol from 2010 onwards is 5.00% volume (3.42% energy)
  # 
  years = collect(Future:Final)
  for year in years
    ETGoal[year] = 0.0342
  end
  
  for year in years
    BDGoal[year] = 0.0372
  end
  
  ComBiofuelBlend(data,Select(Area,"BC"),years)

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

function PolicyControl(db)
  @info "KPIA_Biofuels_Prov.jl - PolicyControl"
  TransPolicy(db)
  IndPolicy(db)
  ResPolicy(db)
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
