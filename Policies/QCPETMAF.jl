#
# QCPETMAF.jl
#
# This file models Quebec's "Programme d’aide a l’amelioration de l’efficacite du transport
# maritime, aerien et ferroviaire" (PETMAF) by increasing the efficiency of trains, marine,
# air and offroad for passenger and freigth to meet emissions goal of 119 kt in 2030. The 
# 119 kt emission goal is based on assumptions provided by Quebec as part of the 
# consultations for Ref16 (M. Charbonneau, 2016/09/19).
#

using SmallModel

module QCPETMAF

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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

  DEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency in Base Case (Mile/mmBtu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Maximum Device Efficiency Multiplier (Btu/Btu)
  DEMMBase::VariableArray{5} = ReadDisk(BCNameDB,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Maximum Device Efficiency Multiplier (Btu/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standards Policy (Btu/Btu)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,Enduses,Tech) = data
  (; DEEBase,DEMM,DEMMBase) = data
  (; DEStdP) = data
  
  ecs = Select(EC,["Passenger","Freight","AirPassenger","AirFreight","ResidentialOffRoad","CommercialOffRoad"])
  areas = Select(Area,"QC") 
  techs = Select(Tech,["TrainDiesel","MarineLight","MarineHeavy","PlaneJetFuel","PlaneGasoline","OffRoad"]) 
  years = collect(Yr(2022):Yr(2050))
  
  for year in years, area in areas, ec in ecs, tech in techs, enduse in Enduses
    DEStdP[enduse,tech,ec,area,year] = max(DEEBase[enduse,tech,ec,area,year],
      DEStdP[enduse,tech,ec,area,year])*1.0163
    @finite_math DEMM[enduse,tech,ec,area,year] = DEMMBase[enduse,tech,ec,area,year]*
      DEStdP[enduse,tech,ec,area,year]/DEEBase[enduse,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/DEStdP",DEStdP)
  WriteDisk(db,"$CalDB/DEMM",DEMM)
end

function PolicyControl(db)
  @info "QCPETMAF.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
