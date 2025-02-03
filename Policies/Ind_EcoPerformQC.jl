#
# Ind_EcoPerformQC.jl - Process Retrofit
#
# Quebec's EcoPerformance Program. RW 08/01/2019
# Includes federal bonification from LCEF leadership funds
# GHG/Energy reductions and investment data from 
# TEQ-ClasseurderapportdesGES - ÉcoPerf.xlsx (RW 06/02/2021)
# Updated program costs and tuning adjustment factors (RST 06Sept2022)
#

using SmallModel

module Ind_EcoPerformQC

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
  AnnualAdjustment::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Adjustment for energy savings rebound
  CCC::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DDD::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::IControl,enduses,techs,ecs,areas,years)
  (; db,Input,Outpt) = data
  (; Enduse) = data
  (; DmdFrac,DmdRef) = data
  (; DmdTotal,FractionRemovedAnnually,PERRef) = data
  (; PERRRExo,PInvExo) = data
  (; PolicyCost,ReductionAdditional,ReductionTotal) = data

  #
  # Total Demands
  #  
  for year in years, area in areas
    DmdTotal[area,year] = 
      sum(DmdRef[eu,tech,ec,area,year] for ec in ecs,tech in techs,eu in enduses)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for year in years, area in areas
    ReductionAdditional[area,year] = max((ReductionAdditional[area,year] - 
      ReductionTotal[area,year-1]),0.0)
    ReductionTotal[area,year] = ReductionAdditional[area,year] + 
      ReductionTotal[area,year-1]
  end

  #
  # Fraction Energy Removed each Year
  #  
  for year in years, area in areas
    @finite_math FractionRemovedAnnually[area,year] = ReductionAdditional[area,year] / 
      DmdTotal[area,year]
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for year in years, area in areas, ec in ecs, tech in techs, enduse in enduses
    PERRRExo[enduse,tech,ec,area,year] = PERRRExo[enduse,tech,ec,area,year] +
      PERRef[enduse,tech,ec,area,year] * FractionRemovedAnnually[area,year]
  end

  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs
    for eu in enduses
      @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
        DmdTotal[area,year]
    end
    
    Heat = Select(Enduse,"Heat")
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      sum(PolicyCost[area,year]*DmdFrac[eu,tech,ec,area,year] for eu in enduses)
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function IndPolicy(db)
  data = IControl(; db)
  (; Area,EC,Enduses) = data
  (; Nation,Tech) = data
  (; AnnualAdjustment) = data
  (; PolicyCost,ReductionAdditional,xInflation) = data

  @. AnnualAdjustment = 1.0

  QC = Select(Area,"QC")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share, Read ReductionAdditional(Area,Year)
  #  
  ReductionAdditional[QC,Yr(2022)] = 1335
  ReductionAdditional[QC,Yr(2023)] = 1335
  ReductionAdditional[QC,Yr(2024)] = 1335
  ReductionAdditional[QC,Yr(2025)] = 1335
  ReductionAdditional[QC,Yr(2026)] = 1335
  ReductionAdditional[QC,Yr(2027)] = 1335
  ReductionAdditional[QC,Yr(2028)] = 1335
  ReductionAdditional[QC,Yr(2029)] = 1335
  ReductionAdditional[QC,Yr(2030)] = 1335
  ReductionAdditional[QC,Yr(2031)] = 1335
  ReductionAdditional[QC,Yr(2032)] = 1335
  ReductionAdditional[QC,Yr(2033)] = 1335
  ReductionAdditional[QC,Yr(2034)] = 1335
  ReductionAdditional[QC,Yr(2035)] = 1335
  ReductionAdditional[QC,Yr(2036)] = 1335
  ReductionAdditional[QC,Yr(2037)] = 1335
  ReductionAdditional[QC,Yr(2038)] = 1335
  ReductionAdditional[QC,Yr(2039)] = 1335
  ReductionAdditional[QC,Yr(2040)] = 1335
  ReductionAdditional[QC,Yr(2041)] = 1335
  ReductionAdditional[QC,Yr(2042)] = 1335
  ReductionAdditional[QC,Yr(2043)] = 1335
  ReductionAdditional[QC,Yr(2044)] = 1335
  ReductionAdditional[QC,Yr(2045)] = 1335
  ReductionAdditional[QC,Yr(2046)] = 1335
  ReductionAdditional[QC,Yr(2047)] = 1335
  ReductionAdditional[QC,Yr(2048)] = 1335
  ReductionAdditional[QC,Yr(2049)] = 1335
  ReductionAdditional[QC,Yr(2050)] = 1335

  #
  # Select Sets for Policy
  #  
  CN = Select(Nation,"CN")
  areas = Select(Area,"QC")
  ecs = Select(EC,!=("OnFarmFuelUse"))
  techs = Select(Tech,["Coal","Oil"])

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[QC,Yr(2022)] = 1.0
  AnnualAdjustment[QC,Yr(2023)] = 1.119
  AnnualAdjustment[QC,Yr(2024)] = 1.197
  AnnualAdjustment[QC,Yr(2025)] = 1.275
  AnnualAdjustment[QC,Yr(2026)] = 1.353
  AnnualAdjustment[QC,Yr(2027)] = 1.433
  AnnualAdjustment[QC,Yr(2028)] = 1.512
  AnnualAdjustment[QC,Yr(2029)] = 1.591
  AnnualAdjustment[QC,Yr(2030)] = 1.671
  AnnualAdjustment[QC,Yr(2031)] = 1.75
  AnnualAdjustment[QC,Yr(2032)] = 1.83
  AnnualAdjustment[QC,Yr(2033)] = 1.909
  AnnualAdjustment[QC,Yr(2034)] = 1.987
  AnnualAdjustment[QC,Yr(2035)] = 2.066
  AnnualAdjustment[QC,Yr(2036)] = 2.145
  AnnualAdjustment[QC,Yr(2037)] = 2.223
  AnnualAdjustment[QC,Yr(2038)] = 2.301
  AnnualAdjustment[QC,Yr(2039)] = 2.379
  AnnualAdjustment[QC,Yr(2040)] = 2.456
  AnnualAdjustment[QC,Yr(2041)] = 2.534
  AnnualAdjustment[QC,Yr(2042)] = 2.61
  AnnualAdjustment[QC,Yr(2043)] = 2.687
  AnnualAdjustment[QC,Yr(2044)] = 2.765
  AnnualAdjustment[QC,Yr(2045)] = 2.84
  AnnualAdjustment[QC,Yr(2046)] = 2.917
  AnnualAdjustment[QC,Yr(2047)] = 2.994
  AnnualAdjustment[QC,Yr(2048)] = 3.069
  AnnualAdjustment[QC,Yr(2049)] = 3.146
  AnnualAdjustment[QC,Yr(2050)] = 3.221

  years = collect(Yr(2022):Yr(2050))
  for year in years, area in areas
    ReductionAdditional[area,year] = ReductionAdditional[area,year]/
      1054.61*AnnualAdjustment[area,year]
  end
  
  AllocateReduction(data,Enduses,techs,ecs,areas,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  #
  PolicyCost[QC,Yr(2022)] = 145
  PolicyCost[QC,Yr(2023)] = 187
  PolicyCost[QC,Yr(2024)] = 180
  PolicyCost[QC,Yr(2025)] = 163
  PolicyCost[QC,Yr(2026)] = 160

  years = collect(Yr(2022):Yr(2050))
  for year in years, area in areas
    PolicyCost[area,year] = PolicyCost[area,year]/xInflation[area,year]
  end
  
end

function PolicyControl(db)
  @info "Ind_EcoPerformQC.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
