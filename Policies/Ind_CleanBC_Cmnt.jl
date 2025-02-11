#
# Ind_CleanBC_Cmnt.jl. Simulates CleanBC investments into decarbonizing the cement sector.
# Typically aligned to the base case, so emissions reductions are assumed to be non-incremental.
# Biomass is substituted for natural gas in the BC cement sector. Aligned to expected emissions reductions from
# British Columbia.
#

using SmallModel

module Ind_CleanBC_Cmnt

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
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
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] device Exogenous Investments (M$/Yr)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
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
  (; DInvExo,DmFracMin,DmFracMax) = data
  (; PolicyCost,Target,xDmFrac,xInflation) = data
  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #
  area = Select(Area,"BC")
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"Cement") 
  tech = Select(Tech,"Gas")
  NaturalGas = Select(Fuel,"NaturalGas")
  Biomass = Select(Fuel,"Biomass")

  # Natural gas demand fractions
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2023)]=0.864
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2024)]=0.801
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2025)]=0.680
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2026)]=0.686
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2027)]=0.709
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2028)]=0.703
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2029)]=0.706
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2030)]=0.709
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2031)]=0.701
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2032)]=0.704
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2033)]=0.707
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2034)]=0.700
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2035)]=0.713
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2036)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2037)]=0.710
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2038)]=0.714
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2039)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2040)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2041)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2042)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2043)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2044)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2045)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2046)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2047)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2048)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2049)]=0.717
  xDmFrac[enduse,NaturalGas,tech,ec,area,Yr(2050)]=0.717

  # Biomass demand fractions
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2023)]=0.025
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2024)]=0.029
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2025)]=0.129
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2026)]=0.125
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2027)]=0.124
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2028)]=0.122
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2029)]=0.129
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2030)]=0.127
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2031)]=0.116
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2032)]=0.112
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2033)]=0.110
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2034)]=0.117
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2035)]=0.115
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2036)]=0.112
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2037)]=0.119
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2038)]=0.107
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2039)]=0.104
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2040)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2041)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2042)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2043)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2044)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2045)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2046)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2047)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2048)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2049)]=0.101
  xDmFrac[enduse,Biomass,tech,ec,area,Yr(2050)]=0.101

  # Set min/max constraints for 2023-2040
  years = collect(Yr(2023):Yr(2040))
  for year in years
    DmFracMin[enduse,Biomass,tech,ec,area,year] = xDmFrac[enduse,Biomass,tech,ec,area,year]
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = xDmFrac[enduse,NaturalGas,tech,ec,area,year]
  end

  # Set min/max constraints for 2041-2050
  years = collect(Yr(2041):Yr(2050))
  for year in years
    DmFracMin[enduse,Biomass,tech,ec,area,year] = xDmFrac[enduse,Biomass,tech,ec,area,year-1]
    DmFracMin[enduse,NaturalGas,tech,ec,area,year] = xDmFrac[enduse,NaturalGas,tech,ec,area,year-1]
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  
  #
  # Program Costs $M
  #
  enduse = Select(Enduse,"Heat")
  tech = Select(Tech,"Gas")
  ec = Select(EC,"Cement")
  area = Select(Area,"BC")

  PolicyCost[Yr(2025)] = 12.30

  DInvExo[enduse,tech,ec,area,Yr(2025)] = DInvExo[enduse,tech,ec,area,Yr(2025)] + 
  PolicyCost[Yr(2025)]/xInflation[area,Yr(2025)]/2

  WriteDisk(db,"$Input/DInvExo",DInvExo)
  
  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #
  area = Select(Area,"BC")
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"Cement")
  tech = Select(Tech,"Biomass")
  waste = Select(Fuel,"Waste")

  # Set waste demand fractions to 2025 values for future years
  years = collect(Yr(2026):Yr(2050))
  for year in years
    xDmFrac[enduse,waste,tech,ec,area,year] = xDmFrac[enduse,waste,tech,ec,area,Yr(2025)]
  end

  # Set min/max demand fractions for 2026-2040
  years = collect(Yr(2026):Yr(2040))
  for year in years
    DmFracMin[enduse,waste,tech,ec,area,year] = xDmFrac[enduse,waste,tech,ec,area,year]
    DmFracMax[enduse,waste,tech,ec,area,year] = xDmFrac[enduse,waste,tech,ec,area,year]  
  end

  # Set min/max demand fractions for 2041-2050
  years = collect(Yr(2041):Yr(2050))
  for year in years
    DmFracMin[enduse,waste,tech,ec,area,year] = xDmFrac[enduse,waste,tech,ec,area,year-1]
    DmFracMin[enduse,waste,tech,ec,area,year] = xDmFrac[enduse,waste,tech,ec,area,year-1]
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
end

function PolicyControl(db)
  @info "Ind_CleanBC_Cmnt.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
