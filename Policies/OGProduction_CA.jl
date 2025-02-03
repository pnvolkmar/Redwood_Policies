#
# OGProduction_CA.jl - Oil and Gas Production Policy
#

using SmallModel

module OGProduction_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  CalDB::String = "SCalDB"
  Input::String = "SInput"
  Outpt::String = "SOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  OGUnit::SetArray = ReadDisk(db,"E2020DB/OGUnitKey")
  OGUnits::Vector{Int} = collect(Select(OGUnit))
  Process::SetArray = ReadDisk(db,"E2020DB/ProcessKey")
  ProcessDS::SetArray = ReadDisk(db,"E2020DB/ProcessDS")
  Processes::Vector{Int} = collect(Select(Process))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  OGArea::Array{String} = ReadDisk(db,"SpInput/OGArea") # [OGUnit] Area
  OGECC::Array{String} = ReadDisk(db,"SpInput/OGECC") # [OGUnit] Economic Sector
  OGFuel::Array{String} = ReadDisk(db,"SpInput/OGFuel") # [OGUnit] Fuel Type
  OGNation::Array{String} = ReadDisk(db,"SpInput/OGNation") # [OGUnit] Nation
  OGNode::Array{String} = ReadDisk(db,"SpInput/OGNode") # [OGUnit] Natural Gas Transmission Node
  OGOGSw::Array{String} = ReadDisk(db,"SpInput/OGOGSw") # [OGUnit] Oil or Gas Switch
  OGProcess::Array{String} = ReadDisk(db,"SpInput/OGProcess") # [OGUnit] Production Process
  xGAProd::VariableArray{3} = ReadDisk(db,"SInput/xGAProd") # [Process,Area,Year] Natural Gas Production (TBtu/Yr)
  xOAProd::VariableArray{3} = ReadDisk(db,"SInput/xOAProd") # [Process,Area,Year] Oil Production (TBtu/Yr)
  xPd::VariableArray{2} = ReadDisk(db,"SpInput/xPd") # [OGUnit,Year] Exogenous Production (TBtu/Yr)
  xPdCum::VariableArray{2} = ReadDisk(db,"SpInput/xPdCum") # [OGUnit,Year] Historical Cumulative Production (TBtu)
  DevSw::VariableArray{2} = ReadDisk(db,"SpInput/DevSw") # [OGUnit,Year] Development Switch
  PdSw::VariableArray{2} = ReadDisk(db,"SpInput/PdSw") # [OGUnit,Year] Production Switch

  # Scratch Variables
end

function OGSetSelect(data,ogunit)
  (; Area,Process) = data #sets
  (; OGArea,OGECC) = data #sets

  OGUnitIsValid="True"

  areaindex = Select(Area,OGArea[ogunit])
  # eccindex = Select(ECC,OGECC[ogunit])
  processindex = Select(Process,OGECC[ogunit])
  # fuelogindex = Select(FuelOG,OGFuel[ogunit])
  # procogindex = Select(ProcOG,OGProcess[ogunit])
  # gnodeindex = Select(GNode,OGNode[ogunit])
  # nationindex = Select(Nation,OGNation[ogunit])

  if OGArea[ogunit] != Area[areaindex]
    @info "OGArea is not valid inside SpOGProd.jl " ogunit, OGArea[ogunit]
    OGUnitIsValid="False"
  # elseif OGECC[ogunit] != ECC[eccindex]
  #   @info "OGECC is not valid inside SpOGProd.jl " OGName[ogunit], OGECC[ogunit]
  #   OGUnitIsValid="False"
  # elseif OGFuel[ogunit] != FuelOG[fuelogindex]
  #   @info "OGFuel is not valid inside SpOGProd.jl " OGName[ogunit], OGFuel[ogunit]
  #   OGUnitIsValid="False"
  # elseif OGNode[ogunit] != GNode[gnodeindex]
  #   @info "OGNode is not valid inside SpOGProd.jl " OGName[ogunit], OGNode[ogunit]
  #   OGUnitIsValid="False"
  # elseif OGNation[ogunit] != Nation[nationindex]
  #   @info "OGNation is not valid inside SpOGProd.jl " OGName[ogunit], OGNation[ogunit]
  #   OGUnitIsValid="False"
  end

  return areaindex,processindex,OGUnitIsValid
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Area) = data
  (; Processes) = data
  (; OGArea,OGOGSw) = data
  (; xGAProd,xOAProd) = data
  (; xPd,xPdCum,DevSw,PdSw) = data

  CA = Select(Area,"CA")
  years = collect(Yr(2045):Final)
  for year in years, process in Processes
    xOAProd[process,CA,year] = 0
    xGAProd[process,CA,year] = 0
  end

  years = collect(Yr(2026):Yr(2044))
  for year in years, process in Processes
    xOAProd[process,CA,year] = xOAProd[process,CA,year-1]+
      (xOAProd[process,CA,Yr(2045)]-xOAProd[process,CA,Yr(2025)])/(2045-2025)
    xGAProd[process,CA,year] = xGAProd[process,CA,year-1]+
      (xGAProd[process,CA,Yr(2045)]-xGAProd[process,CA,Yr(2025)])/(2045-2025)
  end

  WriteDisk(db,"SInput/xGAProd",xGAProd)
  WriteDisk(db,"SInput/xOAProd",xOAProd)

  #
  ########################
  #
  # OGUnits where data directly equal to value in xOAProd and xGAProd
  #
  years = collect(Yr(2026):Final)
  ogunits=findall(OGArea[:] .== "CA")
  if !isempty(ogunits)
    for ogunit in ogunits
      area,process,OGUnitIsValid = OGSetSelect(data,ogunit)
      for year in years
        if OGOGSw[ogunit] == "Oil"
          xPd[ogunit,year] = xOAProd[process,area,year]
        elseif OGOGSw[ogunit] == "Gas"
          xPd[ogunit,year] = xGAProd[process,area,year]
        end
        
      end
      
    end
    
  end

  WriteDisk(db,"SpInput/xPd",xPd)

  #
  ########################
  #
  # Cumulative Production
  #
  years = collect(Yr(2026):Final)
  ogunits=findall(OGArea[:] .== "CA")
  if !isempty(ogunits)
    for year in years,ogunit in ogunits
      xPdCum[ogunit,year] = xPdCum[ogunit,year-1]+xPd[ogunit,year]
    end
    
  end

  WriteDisk(db,"SpInput/xPdCum",xPdCum)

  #
  ########################
  #
  # Set California OG Units exogenous
  #
  years = collect(Yr(2026):Final)
  ogunits=findall(OGArea[:] .== "CA")
  if !isempty(ogunits)
    for year in years,ogunit in ogunits
      DevSw[ogunit,year] = 0
      PdSw[ogunit,year] = 0
    end
    
  end

  WriteDisk(db,"SpInput/DevSw",DevSw)
  WriteDisk(db,"SpInput/PdSw",PdSw)
end

function PolicyControl(db)
  @info "OGProduction_CA.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
