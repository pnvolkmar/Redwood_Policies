#
# Ind_Biomass_QC.jl - Programme de biomasse forestière résiduelle (industries et commercial)
#
# Target 124 kt GHG by 2024 in QC; assume commercial amounts are negligible.
# Approach: Use DmFrac to substitute petroleum coke with Biomass in cement and natural gas with Biomass in Food & Tobacco
# See QC BiomasseProgramme.xlsx
# (RW 06/02/2021)
# Updated fuel switching targets for Ref23 tuning (RST 06Sept2022)
#

using SmallModel

module Ind_Biomass_QC

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] device Exogenous Investments (M$/Yr)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Fraction)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  CCC::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  Target::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Fuel Target (Btu/Btu)
end

function SetFuelSwitchingTargets(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse) = data
  (; Fuel) = data
  (; Tech,Years) = data
  (; DmFracMin) = data
  (; Target,xDmFrac) = data

  for year in Years
    Target[year] = 0
  end

  #
  # Target for fuel switching, Petroleum Coke to Biomass in Cement
  #  
  areas = Select(Area,"QC")
  ecs = Select(EC,"Cement")
  enduses = Select(Enduse,"Heat")
  techs = Select(Tech,"Coal")
  Biomass = Select(Fuel,"Biomass")
  PetroCoke = Select(Fuel,"PetroCoke")
  NaturalGas = Select(Fuel,"NaturalGas")

  years = collect(Yr(2022):Yr(2050))
  
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    Target[year] = 0.15
    xDmFrac[enduse,Biomass,tech,ec,area,year] =
      xDmFrac[enduse,Biomass,tech,ec,area,year]+
        xDmFrac[enduse,PetroCoke,tech,ec,area,year]*Target[year]
    xDmFrac[enduse,PetroCoke,tech,ec,area,year] = 
      xDmFrac[enduse,PetroCoke,tech,ec,area,year]*(1-Target[year])

    DmFracMin[enduse,Biomass,tech,ec,area,year] = 
      xDmFrac[enduse,Biomass,tech,ec,area,year]
    DmFracMin[enduse,PetroCoke,tech,ec,area,year] = 
      xDmFrac[enduse,PetroCoke,tech,ec,area,year]
  end

  #
  # Target for fuel switching, Natural Gas to Biomass in Food & Tobacco
  #  
  for year in Years
    Target[year] = 0
  end
  years = collect(Yr(2022):Yr(2050))
  ecs = Select(EC,"Food")
  techs = Select(Tech,"Gas")
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    Target[year] = 0.047
    xDmFrac[enduse,Biomass,tech,ec,area,year] = 
      xDmFrac[enduse,Biomass,tech,ec,area,year]+
        xDmFrac[enduse,NaturalGas,tech,ec,area,year]*Target[year]
    xDmFrac[enduse,NaturalGas,tech,ec,area,year] = 
      xDmFrac[enduse,NaturalGas,tech,ec,area,year]*(1-Target[year])

    DmFracMin[enduse,Biomass,tech,ec,area,year] = 
      xDmFrac[enduse,Biomass,tech,ec,area,year]
    DmFracMin[enduse,NaturalGas,tech,ec,area,year] = 
      xDmFrac[enduse,NaturalGas,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
end

 function DividePolicyCosts(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse,Tech,Years) = data
  (; DInvExo,PolicyCost,xInflation) = data

  for year in Years
    PolicyCost[year] = 0
  end
  
  areas = Select(Area,"QC")
  enduses = Select(Enduse,"Heat")
  years = Yr(2022)
  ecs = Select(EC,"Cement")
  techs = Select(Tech,"Coal")
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    PolicyCost[year] = 46.75
    #DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]*PolicyCost[year] #works
    #DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[year] #does not work
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+
      (PolicyCost[year])/xInflation[area,year]/2
  end
  
  ecs = Select(EC,"Food")
  techs = Select(Tech,"Gas")
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    PolicyCost[year] = 46.75
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+
      (PolicyCost[year])/xInflation[area,year]/2
  end
  
   WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function IndPolicy(db)
  data = IControl(; db)
  SetFuelSwitchingTargets(db)
  DividePolicyCosts(db)
end

function PolicyControl(db)
  @info "Ind_Biomass_QC.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
