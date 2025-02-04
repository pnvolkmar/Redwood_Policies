#
# Electricity_Patch.jl
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
  unit1 = Select(UnNation,==("CN"))
  unit2 = Select(UnArea,==("NL"))
  unit3 = Select(UnNode,==("LB"))
  unit4 = Select(UnCogen,==(0))
  unit5 = Select(UnPlant,==("PeakHydro"))
  units = intersect(intersect(intersect(intersect(unit1,unit2),unit3),unit4),unit5)

  for month in Months
    UnEAF[units,month,Yr(2023)] *= 1.18 * 1.08 * 1.035 * 1.011
    UnEAF[units,month,Yr(2024)] *= 1.12 * 1.05 * 1.019 * 1.026
    UnEAF[units,month,Yr(2025)] *= 1.1 * 1.05 * 1.027 * 1.054
    UnEAF[units,month,Yr(2026)] *= 1.09 * 1.04 * 1.032 * 1.054
    UnEAF[units,month,Yr(2027)] *= 1.07 * 1.04 * 1.036 * 1.050
    UnEAF[units,month,Yr(2028)] *= 1.06 * 1.03 * 1.041 * 1.050
    UnEAF[units,month,Yr(2029)] *= 1.05 * 1.02 * 1.044 * 1.053
    UnEAF[units,month,Yr(2030)] *= 1.05 * 1.02 * 1.038 * 1.049
    UnEAF[units,month,Yr(2031)] *= 1.04 * 1.01 * 1.042 * 1.049
    UnEAF[units,month,Yr(2032)] *= 1.04 * 1.038 * 1.046
    UnEAF[units,month,Yr(2033)] *= 1.03 * 1.034 * 1.042
    UnEAF[units,month,Yr(2034)] *= 1.02 * 1.030 * 1.039
    UnEAF[units,month,Yr(2035)] *= 1.01 * 1.026 * 1.035
    UnEAF[units,month,Yr(2036)] *= 1.01 * 1.023 * 1.025
    UnEAF[units,month,Yr(2037)] *= 1.01 * 1.015
  end

  # Manitoba (MB)
  unit1 = Select(UnNation,==("CN"))
  unit2 = Select(UnArea,==("MB"))
  unit3 = Select(UnNode,==("MB")) 
  unit4 = Select(UnCogen,==(0))
  unit5 = Select(UnPlant,==("PeakHydro"))
  units = intersect(intersect(intersect(intersect(unit1,unit2),unit3),unit4),unit5)

  for month in Months
    UnEAF[units,month,Yr(2023)] *= 1.085
    UnEAF[units,month,Yr(2024)] *= 1.13
  end

  WriteDisk(db,"EGInput/UnEAF",UnEAF)

  #
  # SECTION 2: Adjust plant operations with UnOR
  # 

  # New Brunswick (NB)
  years = collect(Future:Final)
  
  # OGCC plants
  units = Select(UnCode) do x
    UnArea[x] == "NB" && UnPlant[x] == "OGCC"
  end
  for year in years, unit in units
    UnOR[unit,year] = 0.435
  end

  # OGCT plants
  units = Select(UnCode) do x
    UnArea[x] == "NB" && UnPlant[x] == "OGCT" && UnSource[x] == 0
  end
  for year in years, unit in units
    UnOR[unit,year] = 0.993831606
  end

  # OGSteam plants
  units = Select(UnCode) do x
    UnArea[x] == "NB" && UnPlant[x] == "OGSteam" && UnSource[x] == 0
  end
  for year in years, unit in units
    UnOR[unit,year] = 0.936798596
  end

  # Specific plant adjustments
  belledune = Select(UnCode,==("NB00006601BIO"))
  for year in years, unit in belledune
    UnOR[unit,year] = 0.3708571
  end

  lepreau = Select(UnCode,==("NB00006601201"))
  for year in years, unit in lepreau
    UnOR[unit,year] = 0.20
  end

  # Ontario nuclear plants
  # Complex pattern of years and values for different units
  nuclear_adjustments = [
    ("ON00011106701", Yr(2026):Final, 0.312975744815718),
    ("ON00011106702", Future:Final, 0.312975744815718),
    ("ON00011106703", Yr(2024):Final, 0.312975744815718),
    ("ON00011106704", [Yr(2022); Yr(2027):Final], 0.312975744815718),
    (["ON00011106801","ON00011106802","ON00011106803","ON00011106804"], Yr(2022):Yr(2025), 0.312975744815718),
    ("ON00011107601", Yr(2022):Yr(2023), 0.312975744815718),
    ("ON00011107604", Yr(2022):Yr(2024), 0.312975744815718),
    (["ON00037100201","ON00037100202"], Future:Final, 0.312975744815718),
    ("ON00037100203", [Yr(2022); Yr(2027):Final], 0.312975744815718),
    ("ON00037100204", [Yr(2022):Yr(2024); Yr(2028):Final], 0.312975744815718),
    ("ON00037100301", [Yr(2022):Yr(2025); Yr(2030):Final], 0.312975744815718),
    ("ON00037100302", Yr(2024):Final, 0.312975744815718),
    ("ON00037100303", [Yr(2022):Yr(2027); Yr(2032):Final], 0.312975744815718),
    ("ON00037100304", [Yr(2022):Yr(2029); Yr(2034):Final], 0.312975744815718)
  ]

  for (codes, years, value) in nuclear_adjustments
    codes = isa(codes, String) ? [codes] : codes
    units = Select(UnCode, in(codes))
    for year in years, unit in units
      UnOR[unit,year] = value
    end
  end

  # SMNR plants
  units = Select(UnPlant,==("SMNR"))
  years = collect(Future:Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.073
  end

  # Ontario emergency power adjustments
  units = Select(UnCode) do x
    UnArea[x] == "ON" && UnCogen[x] == 0 && UnPlant[x] == "Nuclear"
  end
  
  nuclear_or_values = [
    (Yr(2027):Yr(2030), 0.113),
    (Yr(2031):Yr(2031), 0.151),
    (Yr(2032):Yr(2032), 0.229),
    (Yr(2033):Yr(2033), 0.231)
  ]

  for (years, value) in nuclear_or_values
    for year in years, unit in units
      UnOR[unit,year] = value
    end
  end

  # Specific refurbishment years
  refurb_adjustments = [
    ("ON00037100204", [(Yr(2027), 1.0)]),
    ("ON00037100301", [(Yr(2027), 1.0), (Yr(2028), 1.0)]),
    ("ON00037100303", [(Yr(2029), 1.0), (Yr(2030), 1.0)]),
    ("ON00037100304", [(Yr(2030), 0.628), (Yr(2031), 1.0), (Yr(2032), 1.0)])
  ]

  for (code, adjustments) in refurb_adjustments
    unit = Select(UnCode,==(code))
    for (year, value) in adjustments
      UnOR[unit,year] = value
    end
  end

  # Natural gas plant adjustments
  excluded_codes = ["ON_EnergyOttawa", "ON_Group_17", "ON00011100101", 
    "ON00011100102", "ON00011100201", "ON00011100202", "ON00011100301", 
    "ON00011100302"]

  units = Select(UnCode) do x
    UnArea[x] == "ON" && UnCogen[x] == 0 && 
    (UnPlant[x] == "OGCT" || UnPlant[x] == "OGCC") &&
    !(x in excluded_codes)
  end

  gas_or_values = [
    (Future:Final, 0.7),
    (Yr(2027):Yr(2027), 0.336),
    (Yr(2028):Yr(2028), 0.372),
    (Yr(2029):Yr(2029), 0.377),
    (Yr(2030):Yr(2030), 0.376)
  ]

  for (years, value) in gas_or_values
    for year in years, unit in units
      UnOR[unit,year] = value
    end
  end

  # Labrador adjustments
  years = collect(Future:Final)
  
  units_lb_ogct = Select(UnCode) do x
    (UnArea[x] == "NL" || UnArea[x] == "LB") && UnPlant[x] == "OGCT"
  end
  for year in years, unit in units_lb_ogct
    UnOR[unit,year] = 0.87
  end

  units_lb_steam = Select(UnCode) do x
    (UnArea[x] == "NL" || UnArea[x] == "LB") && UnPlant[x] == "OGSteam"
  end
  for year in years, unit in units_lb_steam
    UnOR[unit,year] = 0.198
  end

  WriteDisk(db,"EGInput/UnOR",UnOR)

  #
  # Heat rate adjustments for territories
  #
  years = collect(Future:Final)

  # Northwest territories
  nt_adjustments = [
    ("NT00008200100", 9759.329),
    ("NT00008600100", 12712.33),
    ("NT00008700100", 11128.64)
  ]

  for (code, value) in nt_adjustments
    unit = Select(UnCode,==(code))
    for year in years
      UnHRt[unit,year] = value
    end
  end

  # Nunavut
  units = Select(UnCode) do x
    UnArea[x] == "NU" && UnPlant[x] == "OGCT"
  end
  for year in years, unit in units
    UnHRt[unit,year] = 10627.94
  end

  # Yukon
  units = Select(UnCode) do x
    UnArea[x] == "YT" && UnPlant[x] == "OGCT"
  end
  for year in years, unit in units
    UnHRt[unit,year] = 8307.96
  end

  WriteDisk(db,"EGInput/UnHRt",UnHRt)

  #
  # SECTION 3: Manage problematic plants
  #
  years = collect(First:Final)

  # Retire specific units
  meliad = Select(UnCode,==("NU_Meliad_LFO"))
  for year in years, unit in meliad
    UnRetire[unit,year] = 2019
  end

  gensolar = Select(UnCode,==("PE_GenSolar1"))
  for year in years, unit in gensolar
    UnRetire[unit,year] = 2200
  end

  # Set high outage for specific units
  problem_units = Select(UnCode,["NL_Cg_ECC34_OGSteam","BC_Cg_ECC21_OGCC"])
  for year in years, unit in problem_units
    UnOR[unit,year] = 1
  end

  WriteDisk(db,"EGInput/UnRetire",UnRetire)
  WriteDisk(db,"EGInput/UnOR",UnOR)

  #
  # SECTION 4: Coal power generation adjustments
  #
  
  # Reset coal UnOR to generic value
  years = collect(Future:Final)
  units = Select(UnCode) do x
    UnArea[x] != "NB" && UnPlant[x] == "Coal" && UnNation[x] == "CN"
  end
  for year in years, unit in units
    UnOR[unit,year] = 0.177
  end

  WriteDisk(db,"EGInput/UnOR",UnOR)

  # Adjust HDVCFR for various regions
  
  # Saskatchewan
  plant = Select(Plant,"Coal")
  genco = Select(GenCo,"SK")
  node = Select(Node,"SK")
  years = collect(First:Yr(2030))
  for year in years
    HDVCFR[plant,genco,node,:,:,year] .= -2
  end

  # Nova Scotia
  plant = Select(Plant,"Coal")
  genco = Select(GenCo,"NS")
  node = Select(Node,"NS")
  years = collect(First:Yr(2030))
  for year in years
    HDVCFR[plant,genco,node,:,:,year] .= -1
  end

  # New Brunswick
  genco = Select(GenCo,"NB")
  node = Select(Node,"NB")
  years = collect(First:Yr(2040))
  
  plants = Select(Plant,["OGCC","OGCT","OGSteam"])
  for plant in plants, year in years
    HDVCFR[plant,genco,node,:,:,year] .= 0
  end

  plant = Select(Plant,"Coal")
  for year in years
    HDVCFR[plant,genco,node,:,:,year] .= -1
  end

  # Ontario
  plants = Select(Plant,["OGCC","OGCT","OGSteam"])
  genco = Select(GenCo,"ON")
  node = Select(Node,"ON")

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
      HDVCFR[plant,genco,node,:,:,year] .= value
    end
  end

  WriteDisk(db,"EGInput/HDVCFR",HDVCFR)

  #
  # SECTION 5: Reserve margin adjustments
  #
  
  # PEI adjustment
  pe = Select(Node,"PE")
  DRM[pe,:] .= -0.2

  WriteDisk(db,"EInput/DRM",DRM)

  #
  # Building strategies
  #
  
  # Initial restrictions
  build_restrictions = [
    (Select(GenCo,(from="ON",to="NU")), Future:Yr(2023)),
    (Select(GenCo,"AB"), Future:Yr(2024)),
    (Select(GenCo,["NT","NU","YT"]), Future:Yr(2023)),
    (Select(GenCo,["MB","NL"]), Future:Yr(2023)),
    (Select(GenCo,"PE"), Future:Yr(2029))
  ]

  for (gencos, years) in build_restrictions
    for year in years, genco in gencos
      BuildSw[genco,year] = 0
    end
  end

  # Market structure adjustments
  market_adjustments = [
    (Select(GenCo,["AB","ON"]), Future:Final, 5),
    (Select(GenCo,["BC","MB","SK","QC","NS","NB","PE","NL"]), Future:Final, 6)
  ]

  for (gencos, years, value) in market_adjustments
    for year in years, genco in gencos
      BuildSw[genco,year] = value
    end
  end

  WriteDisk(db,"EGInput/BuildSw",BuildSw)

  #
  # Transmission adjustments
  #

  # PEI adjustments
  pe = Select(Node,"PE")
  nb = Select(Node,"NB")
  years = collect(Yr(2020):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[pe,nb,timep,month,year] = 0
  end

  # Provincial interconnection adjustments
  interconnection_adjustments = [
    # BC-AB
    (Select(Node,"BC"), Select(Node,"AB"), Future:Final, 1000),
    (Select(Node,"AB"), Select(Node,"BC"), Future:Final, 800),
    
    # BC-YT
    (Select(Node,"YT"), Select(Node,"BC"), Yr(2028):Final, 9),
    
    # AB-SK
    (Select(Node,"SK"), Select(Node,"AB"), Future:Final, 150),
    (Select(Node,"AB"), Select(Node,"SK"), Future:Final, 150),
    
    # MB-ON
    (Select(Node,"ON"), Select(Node,"MB"), Future:Final, 260),
    (Select(Node,"MB"), Select(Node,"ON"), Future:Final, 250),
    
    # MB-SK
    (Select(Node,"SK"), Select(Node,"MB"), Future:Final, 325),
    (Select(Node,"MB"), Select(Node,"SK"), Future:Final, 175),
    
    # NB-NS
    (Select(Node,"NS"), Select(Node,"NB"), Future:Final, 150),
    (Select(Node,"NS"), Select(Node,"NB"), Yr(2028):Final, 500),
    
    # QC-NB
    (Select(Node,"NB"), Select(Node,"QC"), Future:Final, 1029),
    (Select(Node,"QC"), Select(Node,"NB"), Future:Final, 785),
    
    # LB-QC
    (Select(Node,"QC"), Select(Node,"LB"), Future:Final, 5428),
    (Select(Node,"LB"), Select(Node,"QC"), Future:Final, 0),
    
    # NS-NL
    (Select(Node,"NS"), Select(Node,"NL"), Yr(2021):Final, 500),
    (Select(Node,"NL"), Select(Node,"NS"), Future:Final, 500),
    
    # ON-QC
    (Select(Node,"QC"), Select(Node,"ON"), Future:Final, 1970),
    (Select(Node,"ON"), Select(Node,"QC"), Future:Final, 1970)
  ]

  # Apply interconnection adjustments
  for (node1, node2, years, value) in interconnection_adjustments
    for year in years, month in Months, timep in TimePs
      LLMax[node1,node2,timep,month,year] = value
    end
  end

  # Special case for ON-QC with time period conditions
  qc = Select(Node,"QC")
  on = Select(Node,"ON")
  years = collect(Yr(2030):Final)
  timeperiods = collect(5:6)
  for year in years, month in Months, timep in timeperiods
    LLMax[on,qc,timep,month,year] = 1000
  end

  # US interconnection adjustments
  us_interconnections = [
    # BC-NWPP
    (Select(Node,"NWPP"), Select(Node,"BC"), Future:Final, 3150),
    (Select(Node,"BC"), Select(Node,"NWPP"), Future:Final, 3000),
    
    # AB-NWPP
    (Select(Node,"NWPP"), Select(Node,"AB"), Yr(2021):Yr(2029), 325),
    (Select(Node,"NWPP"), Select(Node,"AB"), Yr(2030):Final, 815),
    (Select(Node,"AB"), Select(Node,"NWPP"), Yr(2021):Yr(2029), 310),
    (Select(Node,"AB"), Select(Node,"NWPP"), Yr(2030):Final, 810),
    
    # MB-MISW
    (Select(Node,"MISW"), Select(Node,"MB"), Future:Final, 2858),
    (Select(Node,"MB"), Select(Node,"MISW"), Future:Final, 1400),
    
    # NB-ISNE
    (Select(Node,"NB"), Select(Node,"ISNE"), Future:Final, 719),
    (Select(Node,"ISNE"), Select(Node,"NB"), Future:Final, 1145),
    
    # SK-SPPN
    (Select(Node,"SPPN"), Select(Node,"SK"), Yr(2013):Yr(2026), 150),
    (Select(Node,"SPPN"), Select(Node,"SK"), Yr(2027):Final, 500),
    (Select(Node,"SK"), Select(Node,"SPPN"), Yr(2013):Yr(2026), 150),
    (Select(Node,"SK"), Select(Node,"SPPN"), Yr(2027):Final, 650),
    
    # ON-MISW/MISE
    (Select(Node,"ON"), Select(Node,"MISW"), Future:Final, 145),
    (Select(Node,"MISW"), Select(Node,"ON"), Future:Final, 150),
    (Select(Node,"ON"), Select(Node,"MISE"), Future:Final, 1650),
    (Select(Node,"MISE"), Select(Node,"ON"), Future:Final, 1500),
    
    # ON-NYUP
    (Select(Node,"ON"), Select(Node,"NYUP"), Future:Final, 2105),
    (Select(Node,"NYUP"), Select(Node,"ON"), Future:Final, 2300),
    
    # QC-NYUP
    (Select(Node,"NYUP"), Select(Node,"QC"), Future:Final, 1999),
    (Select(Node,"QC"), Select(Node,"NYUP"), Future:Final, 1100),
    
    # QC-ISNE
    (Select(Node,"ISNE"), Select(Node,"QC"), Yr(2021):Yr(2023), 2275),
    (Select(Node,"ISNE"), Select(Node,"QC"), Yr(2024):Yr(2025), 3475),
    (Select(Node,"ISNE"), Select(Node,"QC"), Yr(2026):Final, 4725),
    (Select(Node,"QC"), Select(Node,"ISNE"), Future:Final, 2170)
  ]

  # Apply US interconnection adjustments
  for (node1, node2, years, value) in us_interconnections
    for year in years, month in Months, timep in TimePs
      LLMax[node1,node2,timep,month,year] = value
    end
  end

  # MB-US contracts
  misw = Select(Node,"MISW")
  mb = Select(Node,"MB")
  
  # Base contract values
  years = collect(Yr(2023):Yr(2028))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 80  # Basin Electric Power
  end

  years = collect(Yr(2020):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 105  # Minnesota Municipal Power
  end

  years = collect(Yr(2020):Yr(2035))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 250  # Minnesota Power
  end

  years = collect(Yr(2021):Yr(2027))
  for year in years, month in Months, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 100  # Wisconsin Public Service
  end

  # Seasonal contracts
  years = collect(Yr(2022):Yr(2027))
  summer = Select(Month,"Summer")
  for year in years, month in summer, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 50   # Dairyland Power summer
  end

  years = collect(Yr(2013):Yr(2030))
  for year in years, month in summer, timep in TimePs
    HDXLoad[misw,mb,timep,month,year] += 200  # Great River Energy summer
  end

  winter = Select(Month,"Winter")
  years = collect(Yr(2022):Yr(2027))
  for year in years, month in winter, timep in TimePs
    HDXLoad[mb,misw,timep,month,year] += 50   # Dairyland Power winter
  end

  years = collect(Yr(2013):Yr(2030))
  for year in years, month in winter, timep in TimePs
    HDXLoad[mb,misw,timep,month,year] += 200  # Great River Energy winter
  end

  # Design hours adjustments
  # Renewables for peak power
  peak = Select(Power,"Peak")
  plants = Select(Plant,["SolarPV","SolarThermal","OnshoreWind","OffshoreWind",
                        "Wave","Tidal","OtherGeneration"])
  
  for plant in plants, area in Areas, year in Years
    DesHr[plant,peak,area,year] = 0.01
  end

  # Intermediate power adjustments
  interm = Select(Power,"Interm")
  DesHr[:,:,:,:] .= 1401.6  # Default value

  # Solar and other technologies
  plants = Select(Plant,["SolarPV","SolarThermal","Wave","Tidal","OtherGeneration"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,interm,area,year] = 0.01
  end

  # Wind technologies
  plants = Select(Plant,["OnshoreWind","OffshoreWind"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,interm,area,year] = 1401 * 0.15
  end

  # Battery storage
  plant = Select(Plant,"Battery")
  for area in Areas, year in Years
    DesHr[plant,interm,area,year] = 1401 * 0.25
  end

  # Base power adjustments
  basepower = Select(Power,"Base")
  plants = Select(Plant,["Battery","OtherGeneration","PumpedHydro"])
  for plant in plants, area in Areas, year in Years
    DesHr[plant,basepower,area,year] = 0.01
  end

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)
  WriteDisk(db,"EGInput/LLMax",LLMax)
  WriteDisk(db,"EGInput/DesHr",DesHr)
end

function PolicyControl(db)
  @info "Electricity_Patch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end

function PolicyControl(db)
  @info "Electricity_Patch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end