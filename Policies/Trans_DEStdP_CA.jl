#
# Trans_DEStdP_CA.jl - LDV Fuel Economy Standards: I GHG standards
# for 2017 - 2025 model years, 2% annual fuel economy improvement
# for 2026-2035.
#

using SmallModel

module Trans_DEStdP_CA

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

  DEStd::VariableArray{5} = ReadDisk(db,"$Input/DEStd") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standards (Btu/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standards Policy (Btu/Btu)
  xDEE::VariableArray{5} = ReadDisk(db,"$Input/xDEE") # [Enduse,Tech,EC,Area,Year] Historical Device Efficiency (Btu/Btu) 

  # Scratch Variables
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,EC) = data
  (; Tech) = data
  (; DEStd,DEStdP,xDEE) = data

  CA = Select(Area,"CA")
  ec = Select(EC,"Passenger")

  #
  # Assume standard applies just to Gasoline/Diesel
  #  
  techs = Select(Tech,["LDVGasoline","LDVDiesel","LDTGasoline","LDTDiesel"])

  #
  ########################
  #
  # Assume xDEE has 2025 standards (looks like it does in current data)
  # - Ian
  #
  for tech in techs
    DEStdP[1,tech,ec,CA,Yr(2025)] = max(xDEE[1,tech,ec,CA,Yr(2025)],
      DEStd[1,tech,ec,CA,Yr(2025)],DEStdP[1,tech,ec,CA,Yr(2025)])
  end

  years = collect(Yr(2026):Yr(2035))
  for year in years, tech in techs
    DEStdP[1,tech,ec,CA,year] = DEStdP[1,tech,ec,CA,year-1]*1.02
  end

  years = collect(Yr(2036):Final)
  for year in years, tech in techs
    DEStdP[1,tech,ec,CA,year] = DEStdP[1,tech,ec,CA,year-1]
  end

  WriteDisk(db,"$Input/DEStdP",DEStdP)
end

function PolicyControl(db)
  @info "Trans_DEStdP_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
