#
# Ind_AB_Cement.jl - Simulates CleanBC investments into decarbonizing the cement sector.
# Typically aligned to the base case, so emissions reductions are assumed to be non-incremental.
# Biomass is substituted for natural gas in the BC cement sector. Aligned to expected emissions reductions from
# British Columbia.
#

using SmallModel

module Ind_AB_Cement

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
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Fraction)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
end

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data    
  (; Area,EC,Enduse,Fuel,Nation,Tech) = data 
  (; DInvExo,DmFracMin,DmFracMax) = data
  (; PolicyCost,xDmFrac,xInflation) = data

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"Cement")
  area = Select(Area,"AB")
  tech = Select(Tech,"Gas")

  #
  # Set the demand fraction for biomass in each based on what
  # would be approximately needed to achieve the emissions reductions
  # calculated or expected from the project
  #
  fuel = Select(Fuel,"NaturalGas")
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2023)]=0.875
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2024)]=0.767
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2025)]=0.657
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2026)]=0.604
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2027)]=0.549
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2028)]=0.492
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2029)]=0.434
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2030)]=0.374
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2031)]=0.317
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2032)]=0.282
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2033)]=0.269
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2034)]=0.344
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2035)]=0.351
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2036)]=0.359
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2037)]=0.367
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2038)]=0.375
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2039)]=0.384
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2040)]=0.391

  fuel = Select(Fuel,"Biomass")
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2023)]=0.124
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2024)]=0.232
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2025)]=0.342
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2026)]=0.400
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2027)]=0.450
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2028)]=0.507
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2029)]=0.565
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2030)]=0.625
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2031)]=0.682
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2032)]=0.712
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2033)]=0.730
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2034)]=0.655
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2035)]=0.648
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2036)]=0.640
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2037)]=0.632
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2038)]=0.624
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2039)]=0.615
  xDmFrac[enduse,fuel,tech,ec,area,Yr(2040)]=0.608

  # Now ensure that the biomass and natural gas price demand fractions
  # do not fall below what has been previously specified in this txt
  #
  # Assuming policy continues through 2050 - Ian
  #
  years = collect(Yr(2024):Yr(2040))
  for year in years
    DmFracMin[enduse,fuel,tech,ec,area,year] = xDmFrac[enduse,fuel,tech,ec,area,year]
  end
  years = collect(Yr(2041):Yr(2050))
  for year in years
    DmFracMin[enduse,fuel,tech,ec,area,year] = DmFracMin[enduse,fuel,tech,ec,area,year-1]
  end

  fuel = Select(Fuel,"NaturalGas")
  for year in years
    DmFracMax[enduse,fuel,tech,ec,area,year] = xDmFrac[enduse,fuel,tech,ec,area,year]
  end
  years = collect(Yr(2041):Yr(2050))
  for year in years
    #TODOJulia - Right side should probably have 'year-1'. Keeping Promula bug for now
    DmFracMax[enduse,fuel,tech,ec,area,year] = DmFracMax[enduse,fuel,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  
  #
  # Program Costs $M  
  #  
  PolicyCost[Yr(2024)] = 74.20
  DInvExo[enduse,tech,ec,area,Yr(2024)] = DInvExo[enduse,tech,ec,area,Yr(2024)]+
      PolicyCost[Yr(2024)]/xInflation[area,Yr(2024)]/2
  WriteDisk(db,"$Input/DInvExo",DInvExo)

end

function PolicyControl(db)
  @info "Ind_AB_Cement.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
