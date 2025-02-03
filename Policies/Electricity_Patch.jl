#
# Electricity_Patch.jl
#

using SmallModel

module Electricity_Patch

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

  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  GenCo::SetArray = ReadDisk(db,"E2020DB/GenCoKey")
  GenCoDS::SetArray = ReadDisk(db,"E2020DB/GenCoDS")
  GenCos::Vector{Int} = collect(Select(GenCo))
  Month::SetArray = ReadDisk(db,"E2020DB/MonthKey")
  MonthDS::SetArray = ReadDisk(db,"E2020DB/MonthDS")
  Months::Vector{Int} = collect(Select(Month))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  NodeX::SetArray = ReadDisk(db,"E2020DB/NodeXKey")
  NodeXDS::SetArray = ReadDisk(db,"E2020DB/NodeXDS")
  NodeXs::Vector{Int} = collect(Select(NodeX))
  Nodes::Vector{Int} = collect(Select(Node))
  TimeP::SetArray = ReadDisk(db,"E2020DB/TimePKey")
  TimePs::Vector{Int} = collect(Select(TimeP))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  BuildSw::VariableArray{2} = ReadDisk(db,"EGInput/BuildSw") # [GenCo,Year] Build switch
  DRM::VariableArray{2} = ReadDisk(db,"EInput/DRM") # [Node,Year] Desired Reserve Margin (MW/MW)
  HDXLoad::VariableArray{5} = ReadDisk(db,"EGInput/HDXLoad") # [Node,NodeX,TimeP,Month,Year] Exogenous Loading on Transmission Lines (MW)
  LLMax::VariableArray{5} = ReadDisk(db,"EGInput/LLMax") # [Node,NodeX,TimeP,Month,Year] Maximum Loading on Transmission Lines (MW)
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnEAF::VariableArray{3} = ReadDisk(db,"EGInput/UnEAF") # [Unit,Month,Year] Energy Avaliability Factor (MWh/MWh)
  UnFlFrMax::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMax") # [Unit,FuelEP,Year] Fuel Fraction Maximum (Btu/Btu)
  UnFlFrMin::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMin") # [Unit,FuelEP,Year] Fuel Fraction Minimum (Btu/Btu)
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnMustRun::VariableArray{1} = ReadDisk(db,"EGInput/UnMustRun") # [Unit] Must Run (1=Must Run)
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnNation::Array{String} = ReadDisk(db,"EGInput/UnNation") # [Unit] Nation
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnOR::VariableArray{2} = ReadDisk(db,"EGInput/UnOR") # [Unit,Year] Outage Rate (MW/MW)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnRetire::VariableArray{2} = ReadDisk(db,"EGInput/UnRetire") # [Unit,Year] Retirement Date (Year)
  xUnFlFr::VariableArray{3} = ReadDisk(db,"EGInput/xUnFlFr") # [Unit,FuelEP,Year] Fuel Fraction (Btu/Btu)
  
  # Scratch Variables
  LLMin::VariableArray{3} = zeros(Float64,length(Node),length(NodeX),length(Year)) # [Node,NodeX,Year] Minimum Capacity for LB Hydro Flows (MW)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; FuelEP,GenCo) = data
  (; Months,Node) = data
  (; TimePs,Years) = data
  (; BuildSw,DRM,HDXLoad,LLMax,UnArea) = data
  (; UnCode,UnCogen,UnEAF,UnFlFrMax,UnFlFrMin) = data
  (; UnOR,UnPlant,UnRetire) = data

  #
  # Recurring selections
  #
  PE = Select(Node,"PE")
  NS = Select(Node,"NS")
  NB = Select(Node,"NB")
  ISNE = Select(Node,"ISNE")
  QC = Select(Node,"QC")
  NYUP = Select(Node,"NYUP")
  ON = Select(Node,"ON")
  MISS = Select(Node,"MISS")
  AB = Select(Node,"AB")
  NWPP = Select(Node,"NWPP")
  MISW = Select(Node,"MISW")
  MISE = Select(Node,"MISE")

  #
  # Battle River 5 conversion to hydrogen
  #
  units = Select(UnCode,filter(x -> x in UnCode,["AB00029600603NG"]))
  Hydrogen = Select(FuelEP,"Hydrogen")
  years = collect(Yr(2028):Final)
  for year in years, unit in units
    UnFlFrMin[unit,Hydrogen,year] = 1
    UnFlFrMax[unit,Hydrogen,year] = 1
  end
  
  NaturalGas = Select(FuelEP,"NaturalGas")
  for year in years, unit in units
    UnFlFrMin[unit,NaturalGas,year] = 0
    UnFlFrMax[unit,NaturalGas,year] = 0
  end

  WriteDisk(db,"EGInput/UnFlFrMax",UnFlFrMax)
  WriteDisk(db,"EGInput/UnFlFrMin",UnFlFrMin)

  #
  # UnEAF for PeakHydro units in QC and BC
  # For BC to adapt to growing loads from LNG PRoduction while still maintaining some exports to AB
  # For QC to help prevent significant emitting generation in late 2020s
  #

  #
  # BC
  #
  # UnEAF::VariableArray{3} = ReadDisk(db,"EGInput/UnEAF") # [Unit,Month,Year] Energy Avaliability Factor (MWh/MWh)
  unit1 = Select(UnArea,==("BC"))
  unit2 = Select(UnCogen,==(0))
  unit3 = Select(UnPlant,==("PeakHydro"))
  unit = intersect(intersect(unit1,unit2),unit3)
  UnEAF[unit,Months,Yr(2025):Final] = UnEAF[unit,Months,Yr(2025):Final] * 1.07

  #
  # QC
  #
  # UnEAF::VariableArray{3} = ReadDisk(db,"EGInput/UnEAF") # [Unit,Month,Year] Energy Avaliability Factor (MWh/MWh)
  unit1 = Select(UnArea,==("QC"))
  unit2 = Select(UnCogen,==(0))
  unit3 = Select(UnPlant,==("PeakHydro"))
  unit = intersect(intersect(unit1,unit2),unit3)
  UnEAF[unit,Months,Yr(2022):Final] = UnEAF[unit,Months,Yr(2022):Final] * 1.03

  #
  # MB
  #
  unit1 = Select(UnArea,==("MB"))
  unit2 = Select(UnCogen,==(0))
  unit3 = Select(UnPlant,==("PeakHydro"))
  unit = intersect(intersect(unit1,unit2),unit3)
  UnEAF[unit,Months,Yr(2027):Final] = UnEAF[unit,Months,Yr(2027):Final] * 1.01

  #
  # QC Ref23: another patch to resolve emergency power over 2023-2027
  #
  unit1 = Select(UnArea,==("QC"))
  unit2 = Select(UnCogen,==(0))
  unit3 = Select(UnPlant,==("PeakHydro"))
  unit = intersect(intersect(unit1,unit2),unit3)
  UnEAF[unit,Months,Yr(2023)] = UnEAF[unit,Months,Yr(2023)] * 1.045
  UnEAF[unit,Months,Yr(2024)] = UnEAF[unit,Months,Yr(2024)] * 1.055
  UnEAF[unit,Months,Yr(2025)] = UnEAF[unit,Months,Yr(2025)] * 1.05
  UnEAF[unit,Months,Yr(2026)] = UnEAF[unit,Months,Yr(2026)] * 1.04
  UnEAF[unit,Months,Yr(2027)] = UnEAF[unit,Months,Yr(2027)] * 1.025

  WriteDisk(db,"EGInput/UnEAF",UnEAF)

  #
  # Preventing emitting utility units in QC from generating too much
  #
  uncodes = ["QC00029400101","QC00029300100","QC00013507500","QC_New_006","QC00013500101","QC00013500102","QC00013500103","QC00013500104","QC00026500101","QC00016200102","QC00016200101"]
  units = Select(UnCode,filter(x -> x in UnCode,uncodes))
  years = collect(Yr(2022):Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.3
  end

  #
  # Lower outage rate of select NS units to allow them to operate as peakers to avoid emergency power
  #
  uncodes = ["NS00008004201","NS00008004202","NS00008004203"]
  units = Select(UnCode,filter(x -> x in UnCode,uncodes))
  years = collect(Future:Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.05
  end

  #
  # Lower outage rate of select NB units to allow them to operate as peakers to avoid emergency power in PEI
  #
  units = Select(UnCode,filter(x -> x in UnCode,["NB_GenGas_1"]))
  years = collect(Yr(2027):Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.2
  end
  
  units = Select(UnCode,filter(x -> x in UnCode,["NB_GenGas_2"]))
  years = collect(Yr(2030):Final)
  for year in years, unit in units
    UnOR[unit,year] = 0.2
  end

  #
  # Retire problematic Nunavut cogen unit
  #
  units = Select(UnCode,filter(x -> x in UnCode,["NU_Meliad_LFO"]))
  years = collect(First:Final)
  for year in years, unit in units
    UnRetire[unit,year] = 2019
  end

  WriteDisk(db,"EGInput/UnRetire",UnRetire)

  #
  # Increasing generation from Boundary Dam 3 CCS to better align to unit actual generation
  #
  # Update Ref23 (TD,Aug 24): cancelling the following because it causes an unwanted drop in generation.
  # Select Unit*
  # Select Year(2020-Final)
  # Do Unit
  # Do If (UnCode eq "SK_Boundry3_CCS")
  # UnOR=0.08
  # End Do If
  # End Do Unit
  # Select Year*
  # Select Unit*

  WriteDisk(db,"EGInput/UnOR",UnOR)

  #
  # Help prevent building in PE due to reserve margin since province imports half of its electricity
  #

  # Desired Reserve Margin
  for year in Years
    DRM[PE,year] = -0.2
    DRM[NS,year] = 0.1
  end
  
  WriteDisk(db,"EInput/DRM",DRM)

  #
  # Building Strategies
  #
  gencos = Select(GenCo,(from = "ON",to = "NU"))
  years = collect(Future:Yr(2023))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end
  #
  genco = Select(GenCo,"AB")
  years = collect(Future:Yr(2024))
  for year in years
    BuildSw[genco,year] = 0
  end
  #
  gencos = Select(GenCo,["PE","NT","NU","YT"])
  years = collect(Future:Yr(2030))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end
  #
  gencos = Select(GenCo,["MB","NL"])
  years = collect(Future:Yr(2025))
  for year in years, genco in gencos
    BuildSw[genco,year] = 0
  end
  #
  WriteDisk(db,"EGInput/BuildSw",BuildSw)

  #
  # JSO Change 22.01.27 - Since PEI now has growing electricity demands in projections,
  # increase hdxload from NB to PE to allign to NB Power electricity flow projections.
  # Also increase LLMax from NB to PE to prevent peakload emergency power in PE due to growth in peak loads.
  #
  years = collect(Yr(2020):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[PE,NB,timep,month,year] = 115
    LLMax[PE,NB,timep,month,year] = 380
  end
  
  years = collect(Yr(2030):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[PE,NB,timep,month,year] = 600
  end
  
  years = collect(Yr(2028):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,PE,timep,month,year] = 65
  end
  
  years = collect(Yr(2040):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ISNE,NB,timep,month,year] = 800
  end

  #
  # Reduce capacity from ISNE to NB to prevent huge imports
  #
  years = collect(Yr(2026):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,ISNE,timep,month,year] = 400
  end
  
  years = collect(Yr(2028):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,ISNE,timep,month,year] = 300
  end
  
  years = collect(Yr(2030):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,ISNE,timep,month,year] = 200
  end
  
  years = collect(Yr(2028):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,QC,timep,month,year] = 628
  end

  #
  # QC: increase LLMAX to its real value because there is emergency power in 2023-2027
  #
  years = collect(Yr(2023):Yr(2027))
  for year in years, month in Months, timep in TimePs
    LLMax[QC,NYUP,timep,month,year] = 300
    LLMax[QC,ISNE,timep,month,year] = 300
  end
  
  #
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    LLMax[ON,NYUP,timep,month,year] = 340
    LLMax[ON,MISS,timep,month,year] = 570
  end
  
  years = collect(Future:Yr(2029))
  for year in years, month in Months, timep in TimePs
    LLMax[AB,NWPP,timep,month,year] = 300
  end
  
  #
  years = collect(Future:Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[MISW,ON,timep,month,year] = 30
    HDXLoad[MISE,ON,timep,month,year] = 340
    HDXLoad[NYUP,ON,timep,month,year] = 340
  end

  #
  # Lower wheel-through export of electricity from NL to NB (through NS) in 2022 since Muskrat Falls is not yet fully online
  # Contract Flow to New Brunswick (NB) from Nova Scotia (NS)
  #  
  for month in Months, timep in TimePs
    HDXLoad[NB,NS,timep,month,Yr(2022)] = 130
  end
  
  years = collect(Yr(2023):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[NB,NS,timep,month,year] = 194
  end
  
  #
  for month in Months, timep in TimePs
    LLMax[NB,NS,timep,month,Yr(2022)] = 130
  end
  
  years = collect(Yr(2023):Final)
  for year in years, month in Months, timep in TimePs
    LLMax[NB,NS,timep,month,year] = 194
  end

  #
  # Reduce contract from QC to Massachussets during time P1-P5 to prevent emergency power
  #
  years = collect(Yr(2022):Yr(2041))
  for year in years, month in Months, timep in TimePs
    HDXLoad[ISNE,QC,timep,month,year] = 1078.77
  end
  
  #
  for month in Months
    HDXLoad[ISNE,QC,1,month,Yr(2022)] = 1078.77 - 900
    HDXLoad[ISNE,QC,2,month,Yr(2022)] = 1078.77 - 900
    HDXLoad[ISNE,QC,3,month,Yr(2022)] = 1078.77 - 650
    HDXLoad[ISNE,QC,4,month,Yr(2022)] = 1078.77 - 150
  end
  
  #
  for month in Months
    HDXLoad[ISNE,QC,1,month,Yr(2023)] = 1078.77 - 780
    HDXLoad[ISNE,QC,2,month,Yr(2023)] = 1078.77 - 780
    HDXLoad[ISNE,QC,3,month,Yr(2023)] = 1078.77 - 640
    HDXLoad[ISNE,QC,4,month,Yr(2023)] = 1078.77 - 350
  end
  
  #
  for month in Months
    HDXLoad[ISNE,QC,1,month,Yr(2024)] = 1078.77 - 900
    HDXLoad[ISNE,QC,2,month,Yr(2024)] = 1078.77 - 900
    HDXLoad[ISNE,QC,3,month,Yr(2024)] = 1078.77 - 750
    HDXLoad[ISNE,QC,4,month,Yr(2024)] = 1078.77 - 470
  end
  
  #
  for month in Months
    HDXLoad[ISNE,QC,1,month,Yr(2025)] = 1078.77 - 1000
    HDXLoad[ISNE,QC,2,month,Yr(2025)] = 1078.77 - 1000
    HDXLoad[ISNE,QC,3,month,Yr(2025)] = 1078.77 - 1000
    HDXLoad[ISNE,QC,4,month,Yr(2025)] = 1078.77 - 810
    HDXLoad[ISNE,QC,5,month,Yr(2025)] = 1078.77 - 200
  end
  
  #
  for month in Months
    HDXLoad[ISNE,QC,1,month,Yr(2026)] = 1078.77 - 500
    HDXLoad[ISNE,QC,2,month,Yr(2026)] = 1078.77 - 500
    HDXLoad[ISNE,QC,3,month,Yr(2026)] = 1078.77 - 350
    HDXLoad[ISNE,QC,4,month,Yr(2026)] = 1078.77 - 50
  end

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)
  WriteDisk(db,"EGInput/LLMax",LLMax)
end

function PolicyControl(db)
  @info "Electricity_Patch.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
