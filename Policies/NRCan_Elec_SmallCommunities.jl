#
#  NRCan_Elec_SmallCommunities.jl
#

using SmallModel

module NRCan_Elec_SmallCommunities

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
  xUnGCCI::VariableArray{2} = ReadDisk(db,"EGInput/xUnGCCI") # [Unit,Year] Generating Capacity Initiated (MW)
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
  if LocYear - CD[plant,Zero] > (HisTime+1)
    Loc1 = LocYear-CD[plant,Zero]-ITime+1
    year = Int(Loc1)
    xUnGCCI[unit,year] = xUnGCCI[unit,year] + CapAdd/1000

  #
  # If the plant comes on-line in the first few years, then there is no time
  # to simulate construction, so just put it on-line.
  #  
  else
    year = Select(Year,string(LocYear))
    xUnGCCR[unit,year] = xUnGCCR[unit,year]+CapAdd/1000
  end
  
  return
end

function ElecPolicy(db)
  data = EControl(; db)
  (; UnOnLine,xUnGCCI,xUnGCCR) = data

  #
  # Thomas (updated in Ref24): added AB, SK, ON, and NB plants
  #
  #                 Prov_Gentype (UnCode)  Year  xUnGCCI (kW)
  AddCapacity(data,"NT_New_OnshoreWind",  2023,   3000)
  AddCapacity(data,"NT_New_OnshoreWind",  2024,  10000)
  AddCapacity(data,"NT_New_OnshoreWind",  2025,  24000)
  AddCapacity(data,"NU_New_OnshoreWind",  2023,   3000)
  AddCapacity(data,"NU_New_OnshoreWind",  2024,   6500)
  AddCapacity(data,"NU_New_OnshoreWind",  2025,  13000)
  AddCapacity(data,"AB_New_SolarPV",      2024,  13600)
  AddCapacity(data,"SK_New_SolarPV",      2024,   3816)
  AddCapacity(data,"SK_New_SolarPV",      2024,   1000)
  AddCapacity(data,"ON_New_Battery",      2024,  36900)
  AddCapacity(data,"NB_New_OnshoreWind",  2025,  25200)

  WriteDisk(db,"EGInput/UnOnLine",UnOnLine)
  WriteDisk(db,"EGInput/xUnGCCI",xUnGCCI)
  WriteDisk(db,"EGInput/xUnGCCR",xUnGCCR)
end

function PolicyControl(db)
  @info "NRCan_Elec_SmallCommunities.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
