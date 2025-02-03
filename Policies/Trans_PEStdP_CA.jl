#
# Trans_PEStdP_CA.jl - VMT per capita reduced 12% below 2019 levels
# by 2030 and 22% below 2019 levels by 2045
#

using SmallModel

module Trans_PEStdP_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
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
  PEE::VariableArray{5} = ReadDisk(db,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Process Efficiency ($/Btu)
  PEM::VariableArray{4} = ReadDisk(db,"$CalDB/PEM") # [Enduse,Tech,EC,Area] Maximum Process Efficiency ($/Btu)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,year] Process Efficiency Max. Mult. ($/Btu/($/Btu))
  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)

  # Scratch Variables
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,EC) = data
  (; Techs) = data
  (; PEE,PEM,PEMM,PEStd,PEStdP) = data
  (;) = data

  CA = Select(Area,"CA")
  ec = Select(EC,"Passenger")
  #
  ########################
  #
  # Assume VDT improvement applies to all techs, including mass transit - Ian
  #
  years = collect(Yr(2045):Final)
  for tech in Techs
    PEStdP[1,tech,ec,CA,Yr(2021)] = PEE[1,tech,ec,CA,Yr(2019)]
    PEStdP[1,tech,ec,CA,Yr(2030)] = PEE[1,tech,ec,CA,Yr(2019)] * (1+0.12)
    for year in years
      PEStdP[1,tech,ec,CA,year] = PEE[1,tech,ec,CA,Yr(2019)] * (1+0.22)
    end
    
  end

  #
  # Interpolate from 2021
  # 
  years = collect(Yr(2022):Yr(2029))
  for year in years, tech in Techs
    PEStdP[1,tech,ec,CA,year] = PEStdP[1,tech,ec,CA,year-1]+
      (PEStdP[1,tech,ec,CA,Yr(2030)]-PEStdP[1,tech,ec,CA,Yr(2021)])/(2030-2021)
  end

  #
  # Interpolate from 2030
  #  
  years = collect(Yr(2031):Yr(2044))
  for year in years, tech in Techs
    PEStdP[1,tech,ec,CA,year] = PEStdP[1,tech,ec,CA,year-1]+
      (PEStdP[1,tech,ec,CA,Yr(2045)]-PEStdP[1,tech,ec,CA,Yr(2030)])/(2045-2030)
  end

  #
  # Check to stay below maximum
  #  
  years = collect(Yr(2021):Final)
  for year in years, tech in Techs
    PEStdP[1,tech,ec,CA,year] = min(PEM[1,tech,ec,CA]*PEMM[1,tech,ec,CA,year]*.98,
      max(PEStd[1,tech,ec,CA,year],PEStdP[1,tech,ec,CA,year]))
  end

  WriteDisk(db,"$Input/PEStdP",PEStdP);
end

function PolicyControl(db)
  @info "Trans_PEStdP_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
