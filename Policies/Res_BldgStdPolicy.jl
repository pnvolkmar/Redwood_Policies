#
# Res_BldgStdPolicy.jl 
#
# - Future building code standards
# Last updated by Kevin Palmer-Wilson on 2023-06-09
#
########################
#
# This policy increases the process efficiency standard (PEStdP).
# The policy is aimed to reflect provincial actions aimed at increasing
# the energy efficiency of new residential buildings.
#
# It is important to note that provincial measures are expressed as improvements to 
# energy intensity, while the PEStdP variable is expressed in terms of energy 
# efficiency. For this reason, the provincial energy intensity improvement targets 
# need to be converted to energy efficiency targets using the following equation:
# deltaEfficiency = 1/(1-deltaIntensity)-1 
# where deltaIntensity is expressed as a positive number.
#
# For background on how the energy efficiency values were developed, see 
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Policy Support Work\Bld Codes Analysis\.
# Detailed factors available in "Bld Codes Stringencyv7.xlsx".
#
########################

using SmallModel

module Res_BldgStdPolicy

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
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)

  PEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # Process Efficiency ($/Btu) [Enduse,Tech,EC,Area,Year]

  # 
  # PEMMBase should point to 'BCNameDB' in fixed Promula version. Use 'db'
  # for now to match bug
  #

  PEMMBase::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # Process Efficiency Max. Mult. ($/Btu/($/Btu)) [Enduse,Tech,EC,Area,Year]
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # Process Efficiency Max. Mult. ($/Btu/($/Btu)) [Enduse,Tech,EC,Area,Year]
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM") # Maximum Process Efficiency ($/Btu) [Enduse,EC,Area]

  # Scratch Variables
  EEImprovement::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Energy Efficiency Improvement from Baseline Value ($/Btu)/($/Btu)
  EIImprovement::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Energy Intensity Improvement from Baseline Value ($/Btu)/($/Btu)
  PEEAvg_BC::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Base Case Process Efficiency ($/Btu)
  PEMMAvg_BC::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Process Efficiency Max. Mult. ($/Btu/($/Btu))
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduse) = data
  (; Techs) = data
  (; EEImprovement,EIImprovement,PEEAvg_BC,PEEBase) = data
  (; PEM,PEMM,PEMMAvg_BC,PEMMBase,PEStd,PEStdP) = data

  @. EEImprovement = 0.0
  @. EIImprovement = 0.0
  years = collect(Yr(2022):Yr(2025))
  BC = Select(Area,"BC")
  for year in years
    EEImprovement[BC,year] = 0.504
  end
  
  years = collect(Yr(2026):Yr(2030))
  for year in years
    EEImprovement[BC,year] = 0.508
  end
  
  years = collect(Yr(2031):Yr(2035))
  for year in years
    EEImprovement[BC,year] = 0.659
  end
  
  years = collect(Yr(2036):Final)
  for year in years
    EEImprovement[BC,year] = 0.677
  end

  areas = Select(Area,["ON","PE"])
  years = collect(Yr(2022):Final)
  for year in years, area in areas
    EEImprovement[area,year] = 0.2
  end

  NB = Select(Area,"NB")
  years = collect(Yr(2022):Final)
  for year in years
    EEImprovement[NB,year] = 0.2
  end

  SK = Select(Area,"SK")
  years = collect(Yr(2022):Final)
  for year in years
    EEImprovement[SK,year] = 0.2
  end
  
  areas = Select(Area,["BC","ON","PE","NB","SK"])
  years = collect(Yr(2022):Final)
  for year in years, area in areas
    EIImprovement[area,year] = 1 / (1 - EEImprovement[area,year])
  end

  Heat = Select(Enduse,"Heat")
  BC = Select(Area,"BC")
  years = collect(Yr(2006):Yr(2010))
  for tech in Techs, ec in ECs
    PEEAvg_BC[Heat,tech,ec,BC] = sum(PEEBase[Heat,tech,ec,BC,year] for year in years) / 5.0
    PEMMAvg_BC[Heat,tech,ec,BC] = sum(PEMMBase[Heat,tech,ec,BC,year] for year in years) / 5.0
  end

  years = collect(Yr(2022):Final)
  for tech in Techs, ec in ECs, year in years
    PEMM[Heat,tech,ec,BC,year] = max(PEMM[Heat,tech,ec,BC,year],
      PEMMAvg_BC[Heat,tech,ec,BC]*(1+EIImprovement[BC,year]))
    PEStdP[Heat,tech,ec,BC,year] = max(PEStd[Heat,tech,ec,BC,year],
      PEStdP[Heat,tech,ec,BC,year],min(PEM[Heat,ec,BC]*PEMM[Heat,tech,ec,BC,year]*0.98,
        PEEAvg_BC[Heat,tech,ec,BC]*(1+EIImprovement[BC,year])))
  end

  areas = Select(Area,["ON","PE"])
  for tech in Techs, ec in ECs, year in years, area in areas
    PEMM[Heat,tech,ec,area,year] = max(PEMM[Heat,tech,ec,area,year],
      PEMMBase[Heat,tech,ec,area,Yr(2009)]*(1+EIImprovement[area,year]))
    PEStdP[Heat,tech,ec,area,year] = max(PEStd[Heat,tech,ec,area,year],
      PEStdP[Heat,tech,ec,area,year],min(PEM[Heat,ec,area]*PEMM[Heat,tech,ec,area,year]*
        0.98,PEEBase[Heat,tech,ec,area,Yr(2009)]*(1+EIImprovement[area,year])))
  end

  for tech in Techs, ec in ECs, year in years
    PEMM[Heat,tech,ec,NB,year] = max(PEMM[Heat,tech,ec,NB,year],
      PEMMBase[Heat,tech,ec,NB,Yr(2009)]*(1+EIImprovement[NB,year]))
    PEStdP[Heat,tech,ec,NB,year] = max(PEStd[Heat,tech,ec,NB,year],
      PEStdP[Heat,tech,ec,NB,year],min(PEM[Heat,ec,NB]*PEMM[Heat,tech,ec,NB,year]*
        0.98,PEEBase[Heat,tech,ec,NB,Yr(2009)]*(1+EIImprovement[NB,year])))
  end

  for tech in Techs, ec in ECs, year in years
    PEMM[Heat,tech,ec,SK,year] = max(PEMM[Heat,tech,ec,SK,year],
      PEMMBase[Heat,tech,ec,SK,Yr(2009)]*(1+EIImprovement[SK,year]))
    PEStdP[Heat,tech,ec,SK,year] = max(PEStd[Heat,tech,ec,SK,year],
      PEStdP[Heat,tech,ec,SK,year],min(PEM[Heat,ec,SK]*PEMM[Heat,tech,ec,SK,year]*
        0.98,PEEBase[Heat,tech,ec,SK,Yr(2009)]*(1+EIImprovement[SK,year])))
  end

  WriteDisk(db,"$Input/PEStdP",PEStdP)
  WriteDisk(db,"$CalDB/PEMM",PEMM)
end

function PolicyControl(db)
  @info "Res_BldgStdPolicy.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
