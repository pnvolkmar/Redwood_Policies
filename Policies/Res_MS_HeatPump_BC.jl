#
# Res_MS_HeatPump_BC.jl - MS based on 'ResCom_HeatPump_BC.jl'
#
# Ian 08/23/21
#
# This policy simulates the the BC heat pump incentive which is part of the CleanBC plan.
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
# Last updated by Yang Li on 2024-06-13
#

using SmallModel

module Res_MS_HeatPump_BC

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
  db::String

  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

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

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB) = data
  (; Area,EC,Enduse) = data 
  (; Tech) = data
  (; xMMSF) = data

  #
  # Specify values for desired fuel shares (xMMSF)
  # 
  BC = Select(Area,"BC")
  ecs = Select(EC,["SingleFamilyDetached","SingleFamilyAttached","MultiFamily"])
  Heat = Select(Enduse,"Heat")
  HeatPump = Select(Tech,"HeatPump")
  years = collect(Yr(2023):Yr(2030))

  #
  # Roughly 3% of new furnaces will be HeatPump, replacing Gas
  #
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,BC,year] = 0.03
  end

  Gas = Select(Tech,"Gas")

  for year in years, ec in ecs
    xMMSF[Heat,Gas,ec,BC,year] = max(xMMSF[Heat,Gas,ec,BC,year]-0.03,0.0)
  end

  #
  # Make same assumption for Res WH for now
  # 
  HW = Select(Enduse,"HW")
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,BC,year] = 0.03
  end

  for year in years, ec in ecs
    xMMSF[HW,Gas,ec,BC,year] = max(xMMSF[HW,Gas,ec,BC,year]-0.03,0.0)
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Res_MS_HeatPump_BC - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
