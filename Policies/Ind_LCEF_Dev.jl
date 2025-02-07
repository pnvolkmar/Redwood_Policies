#
# Ind_LCEF_Dev.jl - Simulates CleanBC investments into decarbonizing SweetGasProcessing.
# Reductions are assumed to non-incremental, tuned to the base case. Reductions come from energy efficiency.
# Aligned to numbers that have been received from the BC government or pulled from the BC government website.
#

using SmallModel

module Ind_LCEF_Dev

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
  (; Tech) = data
  (; DmdRef,DmdTotal) = data
  (; DERRef,DERRRExo) = data
  (; FractionRemovedAnnually) = data
  (; ReductionAdditional,ReductionTotal) = data

  #
  # Total Demands
  #  
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
  (; Area,EC,Enduse,Enduses,Tech) = data 
  (; AnnualAdjustment,DInvExo,DmdFrac,DmdRef,DmdTotal,ReductionAdditional,PolicyCost) = data

  #
  # Select Sets for Policy
  #  

  area = Select(Area,"AB")
  ec = Select(EC,"OtherNonferrous")
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2023):Yr(2050))

  ReductionAdditional[ec,area,Yr(2025)] = 0.15
  ReductionAdditional[ec,area,Yr(2026)] = 0.31
  ReductionAdditional[ec,area,Yr(2027)] = 0.31
  ReductionAdditional[ec,area,Yr(2028)] = 0.32
  ReductionAdditional[ec,area,Yr(2029)] = 0.32
  ReductionAdditional[ec,area,Yr(2030)] = 0.32
  ReductionAdditional[ec,area,Yr(2031)] = 0.32
  ReductionAdditional[ec,area,Yr(2032)] = 0.32
  ReductionAdditional[ec,area,Yr(2033)] = 0.32
  ReductionAdditional[ec,area,Yr(2034)] = 0.32
  ReductionAdditional[ec,area,Yr(2035)] = 0.32
  ReductionAdditional[ec,area,Yr(2036)] = 0.32
  #ReductionAdditional[ec,area,Yr(2037)] =0.32 TODOJulia: missing in Promula file
  ReductionAdditional[ec,area,Yr(2038)] = 0.32
  ReductionAdditional[ec,area,Yr(2039)] = 0.32
  ReductionAdditional[ec,area,Yr(2040)] = 0.32
  ReductionAdditional[ec,area,Yr(2041)] = 0.32
  ReductionAdditional[ec,area,Yr(2042)] = 0.32
  ReductionAdditional[ec,area,Yr(2043)] = 0.32
  ReductionAdditional[ec,area,Yr(2044)] = 0.32
  ReductionAdditional[ec,area,Yr(2045)] = 0.32
  ReductionAdditional[ec,area,Yr(2046)] = 0.32
  ReductionAdditional[ec,area,Yr(2047)] = 0.32
  ReductionAdditional[ec,area,Yr(2048)] = 0.32
  ReductionAdditional[ec,area,Yr(2049)] = 0.32
  ReductionAdditional[ec,area,Yr(2050)] = 0.32

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2023)] = 20.98
  AnnualAdjustment[ec,area,Yr(2024)] = 21.04
  AnnualAdjustment[ec,area,Yr(2025)] = 21.09
  AnnualAdjustment[ec,area,Yr(2026)] = 21.14
  AnnualAdjustment[ec,area,Yr(2027)] = 21.19
  AnnualAdjustment[ec,area,Yr(2028)] = 21.28
  AnnualAdjustment[ec,area,Yr(2029)] = 21.38
  AnnualAdjustment[ec,area,Yr(2030)] = 21.53
  AnnualAdjustment[ec,area,Yr(2031)] = 21.62
  AnnualAdjustment[ec,area,Yr(2032)] = 21.72
  AnnualAdjustment[ec,area,Yr(2033)] = 21.855
  AnnualAdjustment[ec,area,Yr(2034)] = 21.875
  AnnualAdjustment[ec,area,Yr(2035)] = 22.005
  AnnualAdjustment[ec,area,Yr(2036)] = 22.055
  AnnualAdjustment[ec,area,Yr(2037)] = 22.155
  AnnualAdjustment[ec,area,Yr(2038)] = 22.205
  AnnualAdjustment[ec,area,Yr(2039)] = 22.305
  AnnualAdjustment[ec,area,Yr(2040)] = 22.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Gas")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end

  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2025)] = 6.902

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

  #
  # Select Sets for Policy
  #  

  area = Select(Area,"BC")
  ec = Select(EC,"Lumber")
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2027):Yr(2050))

  ReductionAdditional[ec,area,Yr(2027)] = 0.04
  ReductionAdditional[ec,area,Yr(2028)] = 0.05
  ReductionAdditional[ec,area,Yr(2029)] = 0.07
  ReductionAdditional[ec,area,Yr(2030)] = 0.10
  ReductionAdditional[ec,area,Yr(2031)] = 0.10
  ReductionAdditional[ec,area,Yr(2032)] = 0.10
  ReductionAdditional[ec,area,Yr(2033)] = 0.11
  ReductionAdditional[ec,area,Yr(2034)] = 0.11
  ReductionAdditional[ec,area,Yr(2035)] = 0.11
  ReductionAdditional[ec,area,Yr(2036)] = 0.12
  #ReductionAdditional[ec,area,Yr(2037)] =0.12 TODOJulia: missing in Promula file
  ReductionAdditional[ec,area,Yr(2038)] = 0.12
  ReductionAdditional[ec,area,Yr(2039)] = 0.13
  ReductionAdditional[ec,area,Yr(2040)] = 0.14
  ReductionAdditional[ec,area,Yr(2041)] = 0.14
  ReductionAdditional[ec,area,Yr(2042)] = 0.14
  ReductionAdditional[ec,area,Yr(2043)] = 0.14
  ReductionAdditional[ec,area,Yr(2044)] = 0.14
  ReductionAdditional[ec,area,Yr(2045)] = 0.14
  ReductionAdditional[ec,area,Yr(2046)] = 0.14
  ReductionAdditional[ec,area,Yr(2047)] = 0.14
  ReductionAdditional[ec,area,Yr(2048)] = 0.14
  ReductionAdditional[ec,area,Yr(2049)] = 0.14
  ReductionAdditional[ec,area,Yr(2050)] = 0.14

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2023)] = 0.98
  AnnualAdjustment[ec,area,Yr(2024)] = 1.04
  AnnualAdjustment[ec,area,Yr(2025)] = 1.09
  AnnualAdjustment[ec,area,Yr(2026)] = 1.14
  AnnualAdjustment[ec,area,Yr(2027)] = 1.19
  AnnualAdjustment[ec,area,Yr(2028)] = 1.28
  AnnualAdjustment[ec,area,Yr(2029)] = 1.38
  AnnualAdjustment[ec,area,Yr(2030)] = 1.53
  AnnualAdjustment[ec,area,Yr(2031)] = 1.62
  AnnualAdjustment[ec,area,Yr(2032)] = 1.72
  AnnualAdjustment[ec,area,Yr(2033)] = 1.855
  AnnualAdjustment[ec,area,Yr(2034)] = 1.875
  AnnualAdjustment[ec,area,Yr(2035)] = 2.005
  AnnualAdjustment[ec,area,Yr(2036)] = 2.055
  AnnualAdjustment[ec,area,Yr(2037)] = 2.155
  AnnualAdjustment[ec,area,Yr(2038)] = 2.205
  AnnualAdjustment[ec,area,Yr(2039)] = 2.305
  AnnualAdjustment[ec,area,Yr(2040)] = 2.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Gas")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end
  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2027)] = 11.367
  PolicyCost[ec,Yr(2028)] = 11.367
  PolicyCost[ec,Yr(2029)] = 11.367
  PolicyCost[ec,Yr(2030)] = 11.367

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)
  
  #
  # Select Sets for Policy
  #  
  area = Select(Area,"BC")
  ec = Select(EC,"CoalMining")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2025):Yr(2050))

  ReductionAdditional[ec,area,Yr(2025)] = 0.01
  ReductionAdditional[ec,area,Yr(2026)] = 0.02
  ReductionAdditional[ec,area,Yr(2027)] = 0.03
  ReductionAdditional[ec,area,Yr(2028)] = 0.03
  ReductionAdditional[ec,area,Yr(2029)] = 0.03
  ReductionAdditional[ec,area,Yr(2030)] = 0.03
  ReductionAdditional[ec,area,Yr(2031)] = 0.03
  ReductionAdditional[ec,area,Yr(2032)] = 0.03
  ReductionAdditional[ec,area,Yr(2033)] = 0.03
  ReductionAdditional[ec,area,Yr(2034)] = 0.03
  ReductionAdditional[ec,area,Yr(2035)] = 0.03
  ReductionAdditional[ec,area,Yr(2036)] = 0.03
  #ReductionAdditional[ec,area,Yr(2037)] = 0.03 TODOJulia: missing in Promula file
  ReductionAdditional[ec,area,Yr(2038)] = 0.03
  ReductionAdditional[ec,area,Yr(2039)] = 0.03
  ReductionAdditional[ec,area,Yr(2040)] = 0.03
  ReductionAdditional[ec,area,Yr(2041)] = 0.03
  ReductionAdditional[ec,area,Yr(2042)] = 0.03
  ReductionAdditional[ec,area,Yr(2043)] = 0.03
  ReductionAdditional[ec,area,Yr(2044)] = 0.03
  ReductionAdditional[ec,area,Yr(2045)] = 0.03
  ReductionAdditional[ec,area,Yr(2046)] = 0.03
  ReductionAdditional[ec,area,Yr(2047)] = 0.03
  ReductionAdditional[ec,area,Yr(2048)] = 0.03
  ReductionAdditional[ec,area,Yr(2049)] = 0.03
  ReductionAdditional[ec,area,Yr(2050)] = 0.03

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2023)] = 0.98
  AnnualAdjustment[ec,area,Yr(2024)] = 1.04
  AnnualAdjustment[ec,area,Yr(2025)] = 1.09
  AnnualAdjustment[ec,area,Yr(2026)] = 1.14
  AnnualAdjustment[ec,area,Yr(2027)] = 1.19
  AnnualAdjustment[ec,area,Yr(2028)] = 1.28
  AnnualAdjustment[ec,area,Yr(2029)] = 1.38
  AnnualAdjustment[ec,area,Yr(2030)] = 1.53
  AnnualAdjustment[ec,area,Yr(2031)] = 1.62
  AnnualAdjustment[ec,area,Yr(2032)] = 1.72
  AnnualAdjustment[ec,area,Yr(2033)] = 1.855
  AnnualAdjustment[ec,area,Yr(2034)] = 1.875
  AnnualAdjustment[ec,area,Yr(2035)] = 2.005
  AnnualAdjustment[ec,area,Yr(2036)] = 2.055
  AnnualAdjustment[ec,area,Yr(2037)] = 2.155
  AnnualAdjustment[ec,area,Yr(2038)] = 2.205
  AnnualAdjustment[ec,area,Yr(2039)] = 2.305
  AnnualAdjustment[ec,area,Yr(2040)] = 2.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Electric")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end
  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2027)] = 0

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

  #
  # Select Sets for Policy
  #  
  area = Select(Area,"AB")
  ec = Select(EC,"OnFarmFuelUse")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2025):Yr(2050))

  ReductionAdditional[ec,area,Yr(2025)] = 0.12
  ReductionAdditional[ec,area,Yr(2026)] = 0.12
  ReductionAdditional[ec,area,Yr(2027)] = 0.12
  ReductionAdditional[ec,area,Yr(2028)] = 0.12
  ReductionAdditional[ec,area,Yr(2029)] = 0.12
  ReductionAdditional[ec,area,Yr(2030)] = 0.12
  ReductionAdditional[ec,area,Yr(2031)] = 0.12
  ReductionAdditional[ec,area,Yr(2032)] = 0.12
  ReductionAdditional[ec,area,Yr(2033)] = 0.12
  ReductionAdditional[ec,area,Yr(2034)] = 0.12
  ReductionAdditional[ec,area,Yr(2035)] = 0.12
  ReductionAdditional[ec,area,Yr(2036)] = 0.12
  #ReductionAdditional[ec,area,Yr(2037)] = 0.03 TODOJulia: missing in Promula file
  ReductionAdditional[ec,area,Yr(2038)] = 0.12
  ReductionAdditional[ec,area,Yr(2039)] = 0.12
  ReductionAdditional[ec,area,Yr(2040)] = 0.12
  ReductionAdditional[ec,area,Yr(2041)] = 0.12
  ReductionAdditional[ec,area,Yr(2042)] = 0.12
  ReductionAdditional[ec,area,Yr(2043)] = 0.12
  ReductionAdditional[ec,area,Yr(2044)] = 0.12
  ReductionAdditional[ec,area,Yr(2045)] = 0.12
  ReductionAdditional[ec,area,Yr(2046)] = 0.12
  ReductionAdditional[ec,area,Yr(2047)] = 0.12
  ReductionAdditional[ec,area,Yr(2048)] = 0.12
  ReductionAdditional[ec,area,Yr(2049)] = 0.12
  ReductionAdditional[ec,area,Yr(2050)] = 0.12

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2023)] = 0.98
  AnnualAdjustment[ec,area,Yr(2024)] = 1.04
  AnnualAdjustment[ec,area,Yr(2025)] = 1.09
  AnnualAdjustment[ec,area,Yr(2026)] = 1.14
  AnnualAdjustment[ec,area,Yr(2027)] = 1.19
  AnnualAdjustment[ec,area,Yr(2028)] = 1.28
  AnnualAdjustment[ec,area,Yr(2029)] = 1.38
  AnnualAdjustment[ec,area,Yr(2030)] = 1.53
  AnnualAdjustment[ec,area,Yr(2031)] = 1.62
  AnnualAdjustment[ec,area,Yr(2032)] = 1.72
  AnnualAdjustment[ec,area,Yr(2033)] = 1.855
  AnnualAdjustment[ec,area,Yr(2034)] = 1.875
  AnnualAdjustment[ec,area,Yr(2035)] = 2.005
  AnnualAdjustment[ec,area,Yr(2036)] = 2.055
  AnnualAdjustment[ec,area,Yr(2037)] = 2.155
  AnnualAdjustment[ec,area,Yr(2038)] = 2.205
  AnnualAdjustment[ec,area,Yr(2039)] = 2.305
  AnnualAdjustment[ec,area,Yr(2040)] = 2.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Gas")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end
  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2027)] = 5.500

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

  #
  # Electrification is already maxed out for Ontario so add as energy efficiency
  # Select Sets for Policy
  #  
  area = Select(Area,"ON")
  ec = Select(EC,"IronSteel")

  # 
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2025):Yr(2050))

  ReductionAdditional[ec,area,Yr(2028)] = 2.56
  ReductionAdditional[ec,area,Yr(2029)] = 2.56
  ReductionAdditional[ec,area,Yr(2030)] = 2.56
  ReductionAdditional[ec,area,Yr(2031)] = 2.56
  ReductionAdditional[ec,area,Yr(2032)] = 2.56
  ReductionAdditional[ec,area,Yr(2033)] = 2.56
  ReductionAdditional[ec,area,Yr(2034)] = 2.56
  ReductionAdditional[ec,area,Yr(2035)] = 2.56
  ReductionAdditional[ec,area,Yr(2036)] = 2.56
  #ReductionAdditional[ec,area,Yr(2037)] = 0.03 TODOJulia: missing in Promula file
  ReductionAdditional[ec,area,Yr(2038)] = 2.56
  ReductionAdditional[ec,area,Yr(2039)] = 2.56
  ReductionAdditional[ec,area,Yr(2040)] = 2.56
  ReductionAdditional[ec,area,Yr(2041)] = 2.56
  ReductionAdditional[ec,area,Yr(2042)] = 2.56
  ReductionAdditional[ec,area,Yr(2043)] = 2.56
  ReductionAdditional[ec,area,Yr(2044)] = 2.56
  ReductionAdditional[ec,area,Yr(2045)] = 2.56
  ReductionAdditional[ec,area,Yr(2046)] = 2.56
  ReductionAdditional[ec,area,Yr(2047)] = 2.56
  ReductionAdditional[ec,area,Yr(2048)] = 2.56
  ReductionAdditional[ec,area,Yr(2049)] = 2.56
  ReductionAdditional[ec,area,Yr(2050)] = 2.56

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2028)] = 1.10
  AnnualAdjustment[ec,area,Yr(2029)] = 1.20
  AnnualAdjustment[ec,area,Yr(2030)] = 1.36
  AnnualAdjustment[ec,area,Yr(2031)] = 1.44
  AnnualAdjustment[ec,area,Yr(2032)] = 1.54
  AnnualAdjustment[ec,area,Yr(2033)] = 1.645
  AnnualAdjustment[ec,area,Yr(2034)] = 1.705
  AnnualAdjustment[ec,area,Yr(2035)] = 1.805
  AnnualAdjustment[ec,area,Yr(2036)] = 2.055
  AnnualAdjustment[ec,area,Yr(2037)] = 2.155
  AnnualAdjustment[ec,area,Yr(2038)] = 2.205
  AnnualAdjustment[ec,area,Yr(2039)] = 2.305
  AnnualAdjustment[ec,area,Yr(2040)] = 2.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Gas")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end
  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2028)] = 64.25

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

  #
  # Electrification is already maxed out for Ontario so add as energy efficiency
  # Select Sets for Policy
  #  
  area = Select(Area,"QC")
  ec = Select(EC,"Cement")

  # 
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2025):Yr(2050))

  ReductionAdditional[ec,area,Yr(2027)] = 3.023
  ReductionAdditional[ec,area,Yr(2028)] = 3.119
  ReductionAdditional[ec,area,Yr(2029)] = 3.293
  ReductionAdditional[ec,area,Yr(2030)] = 3.546
  ReductionAdditional[ec,area,Yr(2031)] = 3.571
  ReductionAdditional[ec,area,Yr(2032)] = 3.571
  ReductionAdditional[ec,area,Yr(2033)] = 3.583
  ReductionAdditional[ec,area,Yr(2034)] = 3.583
  ReductionAdditional[ec,area,Yr(2035)] = 3.583
  ReductionAdditional[ec,area,Yr(2036)] = 3.583
  ReductionAdditional[ec,area,Yr(2037)] = 3.583 
  ReductionAdditional[ec,area,Yr(2038)] = 3.583
  ReductionAdditional[ec,area,Yr(2039)] = 3.583
  ReductionAdditional[ec,area,Yr(2040)] = 3.583
  ReductionAdditional[ec,area,Yr(2041)] = 1.583
  ReductionAdditional[ec,area,Yr(2042)] = 1.583
  ReductionAdditional[ec,area,Yr(2043)] = 1.583
  ReductionAdditional[ec,area,Yr(2044)] = 1.583
  ReductionAdditional[ec,area,Yr(2045)] = 1.583
  ReductionAdditional[ec,area,Yr(2046)] = 1.583
  ReductionAdditional[ec,area,Yr(2047)] = 1.583
  ReductionAdditional[ec,area,Yr(2048)] = 1.583
  ReductionAdditional[ec,area,Yr(2049)] = 1.583
  ReductionAdditional[ec,area,Yr(2050)] = 1.583

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2027)] = 1.10
  AnnualAdjustment[ec,area,Yr(2028)] = 1.10
  AnnualAdjustment[ec,area,Yr(2029)] = 1.20
  AnnualAdjustment[ec,area,Yr(2030)] = 1.36
  AnnualAdjustment[ec,area,Yr(2031)] = 1.44
  AnnualAdjustment[ec,area,Yr(2032)] = 1.54
  AnnualAdjustment[ec,area,Yr(2033)] = 1.645
  AnnualAdjustment[ec,area,Yr(2034)] = 1.705
  AnnualAdjustment[ec,area,Yr(2035)] = 1.805
  AnnualAdjustment[ec,area,Yr(2036)] = 2.055
  AnnualAdjustment[ec,area,Yr(2037)] = 2.155
  AnnualAdjustment[ec,area,Yr(2038)] = 2.205
  AnnualAdjustment[ec,area,Yr(2039)] = 2.305
  AnnualAdjustment[ec,area,Yr(2040)] = 2.405
  AnnualAdjustment[ec,area,Yr(2041)] = 2.897
  AnnualAdjustment[ec,area,Yr(2042)] = 3.05
  AnnualAdjustment[ec,area,Yr(2043)] = 3.189
  AnnualAdjustment[ec,area,Yr(2044)] = 3.326
  AnnualAdjustment[ec,area,Yr(2045)] = 3.463
  AnnualAdjustment[ec,area,Yr(2046)] = 3.597
  AnnualAdjustment[ec,area,Yr(2047)] = 3.739
  AnnualAdjustment[ec,area,Yr(2048)] = 3.884
  AnnualAdjustment[ec,area,Yr(2049)] = 4.028
  AnnualAdjustment[ec,area,Yr(2050)] = 4.174

  #
  # Convert from TJ to TBtu
  #  
  techs = Select(Tech,"Gas")
  if techs != []
    for year in years
      ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/1.05461*AnnualAdjustment[ec,area,year]
    end

    AllocateReduction(data,Enduses,techs,ec,area,years)
  end
  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[ec,Yr(2028)] = 0

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in Enduses, tech in techs, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[ec,year]*DmdFrac[enduse,tech,ec,area,year]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

end

function PolicyControl(db)
  @info "Ind_LCEF_Dev.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
