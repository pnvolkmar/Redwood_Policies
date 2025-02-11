#
# LCFS_BC.jl
#
# This policy implements a 20% Low Carbon Fuel Standard for transportation fuels in BC
#
# Note,we are increasing biofuel component of Transportation energy to represent
# the carbon intensity reduction of the fossil fuel component.
# This pushes ethanol to the blend wall limit of 15% by volume.
# Other aspects not modelled here are ZEV credits and part 3 credits.
# The biodiesel (which represents HDRD + Biodiesel) blend rate rises to 23.8%
# by 2030 which represents the full intensity reduction as estimated by BC.
# 
# Matt Lewis Sept 29 2020
#  
# Added 10% SAF blending by 2030 according to comments from BC, use
# ethanol as a proxy for REF24, Biojet works but no emission factors yet
# Matt Lewis Sept 20 2024

using SmallModel

module LCFS_BC

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: DB
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  CTech::SetArray = ReadDisk(db,"$Input/CTechKey")
  CTechDS::SetArray = ReadDisk(db,"$Input/CTechDS")
  CTechs::Vector{Int} = collect(Select(CTech))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  PI::SetArray = ReadDisk(db,"$Input/PIKey")
  PIDS::SetArray = ReadDisk(db,"$Input/PIDS")
  PIs::Vector{Int} = collect(Select(PI))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelKey::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # Demand Fuel/Tech Fraction Minimum (Btu/Btu) [Enduse,Fuel,Tech,EC,Area,Year]
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year]  'Energy Demands Fuel/Tech Split (Fraction)',

  #
  # Scratch Variables
  #
  BDTarget::VariableArray{1} = zeros(Float64,length(Year))
  DmFrXBefore::VariableArray{6} = zeros(Float64,length(Enduse),length(Fuel),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Fuel,Tech,EC,Area,Year] xDmFrac from Biofuel Before Policy (Btu/Btu)
  ETTarget::VariableArray{1} = zeros(Float64,length(Year))
  SAFTarget::VariableArray{1} = zeros(Float64,length(Year)) #Policy Sustainable Aviation Fuel Target by volume (Btu/Btu)
end

function TPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,Areas,EC,ECs,Enduse,Enduses,Fuel,Fuels,Tech,Techs,Year,Years) = data
  (; BDTarget,DmFracMin,DmFrXBefore,ETTarget,SAFTarget) = data
  (; xDmFrac) = data

  ETMax = 0.1026

  BC = Select(Area,"BC")
  for year in Years, ec in ECs, tech in Techs, fuel in Fuels, enduse in Enduses
    DmFrXBefore[enduse,fuel,tech,ec,BC,year] = xDmFrac[enduse,fuel,tech,ec,BC,year]
  end

  #
  # SAFTarget represents the target blending rate of Sustainable Aviation Fuel
  # Use ethanol as a SAF proxy
  # start blending in 2023 ramping to 10% by 2030
  #
  years = collect(Yr(2030):Final)
  for year in years
    SAFTarget[year] = 0.1
  end

  years = collect(Yr(2023):Yr(2029))
  for year in years
    SAFTarget[year] =
      SAFTarget[year-1] + (SAFTarget[Yr(2030)] - SAFTarget[Yr(2022)]) / (2030 - 2022)
  end

  years = collect(Yr(2023):Final)

  ecs = Select(EC,["AirPassenger","AirFreight"])
  enduses = Select(Enduse,"Carriage")
  Ethanol = Select(Fuel,"Ethanol")
  JetFuel = Select(Fuel,"JetFuel")
  techs = Select(Tech,"PlaneJetFuel")

  for year in years,ec in ecs,tech in techs,enduse in enduses
    xDmFrac[enduse,Ethanol,tech,ec,BC,year] =
      max((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year]),
        (((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
           (DmFrXBefore[enduse,JetFuel,tech,ec,BC,year])) * SAFTarget[year])))

    xDmFrac[enduse,JetFuel,tech,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
               (DmFrXBefore[enduse,JetFuel,tech,ec,BC,year])) -
              xDmFrac[enduse,Ethanol,tech,ec,BC,year]))

    DmFracMin[enduse,Ethanol,tech,ec,BC,year] = xDmFrac[enduse,Ethanol,tech,ec,BC,year]
  end

  AviationGasoline = Select(Fuel,"AviationGasoline")
  techs = Select(Tech,"PlaneGasoline")

  for year in years,ec in ecs,tech in techs,enduse in enduses
    xDmFrac[enduse,Ethanol,tech,ec,BC,year] =
      max((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year]),
        (((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
           (DmFrXBefore[enduse,AviationGasoline,tech,ec,BC,year])) * SAFTarget[year])))

    xDmFrac[enduse,AviationGasoline,tech,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
               (DmFrXBefore[enduse,AviationGasoline,tech,ec,BC,year])) -
              xDmFrac[enduse,Ethanol,tech,ec,BC,year]))

    DmFracMin[enduse,Ethanol,tech,ec,BC,year] = xDmFrac[enduse,Ethanol,tech,ec,BC,year]
  end

  # 
  # ETTarget represents the max blending rate of 15%,which does
  # not meet the 20% improvement relative to 2010 baseline
  #
  # BDTarget represents the blending rate needed to reduce emissions
  # intensity by 20% relative to 2010 baseline
  # 


  #
  # Code below matches Promula version. Note that 'Last' != Yr(2020) - Ian 05/16/24
  # TODO - we should decide on Last or 2020 and use it consistenlty - Jeff Amlin 1/22/25
  #  
  ETTarget[Last] = 0.04
  ETTarget[Yr(2030)] = 0.15

  years = collect(Future:Yr(2030))
  for year in years
    ETTarget[year] =
      ETTarget[year-1] + (ETTarget[Yr(2030)] - ETTarget[Yr(2020)]) / (2030 - 2020)
  end

  years = collect(Yr(2031):Final)
  for year in years
    ETTarget[year] = ETTarget[Yr(2030)]
  end

  BDTarget[Last] = 0.04
  BDTarget[Yr(2030)] = 0.238
  years = collect(Future:Yr(2030))
  for year in years
    BDTarget[year] =
      BDTarget[year-1] + (BDTarget[Yr(2030)] - BDTarget[Yr(2020)]) / (2030 - 2020)
  end

  years = collect(Yr(2031):Final)
  for year in years
    BDTarget[year] = BDTarget[Yr(2030)]
  end

  # 
  # Ethanol content target is 15.00% in volume of gasoline,equals 10.26% by energy
  # based on NIR energy content factors
  # 
  years = collect(Future:Final)
  ecs = Select(EC,["Passenger","Freight"])
  Ethanol = Select(Fuel,"Ethanol")
  Gasoline = Select(Fuel,"Gasoline")
  techs = Select(Tech,["LDVGasoline","LDVHybrid","LDTGasoline","LDTHybrid","Motorcycle",
    "BusGasoline","HDV2B3Gasoline","HDV45Gasoline","HDV67Gasoline","HDV8Gasoline"])
  enduse = Select(Enduse,"Carriage")

  ETER = 10.26 / 15

  # 
  # Ethanol goal is the maximum of the Federal goal or an existing (provincial) goal.
  # 
  for year in years,ec in ecs,tech in techs
    xDmFrac[enduse,Ethanol,tech,ec,BC,year] =
      max(DmFrXBefore[enduse,Ethanol,tech,ec,BC,year],
        ((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
          DmFrXBefore[enduse,Gasoline,tech,ec,BC,year]) * ETER * ETTarget[year]))

    xDmFrac[enduse,Ethanol,tech,ec,BC,year] =
      min(xDmFrac[enduse,Ethanol,tech,ec,BC,year],ETMax)

    xDmFrac[enduse,Gasoline,tech,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Ethanol,tech,ec,BC,year] +
               DmFrXBefore[enduse,Gasoline,tech,ec,BC,year]) -
              xDmFrac[enduse,Ethanol,tech,ec,BC,year]))

    DmFracMin[enduse,Ethanol,tech,ec,BC,year] = xDmFrac[enduse,Ethanol,tech,ec,BC,year]
  end

  # 
  # Biodiesel energy content for a 15% volume of diesel = 13.93% energy
  # based on NIR energy content factors
  # 
  Diesel = Select(Fuel,"Diesel")
  Biodiesel = Select(Fuel,"Biodiesel")
  techs = Select(Tech,["LDVDiesel","LDTDiesel","BusDiesel","HDV2B3Diesel",
    "HDV45Diesel","HDV67Diesel","HDV8Diesel","TrainDiesel"])
  enduse = Select(Enduse,"Carriage")

  BDER = 13.93 / 15

  # 
  # Biodiesel goal is the maximum of the Federal goal or an existing (provincial) goal.
  # 
  for year in years,ec in ecs,tech in techs
    xDmFrac[enduse,Biodiesel,tech,ec,BC,year] =
      max(DmFrXBefore[enduse,Biodiesel,tech,ec,BC,year],
        ((DmFrXBefore[enduse,Biodiesel,tech,ec,BC,year] +
          DmFrXBefore[enduse,Diesel,tech,ec,BC,year]) * (BDER * BDTarget[year])))

    xDmFrac[enduse,Diesel,tech,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Biodiesel,tech,ec,BC,year] +
               DmFrXBefore[enduse,Diesel,tech,ec,BC,year]) -
              xDmFrac[enduse,Biodiesel,tech,ec,BC,year]))

    DmFracMin[enduse,Biodiesel,tech,ec,BC,year] = xDmFrac[enduse,Biodiesel,tech,ec,BC,year]
  end

  # 
  # Apply LCFS to Off-Road
  # 
  OffRoad = Select(Tech,"OffRoad")
  ecs = Select(EC,["AirPassenger","ResidentialOffRoad","CommercialOffRoad"])
  enduse = Select(Enduse,"Carriage")

  for year in years,ec in ecs
    xDmFrac[enduse,Biodiesel,OffRoad,ec,BC,year] =
      max(DmFrXBefore[enduse,Biodiesel,OffRoad,ec,BC,year],
        ((DmFrXBefore[enduse,Biodiesel,OffRoad,ec,BC,year] +
          DmFrXBefore[enduse,Diesel,OffRoad,ec,BC,year]) * (BDER * BDTarget[year])))

    xDmFrac[enduse,Diesel,OffRoad,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Biodiesel,OffRoad,ec,BC,year] +
               DmFrXBefore[enduse,Diesel,OffRoad,ec,BC,year]) -
              xDmFrac[enduse,Biodiesel,OffRoad,ec,BC,year]))

    DmFracMin[enduse,Biodiesel,OffRoad,ec,BC,year] =
      xDmFrac[enduse,Biodiesel,OffRoad,ec,BC,year]

    xDmFrac[enduse,Ethanol,OffRoad,ec,BC,year] =
      max(DmFrXBefore[enduse,Ethanol,OffRoad,ec,BC,year],
        ((DmFrXBefore[enduse,Ethanol,OffRoad,ec,BC,year] +
          DmFrXBefore[enduse,Gasoline,OffRoad,ec,BC,year]) * ETER * ETTarget[year]))

    xDmFrac[enduse,Ethanol,OffRoad,ec,BC,year] =
      min(xDmFrac[enduse,Ethanol,OffRoad,ec,BC,year],ETMax)

    xDmFrac[enduse,Gasoline,OffRoad,ec,BC,year] =
      max(0,((DmFrXBefore[enduse,Ethanol,OffRoad,ec,BC,year] +
               DmFrXBefore[enduse,Gasoline,OffRoad,ec,BC,year]) -
              xDmFrac[enduse,Ethanol,OffRoad,ec,BC,year]))

    DmFracMin[enduse,Ethanol,OffRoad,ec,BC,year] =
      xDmFrac[enduse,Ethanol,OffRoad,ec,BC,year]
  end

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

function PolicyControl(db)
  @info "LCFS_BC.jl - PolicyControl"
  TPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
