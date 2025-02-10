#
# Ind_NLOC_Eff.jl - Simulates CleanBC investments into decarbonizing SweetGasProcessing.
# Reductions are assumed to non-incremental, tuned to the base case. Reductions come from energy efficiency.
# Aligned to numbers that have been received from the BC government or pulled from the BC government website.
#

using SmallModel

module Ind_NLOC_Eff

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
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] device Exogenous Investments (M$/Yr)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)

  # Scratch Variables
  AnnualAdjustment::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Adjustment for energy savings rebound
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Total Demand (TBtu/Yr)
  FractionRemovedAnnually::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  ReductionAdditional::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  PolicyCost::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [Year] Policy Cost ($/TBtu)
end

function AllocateReduction(data::IControl,enduses,techs,ec,area,years)
  (; db,Outpt) = data
  (; DmdRef,DmdTotal) = data
  (; DERRef,DERRRExo) = data
  (; FractionRemovedAnnually) = data
  (; ReductionAdditional,ReductionTotal) = data

  #
  # Total Demands
  #  
  # Statement below from Promula code shouldn't work since we enter procudure after Select Tech(Gas) - Ian 02/04/25
  # techs = Select(Tech,["Coal","Oil","Gas"])
  for year in years
    DmdTotal[ec,area,year] = sum(DmdRef[enduse,tech,ec,area,year] for enduse in enduses, tech in techs)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for year in years
    ReductionAdditional[ec,area,year] = max((ReductionAdditional[ec,area,year] - 
      ReductionTotal[ec,area,year-1]),0.0)
    ReductionTotal[ec,area,year] = ReductionAdditional[ec,area,year] + 
      ReductionTotal[ec,area,year-1]
  end

  #
  #Fraction Removed each Year
  #  
  for year in years
    @finite_math FractionRemovedAnnually[ec,area,year] = ReductionAdditional[ec,area,year] / 
      DmdTotal[ec,area,year]
  end

  #
  #Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, year in years
    DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year]+ 
                                         (DERRef[enduse,tech,ec,area,year]*FractionRemovedAnnually[ec,area,year])
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduse,Enduses,Nation,Tech) = data 
  (; AnnualAdjustment,DInvExo,DmdFrac,DmdRef,DmdTotal,ReductionAdditional,PolicyCost) = data

  #
  # Select Sets for Policy
  #  
  nation = Select(Nation,"CN")
  area = Select(Area,"NL")
  ec = Select(EC,"OtherChemicals")
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2022):Yr(2050))

  ReductionAdditional[ec,area,Yr(2023)] = 6.65
  ReductionAdditional[ec,area,Yr(2024)] = 6.00
  ReductionAdditional[ec,area,Yr(2025)] = 6.00
  ReductionAdditional[ec,area,Yr(2026)] = 6.00
  ReductionAdditional[ec,area,Yr(2027)] = 6.00
  ReductionAdditional[ec,area,Yr(2028)] = 6.00
  ReductionAdditional[ec,area,Yr(2029)] = 5.00
  ReductionAdditional[ec,area,Yr(2030)] = 5.00
  ReductionAdditional[ec,area,Yr(2031)] = 5.00
  ReductionAdditional[ec,area,Yr(2032)] = 4.00
  ReductionAdditional[ec,area,Yr(2033)] = 3.00
  ReductionAdditional[ec,area,Yr(2034)] = 2.00
  ReductionAdditional[ec,area,Yr(2035)] = 1.00
  ReductionAdditional[ec,area,Yr(2036)] = 1.00
  ReductionAdditional[ec,area,Yr(2037)] = 1.00
  ReductionAdditional[ec,area,Yr(2038)] = 1.00
  ReductionAdditional[ec,area,Yr(2039)] = 1.00
  ReductionAdditional[ec,area,Yr(2040)] = 1.00
  ReductionAdditional[ec,area,Yr(2041)] = 1.00
  ReductionAdditional[ec,area,Yr(2042)] = 1.00
  ReductionAdditional[ec,area,Yr(2043)] = 1.00
  ReductionAdditional[ec,area,Yr(2044)] = 1.00
  ReductionAdditional[ec,area,Yr(2045)] = 1.00
  ReductionAdditional[ec,area,Yr(2046)] = 1.00
  ReductionAdditional[ec,area,Yr(2047)] = 1.00
  ReductionAdditional[ec,area,Yr(2048)] = 1.00
  ReductionAdditional[ec,area,Yr(2049)] = 1.00
  ReductionAdditional[ec,area,Yr(2050)] = 1.00

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2023)] = 0.15
  AnnualAdjustment[ec,area,Yr(2024)] = 0.15
  AnnualAdjustment[ec,area,Yr(2025)] = 0.15
  AnnualAdjustment[ec,area,Yr(2026)] = 0.14
  AnnualAdjustment[ec,area,Yr(2027)] = 0.13
  AnnualAdjustment[ec,area,Yr(2028)] = 0.12
  AnnualAdjustment[ec,area,Yr(2029)] = 0.11
  AnnualAdjustment[ec,area,Yr(2030)] = 0.10
  AnnualAdjustment[ec,area,Yr(2031)] = 0.10
  AnnualAdjustment[ec,area,Yr(2032)] = 0.10
  AnnualAdjustment[ec,area,Yr(2033)] = 0.09
  AnnualAdjustment[ec,area,Yr(2034)] = 0.09
  AnnualAdjustment[ec,area,Yr(2035)] = 0.08
  AnnualAdjustment[ec,area,Yr(2036)] = 0.08
  AnnualAdjustment[ec,area,Yr(2037)] = 0.08
  AnnualAdjustment[ec,area,Yr(2038)] = 0.07
  AnnualAdjustment[ec,area,Yr(2039)] = 0.07
  AnnualAdjustment[ec,area,Yr(2040)] = 0.06
  AnnualAdjustment[ec,area,Yr(2041)] = 0.85
  AnnualAdjustment[ec,area,Yr(2042)] = 0.85
  AnnualAdjustment[ec,area,Yr(2043)] = 0.85
  AnnualAdjustment[ec,area,Yr(2044)] = 0.85
  AnnualAdjustment[ec,area,Yr(2045)] = 0.85
  AnnualAdjustment[ec,area,Yr(2046)] = 0.85
  AnnualAdjustment[ec,area,Yr(2047)] = 0.85
  AnnualAdjustment[ec,area,Yr(2048)] = 0.85
  AnnualAdjustment[ec,area,Yr(2049)] = 0.85
  AnnualAdjustment[ec,area,Yr(2050)] = 0.85

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,["LPG","Gas"])
  for year in years
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
  end

  AllocateReduction(data,Enduses,techs,ec,area,years)
  
end

function PolicyControl(db)
  @info "Ind_NLOC_Eff.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
