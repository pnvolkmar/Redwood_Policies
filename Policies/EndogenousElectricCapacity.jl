#
# EndogenousElectricCapacity.jl
# Renewable and Non-Conventional Potential Capacity (MW)
#

using SmallModel

module EndogenousElectricCapacity

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
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  Nodes::Vector{Int} = collect(Select(Node))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  GCPA::VariableArray{3} = ReadDisk(db,"EOutput/GCPA") # [Plant,Area,Year] Generation Capacity (MW)
  GCPot::VariableArray{4} = ReadDisk(db,"EGOutput/GCPot") # [Plant,Node,Area,Year] Maximum Potential Generation Capacity (MW)
  NdArFr::VariableArray{3} = ReadDisk(db,"EGInput/NdArFr") # [Node,Area,Year] Fraction of the Node in each Area (MW/MW)
  PjMax::VariableArray{2} = ReadDisk(db,"EGInput/PjMax") # [Plant,Area] Maximum Project Size (MW)
  xGCPot::VariableArray{4} = ReadDisk(db,"EGInput/xGCPot") # [Plant,Node,Area,Year] Exogenous Maximum Potential Generation Capacity (MW)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,Nation) = data
  (; Node,Nodes,Plant) = data
  (; Years) = data
  (; ANMap,GCPA,PjMax,xGCPot) = data

  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))

  AB = Select(Area,"AB")
  AB_N = Select(Node,"AB")
  BC = Select(Area,"BC")
  BC_N = Select(Node,"BC")
  SK = Select(Area,"SK")
  SK_N = Select(Node,"SK")
  MB = Select(Area,"MB")
  MB_N = Select(Node,"MB")
  NB = Select(Area,"NB")
  NB_N = Select(Node,"NB")
  NL = Select(Area,"NL")
  NS = Select(Area,"NS")
  NS_N = Select(Node,"NS")
  NU = Select(Area,"NU")
  NU_N = Select(Node,"NU")
  ON = Select(Area,"ON")
  ON_N = Select(Node,"ON")
  PE = Select(Area,"PE")
  PE_N = Select(Node,"PE")
  QC = Select(Area,"QC")
  QC_N = Select(Node,"QC")
  YT = Select(Area,"YT")

  #
  # GCPot Section
  #
  # OGCC and SmallOGCC
  #
  plants = Select(Plant,["OGCC","SmallOGCC"])
  nodes = Select(Node,["ON","AB","SK"])
  areas = Select(Area,["ON","AB","SK"])
  years = collect(Future:Yr(2024))
  for year in years, area in areas, node in nodes, plant in plants
    xGCPot[plant,node,area,year] = GCPA[plant,area,year] + 100 
  end
  
  years = collect(Yr(2025):Final)
  for year in years, area in areas, node in nodes, plant in plants
    xGCPot[plant,node,area,year] = 1e6
  end
  
  years = collect(Future:Yr(2027))
  for year in years, plant in plants
    xGCPot[plant,SK_N,SK,year] = 0
  end

  #
  # Limited capacity for NS
  #
  years = collect(Yr(2026):Final)
  for year in years, plant in plants
    xGCPot[plant,NS_N,NS,year] = 1500
  end

  #
  # No capacity for other
  #
  nodes = Select(Node,["QC","BC","MB","PE","NL","LB","YT","NT","NU"])
  areas = Select(Area,["QC","BC","MB","PE","NL","YT","NT","NU"])
  for year in years, area in areas, node in nodes, plant in plants
    xGCPot[plant,node,area,year] = 0
  end

  #
  # OGCT
  #
  OGCT = Select(Plant,"OGCT")
  areas = Select(Area,["BC","PE","QC","NL"])
  nodes = Select(Node,["BC","PE","QC","NL"])
  years = collect(Future:Final)
  for year in years, area in areas, node in nodes
    xGCPot[OGCT,node,area,year] = 0
  end
  
  areas = Select(Area,["ON","AB","SK"])
  nodes = Select(Node,["ON","AB","SK"])
  years = collect(Future:Yr(2024))
  for year in years, area in areas, node in nodes
    xGCPot[OGCT,node,area,year] = GCPA[OGCT,area,year] + 20 
  end

  #
  # PeakHydro
  #
  PeakHydro = Select(Plant,"PeakHydro")
  areas = Select(Area,["ON","QC","BC","MB","NL"])
  nodes = Select(Node,["ON","QC","BC","MB","NL"])
  years = collect(Yr(2033):Final)
  for year in years, area in areas, node in nodes
    xGCPot[PeakHydro,node,area,year] = 1e6
  end

  #
  # Solar PV
  #
  SolarPV = Select(Plant,"SolarPV")
  area1 = Select(Area,(from = "ON",to = "BC"))
  areas = union(area1,SK)
  node1 = Select(Node,(from = "ON",to = "BC"))
  nodes = union(node1,SK_N)
  for year in Years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = 7500
  end
  
  for year in Years, node in nodes
    xGCPot[SolarPV,node,SK,year] = 5000
  end

  area1 = Select(Area,(from = "NB",to = "NL"))
  areas = union(area1,MB)
  node1 = Select(Node,(from = "NB",to = "NL"))
  nodes = union(node1,MB_N)
  for year in Years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = 1000
  end
  
  for year in Years, node in nodes
    xGCPot[SolarPV,node,PE,year] = 20
  end
  
  areas = Select(Area,(from = "YT",to = "NU"))
  nodes = Select(Node,(from = "YT",to = "NU"))
  for year in Years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = 10
  end
  
  #
  area1 = Select(Area,(from = "ON",to = "BC"))
  areas = union(area1,SK)
  node1 = Select(Node,(from = "ON",to = "BC"))
  nodes = union(node1,SK_N)
  years = collect(Yr(2022):Yr(2024))
  for year in years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = GCPA[SolarPV,area,year] + 300
  end
  
  area1 = Select(Area,(from = "NB",to = "NL"))
  areas = union(area1,MB)
  node1 = Select(Node,(from = "NB",to = "NL"))
  nodes = union(node1,MB_N)
  for year in years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = GCPA[SolarPV,area,year] + 100
  end
  
  for year in years
    xGCPot[SolarPV,PE_N,PE,year] = GCPA[SolarPV,PE,year] + 5
  end
  
  areas = Select(Area,(from = "YT",to = "NU"))
  nodes = Select(Node,(from = "YT",to = "NU"))
  for year in years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = GCPA[SolarPV,area,year] + 1
  end
  
  #
  years = collect(Yr(2022):Yr(2030))
  for year in years, area in areas, node in nodes
    xGCPot[SolarPV,node,area,year] = GCPA[SolarPV,area,year] + 1
  end
  
  for year in years
    xGCPot[SolarPV,NS_N,NS,year] = 300
  end

  nodes = Select(Node,["NL","LB"])
  for year in years, node in nodes
    xGCPot[SolarPV,node,NL,year] = 150
  end

  #
  # Ref23: we limit new endo development in QC because it seems to be added to meet capacity demand
  # but then, it generates large amounts of electricity (because of mustrun=1)
  # that significantly increases the export to the US (~ 20 TWh)
  #
  years = collect(Yr(2027):Final)
  for year in years
    xGCPot[SolarPV,QC_N,QC,year] = 5000
  end

  #
  # AB: We limit addition because the short term projects are already known (AESO LTA reports)
  #
  years = collect(Future:Yr(2026))
  for year in years
    xGCPot[SolarPV,AB_N,AB,year] = GCPA[SolarPV,AB,year]
  end
  
  years = collect(Yr(2027):Yr(2030))
  for year in years
    xGCPot[SolarPV,AB_N,AB,year] = 3800
  end

  #
  # Offshore Wind
  #
  OffshoreWind = Select(Plant,"OffshoreWind")
  areas = Select(Area,(from = "ON",to = "NU"))
  nodes = Select(Node,(from = "ON",to = "NU"))
  years = collect(Yr(2020):Final)
  for year in years, area in areas, node in nodes
    xGCPot[OffshoreWind,node,area,year] = 0
  end

  areas = Select(Area,["NB","NS"])
  nodes = Select(Node,["NB","NS"])
  years = collect(Yr(2033):Final)
  for year in years, area in areas, node in nodes
    xGCPot[OffshoreWind,node,area,year] = 500
  end

  areas = Select(Area,["BC","NS"])
  nodes = Select(Node,["BC","NS"])
  years = collect(Yr(2033):Final)
  for year in years, area in areas, node in nodes
    xGCPot[OffshoreWind,node,area,year] = 1000
  end

  areas = Select(Area,["AB","SK","ON","MB"])
  nodes = Select(Node,["AB","SK","ON","MB"])
  years = collect(Yr(2033):Final)
  for year in years, area in areas, node in nodes
    xGCPot[OffshoreWind,node,area,year] = 0
  end

  #
  # Solar Thermal
  #
  SolarThermal = Select(Plant,"SolarThermal")
  years = collect(Yr(2020):Final)
  for year in years, area in cn_areas, node in Nodes
    xGCPot[SolarThermal,node,area,year] = 0
  end

  #
  # Unknown
  #
  Unknown = Select(Plant,"Unknown")
  for year in years, area in cn_areas, node in Nodes
    xGCPot[Unknown,node,area,year] = 0
  end

  #
  # Nuclear
  #  
  Nuclear = Select(Plant,"Nuclear")
  years = collect(Yr(2020):Final)
  for year in years, area in cn_areas, node in Nodes
    xGCPot[Nuclear,node,area,year] = 0
  end
  
  years = collect(Yr(2026):Final)
  for year in years
    xGCPot[Nuclear,ON_N,ON,year] = 10620
  end
  
  years = collect(Yr(2033):Final)
  for year in years
    xGCPot[Nuclear,ON_N,ON,year] = 1e6
  end
  
  for year in years
    xGCPot[Nuclear,NB_N,NB,year] = 1e6
  end
  
  areas = Select(Area,["AB","SK"])
  nodes = Select(Node,["AB","SK"])
  years = collect(Yr(2030):Final)
  for year in years, area in areas, node in nodes
    xGCPot[Nuclear,node,area,year] = 300
  end
  
  years = collect(Yr(2033):Final)
  for year in years, area in areas, node in nodes
    xGCPot[Nuclear,node,area,year] = 1e6
  end

  #
  # Fuel Cell
  #  
  FuelCell = Select(Plant,"FuelCell")
  for year in Years, area in cn_areas, node in Nodes
    xGCPot[FuelCell,node,area,year] = 0
  end

  #
  # NG CCS
  #  
  NGCCS = Select(Plant,"NGCCS")
  for year in Years, area in cn_areas, node in Nodes
    xGCPot[NGCCS,node,area,year] = 0
  end
  
  areas = Select(Area,["AB","SK","MB"])
  years = collect(Yr(2029):Final)
  for year in years, area in areas, node in Nodes
    xGCPot[NGCCS,node,area,year] = 1e6
  end

  #
  # Coal CCS
  #  
  areas = Select(Area,(from = "ON",to = "NU"))
  CoalCCS = Select(Plant,"CoalCCS")
  years = collect(Future:Final)
  for year in years, area in areas, node in Nodes
    xGCPot[CoalCCS,node,area,year] = 0
  end

  #
  # BaseHydro
  # 
  BaseHydro = Select(Plant,"BaseHydro")
  area1 = Select(Area,(from = "ON",to = "NL"))
  area2 = Select(Area,(from = "YT",to = "NU"))
  areas = union(area1,area2)
  for year in Years, area in areas, node in Nodes
    xGCPot[BaseHydro,node,area,year] = 0
  end
  
  years = collect(Yr(2029):Final)
  for year in years, area in areas, node in Nodes
    xGCPot[BaseHydro,node,area,year] = 1e6
  end
  
  areas = Select(Area,["AB","SK"])
  nodes = Select(Node,["AB","SK"])
  for year in years, area in areas, node in nodes
    xGCPot[BaseHydro,node,area,year] = GCPA[BaseHydro,area,year] + 1000 
  end
  
  for year in years
    xGCPot[BaseHydro,NS_N,NS,year] = 600
    xGCPot[BaseHydro,ON_N,ON,year] = 2000
    xGCPot[BaseHydro,NU_N,NU,year] = 0
    xGCPot[BaseHydro,BC_N,BC,year] = 500
  end
  
  years = collect(Yr(2034):Final)
  for year in years
    xGCPot[BaseHydro,BC_N,BC,year] = 1000
  end
  
  years = collect(Yr(2038):Final)
  for year in years
    xGCPot[BaseHydro,BC_N,BC,year] = 1500
  end

  #
  # SmallHydro
  #  
  SmallHydro = Select(Plant,"SmallHydro")
  area1 = Select(Area,(from = "ON",to = "NL"))
  area2 = Select(Area,(from = "YT",to = "NU"))
  areas = union(area1,area2)
  for year in Years, area in areas, node in Nodes
    xGCPot[SmallHydro,node,area,year] = 0
  end
  
  years = collect(Yr(2029):Final)
  for year in years, area in areas, node in Nodes
    xGCPot[SmallHydro,node,area,year] = 1e6
  end
  
  for year in years
    xGCPot[SmallHydro,NB_N,NB,year] = 95
    xGCPot[SmallHydro,NS_N,NS,year] = 40
    xGCPot[SmallHydro,NU_N,NU,year] = 0
  end

  #
  # Waste
  #  
  Waste = Select(Plant,"Waste")
  areas = Select(Area,(from = "ON",to = "NU"))
  nodes = Select(Node,(from = "ON",to = "NU"))
  for year in Years, area in areas, node in nodes
    xGCPot[Waste,node,area,year] = 0
  end

  #
  # OnshoreWind
  #  
  OnshoreWind = Select(Plant,"OnshoreWind")
  for year in Years
    xGCPot[OnshoreWind,ON_N,ON,year] = 20000
    xGCPot[OnshoreWind,SK_N,SK,year] = 10000
  end
  
  areas = Select(Area,["QC","BC"])
  nodes = Select(Node,["QC","BC"])
  for year in Years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = 15000
  end
  
  areas = Select(Area,["MB","NB","NS"])
  nodes = Select(Node,["MB","NB","NS"])
  for year in Years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = 5000
  end
  
  nodes = Select(Node,["NL","LB"])
  for year in Years, node in nodes
    xGCPot[OnshoreWind,node,NL,year] = 1000
  end
  for year in Years
    xGCPot[OnshoreWind,PE_N,PE,year] = 200
  end
  
  areas = Select(Area,(from = "YT",to = "NU"))
  nodes = Select(Node,(from = "YT",to = "NU"))
  for year in Years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = 10
  end

  #
  # AB: We limit addition in AB because the short term projects are already known (AESO LTA reports)
  #  
  years = collect(Future:Yr(2026))
  for year in years
    xGCPot[OnshoreWind,AB_N,AB,year] = GCPA[OnshoreWind,AB,year]
  end
  
  years = collect(Yr(2027):Final)
  for year in years
    xGCPot[OnshoreWind,AB_N,AB,year] = 15000
  end

  #
  # Ref23: we limit new endo development in QC because it seems to be 
  # added to meet capacity demand but then, it generates large amounts 
  # of electricity (because of mustrun=1) that significantly increases 
  # the export to the US (~ 20 TWh)
  #  
  for year in years
    xGCPot[OnshoreWind,QC_N,QC,year] = 10000
  end

  #
  # Changed to Capacity plus 10 for Hydrogen Production - Jeff Amlin 8/2/22
  # TD: no addition in AB
  #
  areas = Select(Area,(from = "ON",to = "BC"))
  nodes = Select(Node,(from = "ON",to = "BC"))
  for area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,Yr(2021)] = GCPA[OnshoreWind,area,Yr(2021)] + 10
  end
  
  areas = Select(Area,(from = "MB",to = "NU"))
  nodes = Select(Node,(from = "MB",to = "NU"))
  for area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,Yr(2021)] = GCPA[OnshoreWind,area,Yr(2021)] + 10
  end
  
  #
  years = collect(Yr(2022):Yr(2024))
  for year in years
    xGCPot[OnshoreWind,ON_N,ON,year] = GCPA[OnshoreWind,ON,year] + 200
  end
  
  areas = Select(Area,["QC","BC","SK"])
  nodes = Select(Node,["QC","BC","SK"])
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = GCPA[OnshoreWind,area,year] + 100
  end
  
  areas = Select(Area,["MB","NB","NS"])
  nodes = Select(Node,["MB","NB","NS"])
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = GCPA[OnshoreWind,area,year] + 100
  end
  
  nodes = Select(Node,["NL","LB"])
  for year in years, node in nodes
    xGCPot[OnshoreWind,node,NL,year] = GCPA[OnshoreWind,NL,year] + 10 
  end
  
  for year in years
    xGCPot[OnshoreWind,PE_N,PE,year] = GCPA[OnshoreWind,PE,year] + 2
  end
  
  years =collect(Yr(2022):Yr(2024))
  areas = Select(Area,(from = "YT",to = "NU"))
  nodes = Select(Node,(from = "YT",to = "NU"))
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = GCPA[OnshoreWind,area,year] + 1
  end
  
  #
  # No addition in AB
  #
  # Select Area(AB), Node(AB)
  # xGCPot=GCPA+150
  #
  areas = Select(Area,(from = "YT",to = "NU"))
  nodes = Select(Node,(from = "YT",to = "NU"))
  years = collect(Yr(2022):Yr(2030))
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = GCPA[OnshoreWind,area,year] + 1
  end
  
  areas = Select(Area,"NS")
  nodes = Select(Node,"NS")
  years = collect(Yr(2022):Yr(2030))
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = 1500
  end

  #
  # No addition in AB before 2027
  #  
  areas = Select(Area,"AB")
  nodes = Select(Node,"AB")
  years = collect(Yr(2022):Yr(2026))
  for year in years, area in areas, node in nodes
   xGCPot[OnshoreWind,node,area,year] = GCPA[OnshoreWind,area,year]
  end
  
  years =collect(Yr(2027):Yr(2030))
  for year in years, area in areas, node in nodes
    xGCPot[OnshoreWind,node,area,year] = 9000
  end
  
  #
  # Biomass CCS
  #  
  BiomassCCS = Select(Plant,"BiomassCCS")
  areas = Select(Area,(from = "ON",to = "NU"))
  nodes = Select(Node,(from = "ON",to = "NU"))
  for year in Years, area in areas, node in nodes
    xGCPot[BiomassCCS,node,area,year] = 0
  end

  WriteDisk(db,"EGInput/xGCPot",xGCPot)

  ############################
  #
  # PjMax Section
  #
  # NFLD, Yukon, and Nunavut has no natural gas capacity
  #
  OGCC = Select(Plant,"OGCC")
  areas = Select(Area,["YT","NU"])
  # JSO Change
  for area in areas
    PjMax[OGCC,area] = 99999
  end
  # JSO Change
  OGSteam = Select(Plant,"OGSteam")
  for area in areas
    PjMax[OGSteam,area] = 99999
  end

  #
  # Advanced Coal must be IGCC
  #
  # Select Plant(CoalAdvanced)
  # PjMax=0
  # Select Area(AB,SK)
  # PjMax=99999
  #
  
  #
  # Quebec builds hydro instead of natural gas and oil
  #
  PjMax[PeakHydro,ON] = 100
 
  #
  # JSO Change
  # Select Plant(OGCC,OGCT)
  # PjMax=0
  #

  #
  # Manitoba builds hydro instead of natural gas and oil
  #  
  PjMax[PeakHydro,MB] = 200
  plants = Select(Plant,["OGCC","OGCT"])
  for plant in plants
    PjMax[plant,MB] = 0
  end
  
  #
  plants = Select(Plant,["OGCC","OGCT","SmallOGCC"])
  for plant in plants
    PjMax[plant,NL] = 0
  end
  
  #
  PjMax[CoalCCS,AB] = 0

  # Yukon builds small hydro - Jeff Amlin 11/07/16
  PjMax[PeakHydro,YT] = 15

  #
  # John St-Laurent O'Connor 2021.10.15 Changes to cap yearly growth
  # of some plant types in some areas
  #  
  areas = Select(Area,(from = "ON",to = "AB"))
  OtherStorage = Select(Plant,"OtherStorage")
  for area in areas
   PjMax[OtherStorage,area] = 40
  end
  
  areas = Select(Area,(from = "MB",to = "NL"))
  for area in areas
    PjMax[OtherStorage,area] = 15
  end
  
  areas = Select(Area,(from = "PE",to = "NU"))
  for area in areas
    PjMax[OtherStorage,area] = 1
  end
  
  #
  areas = Select(Area,(from = "ON",to = "NL"))
  Biomass = Select(Plant,"Biomass")
  for area in areas
    PjMax[Biomass,area] = 30
  end
  
  areas = Select(Area,(from = "PE",to = "NU"))
  for area in areas
    PjMax[Biomass,area] = 1
  end
  
  #
  areas = Select(Area,(from = "ON",to = "MB"))
  for area in areas
    PjMax[SmallHydro,area] = 50
  end
  
  areas = Select(Area,(from = "SK",to = "NU"))
  for area in areas
    PjMax[SmallHydro,area] = 10
  end
  
  #
  areas = Select(Area,["AB","SK"])
  for area in areas
    PjMax[BaseHydro,area] = 200
  end
  
  #
  areas = Select(Area,(from = "ON",to = "BC"))
  for area in areas
    PjMax[OnshoreWind,area] = 650
  end
  
  PjMax[OnshoreWind,AB] = 350
  PjMax[OnshoreWind,SK] = 150
  areas = Select(Area,["MB","NB","NS"])
  for area in areas
    PjMax[OnshoreWind,area] = 100
  end
  
  PjMax[OnshoreWind,NL] = 70
  areas = Select(Area,(from = "PE",to = "NU"))
  for area in areas
    PjMax[OnshoreWind,area] = 20
  end
  
  #
  areas = Select(Area,(from = "ON",to = "BC"))
  for area in areas
    PjMax[SolarPV,area] = 300
  end
  
  PjMax[SolarPV,AB] = 150
  areas = Select(Area,["MB","NB","NL","SK"])
  for area in areas
    PjMax[SolarPV,area] = 100
  end
  
  area1 = Select(Area,(from = "PE",to = "NU"))
  areas = union(area1,NS)
  for area in areas
    PjMax[SolarPV,area] = 50
  end
  
  #
  areas = Select(Area,(from = "ON",to = "NU"))
  for area in areas
    PjMax[Waste,area] = 0
  end

  WriteDisk(db,"EGInput/PjMax",PjMax)
end

function PolicyControl(db)
  @info "EndogenousElectricCapacity.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
