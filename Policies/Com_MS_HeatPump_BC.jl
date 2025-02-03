#
# Com_MS_HeatPump_BC.jl - MS based on 'ResCom_HeatPump_BC.jl'
#
# Ian 08/23/21
#
# This policy simulates the the BC heat pump incentive which is part of the CleanBC plan.
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
# (A. Dumas 2020/06/25).
# Last updated by Kevin Palmer-Wilson on 2023-06-09
#

using SmallModel

module Com_MS_HeatPump_BC

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))
  
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
end

function ComPolicy()
  data = CControl(db=DB)
  (; CalDB) = data
  (; Area,ECs,Enduse) = data
  (; Tech) = data
  (; xMMSF) = data

  #
  # specify values for desired fuel shares (xMMSF)
  #  
  BC = Select(Area,"BC")  
  years = collect(Yr(2022):Yr(2030)) 
  
  #
  # Roughly 10% of new furnaces will be HeatPump,replacing Gas
  #  
  Heat = Select(Enduse,"Heat")
  HeatPump = Select(Tech,"HeatPump")
  Gas = Select(Tech,"Gas")
  for ec in ECs, year in years
    xMMSF[Heat,HeatPump,ec,BC,year] = 0.1
    xMMSF[Heat,Gas,ec,BC,year] = max(xMMSF[Heat,Gas,ec,BC,year]-0.1,0.0)
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Com_MS_HeatPump_BC - PolicyControl"
  ComPolicy()
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
