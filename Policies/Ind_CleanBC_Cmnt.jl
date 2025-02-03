#
# Ind_CleanBC_Cmnt.jl - Programme de biomasse foresti�re r�siduelle (industries et commercial)
#
# Target 124 kt GHG by 2024 in QC; assume commercial amounts are negligible.
# Approach: Use DmFrac to substitute petroleum coke with biomass in cement and natural gas 
# with biomass in Food & Tobacco
# See QC BiomasseProgramme.xlsx
# (RW 06/02/2021)
# Updated fuel switching targets for Ref22 tuning (RST 06Sept2022)
#

using SmallModel

module Ind_CleanBC_Cmnt

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: DB
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

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data    
  (; Area,EC,Enduse) = data 
  (; Fuel,Nation) = data
  (; Tech) = data
  (; DInvExo,DmFracMin) = data
  (; PolicyCost,Target,xDmFrac,xInflation) = data

  #
  # Select Policy Sets (Enduse,Tech,EC)
  #  
  CN = Select(Nation,"CN")
  years = collect(Yr(2022):Yr(2050))
  areas = Select(Area,"BC")
  ecs = Select(EC,"Cement")
  tech = Select(Tech,"Gas")
  enduses = Select(Enduse,"Heat")

  for year in years
    Target[year] = 0.0168
  end

  Biomass = Select(Fuel,"Biomass")
  NaturalGas = Select(Fuel,"NaturalGas")

  for year in years, area in areas, ec in ecs, eu in enduses
    xDmFrac[eu,Biomass,tech,ec,area,year] = 
      xDmFrac[eu,Biomass,tech,ec,area,year] + Target[year]
    xDmFrac[eu,NaturalGas,tech,ec,area,year] = 
      xDmFrac[eu,NaturalGas,tech,ec,area,year] - Target[year]

    DmFracMin[eu,Biomass,tech,ec,area,year] = 
      xDmFrac[eu,Biomass,tech,ec,area,year]
    DmFracMin[eu,NaturalGas,tech,ec,area,year] = 
      xDmFrac[eu,NaturalGas,tech,ec,area,year]
  end

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  
  #
  # Program Costs $M  
  #  
  PolicyCost[Yr(2022)] = 1.32

  enduses = Select(Enduse,"Heat")
  for area in areas, ec in ecs, tech in tech, eu in enduses
    DInvExo[eu,tech,ec,area,Yr(2022)] = DInvExo[eu,tech,ec,area,Yr(2022)]+
      PolicyCost[Yr(2022)]/xInflation[area,Yr(2022)]/2
  end
  
  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Ind_CleanBC_Cmnt.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
