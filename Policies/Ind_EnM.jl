#
# Ind_EnM.jl - Device Retrofit
#
# NRCan Energy Management Program
# Energy impacts are input directly as provided by NRCan.  Note program costs are as provided for
# Ref18 since no new estimates were provided. (RW 06 02 2021)
# Edited by RST 02Aug2022, re-tuning for Ref22
#

using SmallModel

module Ind_EnM

import ...SmallModel: ReadDisk,WriteDisk,Select,Yr
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
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERReductionStart::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Adjustment for energy savings rebound
  CCC::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data,DmdTotal,enduses,techs,ecs,years,areas)
  (; db,Outpt) = data
  (; DERRef) = data
  (; DERRRExo,DmdRef) = data
  (; FractionRemovedAnnually) = data
  (; ReductionAdditional,ReductionTotal) = data


  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for year in years
    ReductionAdditional[year] = max((ReductionAdditional[year] - 
      ReductionTotal[year-1]),0.0)
    ReductionTotal[year] = ReductionAdditional[year] + 
      ReductionTotal[year-1]
  end

  #
  # Fraction Removed each Year
  #  
  for year in years
    @finite_math FractionRemovedAnnually[year] = 
      ReductionAdditional[year]/DmdTotal[year]
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for tech in techs, ec in ecs, area in areas, year in years, enduse in enduses
    DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year] +
      DERRef[enduse,tech,ec,area,year] * FractionRemovedAnnually[year]
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)

end #AllocateReduction

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; EC,ECs,Enduse) = data
  (; Nation,Tech) = data
  (; ANMap,AnnualAdjustment) = data
  (; DInvExo,DmdFrac,DmdRef,DmdTotal) = data
  (; PolicyCost,ReductionAdditional,xInflation) = data

  #
  # Select Sets for Policy
  #
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1.0)
  enduses = Select(Enduse,"Heat")
  Heat = Select(Enduse,"Heat")
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2022):Yr(2050))

  #
  # Read ReductionAdditional
  #
  ReductionAdditional[Yr(2023)] = 15.94
  ReductionAdditional[Yr(2024)] = 31.89
  ReductionAdditional[Yr(2025)] = 47.83
  ReductionAdditional[Yr(2026)] = 63.78
  ReductionAdditional[Yr(2027)] = 79.72
  ReductionAdditional[Yr(2028)] = 86.33
  ReductionAdditional[Yr(2029)] = 93.94
  
  years = collect(Yr(2030):Yr(2050))
  for year in years
    ReductionAdditional[year] = 101.05
  end

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[Yr(2022)] = 1
  AnnualAdjustment[Yr(2023)] = 1.103
  AnnualAdjustment[Yr(2024)] = 1.127
  AnnualAdjustment[Yr(2025)] = 1.182
  AnnualAdjustment[Yr(2026)] = 1.250
  AnnualAdjustment[Yr(2027)] = 1.337
  AnnualAdjustment[Yr(2028)] = 1.385
  AnnualAdjustment[Yr(2029)] = 1.511
  AnnualAdjustment[Yr(2030)] = 1.624
  AnnualAdjustment[Yr(2031)] = 1.764
  AnnualAdjustment[Yr(2032)] = 1.904
  AnnualAdjustment[Yr(2033)] = 2.065
  AnnualAdjustment[Yr(2034)] = 2.283
  AnnualAdjustment[Yr(2035)] = 2.342
  AnnualAdjustment[Yr(2036)] = 2.485
  AnnualAdjustment[Yr(2037)] = 2.649
  AnnualAdjustment[Yr(2038)] = 2.840
  AnnualAdjustment[Yr(2039)] = 2.940
  AnnualAdjustment[Yr(2040)] = 3.060
  AnnualAdjustment[Yr(2041)] = 2.897
  AnnualAdjustment[Yr(2042)] = 3.05
  AnnualAdjustment[Yr(2043)] = 3.189
  AnnualAdjustment[Yr(2044)] = 3.326
  AnnualAdjustment[Yr(2045)] = 3.463
  AnnualAdjustment[Yr(2046)] = 3.597
  AnnualAdjustment[Yr(2047)] = 3.739
  AnnualAdjustment[Yr(2048)] = 3.884
  AnnualAdjustment[Yr(2049)] = 4.028
  AnnualAdjustment[Yr(2050)] = 4.174
  
  tech_e = Select(Tech,!=("Electric"))
  tech_s = Select(Tech,!=("Steam"))
  techs = intersect(tech_e,tech_s)

  #
  # Total Demands
  #  
  for year in years
    DmdTotal[year] = sum(DmdRef[Heat,tech,ec,area,year] for tech in techs,
      ec in ECs, area in areas)
  end

  for year in years
    ReductionAdditional[year] = ReductionAdditional[year]/1.05461*AnnualAdjustment[year]
  end


  AllocateReduction(data,DmdTotal,enduses,techs,ECs,years,areas)

  #
  # Program Costs
  #  
  PolicyCost[Yr(2022)] = 418.192
  PolicyCost[Yr(2023)] = 492.767
  PolicyCost[Yr(2024)] = 573.323
  PolicyCost[Yr(2025)] = 662.153
  PolicyCost[Yr(2026)] = 755.243
  PolicyCost[Yr(2027)] = 812.497
  PolicyCost[Yr(2028)] = 918.6
  PolicyCost[Yr(2029)] = 1040.749
  PolicyCost[Yr(2030)] = 1157.459

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for year in years, area in areas, ec in ECs, tech in techs
    @finite_math DmdFrac[Heat,tech,ec,area,year] = DmdRef[Heat,tech,ec,area,year]/
      DmdTotal[year]

  end
  for year in years, area in areas, ec in ECs, tech in techs
    DInvExo[Heat,tech,ec,area,year] = DInvExo[Heat,tech,ec,area,year]+
      (PolicyCost[year]*DmdFrac[Heat,tech,ec,area,year])/xInflation[area,Yr(2015)]
  end

  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Ind_EnM.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
