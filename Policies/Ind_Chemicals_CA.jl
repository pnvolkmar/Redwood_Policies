#
# Ind_Chemicals_CA.jl - Chemicals and Pulp and Paper: Electrify 0%
# of boilers by 2030 and 100% of boilers by 2045. Hydrogen for 25% of
# process heat by 2035 and 100% by 2045. Electrify 100% of other
# energy demand by 2045
#

using SmallModel

module Ind_Chemicals_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
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
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
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
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  FsFracMin::VariableArray{5} = ReadDisk(db,"$Input/FsFracMin") # [Fuel,Tech,EC,Area,Year] Feedstock Fuel/Tech Fraction Minimum (Btu/Btu)

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMin,FsFracMin) = data

  CA = Select(Area,"CA")

  #
  ########################
  #
  # Select E2020 Chemical sectors and PulpPaper
  #
  ecs_1 = Select(EC,"PulpPaperMills")
  ecs_2 = Select(EC,(from="Petrochemicals",to="OtherChemicals"))
  ecs = union(ecs_1,ecs_2)

  #
  # Heat converts to H2
  #  
  Heat = Select(Enduse,"Heat")
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","OffRoad"])

  Hydrogen = Select(Fuel,"Hydrogen")
  for ec in ecs, tech in techs
    DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2035)] = 
      max(DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2035)],0.25)
    FsFracMin[Hydrogen,tech,ec,CA,Yr(2035)] = 
      max(FsFracMin[Hydrogen,tech,ec,CA,Yr(2035)],0.25)
  end

  years = collect(Yr(2045):Final)
  for year in years, ec in ecs, tech in techs
    DmFracMin[Heat,Hydrogen,tech,ec,CA,year] = 
      max(DmFracMin[Heat,Hydrogen,tech,ec,CA,year],1.0)
    FsFracMin[Hydrogen,tech,ec,CA,year] = 
      max(FsFracMin[Hydrogen,tech,ec,CA,year],1.0)
  end

  #
  # Interpolate from 2021
  #  
  years = collect(Yr(2022):Yr(2034))
  for year in years, ec in ecs, tech in techs
    DmFracMin[Heat,Hydrogen,tech,ec,CA,year] = 
      DmFracMin[Heat,Hydrogen,tech,ec,CA,year-1]+
        (DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2035)]-
          DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2021)])/(2035-2021)
    FsFracMin[Hydrogen,tech,ec,CA,year] = 
      FsFracMin[Hydrogen,tech,ec,CA,year-1]+
        (FsFracMin[Hydrogen,tech,ec,CA,Yr(2035)]-
          FsFracMin[Hydrogen,tech,ec,CA,Yr(2021)])/(2035-2021)
  end

  years = collect(Yr(2036):Yr(2044))
  for year in years, ec in ecs, tech in techs
    DmFracMin[Heat,Hydrogen,tech,ec,CA,year] = 
      DmFracMin[Heat,Hydrogen,tech,ec,CA,year-1]+
        (DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2045)]-
          DmFracMin[Heat,Hydrogen,tech,ec,CA,Yr(2035)])/(2045-2035)
    FsFracMin[Hydrogen,tech,ec,CA,year] = FsFracMin[Hydrogen,tech,ec,CA,year-1]+
      (FsFracMin[Hydrogen,tech,ec,CA,Yr(2045)]-
        FsFracMin[Hydrogen,tech,ec,CA,Yr(2035)])/(2045-2035)
  end

  #
  # OthSub and OffRoad converts to Electric
  #  
  enduses = Select(Enduse,["OthSub","OffRoad"])
  techs = Select(Tech,["Gas","Coal","Oil","Biomass","OffRoad"])
  #
  Electric = Select(Fuel,"Electric")
  years = collect(Yr(2045):Final)
  for year in years, ec in ecs, tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,year] = 
      max(DmFracMin[enduse,Electric,tech,ec,CA,year],1.0)
  end

  #
  # Interpolate from 2021
  #  
  years = collect(Yr(2022):Yr(2044))
  for year in years, ec in ecs, tech in techs, enduse in enduses
    DmFracMin[enduse,Electric,tech,ec,CA,year] = 
      DmFracMin[enduse,Electric,tech,ec,CA,year-1]+
        (DmFracMin[enduse,Electric,tech,ec,CA,Yr(2045)]-
          DmFracMin[enduse,Electric,tech,ec,CA,Yr(2021)])/(2045-2021)
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin);
  WriteDisk(db,"$Input/FsFracMin",FsFracMin);
end

function PolicyControl(db)
  @info "Ind_Chemicals_CA.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
