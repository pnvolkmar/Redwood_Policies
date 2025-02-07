#
# Ind_LCEF_Pro.jl - Process Retrofit
#
# Quebec's EcoPerformance Program. RW 08/01/2019
# Includes federal bonification from LCEF leadership funds
# GHG/Energy reductions and investment data from 
# TEQ-ClasseurderapportdesGES - ÉcoPerf.xlsx (RW 06/02/2021)
# Updated program costs and tuning adjustment factors (RST 06Sept2022)
#

using SmallModel

module Ind_LCEF_Pro

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
  DEEARef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEEA") # [Enduse,Tech,EC,Area,Year] Average Device Efficiency (Btu/Btu)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  PERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PER") # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Adjustment for energy savings rebound
  CCC::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DDD::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::IControl,enduses,techs,ecs,areas,years)
  (; db,Input,Outpt) = data
  (; Enduse) = data
  (; DmdFrac,DmdRef) = data
  (; DmdTotal,FractionRemovedAnnually,PERRef) = data
  (; PERRRExo) = data
  (; ReductionAdditional,ReductionTotal) = data

  #
  # Total Demands
  #  
  for year in years, area in areas, ec in ecs
    DmdTotal[ec,area,year] = sum(DmdRef[eu,tech,ec,area,year] for tech in techs,eu in enduses)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for year in years, area in areas, ec in ecs
    ReductionAdditional[ec,area,year] = max((ReductionAdditional[ec,area,year] - 
      ReductionTotal[ec,area,year-1]),0.0)
    ReductionTotal[ec,area,year] = ReductionAdditional[ec,area,year] + 
      ReductionTotal[ec,area,year-1]
  end

  #
  # Fraction Energy Removed each Year
  #  
  for year in years, area in areas, ec in ecs
    @finite_math FractionRemovedAnnually[ec,area,year] = ReductionAdditional[ec,area,year] / 
      DmdTotal[ec,area,year]
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    PERRRExo[enduse,tech,ec,area,year] = PERRRExo[enduse,tech,ec,area,year] +
      PERRef[enduse,tech,ec,area,year] * FractionRemovedAnnually[ec,area,year]
  end

  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse,Enduses) = data
  (; Nation,Tech) = data
  (; AnnualAdjustment) = data
  (; DmdFrac,DmdRef,DmdTotal,PInvExo,PolicyCost,ReductionAdditional,xInflation) = data

  @. AnnualAdjustment = 1.0

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share, Read ReductionAdditional(Area,Year)
  #  
  ecs = Select(EC,"OtherMetalMining")
  areas = Select(Area,"ON")

  ReductionAdditional[ecs,areas,Yr(2027)] = 55.72
  ReductionAdditional[ecs,areas,Yr(2028)] = 72.90
  ReductionAdditional[ecs,areas,Yr(2029)] = 124.22
  ReductionAdditional[ecs,areas,Yr(2030)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2031)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2032)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2033)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2034)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2035)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2036)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2037)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2038)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2039)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2040)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2041)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2042)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2043)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2044)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2045)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2046)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2047)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2048)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2049)] = 137.81
  ReductionAdditional[ecs,areas,Yr(2050)] = 137.81

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,areas,Yr(2023)] = 1.119
  AnnualAdjustment[ecs,areas,Yr(2024)] = 1.197
  AnnualAdjustment[ecs,areas,Yr(2025)] = 1.275
  AnnualAdjustment[ecs,areas,Yr(2026)] = 1.353
  AnnualAdjustment[ecs,areas,Yr(2027)] = 1.433
  AnnualAdjustment[ecs,areas,Yr(2028)] = 1.512
  AnnualAdjustment[ecs,areas,Yr(2029)] = 1.591
  AnnualAdjustment[ecs,areas,Yr(2030)] = 1.671
  AnnualAdjustment[ecs,areas,Yr(2031)] = 1.75
  AnnualAdjustment[ecs,areas,Yr(2032)] = 1.83
  AnnualAdjustment[ecs,areas,Yr(2033)] = 1.909
  AnnualAdjustment[ecs,areas,Yr(2034)] = 1.987
  AnnualAdjustment[ecs,areas,Yr(2035)] = 2.066
  AnnualAdjustment[ecs,areas,Yr(2036)] = 2.145
  AnnualAdjustment[ecs,areas,Yr(2037)] = 2.223
  AnnualAdjustment[ecs,areas,Yr(2038)] = 2.301
  AnnualAdjustment[ecs,areas,Yr(2039)] = 2.379
  AnnualAdjustment[ecs,areas,Yr(2040)] = 2.456
  AnnualAdjustment[ecs,areas,Yr(2041)] = 2.534
  AnnualAdjustment[ecs,areas,Yr(2042)] = 2.61
  AnnualAdjustment[ecs,areas,Yr(2043)] = 2.687
  AnnualAdjustment[ecs,areas,Yr(2044)] = 2.765
  AnnualAdjustment[ecs,areas,Yr(2045)] = 2.84
  AnnualAdjustment[ecs,areas,Yr(2046)] = 2.917
  AnnualAdjustment[ecs,areas,Yr(2047)] = 2.994
  AnnualAdjustment[ecs,areas,Yr(2048)] = 3.069
  AnnualAdjustment[ecs,areas,Yr(2049)] = 3.146
  AnnualAdjustment[ecs,areas,Yr(2050)] = 3.221

  years = collect(Yr(2023):Yr(2050))
  techs = Select(Tech,"Electric")
  for year in years, area in areas, ec in ecs
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1054.61*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,techs,ecs,areas,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  #
  PolicyCost[ecs,areas,Yr(2023)] = 81
  PolicyCost[ecs,areas,Yr(2024)] = 163
  PolicyCost[ecs,areas,Yr(2025)] = 204
  PolicyCost[ecs,areas,Yr(2026)] = 220
  PolicyCost[ecs,areas,Yr(2027)] = 247
  PolicyCost[ecs,areas,Yr(2028)] = 281

  years = collect(Yr(2023):Yr(2026))
  for year in years, area in areas
    PolicyCost[ecs,area,year] = PolicyCost[ecs,area,year]/xInflation[area,year]
  end
  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs
    for eu in Enduses
      @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
        DmdTotal[ec,area,year]
    end
    
    Heat = Select(Enduse,"Heat")
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      sum(PolicyCost[ec,area,year]*DmdFrac[eu,tech,ec,area,year] for eu in Enduses)
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)

  @. AnnualAdjustment = 1.0

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share, Read ReductionAdditional(Area,Year)
  #  
  ecs = Select(EC,"Cement")
  areas = Select(Area,"QC")

  ReductionAdditional[ecs,areas,Yr(2026)] = 406
  ReductionAdditional[ecs,areas,Yr(2027)] = 2023
  ReductionAdditional[ecs,areas,Yr(2028)] = 2119
  ReductionAdditional[ecs,areas,Yr(2029)] = 2293
  ReductionAdditional[ecs,areas,Yr(2030)] = 2546
  ReductionAdditional[ecs,areas,Yr(2031)] = 2571
  ReductionAdditional[ecs,areas,Yr(2032)] = 2571
  ReductionAdditional[ecs,areas,Yr(2033)] = 2583
  ReductionAdditional[ecs,areas,Yr(2034)] = 2583
  ReductionAdditional[ecs,areas,Yr(2035)] = 2583
  ReductionAdditional[ecs,areas,Yr(2036)] = 2583
  ReductionAdditional[ecs,areas,Yr(2037)] = 2583
  ReductionAdditional[ecs,areas,Yr(2038)] = 2583
  ReductionAdditional[ecs,areas,Yr(2039)] = 2583
  ReductionAdditional[ecs,areas,Yr(2040)] = 2583
  ReductionAdditional[ecs,areas,Yr(2041)] = 2583
  ReductionAdditional[ecs,areas,Yr(2042)] = 2583
  ReductionAdditional[ecs,areas,Yr(2043)] = 2583
  ReductionAdditional[ecs,areas,Yr(2044)] = 2583
  ReductionAdditional[ecs,areas,Yr(2045)] = 2583
  ReductionAdditional[ecs,areas,Yr(2046)] = 2583
  ReductionAdditional[ecs,areas,Yr(2047)] = 2583
  ReductionAdditional[ecs,areas,Yr(2048)] = 2583
  ReductionAdditional[ecs,areas,Yr(2049)] = 2583
  ReductionAdditional[ecs,areas,Yr(2050)] = 2583

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,areas,Yr(2023)] = 1.219
  AnnualAdjustment[ecs,areas,Yr(2024)] = 1.797
  AnnualAdjustment[ecs,areas,Yr(2025)] = 2.075
  AnnualAdjustment[ecs,areas,Yr(2026)] = 2.253
  AnnualAdjustment[ecs,areas,Yr(2027)] = 4.333
  AnnualAdjustment[ecs,areas,Yr(2028)] = 4.412
  AnnualAdjustment[ecs,areas,Yr(2029)] = 4.591
  AnnualAdjustment[ecs,areas,Yr(2030)] = 4.671
  AnnualAdjustment[ecs,areas,Yr(2031)] = 4.700
  AnnualAdjustment[ecs,areas,Yr(2032)] = 4.750
  AnnualAdjustment[ecs,areas,Yr(2033)] = 4.800
  AnnualAdjustment[ecs,areas,Yr(2034)] = 4.850
  AnnualAdjustment[ecs,areas,Yr(2035)] = 4.900
  AnnualAdjustment[ecs,areas,Yr(2036)] = 4.950
  AnnualAdjustment[ecs,areas,Yr(2037)] = 4.000
  AnnualAdjustment[ecs,areas,Yr(2038)] = 4.100
  AnnualAdjustment[ecs,areas,Yr(2039)] = 4.150
  AnnualAdjustment[ecs,areas,Yr(2040)] = 4.200
  AnnualAdjustment[ecs,areas,Yr(2041)] = 3.534
  AnnualAdjustment[ecs,areas,Yr(2042)] = 3.61
  AnnualAdjustment[ecs,areas,Yr(2043)] = 3.687
  AnnualAdjustment[ecs,areas,Yr(2044)] = 3.765
  AnnualAdjustment[ecs,areas,Yr(2045)] = 3.84
  AnnualAdjustment[ecs,areas,Yr(2046)] = 3.917
  AnnualAdjustment[ecs,areas,Yr(2047)] = 3.994
  AnnualAdjustment[ecs,areas,Yr(2048)] = 3.069
  AnnualAdjustment[ecs,areas,Yr(2049)] = 4.146
  AnnualAdjustment[ecs,areas,Yr(2050)] = 4.221

  years = collect(Yr(2023):Yr(2050))
  techs = Select(Tech,"Gas")
  for year in years, area in areas, ec in ecs
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1054.61*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,techs,ecs,areas,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  #
  PolicyCost[ecs,areas,Yr(2023)] = 81
  PolicyCost[ecs,areas,Yr(2024)] = 163
  PolicyCost[ecs,areas,Yr(2025)] = 204
  PolicyCost[ecs,areas,Yr(2026)] = 220
  PolicyCost[ecs,areas,Yr(2027)] = 247
  PolicyCost[ecs,areas,Yr(2028)] = 281

  years = Yr(2026)
  for year in years, area in areas
    PolicyCost[ecs,area,year] = PolicyCost[ecs,area,year]/xInflation[area,year]
  end
  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs
    for eu in Enduses
      @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
        DmdTotal[ec,area,year]
    end
    
    Heat = Select(Enduse,"Heat")
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      sum(PolicyCost[ec,area,year]*DmdFrac[eu,tech,ec,area,year] for eu in Enduses)
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)

  @. AnnualAdjustment = 1.0
  @. ReductionAdditional = 0.0

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share, Read ReductionAdditional(Area,Year)
  #  
  ecs = Select(EC,"Cement")
  areas = Select(Area,"QC")

  ReductionAdditional[ecs,areas,Yr(2026)] = 20.48
  ReductionAdditional[ecs,areas,Yr(2027)] = 66.80
  ReductionAdditional[ecs,areas,Yr(2028)] = 66.19
  ReductionAdditional[ecs,areas,Yr(2029)] = 63.74
  ReductionAdditional[ecs,areas,Yr(2030)] = 56.90
  ReductionAdditional[ecs,areas,Yr(2031)] = 58.70
  ReductionAdditional[ecs,areas,Yr(2032)] = 59.10
  ReductionAdditional[ecs,areas,Yr(2033)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2034)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2035)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2036)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2037)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2038)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2039)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2040)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2041)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2042)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2043)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2044)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2045)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2046)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2047)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2048)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2049)] = 55.09
  ReductionAdditional[ecs,areas,Yr(2050)] = 55.09

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,areas,Yr(2023)] = 1.119
  AnnualAdjustment[ecs,areas,Yr(2024)] = 1.197
  AnnualAdjustment[ecs,areas,Yr(2025)] = 1.275
  AnnualAdjustment[ecs,areas,Yr(2026)] = 1.353
  AnnualAdjustment[ecs,areas,Yr(2027)] = 1.433
  AnnualAdjustment[ecs,areas,Yr(2028)] = 1.512
  AnnualAdjustment[ecs,areas,Yr(2029)] = 1.591
  AnnualAdjustment[ecs,areas,Yr(2030)] = 1.671
  AnnualAdjustment[ecs,areas,Yr(2031)] = 1.75
  AnnualAdjustment[ecs,areas,Yr(2032)] = 1.83
  AnnualAdjustment[ecs,areas,Yr(2033)] = 1.909
  AnnualAdjustment[ecs,areas,Yr(2034)] = 1.987
  AnnualAdjustment[ecs,areas,Yr(2035)] = 2.066
  AnnualAdjustment[ecs,areas,Yr(2036)] = 2.145
  AnnualAdjustment[ecs,areas,Yr(2037)] = 2.223
  AnnualAdjustment[ecs,areas,Yr(2038)] = 2.301
  AnnualAdjustment[ecs,areas,Yr(2039)] = 2.379
  AnnualAdjustment[ecs,areas,Yr(2040)] = 2.456
  AnnualAdjustment[ecs,areas,Yr(2041)] = 2.534
  AnnualAdjustment[ecs,areas,Yr(2042)] = 2.61
  AnnualAdjustment[ecs,areas,Yr(2043)] = 2.687
  AnnualAdjustment[ecs,areas,Yr(2044)] = 2.765
  AnnualAdjustment[ecs,areas,Yr(2045)] = 2.84
  AnnualAdjustment[ecs,areas,Yr(2046)] = 2.917
  AnnualAdjustment[ecs,areas,Yr(2047)] = 2.994
  AnnualAdjustment[ecs,areas,Yr(2048)] = 3.069
  AnnualAdjustment[ecs,areas,Yr(2049)] = 3.146
  AnnualAdjustment[ecs,areas,Yr(2050)] = 3.221

  years = collect(Yr(2023):Yr(2050))
  techs = Select(Tech,"Electric")
  for year in years, area in areas, ec in ecs
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1054.61*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,techs,ecs,areas,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  #
  PolicyCost[ecs,areas,Yr(2026)] = 0

  years = Yr(2026)
  for year in years, area in areas
    PolicyCost[ecs,area,year] = PolicyCost[ecs,area,year]/xInflation[area,year]
  end
  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs
    for eu in Enduses
      @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
        DmdTotal[ec,area,year]
    end
    
    Heat = Select(Enduse,"Heat")
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      sum(PolicyCost[ec,area,year]*DmdFrac[eu,tech,ec,area,year] for eu in Enduses)
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "Ind_LCEF_Pro.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
