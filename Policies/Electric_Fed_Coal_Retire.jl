#
# Electric_Fed_Coal_Retire.jl
#
# Formerly Electric_EPS_Coal.jl
#
# 2012 federal coal-fired electricity regulation requiring all coal units to meet a
# 420 tonnes/GWh emissions intensity standardor shut down by "end of life"
# (defined by vintage in the regulation).
# Assume all coal units shut down. No units except Boundary Dam 3 are expected to meet
# the EI standard of 420 tonnes/GWh
#
# Re-written to be sensitive to earlier retirements defined in other jl files or the vData.
# Hilary Paulin 18.07.03
# Edited to adjust for earlier retirement of some SK coal plants. John St-Laurent O'Connor 20.07.03
#

using SmallModel

module Electric_Fed_Coal_Retire

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  Nodes::Vector{Int} = collect(Select(Node))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnFlFrMax::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMax") # [Unit,FuelEP,Year] Fuel Fraction Maximum (Btu/Btu)
  UnFlFrMin::VariableArray{3} = ReadDisk(db,"EGInput/UnFlFrMin") # [Unit,FuelEP,Year] Fuel Fraction Minimum (Btu/Btu)
  UnRetire::VariableArray{2} = ReadDisk(db,"EGInput/UnRetire") # [Unit,Year] Retirement Date (Year)
  xGCPot::VariableArray{4} = ReadDisk(db,"EGInput/xGCPot") # [Plant,Node,Area,Year] Exogenous Maximum Potential Generation Capacity (MW)
  xUnFlFr::VariableArray{3} = ReadDisk(db,"EGInput/xUnFlFr") # [Unit,FuelEP,Year] Fuel Fraction (Btu/Btu)

  # Scratch Variables
  # UCode    'Unit Code of Unit with New Retirement Date',Type = String(20)
  # UName 'Unit Name',Type = String(20)
  # URetire  'New Retirement Date (Year)'
  # URetireOld     'Old Retirement Date (Year)'
end

function GetUnitData(data,UCode,UName,URetire,years)
  (; UnCode,UnRetire) = data
  unit = Select(UnCode,filter(x -> x in UnCode,[UCode]))
  if unit == []
    @debug("Could not match UnCode $UCode")
  else
    if URetire < UnRetire[unit,Future][1]
      for unit in unit, year in years
        UnRetire[unit,year] = URetire
      end
    end
    
  end
  
  return
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,FuelEP,FuelEPs) = data
  (; Nodes,Plant) = data
  (; Years) = data
  (; xGCPot,xUnFlFr,UnCode,UnFlFrMax,UnFlFrMin,UnRetire) = data

  #
  # No one (including AB) is allowed to build any coal plants unless
  # they are CCS. And only AB or SK realistically will build CoalCCS.
  # Per J.Amlin 7/21/2010 RBL.
  # Remove potential for Coal CCS in SK - Jeff Amlin 11/10/19
  #  
  Coal = Select(Plant,"Coal")
  for year in Years, area in Areas, node in Nodes
    xGCPot[Coal,node,area,year] = 0
  end
  
  CoalCCS = Select(Plant,"CoalCCS")
  AB = Select(Area,"AB")
  for year in Years, node in Nodes
    xGCPot[CoalCCS,node,AB,year] = 1000000
  end

  WriteDisk(db,"EGInput/xGCPot",xGCPot)

  #
  # Coleson Cove 3 is an OGSteam which burns Pet Coke so it is outside the loop.
  # Coleson Cove 3 converts back to burning only HFO instead of a mix of HFO and petcoke
  # 17.06.30 H. Paulin (discussions with NB Power).
  #  
  units = Select(UnCode,filter(x -> x in UnCode,["NB00006601403"]))
  PetroCoke = Select(FuelEP,"PetroCoke")
  for unit in units
    xUnFlFr[unit,PetroCoke,Yr(2029)] = xUnFlFr[unit,PetroCoke,Yr(2029)] / 2
  end
  
  HFO = Select(FuelEP,"HFO")
  for unit in units
    xUnFlFr[unit,HFO,Yr(2029)] = 1 - xUnFlFr[unit,PetroCoke,Yr(2029)]
  end
  
  years = collect(Yr(2030):Final)
  for year in years, fuelep in FuelEPs, unit in units
    xUnFlFr[unit,fuelep,year] = 0
  end
  
  for year in years, unit in units
    xUnFlFr[unit,HFO,year] = 1.0
  end
  
  years = collect(Future:Final)
  for year in years, fuelep in FuelEPs, unit in units
    UnFlFrMax[units,fuelep,year] = xUnFlFr[units,fuelep,year]
    UnFlFrMin[units,fuelep,year] = xUnFlFr[units,fuelep,year]
  end

  WriteDisk(db,"EGInput/UnFlFrMax",UnFlFrMax)
  WriteDisk(db,"EGInput/UnFlFrMin",UnFlFrMin)
  WriteDisk(db,"EGInput/xUnFlFr",xUnFlFr)

  #
  # No Nova Scotia units included due to equivalency agreement.
  # No BD4 or BD5 due to SK equivalency agreement.
  #
  #                  UnCode           UnitName         UnRetire
  GetUnitData(data,"AB00029600601","Battle River 3",2020, years)
  GetUnitData(data,"AB00029600602","Battle River 4",2026, years)
  GetUnitData(data,"AB00029600603","Battle River 5",2030, years)
  GetUnitData(data,"AB00001300201","Genesee 1",     2045, years)
  GetUnitData(data,"AB00001300202","Genesee 2",     2040, years)
  GetUnitData(data,"AB00001300203","Genesee 3",     2056, years)
  GetUnitData(data,"AB00002201501","Keephills 1",   2030, years)
  GetUnitData(data,"AB00002201502","Keephills 2",   2030, years)
  GetUnitData(data,"AB_New_26",    "Keephills 3",   2062, years)
  GetUnitData(data,"AB00029600801","Sheerness 1",   2037, years)
  GetUnitData(data,"AB00029600802","Sheerness 2",   2041, years)
  GetUnitData(data,"AB00002201601","Sundance 1",    2020, years)
  GetUnitData(data,"AB00002201602","Sundance 2",    2020, years)
  GetUnitData(data,"AB00002201603","Sundance 3",    2027, years)
  GetUnitData(data,"AB00002201604","Sundance 4",    2028, years)
  GetUnitData(data,"AB00002201605","Sundance 5",    2029, years)
  GetUnitData(data,"AB00002201606","Sundance 6",    2030, years)
  GetUnitData(data,"AB00029600701","H R Milner",    2020, years)
  GetUnitData(data,"MB00005401701","Brandon",       2030, years)
  GetUnitData(data,"NB00006601301","Belledune",     2044, years)
  GetUnitData(data,"SK00015301206","Boundary Dam 6",2028, years)
  GetUnitData(data,"SK00015301301","Poplar River 1",2030, years)
  GetUnitData(data,"SK00015301302","Poplar River 2",2030, years)
  GetUnitData(data,"SK00015301501","Shand",         2043, years)

  WriteDisk(db,"EGInput/UnRetire",UnRetire)
end

function PolicyControl(db)
  @info "Electric_Fed_Coal_Retire.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
