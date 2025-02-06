#
# Electricity_Patch.jl
#
# This file is used to fix issues related to a specific scenario.
# Normally, all fixes should be removed when preparing a new scenario.
# The file is organized in several sections:
#
# SECTION 1: increase hydropower with (UnEAF): usually to resolve emergency power
# SECTION 2: increase power plant generation with (UnOR): usually to resolve emergency power or increase thermal power generation
# SECTION 3: manage problematic power plants (UnRetire, UnOnline, UnOR)
# SECTION 4: increase coal power generation (HDVCFR, AvFactor): E2020 tends to under estimate coal power generation in projections
# SECTION 5: reserve margin (DRM): could be used to resolve emergency power
# 
# Other codes (to be cleaned):
#     - Edits for CER CGII (temporary): this section will be moved to the relevant files
#     - Capacity transmission and contracts: this section will be moved to the relevant files
#      (a Section 6 will be created for adjusting LLMax and HDXload to resolve scenario issues) 
#     - Design hours: this section will be moved to the relevant files (could it be used in a new Section 7?)
#

using SmallModel

module Electricity_Patch

import ...SmallModel: ReadDisk, WriteDisk, Select
import ...SmallModel: HisTime, ITime, MaxTime, First, Future, Final, Yr
import ...SmallModel: @finite_math, finite_inverse, finite_divide, finite_power, finite_exp, finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String
  
  # Sets
  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  GenCo::SetArray = ReadDisk(db,"E2020DB/GenCoKey")
  GenCos::Vector{Int} = collect(Select(GenCo))
  Month::SetArray = ReadDisk(db,"E2020DB/MonthKey")
  Months::Vector{Int} = collect(Select(Month))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey") 
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  Nodes::Vector{Int} = collect(Select(Node))
  NodeX::SetArray = ReadDisk(db,"E2020DB/NodeXKey")
  NodeXs::Vector{Int} = collect(Select(NodeX))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  Plants::Vector{Int} = collect(Select(Plant))
  Power::SetArray = ReadDisk(db,"E2020DB/PowerKey")
  Powers::Vector{Int} = collect(Select(Power))
  TimeP::SetArray = ReadDisk(db,"E2020DB/TimePKey")
  TimePs::Vector{Int} = collect(Select(TimeP))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  Years::Vector{Int} = collect(Select(Year))

  # Variables
  AvFactor::VariableArray{5} = ReadDisk(db,"EGInput/AvFactor") # [Plant,TimeP,Month,Area,Year] Availability Factor (MW/MW)
  BuildSw::VariableArray{2} = ReadDisk(db,"EGInput/BuildSw") # [GenCo,Year] Build switch
  DesHr::VariableArray{4} = ReadDisk(db,"EGInput/DesHr") # [Plant,Power,Area,Year] Design Hours (Hours)
  DRM::VariableArray{2} = ReadDisk(db,"EInput/DRM") # [Node,Year] Desired Reserve Margin (MW/MW)
  HDHours::VariableArray{2} = ReadDisk(db,"EInput/HDHours") # [TimeP,Month] Number of Hours in the Interval (Hours)
  HDVCFR::VariableArray{6} = ReadDisk(db,"EGInput/HDVCFR") # [Plant,GenCo,Node,TimeP,Month,Year] Fraction of Variable Costs Bid ($/$)
  HDXLoad::VariableArray{5} = ReadDisk(db,"EGInput/HDXLoad") # [Node,NodeX,TimeP,Month,Year] Exogenous Loading on Transmission Lines (MW)
  LLMax::VariableArray{5} = ReadDisk(db,"EGInput/LLMax") # [Node,NodeX,TimeP,Month,Year] Maximum Loading on Transmission Lines (MW)
  TPRMap::VariableArray{2} = ReadDisk(db,"EGInput/TPRMap") # [TimeP,Power] TimeP to Power Map
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag
  UnEAF::VariableArray{3} = ReadDisk(db,"EGInput/UnEAF") # [Unit,Month,Year] Energy Availability Factor
  UnFlFrMax::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMax") # [Unit,FuelEP,Year] Fuel Fraction Maximum
  UnFlFrMin::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMin") # [Unit,FuelEP,Year] Fuel Fraction Minimum
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnHRt::VariableArray{2} = ReadDisk(db,"EGInput/UnHRt") # [Unit,Year] Heat Rate (BTU/KWh)
  UnMustRun::VariableArray{1} = ReadDisk(db,"EGInput/UnMustRun") # [Unit] Must Run Flag
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnNation::Array{String} = ReadDisk(db,"EGInput/UnNation") # [Unit] Nation
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnOR::VariableArray{2} = ReadDisk(db,"EGInput/UnOR") # [Unit,Year] Outage Rate (MW/MW)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnRetire::VariableArray{2} = ReadDisk(db,"EGInput/UnRetire") # [Unit,Year] Retirement Date (Year)
  UnSource::VariableArray{1} = ReadDisk(db,"EGInput/UnSource") # [Unit] Source Flag
  xUnFlFr::VariableArray{3} = ReadDisk(db,"EGInput/xUnFlFr") # [Unit,FuelEP,Year] Fuel Fraction (Btu/Btu)
  xUnVCost::VariableArray{4} = ReadDisk(db,"EGInput/xUnVCost") # [Unit,TimeP,Month,Year] Exogenous Market Price Bid ($/MWh)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,FuelEP,GenCo,Month,Node,NodeX,Plant,Power,TimeP,Unit,Year) = data
  (; Areas,FuelEPs,GenCos,Months,Nodes,NodeXs,Plants,Powers,TimePs,Units,Years) = data
  (; AvFactor,BuildSw,DesHr,DRM,HDHours,HDVCFR,HDXLoad,LLMax) = data
  (; UnArea,UnCode,UnCogen,UnEAF,UnFlFrMax,UnFlFrMin) = data
  (; UnGenCo,UnHRt,UnMustRun,UnNode,UnNation,UnOnLine) = data
  (; UnOR,UnPlant,UnRetire,UnSource,xUnFlFr,xUnVCost) = data

  #
  # SECTION 1: Increase hydropower with UnEAF
  #
  
  # Labrador (LB)
  unit1 = Select(UnNation, ==("CN"))
  unit2 = Select(UnArea, ==("NL"))
  unit3 = Select(UnNode, ==("LB"))
  unit4 = Select(UnCogen, ==(0))
  unit5 = Select(UnPlant, ==("PeakHydro"))
  units = intersect(unit1, unit2, unit3, unit4, unit5)

  for month in Months, unit in units
    UnEAF[unit,month,Yr(2023)] *= 1.18 * 1.08 * 1.035 * 1.011
    UnEAF[unit,month,Yr(2024)] *= 1.12 * 1.05 * 1.019 * 1.026
    UnEAF[unit,month,Yr(2025)] *= 1.1 * 1.05 * 1.027 * 1.054
    UnEAF[unit,month,Yr(2026)] *= 1.09 * 1.04 * 1.032 * 1.054
    UnEAF[unit,month,Yr(2027)] *= 1.07 * 1.04 * 1.036 * 1.050
    UnEAF[unit,month,Yr(2028)] *= 1.06 * 1.03 * 1.041 * 1.050
    UnEAF[unit,month,Yr(2029)] *= 1.05 * 1.02 * 1.044 * 1.053
    UnEAF[unit,month,Yr(2030)] *= 1.05 * 1.02 * 1.038 * 1.049
    UnEAF[unit,month,Yr(2031)] *= 1.04 * 1.01 * 1.042 * 1.049
    UnEAF[unit,month,Yr(2032)] *= 1.04 * 1.038 * 1.046
    UnEAF[unit,month,Yr(2033)] *= 1.03 * 1.034 * 1.042
    UnEAF[unit,month,Yr(2034)] *= 1.02 * 1.030 * 1.039
    UnEAF[unit,month,Yr(2035)] *= 1.01 * 1.026 * 1.035
    UnEAF[unit,month,Yr(2036)] *= 1.01 * 1.023 * 1.025
    UnEAF[unit,month,Yr(2037)] *= 1.01 * 1.015
  end

  # Manitoba (MB)
  unit1 = Select(UnNation, ==("CN"))
  unit2 = Select(UnArea, ==("MB"))
  unit3 = Select(UnNode, ==("MB"))
  unit4 = Select(UnCogen, ==(0))
  unit5 = Select(UnPlant, ==("PeakHydro"))
  units = intersect(unit1, unit2, unit3, unit4, unit5)

  for month in Months, unit in units
    UnEAF[unit,month,Yr(2023)] *= 1.085
    UnEAF[unit,month,Yr(2024)] *= 1.13
  end

  # New Brunswick (NB)
  unit1 = Select(UnNation, ==("CN"))
  unit2 = Select(UnArea, ==("NB"))
  unit3 = Select(UnNode, ==("NB"))
  unit4 = Select(UnCogen, ==(0))
  unit5 = Select(UnPlant, ==("PeakHydro"))
  units = intersect(unit1, unit2, unit3, unit4, unit5)
  years = collect(Yr(2023):Yr(2025))
  
  for year in years, month in Months, unit in units
    UnEAF[unit,month,year] *= 1.15
  end

  # Ontario (ON)
  unit1 = Select(UnNation, ==("CN"))
  unit2 = Select(UnArea, ==("ON"))
  unit3 = Select(UnNode, ==("ON"))
  unit4 = Select(UnCogen, ==(0))
  unit5 = Select(UnPlant, ==("PeakHydro"))
  units = intersect(unit1, unit2, unit3, unit4, unit5)
  years = collect(Yr(2027):Yr(2033))
  
  for year in years, month in Months, unit in units
    UnEAF[unit,month,year] *= 1.2
  end

  WriteDisk(db,"EGInput/UnEAF",UnEAF)

  #
  # SECTION 2: Adjust plant operations with UnOR
  # 
  # NB(2023) Missing generation due to inadequat historical values
  # NB (2024-2050) lack of oil and gas generation
  # ON we have too much nuclear generation because we used generic UnOR rather than LHY UnOR
  # ON after decreasing natural gas plant bidding price we have too much natural gas generation
  # NL emissions are a bit low in projections (also due to UnOR(LHY))
  #
  # NT, NU, YT: fixing Future-Final heat rates that are too high causing a jump in emissions
  #
  
  # New Brunswick (NB) 
  
  # OGCC plants: Adjusting UnOR to reach ~1400 GWh as wanted in NB consultation REF24

  unit1 = Select(UnArea, ==("NB"))
  unit2 = Select(UnPlant, ==("OGCC"))
  units = intersect(unit1, unit2)
  
  years = collect(Future:Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.435
  end

  # NB OGCT plants: Adjusting UnOR to reach ~570 GWh as wanted in NB consultation REF24

  unit1 = Select(UnArea, ==("NB"))
  unit2 = Select(UnPlant, ==("OGCT"))
  unit3 = Select(UnSource, ==(0))
  units = intersect(unit1, unit2, unit3)
  
  for year in years, unit in units
    UnOR[unit,year] = 0.993831606
  end

  # NB OGSteam plants: Adjusting UnOR to reach ~570 GWh as wanted in NB consultation REF24

  unit1 = Select(UnArea, ==("NB"))
  unit2 = Select(UnPlant, ==("OGSteam"))
  unit3 = Select(UnSource, ==(0))
  units = intersect(unit1, unit2, unit3)

  for year in years, unit in units
    UnOR[unit,year] = 0.936798596
  end

  # Belledune: Align Belledune (OGSteam) biomass generation to 
  # previous coal generation (before conversion)
  units = Select(UnCode, ==("NB00006601BIO"))
  for year in years, unit in units
    UnOR[unit,year] = 0.3708571
  end

  # Point Lepreau has a high UnOR due to LHY, it contributes to cause emega --> implementing 5 years-average historical UnOR
  units = Select(UnCode, ==("NB00006601201"))
  for year in years, unit in units
    UnOR[unit,year] = 0.20
  end

  # Ontario (ON)
  
  #
  # Restore LHY values for UnOR (excepted for refurbishment)
  #
  for unit in Units
    if UnCode[unit] =="ON00011106701"
      UnOR[unit, Yr(2026):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011106702"
      UnOR[unit, Future:Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011106703"
      UnOR[unit, Yr(2024):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011106704"
      UnOR[unit, Yr(2022)] = 0.312975744815718
      UnOR[unit, Yr(2027):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011106801" || UnCode[unit] =="ON00011106802" || UnCode[unit] =="ON00011106803" || UnCode[unit] =="ON00011106804"
      UnOR[unit, Yr(2022):Yr(2025)] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011107601" 
      UnOR[unit, Yr(2022):Yr(2023)] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00011107604" 
      UnOR[unit, Yr(2022):Yr(2024)] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100201" || UnCode[unit] =="ON00037100202"
      UnOR[unit, Future:Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100203"
      UnOR[unit, Yr(2022)] = 0.312975744815718
      UnOR[unit, Yr(2027):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100204"
      UnOR[unit, Yr(2022):Yr(2024)] .= 0.312975744815718
      UnOR[unit, Yr(2028):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100301"
      UnOR[unit, Yr(2022):Yr(2025)] .= 0.312975744815718
      UnOR[unit, Yr(2030):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100302"
      UnOR[unit, Yr(2024):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100303"
      UnOR[unit, Yr(2022):Yr(2027)] .= 0.312975744815718
      UnOR[unit, Yr(2032):Final] .= 0.312975744815718
    end
    if UnCode[unit] =="ON00037100304"
      UnOR[unit, Yr(2022):Yr(2029)] .= 0.312975744815718
      UnOR[unit, Yr(2034):Final] .= 0.312975744815718
    end
    #
    # SMNR plants: Endogenous UnOR is wrong (0.3 instead of 0.073)
    #
    if UnPlant[unit] =="SMNR"
      UnOR[unit, Future:Final] .= 0.073
    end
  end
  
  #
  # There is emergency power in ON.
  # We deal with it by increasing peak hydro (above) and nuclear/natural gas (below)
  #
  
  unit1 = Select(UnArea, ==("ON"))
  unit2 = Select(UnCogen, ==(0))
  units = intersect(unit1, unit2)
  non_NG_plant_codes = ["ON_EnergyOttawa", "ON_Group_17", "ON00011100101", 
  "ON00011100102", "ON00011100201", "ON00011100202", "ON00011100301", 
  "ON00011100302"]
  for unit in Units
    if UnPlant[unit] == "Nuclear"
      UnOR[unit,Yr(2027):Yr(2030)] .= 0.113
      UnOR[unit,Yr(2031)] = 0.151
      UnOR[unit,Yr(2032)] = 0.229
      UnOR[unit,Yr(2033)] = 0.231
    end
    #
    # Keeping Refurbishment
    #
    if UnCode[unit] =="ON00037100204"
      UnOR[unit, Yr(2027)] = 1
    end
    if UnCode[unit] =="ON00037100301"
      UnOR[unit, Yr(2027)] = 1
      UnOR[unit, Yr(2028)] = 1
    end
    if UnCode[unit] =="ON00037100303"
      UnOR[unit, Yr(2029)] = 1
      UnOR[unit, Yr(2030)] = 1
    end
    if UnCode[unit] =="ON00037100304"
      UnOR[unit, Yr(2030)] = 0.628
      UnOR[unit, Yr(2031)] = 1
      UnOR[unit, Yr(2032)] = 1
    end
    # Adjusting UnOR of natural gas power plants
    if UnPlant[unit] == "OGCT" || UnPlant[unit] == "OGCC"
      # Non natural gas power plants are excluded
      if !in(UnCode[unit],non_NG_plant_codes)
        UnOR[unit, Future:Final] .= 0.7
        UnOR[unit, Yr(2027)] = 0.336
        UnOR[unit, Yr(2028)] = 0.372
        UnOR[unit, Yr(2029)] = 0.377
        UnOR[unit, Yr(2030)] = 0.376
      end
    end
  end

  # 
  # Labrador (LB))
  #
  years = collect(Future:Final)
  for unit in Units
    if UnArea[unit] == "NB"
      # Adjusted to have ~50 ktCO2e/year for remote diesel generators
      if UnPlant[unit] == "OGCT"
        UnOR[unit,years] .= 0.87
      end
      if UnPlant[unit] == "OGSteam"
        UnOR[unit,years] .= 0.198
      end
    end
    if UnArea[unit] == "LB"
      # Adjusted to have ~50 ktCO2e/year for remote diesel generators
      if UnPlant[unit] == "OGCT"
        UnOR[unit,years] .= 0.87
      end
      if UnPlant[unit] == "OGSteam"
        UnOR[unit,years] .= 0.198
      end
    end
  end

  WriteDisk(db,"EGInput/UnOR",UnOR)

  #
  # Territories heat rate adjustments
  #
  
  # Northwest territories (NT)
  years = collect(Future:Final)
  for unit in Units
    if UnCode[unit] =="NT00008200100"
      UnHRt[unit, years] .= 9759.329
    end
    if UnCode[unit] =="NT00008600100"
      UnHRt[unit, years] .= 12712.33
    end
    if UnCode[unit] =="NT00008700100"
      UnHRt[unit, years] .= 11128.64
    end
  end 

  # Nunavut (NU)
  unit1 = Select(UnArea, ==("NU"))
  unit2 = Select(UnPlant, ==("OGCT"))
  units = intersect(unit1, unit2)
  years = collect(Future:Final)
  if !isempty(units)
    for year in years, unit in units
      UnHRt[unit,year] = 10627.94
    end
  end

  # Yukon (YT)
  unit1 = Select(UnArea, ==("YT"))
  unit2 = Select(UnPlant, ==("OGCT"))
  units = intersect(unit1, unit2)
  years = collect(Future:Final)
  if !isempty(units)
    for year in years, unit in units
      UnHRt[unit,year] = 8307.96
    end
  end

  WriteDisk(db,"EGInput/UnHRt",UnHRt)

  #
  # SECTION 3: Manage problematic plants
  #
  years = collect(First:Final)

  # Retire specific units
  for unit in Units
    if UnCode[unit] == "NU_Meliad_LFO"
      for year in years, unit in units
        UnRetire[unit,year] = 2019
      end
    elseif UnCode[unit] == "PE_GenSolar1"
      for year in years, unit in units
        UnRetire[unit,year] = 2200
      end
      # Set high outage for specific units
    elseif UnCode[unit] in ["NL_Cg_ECC34_OGSteam","BC_Cg_ECC21_OGCC"]
      for year in years, unit in units
        UnOR[unit,year] = 1
      end
    end
  end

  WriteDisk(db,"EGInput/UnRetire",UnRetire)
  WriteDisk(db,"EGInput/UnOR",UnOR)

  #
  # SECTION 4: Coal power generation adjustments
  #
  # Boost coal power generation in SK, NS, NB
  # Boost other thermal generation in NB, ON
  #
  # Coal power generation is limited by UnOR(LHY), thus resetting it to generic value

  # Reset coal UnOR to generic value
  unit1 = Select(UnArea, !=("NB"))
  unit2 = Select(UnPlant, ==("Coal"))
  unit3 = Select(UnNation, ==("CN"))
  units = intersect(unit1, unit2, unit3)
  years = collect(Future:Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.177
  end

  WriteDisk(db,"EGInput/UnOR",UnOR)

  # Saskatchewan coal
  
  plant = Select(Plant, ==("Coal"))
  genco = Select(GenCo, ==("SK"))
  node = Select(Node, ==("SK"))
  years = collect(First:Yr(2030))
  for year in years
    HDVCFR[plant,genco,node,TimePs,Months,year] .= -2
  end

  # Nova Scotia coal
  
  plant = Select(Plant, ==("Coal"))
  genco = Select(GenCo, ==("NS"))
  node = Select(Node, ==("NS"))
  years = collect(First:Yr(2030))
  for year in years
    HDVCFR[plant,genco,node,TimePs,Months,year] .= -1
  end

  # New Brunswick 
  # NB lacks coal, oil and gas power generation in the future
  genco = Select(GenCo, ==("NB"))
  node = Select(Node, ==("NB"))
  years = collect(First:Yr(2040))
  
  # Gas plants
  plants = Select(Plant, ["OGCC","OGCT","OGSteam"])
  for plant in plants, year in years
    HDVCFR[plant,genco,node,TimePs,Months,year] .= 0
  end

  # Coal plants
  plant = Select(Plant, ==("Coal"))
  for year in years
    HDVCFR[plant,genco,node,TimePs,Months,year] .= -1
  end

  # 
  # Ontario (ON)
  # 
  # ON lacks gas power generation in the future (especially over 2026-2040)
  plants = Select(Plant, ["OGCC","OGCT","OGSteam"])
  genco = Select(GenCo, ==("ON"))
  node = Select(Node, ==("ON"))

  on_adjustments = [
    (Yr(2023), 0.8),
    (Yr(2024), 0.6),
    (Yr(2025), 0.4),
    (Yr(2026), 0.2),
    (Yr(2027):Yr(2034), 0.0),
    (Yr(2035), 0.2),
    (Yr(2036), 0.4),
    (Yr(2037), 0.6),
    (Yr(2038), 0.8),
    (Yr(2039):Final, 1.0)
  ]

  for (years, value) in on_adjustments
    for year in years, plant in plants
      HDVCFR[plant,genco,node,TimePs,Months,year] .= value
    end
  end

  WriteDisk(db,"EGInput/HDVCFR",HDVCFR)
  #
  ###############################
  # SECTION 5
  #
  node = Select(Node,"PE")
  DRM[node,Years] .=-0.2
  #
  # Edits for CER CGII
  #
  # Building strategy adjustments
  #
  
  # Initial restrictions
  gencos = Select(GenCo, (from="ON",to="NU"))
  years = collect(Future:Yr(2023))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end

  # AB restrictions
  genco = Select(GenCo, ==("AB"))
  years = collect(Future:Yr(2024))
  for year in years
    BuildSw[genco,year] .= 0
  end

  # Territory restrictions
  gencos = Select(GenCo, ["NT","NU","YT"])
  years = collect(Future:Yr(2023))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end

  # MB/NL restrictions
  gencos = Select(GenCo, ["MB","NL"])
  years = collect(Future:Yr(2023))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end

  # PE restrictions
  genco = Select(GenCo, ==("PE"))
  years = collect(Future:Yr(2029))
  for year in years
    BuildSw[genco,year] .= 0
  end

  #################################
  # Updated to reflect current market structures. March 2024. V.Keller
  # Market structure adjustments
  # Market participants
  # AB is a market. Should point to 6. But that part of the model is not very well developed yet. Until then, leave it at 5.
  # ON is a market. Mostly. But it has some other complicated dynamics. 
  gencos = Select(GenCo, ["AB","ON"])
  years = collect(Future:Final)
  for year in years, genco in gencos
    BuildSw[genco,year] = 5
  end

  # Vertically integrated utilities
  gencos = Select(GenCo, ["BC","MB","SK","QC","NS","NB","PE","NL"])
  years = collect(Future:Final)
  for year in years, genco in gencos
    BuildSw[genco,year] = 6
  end

  WriteDisk(db,"EGInput/BuildSw",BuildSw)
  #
  #JSO Change 22.01.27 - Since PEI now has growing electricity demands in projections,
  #increase hdxload from NB to PE to align to NB Power electricity flow projections.
  #Also increase LLMax from NB to PE to prevent peak load emergency power in PE due to growth in peak loads.
  #
  ###### Updated by Victor Keller. March 2024. NextGrid alignment work for
  years = collect(Yr(2020):Final)
  node = Select(Node, "PE")
  nodex = Select(NodeX, "NB")
  HDXLoad[node,nodex,TimePs,Months,years] .= 0
  #
  # Patch for interties for CER CGII - to allign with NextGrid.
  # V.Keller updated for CER CGII January 2024
  #

  # Alberta to BC
  bc = Select(Node, "BC")
  ab = Select(NodeX,"AB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[bc,ab,timep,month,year] = 1000
  end

  # BC to Alberta
  ab = Select(Node,"AB")
  bc = Select(NodeX,"BC")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ab,bc,timep,month,year] = 800
  end

  # BC to Yukon
  yt = Select(Node,"YT")
  bc = Select(NodeX,"BC")
  for year in Years, month in Months, timep in TimePs
    HDXLoad[yt,bc,timep,month,year] = 0
  end
  years = collect(Yr(2028):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[yt,bc,timep,month,year] = 9
  end

  # The Energy Procurement Agreement is expected to deliver 31 GWh in Winter to Yukon
  winter = Select(Month,"Winter")
  for year in years, month in winter
    for timep in 1:5
      HDXLoad[yt,bc,timep,month,year] = 8.5
    end
    HDXLoad[yt,bc,6,month,year] = 6
  end

  # Alberta to Saskatchewan
  sk = Select(Node,"SK")
  ab = Select(NodeX,"AB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[sk,ab,timep,month,year] = 150
  end

  # Saskatchewan to Alberta
  ab = Select(Node,"AB")
  sk = Select(NodeX,"SK")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ab,sk,timep,month,year] = 150
  end

  # Manitoba to Ontario
  on = Select(Node,"ON")
  mb = Select(NodeX,"MB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[on,mb,timep,month,year] = 260
  end

  # Ontario to Manitoba
  mb = Select(Node,"MB")
  on = Select(NodeX,"ON")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[mb,on,timep,month,year] = 250
  end

  # Manitoba to Saskatchewan
  sk = Select(Node,"SK")
  mb = Select(NodeX,"MB")
  years = collect(Future:Final)
  # LLMax=315 new value from SK Questionnaire Ref24)
  for year in years, month in Months, timep in TimePs
    LLMax[sk,mb,timep,month,year] = 325
  end

  # Saskatchewan to Manitoba
  mb = Select(Node,"MB")
  sk = Select(NodeX,"SK")
  years = collect(Future:Final)
  # LLMax=60 new value from SK Questionnaire Ref24)
  for year in years, month in Months, timep in TimePs
    LLMax[mb,sk,timep,month,year] = 175
  end

  # NB to NS
  ns = Select(Node,"NS")
  nb = Select(NodeX,"NB")
  years = collect(Future:Final)
  summer = Select(Month,"Summer")
  for year in years, month in summer, timep in TimePs
    LLMax[ns,nb,timep,month,year] = 150
  end
  # Update Ref24 (consultation document)
  years = collect(Yr(2028):Final)
  for year in years, month in summer, timep in TimePs
    LLMax[ns,nb,timep,month,year] = 500
  end

  # NS to NB
  # Lower wheel-through export of electricity from NL to NB (through NS) in 2022 since Muskrat Falls is not yet fully online
  nb = Select(Node,"NB")
  ns = Select(NodeX,"NS")
  for month in Months, timep in TimePs
    LLMax[nb,ns,timep,month,Yr(2022)] = 150
    HDXLoad[nb,ns,timep,month,Yr(2022)] = 150
  end

  years = collect(Yr(2023):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nb,ns,timep,month,year] = 194
    HDXLoad[nb,ns,timep,month,year] = 194
  end

  # NB to PEI
  pe = Select(Node,"PE")
  nb = Select(NodeX,"NB")
  years = collect(Future:Yr(2035))
  for year in years, month in Months, timep in TimePs
    LLMax[pe,nb,timep,month,year] = 300
  end
  years = collect(Yr(2036):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[pe,nb,timep,month,year] = 400
  end

  # PEI to NB
  nb = Select(Node,"NB")
  pe = Select(NodeX,"PE")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nb,pe,timep,month,year] = 170
  end

  # QC to NB
  nb = Select(Node,"NB")
  qc = Select(NodeX,"QC")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nb,qc,timep,month,year] = 1029
  end

  # NB to QC
  qc = Select(Node,"QC")
  nb = Select(NodeX,"NB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[qc,nb,timep,month,year] = 785
  end

  # LB to QC
  qc = Select(Node,"QC")
  lb = Select(NodeX,"LB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[qc,lb,timep,month,year] = 5428
  end

  # QC to LB
  lb = Select(Node,"LB")
  qc = Select(NodeX,"QC")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[lb,qc,timep,month,year] = 0
  end

  # NS-NL
  ns = Select(Node,"NS")
  nl = Select(NodeX,"NL")
  years = collect(Yr(2021):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ns,nl,timep,month,year] = 500
  end

  nl = Select(Node,"NL")
  ns = Select(NodeX,"NS")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nl,ns,timep,month,year] = 500
  end

  # ON to QC
  qc = Select(Node,"QC")
  on = Select(NodeX,"ON")
  years = collect(Future:Final)
  # LLMax=2135: reduced to original known value because it causes problem in Ref24
  for year in years, month in Months, timep in TimePs
    LLMax[qc,on,timep,month,year] = 1970
  end

  # QC to ON
  on = Select(Node,"ON")
  qc = Select(NodeX,"QC")
  years = collect(Future:Final)
  # LLMax=2730: reduced to original known value because it causes problem in Ref24
  for year in years, month in Months, timep in TimePs
    LLMax[on,qc,timep,month,year] = 1970
  end
  years = collect(Yr(2030):Final)
  timeperiods = collect(5:6)
  for year in years, month in Months, timep in timeperiods
    LLMax[on,qc,timep,month,year] = 1000
  end

  # BC to USA
  nwpp = Select(Node,"NWPP")
  bc = Select(NodeX,"BC")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nwpp,bc,timep,month,year] = 3150
  end

  # USA to BC
  bc = Select(Node,"BC")
  nwpp = Select(NodeX,"NWPP")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[bc,nwpp,timep,month,year] = 3000
  end

  # AB to USA
  nwpp = Select(Node,"NWPP")
  ab = Select(NodeX,"AB")
  years = collect(Yr(2021):Yr(2029))
  for year in years, month in Months, timep in TimePs
    LLMax[nwpp,ab,timep,month,year] = 325
  end
  years = collect(Yr(2030):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nwpp,ab,timep,month,year] = 815
  end

  # USA to AB
  ab = Select(Node,"AB")
  nwpp = Select(NodeX,"NWPP")
  years = collect(Yr(2021):Yr(2029))
  for year in years, month in Months, timep in TimePs
    LLMax[ab,nwpp,timep,month,year] = 310
  end
  years = collect(Yr(2030):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ab,nwpp,timep,month,year] = 810
  end

  # MB to USA
  misw = Select(Node,"MISW")
  mb = Select(NodeX,"MB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[misw,mb,timep,month,year] = 2858
  end

  # MB to USA Contracts (Ref24, Consultation)
  # Contract with US stakeholders are as follow:
  # 1.Basin Electric Power: Firm power contract, up to 80 MW negotiated each year, 2023-2028
  # 2. Dairyland Power Cooperative: bi-directional firm contract on power, 50 MW, MB imports in winter, exports in summer, June 2022- May 2027
  # 3. Great River Energy, bi-directional firm contract on power, 200 MW, MB imports in winter, exports in summer, 2013- 2030
  # 4. Minnesota Municipal Power Agency, firm power contract, up to 105 MW negotiated each year, June 2020-untertermined
  # 5. Minnesota Power, firm contract on power, 250 MW, 2020-2035
  # 6. Wisconsin Public Service, firm contract on power, 100 MW, 2021-2027

  misw = Select(Node, "MISW")
  mb = Select(NodeX, "MB")

  years = collect(Yr(2023):Yr(2028))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 80
  end
  years = collect(Yr(2020):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 105
  end
  years = collect(Yr(2020):Yr(2035))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 250
  end
  years = collect(Yr(2021):Yr(2027))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 100
  end
  summer = Select(Month, "Summer")
  years = collect(Yr(2022):Yr(2027))
  for year in years, month in summer, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 50
  end
  years = collect(Yr(2013):Yr(2030))
  for year in years, month in summer, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 200
  end

  # USA to MB
  mb = Select(Node, "MB")
  misw = Select(NodeX, "MISW")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[mb,misw,timep,month,year] = 1400
  end
  # Contract
  winter = Select(Month, "Winter")
  years = collect(Yr(2022):Yr(2027))
  for year in years, month in winter, timep in TimePs
    HDXLoad[mb,misw,timep,month,year] += 50
  end
  years = collect(Yr(2013):Yr(2030))
  for year in years, month in winter, timep in TimePs
    HDXLoad[mb,misw,timep,month,year] += 200
  end

  # USA to NB
  nb = Select(Node, "NB")
  isne = Select(NodeX, "ISNE")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nb,isne,timep,month,year] = 719
  end

  # NB to USA
  isne = Select(Node, "ISNE")
  nb = Select(NodeX, "NB")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[isne,nb,timep,month,year] = 1145
  end
  # Reduce capacity because there are huge export causing emergency power
  years = collect(Future:Yr(2035))
  timeperiods = collect(1:5)
  for year in years, month in Months, timep in timeperiods
    LLMax[isne,nb,timep,month,year] = 550
  end
  years = collect(Yr(2023):Yr(2024))
  timeperiods = collect(1:3)
  for year in years, month in Months, timep in timeperiods
    LLMax[isne,nb,timep,month,year] = 100
  end

  # SK to USA
  sppn = Select(Node, "SPPN")
  sk = Select(NodeX, "SK")
  years = collect(Yr(2013):Yr(2026))
  # LLMax=105 new value up to 2026 and then value increased, from SK Questionnaire Ref24
  for year in years, month in Months, timep in TimePs
    LLMax[sppn,sk,timep,month,year] = 150
  end
  years = collect(Yr(2027):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[sppn,sk,timep,month,year] = 500
  end

  # USA to SK
  sk = Select(Node, "SK")
  sppn = Select(NodeX, "SPPN")
  years = collect(Yr(2013):Yr(2026))
  for year in years, month in Months, timep in TimePs
    LLMax[sk,sppn,timep,month,year] = 150
  end
  # SK adds 2 x 250 MW in 2027 (questionnaire Ref24)
  years = collect(Yr(2027):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[sk,sppn,timep,month,year] = 650
  end

  # MISW to ON
  on = Select(Node, "ON")
  misw = Select(NodeX, "MISW")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[on,misw,timep,month,year] = 145
  end

  # ON to MISW
  misw = Select(Node, "MISW")
  on = Select(NodeX, "ON")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[misw,on,timep,month,year] = 150
  end

  # MISE to ON
  on = Select(Node, "ON")
  mise = Select(NodeX, "MISE")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[on,mise,timep,month,year] = 1650
  end

  # ON to MISE
  mise = Select(Node, "MISE")
  on = Select(NodeX, "ON")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[mise,on,timep,month,year] = 1500
  end

  # NYUP to ON
  on = Select(Node, "ON")
  nyup = Select(NodeX, "NYUP")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[on,nyup,timep,month,year] = 1810 + 295
  end

  # ON to NYUP
  nyup = Select(Node, "NYUP")
  on = Select(NodeX, "ON")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nyup,on,timep,month,year] = 2005 + 295
  end

  # MISS to ON
  on = Select(Node, "ON")
  miss = Select(NodeX, "MISS")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[on,miss,timep,month,year] = 0
  end

  # ON to MISS
  miss = Select(Node, "MISS")
  on = Select(NodeX, "ON")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[miss,on,timep,month,year] = 0
  end

  # QC to NYUP
  nyup = Select(Node, "NYUP")
  qc = Select(NodeX, "QC")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[nyup,qc,timep,month,year] = 1999
  end

  # NYUP to QC
  qc = Select(Node, "QC")
  nyup = Select(NodeX, "NYUP")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[qc,nyup,timep,month,year] = 1100
  end

  # QC to ISNE
  isne = Select(Node, "ISNE")
  qc = Select(NodeX, "QC")
  years = collect(Yr(2021):Yr(2023))
  for year in years, month in Months, timep in TimePs
    LLMax[isne,qc,timep,month,year] = 2275
  end
  years = collect(Yr(2024):Yr(2025))
  for year in years, month in Months, timep in TimePs
    LLMax[isne,qc,timep,month,year] = 3475
  end
  years = collect(Yr(2026):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[isne,qc,timep,month,year] = 4725
  end

  # Replacing CER values above because they cause issues (and seem too high)
  #years = collect(Yr(2024):Final)
  #for year in years, month in Months, timep in TimePs
  #  LLMax[isne,qc,timep,month,year] = 3475
  #end
  #
  #timeperiods = collect(5:6)
  #for year in years, month in Months, timep in timeperiods
  #  LLMax[isne,qc,timep,month,year] = 1800
  #end

  # ISNE to QC
  qc = Select(Node, "QC")
  isne = Select(NodeX, "ISNE")
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[qc,isne,timep,month,year] = 2170
  end

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)
  WriteDisk(db,"EGInput/LLMax",LLMax)

  #
  # Additional transmission load settings
  #

  # Base HDXLoad settings
  misw = Select(Node, "MISW")
  mise = Select(Node, "MISE")
  nyup = Select(Node, "NYUP")
  on = Select(NodeX, "ON")
  years = collect(Future:Final)

  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,on,timep,month,year] = 30
    HDXLoad[mise,on,timep,month,year] = 340
    HDXLoad[nyup,on,timep,month,year] = 340
  end

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)

  #
  # QC to ISNE settings
  #
  isne = Select(Node, "ISNE")
  qc = Select(NodeX, "QC")
  nyup = Select(Node, "NYUP")

  years = collect(Yr(2025):Yr(2038))
  for year in years, month in Months, timep in TimePs
    HDXLoad[isne,qc,timep,month,year] = 1227
  end

  years = collect(Yr(2039):Yr(2045))
  for year in years, month in Months, timep in TimePs
    HDXLoad[isne,qc,timep,month,year] = 1078.77
  end

  years = collect(Yr(2046):Yr(2051))
  for year in years, month in Months, timep in TimePs
    HDXLoad[nyup,qc,timep,month,year] = 1250
  end

  #
  # Updated to reflect CER CGII work for allignment with NextGrid. Victor Keller March 2024
  #

  # First the capacity contracts (assumed to be TimeP1-2)
  ns = Select(Node, "NS")
  nl = Select(NodeX, "NL")
  timeperiods = collect(1:2)
  years = collect(Yr(2020):Final)

  for year in years, month in Months, timep in timeperiods
    HDXLoad[ns,nl,timep,month,year] = 153
  end

  # Then, energy contracts
  timeperiods = collect(3:6)

  years = collect(Yr(2020):Yr(2029))
  for year in years, month in Months, timep in timeperiods
    HDXLoad[ns,nl,timep,month,year] = 118
  end

  years = collect(Yr(2030):Final)
  for year in years, month in Months, timep in timeperiods
    HDXLoad[ns,nl,timep,month,year] = 102
  end

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)
  #
  # Design hours adjustments
  #

  # Renewables for peak power
  ########################
  #
  # Change design hours for each of the three power types. 
  # CER CGII alignment work with NextGrid. Feb 2024. V. Keller
  #
  # First, assume that renewables do not contribute any generation for peaking purposes

  peak = Select(Power, "Peak")
  # Default is 526.2 hours (100%)
  for plant in Plants, area in Areas, year in Years
    DesHr[plant,peak,area,year] = 525.6
  end
  plants = Select(Plant, ["SolarPV","SolarThermal","OnshoreWind","OffshoreWind",
                          "Wave","Tidal","OtherGeneration"])
  
  for plant in plants, area in Areas, year in Years
    DesHr[plant,peak,area,year] = 0.01
  end

  # Intermediate power adjustments
  interm = Select(Power, "Interm")
  DesHr[Plants,interm,Areas,Years] .= 1401.6  # Default value

  # Solar and other technologies
  plants = Select(Plant, ["SolarPV","SolarThermal","Wave","Tidal","OtherGeneration"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,interm,area,year] = 0.01
  end

  # Wind technologies assumed to only contribute it s ELCC at intermediate hours
  plants = Select(Plant, ["OnshoreWind","OffshoreWind"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,interm,area,year] = 1401 * 0.15
  end

  # Battery storage
  plant = Select(Plant, "Battery")
  for area in Areas, year in Years
    DesHr[plant,interm,area,year] = 1401 * 0.25
  end

  # Base power adjustments
  basepower = Select(Power, "Base")
  plants = Select(Plant, ["Battery","OtherGeneration","PumpedHydro"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,basepower,area,year] = 0.01
  end

  WriteDisk(db,"EGInput/DesHr",DesHr)

end

function PolicyControl(db)
  @info "Electricity_Patch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

function PolicyControl(db)
  @info "Electricity_Patch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
