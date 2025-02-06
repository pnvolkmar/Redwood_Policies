# 
# EndogenousElectricCapacity.jl
#
# This file contains the maximum capacities that can be installed in each PT by yearly
# GCPot refers to the absolute maximum while PjMax is the maximum that can be installed by year.
# Some Ref23 values have been reviewed when working on the Clean Electricity Regulations
# Thus, the 'CER values' have been implemented in Ref24 because they were more up to date
# Consequently, EndogenousElectricCapacity_CER.txp won't be needed anymore
#
# IMPORTANT: AREA & NODE MUST BE SELECTED ONE BY ONE
#            previously Areas and Nodes were selected in group (e.g. Select Area(ON-NL), Node(ON-NL))
#            but it was found causing important errors in simulation.
#            
#
# Updated by Thomas D. (August 2024)
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

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  Nodes::Vector{Int} = collect(Select(Node))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  GCPA::VariableArray{3} = ReadDisk(db,"EOutput/GCPA") # [Plant,Area,Year] Generation Capacity (MW)
  GCPot::VariableArray{4} = ReadDisk(db,"EGOutput/GCPot") # [Plant,Node,Area,Year] Maximum Potential Generation Capacity (MW)
  NdArFr::VariableArray{3} = ReadDisk(db,"EGInput/NdArFr") # [Node,Area,Year] Fraction of the Node in each Area (MW/MW)
  PjMax::VariableArray{2} = ReadDisk(db,"EGInput/PjMax") # [Plant,Area] Maximum Project Size (MW)
  xGCPot::VariableArray{4} = ReadDisk(db,"EGInput/xGCPot") # [Plant,Node,Area,Year] Exogenous Maximum Potential Generation Capacity (MW)
end 

function NodeAreaIndex(data, Ind)
  (; Area, Node) = data 
  if Area[Ind] == "NL"
    return Select(Node, ["NL", "LB"])
  else 
    return Select(Node, Area[Ind])
  end
end
  
function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,Node,Nodes,Plant,Plants,Year,Years) = data
  (; GCPA,PjMax,xGCPot) = data

  #
  # Reset GCPot for Canada
  #
  areas = Select(Area,["ON","QC","BC","NB","NS","NL","PE","AB","MB","SK","NT","NU","YT"])
  
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for year in Years, node in nodes, plant in Plants
      xGCPot[plant,node,area,year] = 0
    end
  end
  
  # No development for the following plant types:
  # Biogas, Biomass, Coal, CoalCCS, Geothermal, FuelCell, OGSteam,
  # OtherGeneration, PumpedHydro, SolarThermal, Tidal, Waste, Unknown
  plants = Select(Plants, ["Biogas", "Biomass", "Coal","CoalCCS","Geothermal", "FuelCell","OGSteam","OtherGeneration","PumpedHydro","SolarThermal","Tidal","Waste"])
  years = collect(Future:Final)
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  #
  # OGCC
  #
  plants = Select(Plants, "OGCC")
  years = collect(Future:Final)
  areas = Select(Area,["ON", "QC","BC","NL","PE","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  #
  # No Limit
  # 
  areas = Select(Area,["AB","SK","NB","NS"])
  for area_name in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  area = Select(Area, "MB")
  nodes = NodeAreaIndex(data,area)
  for plant in plants, node in nodes, year in years
    xGCPot[plant,node,area,year] = 3000
  end
  #
  # SmallOGCC
  #
  plants = Select(Plants, "SmallOGCC")
  years = collect(Future:Final)
  areas = Select(Area,["ON", "QC","BC","MB","NL","PE","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  # No Limit
  areas = Select(Area, ["AB","SK","NB","NS"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  #
  # OGCT
  #
  plants = Select(Plants, "OGCT")
  years = collect(Future:Final)
  # No development
  areas = Select(Area, ["QC","BC","NL"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  # limited development
  areas = ["NT","NU","YT"]
  areas = Select(Area, ["QC","BC","NL"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + 20
    end
  end
  area = Select(Area, "PE")
  node = NodeAreaIndex(data, area)
  xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + 140
  area = Select(Area, "MB")
  node = NodeAreaIndex(data, area)
  xGCPot[plant,node,area,year] = 7000
  # No Limit
  areas = Select(Area, ["ON","AB","SK","NB"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  #
  # NGCCS
  #
  plants = Select(Plants, "NGCCS")
  years = collect(Future:Final)
  # No development
  areas = Select(Area, ["BC","ON","QC","NB","NS","NL","PE","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  # No Limit
  areas = Select(Area, ["AB","MB","SK"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  #
  # BiomassCCS
  #
  plants = Select(Plants, "BiomassCCS")
  years = collect(Future:Final)
  # No development
  areas = Select(Area, ["BC","ON","QC","NB","NS","NL","PE","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  # No Limit
  areas = Select(Area, ["AB","MB","SK"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  #
  # BaseHydro
  #
  plants = Select(Plant, "BaseHydro")
  
  # No development
  areas = Select(Area, ["PE","NU"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # Limited development
  area_limits = [("ON", 6408), ("QC", 3961), ("BC", 2819.20), 
                 ("AB", 1000), ("MB", 8329.94), ("SK", 200),
                 ("NB", 2.6), ("NL", 159.71)]
  for (area_name, increment) in area_limits
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end

  # No limit
  areas = Select(Area, ["NT","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end

  #
  # SmallHydro
  #
  plants = Select(Plant, "SmallHydro")
  years = collect(Future:Final)

  # No development
  areas = Select(Area, ["AB","PE","NU"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # Limited development
  area_limits = [
    ("ON", 3105),
    ("QC", 63),
    ("BC", 1118.76),
    ("MB", 77.06),
    ("SK", 200)
  ]
  for (area_name, increment) in area_limits
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end

  # Areas with no increment
  areas = Select(Area, ["NB","NS"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # NL development periods
  area = Select(Area, "NL")
  nodes = NodeAreaIndex(data,area)

  years = collect(Future:Yr(2028))
  for plant in plants, node in nodes, year in years
    xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
  end

  years = collect(Yr(2029):Final)
  for plant in plants, node in nodes, year in years
    xGCPot[plant,node,area,year] = 1000000
  end

  # No limit areas
  areas = Select(Area, ["NT","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  
  #
  # PeakHydro
  #
  plants = Select(Plant, "PeakHydro")
  years = collect(Future:Final)

  # No development
  areas = Select(Area, ["ON","AB","MB","NS","PE","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # Limited development
  area_limits = [
    ("BC", 26354.04),
    ("NB", 577.4),
    ("NL", 8394.29),
    ("QC", 36218.7)
  ]
  for (area_name, increment) in area_limits
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end

  # SK development periods
  area = Select(Area, "SK")
  nodes = NodeAreaIndex(data,area)

  years = collect(Future:Yr(2034))
  for plant in plants, node in nodes, year in years
    xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + 60
  end

  years = collect(Yr(2035):Final)
  for plant in plants, node in nodes, year in years
    xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + 410
  end
  
  #
  # OnshoreWind
  #
  plants = Select(Plant, "OnshoreWind")
  years = collect(Future:Final)

  # Fixed increment development
  area_limits = [
    ("BC", 15000),
    ("ON", 15000),
    ("MB", 6000),
    ("NL", 1000),
    ("PE", 200),
    ("NT", 10),
    ("NU", 10),
    ("YT", 10)
  ]
  for (area_name, increment) in area_limits
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end

  # Three-period development
  dev_schedule = [
    ("AB", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 9000), (Yr(2030), Final, 15000)]),
    ("SK", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 1678), (Yr(2030), Final, 5000)]),
    ("NS", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 1500), (Yr(2030), Final, 5000)])
  ]

  for (area_name, periods) in dev_schedule
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for (start_year, end_year, increment) in periods
      years = collect(start_year:end_year)
      for plant in plants, node in nodes, year in years
        xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
      end
    end
  end

  # Two-period development
  dev_schedule = [
    ("QC", [(Future, Yr(2030), 0), (Yr(2031), Final, 7500)]),
    ("NB", [(Future, Yr(2030), 0), (Yr(2031), Final, 2000)])
  ]

  for (area_name, periods) in dev_schedule
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for (start_year, end_year, increment) in periods
      years = collect(start_year:end_year)
      for plant in plants, node in nodes, year in years
        xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
      end
    end
  end
  
  #
  # OffshoreWind
  #
  plants = Select(Plant, "OffshoreWind")
  years = collect(Future:Final)

  # No development
  areas = Select(Area, ["ON","QC","PE","AB","MB","SK","NB","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # Two-period development
  dev_schedule = [
    ("BC", 1000),
    ("NS", 500),
    ("NL", 1000)
  ]

  for (area_name, increment) in dev_schedule
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    
    years = collect(Future:Yr(2034))
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
    
    years = collect(Yr(2035):Final)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end
  
  #
  # SolarPV
  #
  plants = Select(Plant, "SolarPV")
  years = collect(Future:Final)

  # Fixed increment development
  area_limits = [
    ("ON", 7500),
    ("QC", 5000),
    ("BC", 7500),
    ("MB", 3000),
    ("NB", 1000),
    ("SK", 1000),
    ("PE", 100),
    ("NT", 10),
    ("NU", 10),
    ("YT", 10)
  ]
  for (area_name, increment) in area_limits
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
    end
  end

  # Three-period development
  dev_schedule = [
    ("AB", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 5350), (Yr(2030), Final, 7500)]),
    ("NS", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 300), (Yr(2030), Final, 1000)]),
    ("NL", [(Future, Yr(2024), 0), (Yr(2025), Yr(2029), 150), (Yr(2030), Final, 1000)])
  ]

  for (area_name, periods) in dev_schedule
    area = Select(Area, area_name)
    nodes = NodeAreaIndex(data,area)
    for (start_year, end_year, increment) in periods
      years = collect(start_year:end_year)
      for plant in plants, node in nodes, year in years
        xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
      end
    end
  end
  
  #
  # Wave
  #
  plants = Select(Plant, "Wave")
  years = collect(Future:Final)

  # No development
  areas = Select(Area, ["ON","QC","BC","NB","NL","PE","AB","MB","SK","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end

  # Three-period development for NS
  area = Select(Area, "NS")
  nodes = NodeAreaIndex(data,area)
  dev_schedule = [
    (Future, Yr(2024), 10),
    (Yr(2025), Yr(2029), 9.65),
    (Yr(2030), Final, 1000000)
  ]

  for (start_year, end_year, increment) in dev_schedule
    years = collect(start_year:end_year)
    for plant in plants, node in nodes, year in years
      if increment == 1000000
        xGCPot[plant,node,area,year] = increment
      else
        xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)] + increment
      end
    end
  end
  
  #
  # Battery (Energy Storage)
  #
  plants = Select(Plant, "Battery")
  years = collect(Future:Final)

  # No limit for all areas
  areas = Select(Area, ["ON","QC","BC","NB","NS","NL","PE","AB","MB","SK","NT","NU","YT"])
  for area in areas
    nodes = NodeAreaIndex(data,area)
    for plant in plants, node in nodes, year in years
      xGCPot[plant,node,area,year] = 1000000
    end
  end
  
  #
  # Nuclear and SMNR
  #
  plants = Select(Plant, ["Nuclear", "SMNR"])
  # No development
  years = collect(Future:Final)
  areas = Select(Area, ["BC","NL","PE"])
  for area in areas 
    nodes = NodeAreaIndex(data, area)
    for plant in plants, node in nodes, year in Years
      xGCPot[plant,node,area,year] = GCPA[plant,area,Yr(2021)]
    end
  end
  
  #
  # Nuclear specific settings
  #
  Nuclear = Select(Plant,"Nuclear")
  
  # No development
  no_dev_areas = ["NT","NU","YT","MB","NB"]
  for area_name in no_dev_areas
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in years
      xGCPot[Nuclear,node,area,year] = GCPA[Nuclear,area,Yr(2021)]
    end
  end

  # Limited development with different time periods
  # QC and ON through 2034
  early_years = collect(Future:Yr(2034))
  for area_name in ["QC","ON"]
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in early_years
      xGCPot[Nuclear,node,area,year] = GCPA[Nuclear,area,Yr(2021)]
    end
  end
  
  # QC and ON after 2034
  later_years = collect(Yr(2035):Final)
  for area_name in ["QC","ON"]
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in later_years
      xGCPot[Nuclear,node,area,year] = GCPA[Nuclear,area,Yr(2021)] + 10000
    end
  end
  
  # NS, AB, SK development periods
  early_years = collect(Future:Yr(2034))
  for area_name in ["NS","AB","SK"]
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in early_years
      xGCPot[Nuclear,node,area,year] = GCPA[Nuclear,area,Yr(2021)]
    end
  end
  
  later_years = collect(Yr(2035):Final)
  area_limits = [("NS", 840), ("AB", 500), ("SK", 500)]
  for (area_name, limit) in area_limits
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in later_years
      xGCPot[Nuclear,node,area,year] = GCPA[Nuclear,area,Yr(2021)] + limit
    end
  end

  #
  # SMNR specific settings
  #
  SMNR = Select(Plant,"SMNR")
  
  # No development
  for area_name in ["QC","NS"]
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    for node in nodes, year in years
      xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
    end
  end

  # ON development
  area = Select(Area,"ON")
  node = Select(Node,"ON")
  early_years = collect(Future:Yr(2039))
  for year in early_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
  end
  later_years = collect(Yr(2040):Final)
  for year in later_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 5390
  end

  # AB development periods
  area = Select(Area,"AB")
  node = Select(Node,"AB")
  period1 = collect(Future:Yr(2029))
  for year in period1
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
  end
  period2 = collect(Yr(2030):Yr(2039))
  for year in period2
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 4420
  end
  period3 = collect(Yr(2040):Final)
  for year in period3
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 14620
  end

  # SK development periods
  area = Select(Area,"SK")
  node = Select(Node,"SK")
  period1 = collect(Future:Yr(2034))
  for year in period1
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
  end
  period2 = collect(Yr(2035):Yr(2039))
  for year in period2
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 600
  end
  period3 = collect(Yr(2040):Final)
  for year in period3
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 1500
  end

  # MB development
  area = Select(Area,"MB")
  node = Select(Node,"MB")
  early_years = collect(Future:Yr(2030))
  for year in early_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
  end
  later_years = collect(Yr(2031):Final)
  for year in later_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 1500
  end

  # NB development
  area = Select(Area,"NB")
  node = Select(Node,"NB")
  early_years = collect(Future:Yr(2039))
  for year in early_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
  end
  later_years = collect(Yr(2040):Final)
  for year in later_years
    xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)] + 840
  end

  # No Limit areas
  no_limit_areas = ["NT","NU","YT"]
  for area_name in no_limit_areas
    area = Select(Area,area_name)
    nodes = NodeAreaIndex(data, area)
    early_years = collect(Future:Yr(2029))
    for node in nodes, year in early_years
      xGCPot[SMNR,node,area,year] = GCPA[SMNR,area,Yr(2021)]
    end
    later_years = collect(Yr(2030):Final)
    for node in nodes, year in later_years
      xGCPot[SMNR,node,area,year] = 1e6
    end
  end

  WriteDisk(db,"EGInput/xGCPot",xGCPot)

  #
  # PjMax Section
  #
  
  # Peakhydro
  PeakHydro = Select(Plant,"PeakHydro")
  area_limits = [
    ("ON", 100),
    ("MB", 200),
    ("QC", 300),
    ("YT", 15)
  ]
  for (area_name, limit) in area_limits
    area = Select(Area,area_name)
    PjMax[PeakHydro,area] = limit
  end

  # Small Hydro
  SmallHydro = Select(Plant,"SmallHydro")
  
  # Areas ON-MB
  areas = Select(Area,(from="ON",to="MB"))
  for area in areas
    PjMax[SmallHydro,area] = 50
  end
  
  # Areas SK-NU
  areas = Select(Area,(from="SK",to="NU"))
  for area in areas
    PjMax[SmallHydro,area] = 10
  end

  # Base Hydro
  BaseHydro = Select(Plant,"BaseHydro")
  areas = Select(Area,["AB","SK"])
  for area in areas
    PjMax[BaseHydro,area] = 200
  end
  
  area = Select(Area,"QC")
  PjMax[BaseHydro,area] = 100

  # Battery
  Battery = Select(Plant,"Battery")
  
  # Areas ON-AB
  areas = Select(Area,(from="ON",to="AB"))
  for area in areas
    PjMax[Battery,area] = 40
  end
  
  # Areas MB-NL
  areas = Select(Area,(from="MB",to="NL"))
  for area in areas
    PjMax[Battery,area] = 15
  end
  
  # Areas PE-NU
  areas = Select(Area,(from="PE",to="NU"))
  for area in areas
    PjMax[Battery,area] = 1
  end

  # Biomass
  Biomass = Select(Plant,"Biomass")
  
  # Areas ON-NL
  areas = Select(Area,(from="ON",to="NL"))
  for area in areas
    PjMax[Biomass,area] = 30
  end
  
  # Areas PE-NU
  areas = Select(Area,(from="PE",to="NU"))
  for area in areas
    PjMax[Biomass,area] = 1
  end

  # Onshore Wind
  OnshoreWind = Select(Plant,"OnshoreWind")
  
  # Areas ON-BC
  areas = Select(Area,(from="ON",to="BC"))
  for area in areas
    PjMax[OnshoreWind,area] = 650
  end
  
  area_limits = [
    ("QC", 750),
    ("AB", 350),
    ("SK", 150),
    ("NL", 70)
  ]
  for (area_name, limit) in area_limits
    area = Select(Area,area_name)
    PjMax[OnshoreWind,area] = limit
  end
  
  areas = Select(Area,["MB","NB","NS"])
  for area in areas
    PjMax[OnshoreWind,area] = 100
  end
  
  # Areas PE-NU
  areas = Select(Area,(from="PE",to="NU"))
  for area in areas
    PjMax[OnshoreWind,area] = 20
  end

  # Solar PV
  SolarPV = Select(Plant,"SolarPV")
  
  # Areas ON-BC
  areas = Select(Area,(from="ON",to="BC"))
  for area in areas
    PjMax[SolarPV,area] = 300
  end
  
  area = Select(Area,"AB")
  PjMax[SolarPV,area] = 150
  
  areas = Select(Area,["MB","NL","SK"])
  for area in areas
    PjMax[SolarPV,area] = 100
  end
  
  area1 = Select(Area,(from="PE",to="NU"))
  areas = union(area1,Select(Area,["NB","NS"]))
  for area in areas
    PjMax[SolarPV,area] = 50
  end

  # SMNR
  SMNR = Select(Plant,"SMNR")
  areas = Select(Area,(from="ON",to="NU"))
  for area in areas
    PjMax[SMNR,area] = 300
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
