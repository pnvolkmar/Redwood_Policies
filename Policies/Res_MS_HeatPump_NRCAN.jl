#
# Res_MS_HeatPump_NRCAN.jl - MS based on 'ResCom_HeatPump_BC.jl'
#
# This policy simulates OHPA targets low- to median-income Canadian households heating with oil (approx 350,000 but  ~75% of which are owner-occupied (excluding territorial figures).
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
# Timothy Timothy on 2023-08-22
# Last updated by Yang Li on 2024-06-12
#

using SmallModel

module Res_MS_HeatPump_NRCAN

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
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
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
  ecs = Select(EC,["SingleFamilyDetached", "SingleFamilyAttached","MultiFamily"])

  #    
  # Roughly 4% of new furnaces will be HeatPump, replacing Oil
  #  
  Heat = Select(Enduse,"Heat")
  HeatPump = Select(Tech,"HeatPump")
  Oil = Select(Tech,"Oil")
  years = collect(Yr(2023):Yr(2028))

  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,BC,year] = 0.04
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,BC,year] = max(xMMSF[Heat,Oil,ec,BC,year]-0.04,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  HW = Select(Enduse,"HW")
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,BC,year] = 0.04
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,BC,year] = max(xMMSF[HW,Oil,ec,BC,year]-0.04,0.0)
  end

  #
  # Roughly 7% of new furnaces will be HeatPump, replacing Oil
  #  
  ON = Select(Area,"ON")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,ON,year] = 0.07
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,ON,year] = max(xMMSF[Heat,Oil,ec,ON,year]-0.07,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,ON,year] = 0.07
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,ON,year] = max(xMMSF[HW,Oil,ec,ON,year]-0.07,0.0)
  end

  #
  # Roughly 1% of new furnaces will be HeatPump, replacing Oil
  #
  areas = Select(Area,["AB","MB","SK","NU"])
  for year in years, area in areas, ec in ecs
    xMMSF[Heat,HeatPump,ec,area,year] = 0.01
  end

  for year in years, ec in ecs, area in areas
    xMMSF[Heat,Oil,ec,area,year] = max(xMMSF[Heat,Oil,ec,area,year]-0.01,0.0)
  end

  #
  # Make same assumption for Res HW for now
  # 
  for year in years, area in areas, ec in ecs
    xMMSF[HW,HeatPump,ec,area,year] = 0.01
  end

  for year in years, ec in ecs, area in areas
    xMMSF[HW,Oil,ec,area,year] = max(xMMSF[HW,Oil,ec,area,year]-0.01,0.0)
  end

  #
  # Roughly 15% of new furnaces will be HeatPump, replacing Oil
  #  
  QC = Select(Area,"QC")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,QC,year] = 0.15
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,QC,year] = max(xMMSF[Heat,Oil,ec,QC,year]-0.15,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,QC,year] = 0.15
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,QC,year] = max(xMMSF[HW,Oil,ec,QC,year]-0.15,0.0)
  end

  #
  # Roughly 34% of new furnaces will be HeatPump, replacing Oil
  #  
  NS = Select(Area,"NS")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,NS,year] = 0.34
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,NS,year] = max(xMMSF[Heat,Oil,ec,NS,year]-0.34,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,NS,year] = 0.34
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,NS,year] = max(xMMSF[HW,Oil,ec,NS,year]-0.34,0.0)
  end

  #
  # Roughly 10% of new furnaces will be HeatPump, replacing Oil
  #  
  NL = Select(Area,"NL")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,NL,year] = 0.1
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,NL,year] = max(xMMSF[Heat,Oil,ec,NL,year]-0.1,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,NL,year] = 0.1
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,NL,year] = max(xMMSF[HW,Oil,ec,NL,year]-0.1,0.0)
  end

  #
  # Roughly 13% of new furnaces will be HeatPump, replacing Oil
  #  
  NB = Select(Area,"NB")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,NB,year] = 0.13
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,NB,year] = max(xMMSF[Heat,Oil,ec,NB,year]-0.13,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,NB,year] = 0.13
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,NB,year] = max(xMMSF[HW,Oil,ec,NB,year]-0.13,0.0)
  end

  #
  # Roughly 9% of new furnaces will be HeatPump, replacing Oil
  #  
  PE = Select(Area,"PE")
  for year in years, ec in ecs
    xMMSF[Heat,HeatPump,ec,PE,year] = 0.09
  end

  for year in years, ec in ecs
    xMMSF[Heat,Oil,ec,PE,year] = max(xMMSF[Heat,Oil,ec,PE,year]-0.09,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  for year in years, ec in ecs
    xMMSF[HW,HeatPump,ec,PE,year] = 0.09
  end

  for year in years, ec in ecs
    xMMSF[HW,Oil,ec,PE,year] = max(xMMSF[HW,Oil,ec,PE,year]-0.09,0.0)
  end

  #
  # Roughly 2% of new furnaces will be HeatPump, replacing Oil
  #  
  areas = Select(Area,["YT","NT"])
  for year in years, area in areas, ec in ecs
    xMMSF[Heat,HeatPump,ec,area,year] = 0.02
  end

  for year in years, ec in ecs, area in areas
    xMMSF[Heat,Oil,ec,area,year] = max(xMMSF[Heat,Oil,ec,area,year]-0.02,0.0)
  end

  #
  # Make same assumption for Res HW for now
  #  
  for year in years, area in areas, ec in ecs
    xMMSF[HW,HeatPump,ec,area,year] = 0.02
  end

  for year in years, ec in ecs, area in areas
    xMMSF[HW,Oil,ec,area,year] = max(xMMSF[HW,Oil,ec,area,year]-0.02,0.0)
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Res_MS_HeatPump_NRCAN - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
