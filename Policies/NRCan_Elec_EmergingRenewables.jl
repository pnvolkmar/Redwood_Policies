#
#  NRCan_Elec_EmergingRenewables.jl - NRCan Clean Electricity Policy 
#
# Thomas: I have edited the plants being added,see comments starting at Line 128
# Ref: https://natural-resources.canada.ca/climate-change/green-infrastructure-programs/emerging-renewable-power/20502
#

using SmallModel

module NRCan_Elec_EmergingRenewables

import ...SmallModel: ReadDisk,WriteDisk,Select,Zero
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
  GenCo::SetArray = ReadDisk(db,"E2020DB/GenCoKey")
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  CD::VariableArray{2} = ReadDisk(db,"EGInput/CD") # [Plant,Year] Construction Delay (YEARS)
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnUFOMC::VariableArray{2} = ReadDisk(db,"EGInput/UnUFOMC") # [Unit,Year] Fixed O&M Costs ($/Kw/Yr)
  UnUOMC::VariableArray{2} = ReadDisk(db,"EGInput/UnUOMC") # [Unit,Year] Variable O&M Costs (Real $/MWH)
  xUnGCCI::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCI") # [Unit,Year] Generating Capacity Initiated (MW) 
  xUnGCCC::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCC") # [Unit,Year] Generating Unit Capital Cost (Real $/KW)
  xUnGCCR::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCR") # [Unit,Year] Exogenous Generating Capacity Completion Rate (MW)

  # Scratch Variables
  # CapAdd     'Local Variable for Capacity Additions (MW)'
  # LocYear     'Local Variable for Year of Addition (Year)'
  # UCode    'Scratch Variable for UnCode',Type = String(20)
end

function GetUnitSets(data,unit)
  (; Area,GenCo,Node,Plant) = data
  (; UnArea,UnGenCo,UnNode,UnPlant) = data

  plant = Select(Plant,UnPlant[unit])
  node = Select(Node,UnNode[unit])
  genco = Select(GenCo,UnGenCo[unit])
  area = Select(Area,UnArea[unit])

  return plant,node,genco,area
end

function AddCapacity(data,UCode,LocYear,CapAdd)
  (; Year) = data
  (; CD,UnCode,UnOnLine,xUnGCCI,xUnGCCR) = data

  unit = Select(UnCode,UCode)

  #
  # Select GenCo, Area, Node, and Plant Type for this Unit
  #  
  plant,node,genco,area = GetUnitSets(data,unit)

  #
  # Update Online year if needed.
  # 
  UnOnLine[unit] = min(UnOnLine[unit],LocYear)

  #
  # If the plant comes on later in the forecast, then simulate construction
  #  
  if LocYear-CD[plant,Zero] > (HisTime+1)
    Loc1 = LocYear-CD[plant,Zero]-ITime+1
    year = Int(Loc1)
    xUnGCCI[unit,year] = xUnGCCI[unit,year]+CapAdd/1000

  #
  # If the plant comes on-line in the first few years, then there is no time
  # to simulate construction, so just put it on-line.
  #  
  else
    year = Select(Year,string(LocYear))
    xUnGCCR[unit,year] = xUnGCCR[unit,year] + CapAdd/1000
  end
  return
end


function ElecPolicy(db)
  data = EControl(; db)
  (; UnOnLine,xUnGCCI,xUnGCCR) = data

  #
  # Edited by Thomas: (update Ref23)
  #                   I delayed AB_New_Geo from 2022 to 2024 base on "Major Projects Alberta".
  #                   I have postponed BC_New_Geo from 2023 to 2025 and increased the capacity from 5 to 7 MW
  #                                                                     reference: http://fnmpc.ca/clarke_lake)
  #                   I have added NS_New_Wave corresponding to the Meteghan project by Fundry Ocean Research Centre for Energy
  # Edited by Thomas:
  #                   (consultation Ref24)
  #					1.	Suffield Solar, Bifacial solar power generating facility, Alberta, 23 MWac, commissioned in 2021
  #					2.	DEEP Earth Energy, geothermal power facility, Saskatchewan, 5 MW, commissioning 2025-2026
  #					3.	Tu Deh-Kah Geothermal, geothermal power facility, Fort Nelson BC, 5-7 MW, commissioning TBD
  #					4.	Alberta No. 1, geothermal heat and power facility, Alberta, 5 MW, commissioning TBD
  # 					5.	DP Energy Uisce Tapa, tidal energy, Bay of Fundy Nova Scotia, 9 MW, commissioning TBD
  #					6.	Sustainable Marine Energy, tidal energy, Bay of Fundy Nova Scotia, 9 MW, will not commission, parent company went bankrupt
  # 					1 and 2 are already in vData Electric Units other are updated (2028 is arbitrary)

  #                               Year xUnGCCI (kW)
  AddCapacity(data,"AB_New_Geo",  2028,  5000)
  AddCapacity(data,"BC_New_Geo",  2028,  6000)
  AddCapacity(data,"NS_New_Wave", 2028,  9000)

  WriteDisk(db,"EGInput/UnOnLine",UnOnLine)
  WriteDisk(db,"EGInput/xUnGCCI",xUnGCCI)
  WriteDisk(db,"EGInput/xUnGCCR",xUnGCCR)
end

function PolicyControl(db)
  @info "NRCan_Elec_EmergingRenewables.jl - PolicyControl"

  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
