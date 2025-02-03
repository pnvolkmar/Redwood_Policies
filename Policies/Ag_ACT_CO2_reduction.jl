#
# Ag_ACT_CO2_reduction.jl
#
# Agricultural Clean Tech:
# green energy and energy efficiency (e.g., more efficient grain dryers and solar panels), 
# precision agriculture, (e.g., methane reduction technologies, anaerobic digestion of manure), 
# low carbon energy/fuel systems (e.g., infrastructure to allow barn heating fully with wood waste biomass, triple green
# biomass grain drying using rye ergot waste from rye grain processing, new biomass
# boilers that will convert biomass to heat for the greenhouses).
#
# Energy impacts are are calculated based on CO2 reduction estimates provided by AAFC.
# No program costs are included.
# written Oct 20th, 2023 by Bryn Parsons

using SmallModel

module Ag_ACT_CO2_reduction

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
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # Map between Area and Nation [Area,Nation]
  DEEARef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEEA") # [Enduse,Tech,EC,Area,Year] Average Device Efficiency (Btu/Btu)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)

  # Scratch Variables
  AnnualAdjustment::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Adjustment for energy savings rebound
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  ReductionAdditional::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::IControl,enduses,techs,ecs,areas,years)
  (; db,Outpt) = data
  (; DmdRef,DmdTotal) = data
  (; DERRef,DERRRExo) = data
  (; FractionRemovedAnnually) = data
  (; ReductionAdditional,ReductionTotal) = data

  KJBtu = 1.054615

  #
  # Total Demands
  #  
  for ec in ecs, year in years
    DmdTotal[ec,year] = 
      sum(DmdRef[enduse,tech,ec,area,year] for enduse in enduses,tech in techs,area in areas)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for ec in ecs, year in years
    ReductionAdditional[ec,year] = max((ReductionAdditional[ec,year] - 
      ReductionTotal[ec,year-1]),0.0)
    ReductionTotal[ec,year] = ReductionAdditional[ec,year] + 
      ReductionTotal[ec,year-1]
  end

  #
  #Fraction Removed each Year
  #  
  for ec in ecs, year in years
    @finite_math FractionRemovedAnnually[ec,year] = ReductionAdditional[ec,year] / 
      DmdTotal[ec,year]
  end

  #
  #Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas, year in years
    DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year] + 
      DERRef[enduse,tech,ec,area,year] * FractionRemovedAnnually[ec,year]
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse,Nation,Tech) = data 
  (; ANMap,AnnualAdjustment,DmdFrac,DmdRef,DmdTotal,ReductionAdditional) = data

  KJBtu = 1.054615

  #
  # Select Sets for Policy
  #  
  nation = Select(Nation,"CN")
  areas = findall(ANMap[:,nation] .== 1.0)
  years = collect(Yr(2022):Yr(2050))
  ecs = Select(EC,"OnFarmFuelUse")
  enduses = Select(Enduse,"Heat")

  #
  # LPG portion
  #  
  techs = Select(Tech,"LPG")

  ReductionAdditional[ecs,Yr(2022)] = 0.600127068
  ReductionAdditional[ecs,Yr(2023)] = 1.200254137
  ReductionAdditional[ecs,Yr(2024)] = 1.800381205
  ReductionAdditional[ecs,Yr(2025)] = 2.400508274
  ReductionAdditional[ecs,Yr(2026)] = 3.000635342
  ReductionAdditional[ecs,Yr(2027)] = 3.600762411
  ReductionAdditional[ecs,Yr(2028)] = 4.200889479
  ReductionAdditional[ecs,Yr(2029)] = 4.801016548
  ReductionAdditional[ecs,Yr(2030)] = 5.401143616
  ReductionAdditional[ecs,Yr(2031)] = 5.401143616
  ReductionAdditional[ecs,Yr(2032)] = 5.401143616
  ReductionAdditional[ecs,Yr(2033)] = 5.401143616
  ReductionAdditional[ecs,Yr(2034)] = 5.401143616
  ReductionAdditional[ecs,Yr(2035)] = 5.401143616
  ReductionAdditional[ecs,Yr(2036)] = 5.401143616
  ReductionAdditional[ecs,Yr(2037)] = 5.401143616
  ReductionAdditional[ecs,Yr(2038)] = 5.401143616
  ReductionAdditional[ecs,Yr(2039)] = 5.401143616
  ReductionAdditional[ecs,Yr(2040)] = 5.401143616
  ReductionAdditional[ecs,Yr(2041)] = 5.401143616
  ReductionAdditional[ecs,Yr(2042)] = 5.401143616
  ReductionAdditional[ecs,Yr(2043)] = 5.401143616
  ReductionAdditional[ecs,Yr(2044)] = 5.401143616
  ReductionAdditional[ecs,Yr(2045)] = 5.401143616
  ReductionAdditional[ecs,Yr(2046)] = 5.401143616
  ReductionAdditional[ecs,Yr(2047)] = 5.401143616
  ReductionAdditional[ecs,Yr(2048)] = 5.401143616
  ReductionAdditional[ecs,Yr(2049)] = 5.401143616
  ReductionAdditional[ecs,Yr(2050)] = 5.401143616

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,Yr(2022)] = 1
  AnnualAdjustment[ecs,Yr(2023)] = 1.309
  AnnualAdjustment[ecs,Yr(2024)] = 1.501
  AnnualAdjustment[ecs,Yr(2025)] = 1.696
  AnnualAdjustment[ecs,Yr(2026)] = 1.9
  AnnualAdjustment[ecs,Yr(2027)] = 2.161
  AnnualAdjustment[ecs,Yr(2028)] = 2.515
  AnnualAdjustment[ecs,Yr(2029)] = 2.893
  AnnualAdjustment[ecs,Yr(2030)] = 3.232
  AnnualAdjustment[ecs,Yr(2031)] = 3.652
  AnnualAdjustment[ecs,Yr(2032)] = 4.072
  AnnualAdjustment[ecs,Yr(2033)] = 4.555
  AnnualAdjustment[ecs,Yr(2034)] = 4.795
  AnnualAdjustment[ecs,Yr(2035)] = 4.909
  AnnualAdjustment[ecs,Yr(2036)] = 5.197
  AnnualAdjustment[ecs,Yr(2037)] = 5.326
  AnnualAdjustment[ecs,Yr(2038)] = 5.59
  AnnualAdjustment[ecs,Yr(2039)] = 5.992
  AnnualAdjustment[ecs,Yr(2040)] = 6.388
  AnnualAdjustment[ecs,Yr(2041)] = 6.691
  AnnualAdjustment[ecs,Yr(2042)] = 7.15
  AnnualAdjustment[ecs,Yr(2043)] = 7.567
  AnnualAdjustment[ecs,Yr(2044)] = 7.978
  AnnualAdjustment[ecs,Yr(2045)] = 8.389
  AnnualAdjustment[ecs,Yr(2046)] = 8.791
  AnnualAdjustment[ecs,Yr(2047)] = 9.217
  AnnualAdjustment[ecs,Yr(2048)] = 9.652
  AnnualAdjustment[ecs,Yr(2049)] = 10.084
  AnnualAdjustment[ecs,Yr(2050)] = 10.522

  #
  # Convert from TJ to TBtu
  #  
  @. ReductionAdditional = ReductionAdditional/KJBtu*AnnualAdjustment

  AllocateReduction(data,enduses,techs,ecs,areas,years)
  
  #
  # Natural Gas portion
  #  
  techs = Select(Tech,"Gas")

  ReductionAdditional[ecs,Yr(2022)] = 0.501188119
  ReductionAdditional[ecs,Yr(2023)] = 1.002376238
  ReductionAdditional[ecs,Yr(2024)] = 1.503564356
  ReductionAdditional[ecs,Yr(2025)] = 2.004752475
  ReductionAdditional[ecs,Yr(2026)] = 2.505940594
  ReductionAdditional[ecs,Yr(2027)] = 3.007128713
  ReductionAdditional[ecs,Yr(2028)] = 3.508316832
  ReductionAdditional[ecs,Yr(2029)] = 4.00950495
  ReductionAdditional[ecs,Yr(2030)] = 4.510693069
  ReductionAdditional[ecs,Yr(2031)] = 4.510693069
  ReductionAdditional[ecs,Yr(2032)] = 4.510693069
  ReductionAdditional[ecs,Yr(2033)] = 4.510693069
  ReductionAdditional[ecs,Yr(2034)] = 4.510693069
  ReductionAdditional[ecs,Yr(2035)] = 4.510693069
  ReductionAdditional[ecs,Yr(2036)] = 4.510693069
  ReductionAdditional[ecs,Yr(2037)] = 4.510693069
  ReductionAdditional[ecs,Yr(2038)] = 4.510693069
  ReductionAdditional[ecs,Yr(2039)] = 4.510693069
  ReductionAdditional[ecs,Yr(2040)] = 4.510693069
  ReductionAdditional[ecs,Yr(2041)] = 4.510693069
  ReductionAdditional[ecs,Yr(2042)] = 4.510693069
  ReductionAdditional[ecs,Yr(2043)] = 4.510693069
  ReductionAdditional[ecs,Yr(2044)] = 4.510693069
  ReductionAdditional[ecs,Yr(2045)] = 4.510693069
  ReductionAdditional[ecs,Yr(2046)] = 4.510693069
  ReductionAdditional[ecs,Yr(2047)] = 4.510693069
  ReductionAdditional[ecs,Yr(2048)] = 4.510693069
  ReductionAdditional[ecs,Yr(2049)] = 4.510693069
  ReductionAdditional[ecs,Yr(2050)] = 4.510693069

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,Yr(2022)] = 1
  AnnualAdjustment[ecs,Yr(2023)] = 1.309
  AnnualAdjustment[ecs,Yr(2024)] = 1.501
  AnnualAdjustment[ecs,Yr(2025)] = 1.696
  AnnualAdjustment[ecs,Yr(2026)] = 1.9
  AnnualAdjustment[ecs,Yr(2027)] = 2.161
  AnnualAdjustment[ecs,Yr(2028)] = 2.515
  AnnualAdjustment[ecs,Yr(2029)] = 2.893
  AnnualAdjustment[ecs,Yr(2030)] = 3.232
  AnnualAdjustment[ecs,Yr(2031)] = 3.652
  AnnualAdjustment[ecs,Yr(2032)] = 4.072
  AnnualAdjustment[ecs,Yr(2033)] = 4.555
  AnnualAdjustment[ecs,Yr(2034)] = 4.795
  AnnualAdjustment[ecs,Yr(2035)] = 4.909
  AnnualAdjustment[ecs,Yr(2036)] = 5.197
  AnnualAdjustment[ecs,Yr(2037)] = 5.326
  AnnualAdjustment[ecs,Yr(2038)] = 5.59
  AnnualAdjustment[ecs,Yr(2039)] = 5.992
  AnnualAdjustment[ecs,Yr(2040)] = 6.388
  AnnualAdjustment[ecs,Yr(2041)] = 6.691
  AnnualAdjustment[ecs,Yr(2042)] = 7.15
  AnnualAdjustment[ecs,Yr(2043)] = 7.567
  AnnualAdjustment[ecs,Yr(2044)] = 7.978
  AnnualAdjustment[ecs,Yr(2045)] = 8.389
  AnnualAdjustment[ecs,Yr(2046)] = 8.791
  AnnualAdjustment[ecs,Yr(2047)] = 9.217
  AnnualAdjustment[ecs,Yr(2048)] = 9.652
  AnnualAdjustment[ecs,Yr(2049)] = 10.084
  AnnualAdjustment[ecs,Yr(2050)] = 10.522

  #
  # Convert from TJ to TBtu
  #  
  @. ReductionAdditional = ReductionAdditional/KJBtu*AnnualAdjustment

  AllocateReduction(data,enduses,techs,ecs,areas,years)

end

function PolicyControl(db)
  @info "Ag_ACT_CO2_reduction.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
