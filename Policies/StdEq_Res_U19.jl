#
# StdEq_Res_U19.jl
#
# This jl simulates the impact of the following NRCan policies on the energy efficiency of residential equipment.
# Details about the underlying assumptions for this policy (Federal Equipment Standards and Labelling)
# are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
#

using SmallModel

module StdEq_Res_U19

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
  DCCLimit::VariableArray{5} = ReadDisk(db,"$Input/DCCLimit") # [Enduse,Tech,EC,Area,Year] Device Capital Cost Limit Multiplier ($/$)
  DEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Base Year Device Efficiency ($/Btu)
  DEE::VariableArray{5} = ReadDisk(db,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency ($/Btu)
  DEM::VariableArray{4} = ReadDisk(db,"$Input/DEM") # [Enduse,Tech,EC,Area] Maximum Device Efficiency ($/mmBtu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Device Efficiency Max. Mult. ($/Btu/$/Btu)
  DEStd::VariableArray{5} = ReadDisk(db,"$Input/DEStd") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard ($/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard Policy ($/Btu)

  # Scratch Variables
  Change::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Change in Policy Variable
  # InterpFirst   'First year of interpolation period (Year)'
  # InterpLast    'Last year of interpolation period (Year)'
  # PolicyFirst   'Year before first policy impact (Year)'
  # PolicyLast    'Year when full policy impact is achieved (Year)'
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; ECs,Enduse,Enduses) = data
  (; Nation,Tech,Techs) = data
  (; ANMap,Change,DCCLimit,DEEBase,DEM,DEMM,DEStd,DEStdP) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1.0)

  PolicyLast = 2030-ITime+1
  PolicyFirst = Future
  InterpFirst = PolicyFirst+1
  InterpLast = PolicyLast-1
  AfterPolicyEnd = PolicyLast+1

  #
  # Default Value (for all Techs)
  # 
  years = collect(PolicyLast:Final)
  for year in years,tech in Techs
    Change[tech,year] = 0.0
  end

  for tech in Techs
    Change[tech,PolicyFirst] = 0.0
  end

  years = collect(InterpFirst:InterpLast)
  for year in years, tech in Techs
    Change[tech,year] = Change[tech,year-1]+
      ((Change[tech,PolicyLast]-Change[tech,PolicyFirst])/
      (PolicyLast-PolicyFirst))
  end

  #
  # Example - Different value for electric
  #
  Electric = Select(Tech,"Electric")
  years = collect(PolicyLast:Final)
  for year in years
    Change[Electric,year] = 0.19
  end

  Change[Electric,PolicyFirst]=0.0    

  years = collect(InterpFirst:InterpLast)
  for year in years
    Change[Electric,year] = Change[Electric,year-1]+
      ((Change[Electric,PolicyLast]-Change[Electric,PolicyFirst])/
       (PolicyLast-PolicyFirst))
  end

  #
  # Example - Different value for gas
  # 
  Gas = Select(Tech,"Gas")
  years = collect(PolicyLast:Final)
  for year in years
    Change[Gas,year] = 0.12
  end

  Change[Gas,PolicyFirst] = 0.0

  years = collect(InterpFirst:InterpLast)
  for year in years
    Change[Gas,year] = Change[Gas,year-1]+
     ((Change[Gas,PolicyLast]-Change[Gas,PolicyFirst])/
      (PolicyLast-PolicyFirst))
  end

  years = collect(PolicyFirst:Final)
  for enduse in Enduses, tech in Techs, ec in ECs, area in areas, year in years
    DEStdP[enduse,tech,ec,area,year] = max(DEStd[enduse,tech,ec,area,year],
      DEStdP[enduse,tech,ec,area,year],DEEBase[enduse,tech,ec,area,year])*
      (1+Change[tech,year])
  end

  #
  # Making sure efficiencies are not greater that 98.9%
  #  
  techs = Select(Tech,["Electric","Gas"])
  NotAC = Select(Enduse,!=("AC"))

  for enduse in NotAC, tech in techs, ec in ECs, area in areas, year in years
    DEStdP[enduse,tech,ec,area,year] = min(DEStdP[enduse,tech,ec,area,year],0.989)
  end

  for enduse in Enduses, tech in Techs, ec in ECs, area in areas, year in years
    @finite_math DEMM[enduse,tech,ec,area,year] = max((DEStdP[enduse,tech,ec,area,year]/
      (DEM[enduse,tech,ec,area] *0.98)),DEMM[enduse,tech,ec,area,year])
    
    DCCLimit[enduse,tech,ec,area,year] = 3.0
  end

  WriteDisk(db,"$Input/DEStdP",DEStdP)      
  WriteDisk(db,"$CalDB/DEMM",DEMM)
  WriteDisk(db,"$Input/DCCLimit",DCCLimit)
end

function PolicyControl(db)
  @info "StdEq_Res_U19.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
