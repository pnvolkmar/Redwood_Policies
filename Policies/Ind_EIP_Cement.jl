#
# Ind_EIP_Cement.jl - Simulates investments into decarbonizing cement production through the injection of CO2
# into concrete (NS), leading to less demand for cement. This is modelled as a process efficiency retrofit.
# The other investment that is modelled is an investment into decarbonizing cement through the upcycling
# of fly-ash (AB) which reduces demand for cement. This is also modelled through a process efficiency retrofit.
#

using SmallModel

module Ind_EIP_Cement

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

  # TODOJulia: In Promula version the Define Variable section is pointing to the 'D'
  # variables on the database, not 'P'. Fixed below to match results. Variable names
  # should be changed in future versions. Ian 02/05/25
  #
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  PERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  #PERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PER") # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  #PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  #PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  #PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Adjustment for energy savings rebound
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::IControl,enduses,techs,ecs,areas,years)
  (; db,Outpt) = data
  (; DmdRef,DmdTotal,FractionRemovedAnnually,PERRef,PERRRExo) = data
  (; ReductionAdditional,ReductionTotal) = data

  #
  # Total Demands
  #  
  for year in years, area in areas, ec in ecs
    DmdTotal[ec,area,year] = 
      sum(DmdRef[eu,tech,ec,area,year] for tech in techs,eu in enduses)
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

  #WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)
  WriteDisk(db,"$Outpt/DERRRExo",PERRRExo)

end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduses,Tech) = data
  (; AnnualAdjustment,DmdFrac,DmdRef,DmdTotal) = data
  (; PInvExo,PolicyCost,ReductionAdditional,xInflation) = data

  @. AnnualAdjustment = 1.0

  #
  # Select Sets for Policy
  #  
  area = Select(Area,"NS")
  ec = Select(EC,"Cement")
  tech = Select(Tech,"Coal")
  years = collect(Yr(2026):Yr(2050))

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #  
  ReductionAdditional[ec,area,Yr(2026)] = 0.286
  ReductionAdditional[ec,area,Yr(2027)] = 0.286
  ReductionAdditional[ec,area,Yr(2028)] = 0.286
  ReductionAdditional[ec,area,Yr(2029)] = 0.286
  ReductionAdditional[ec,area,Yr(2030)] = 0.286
  ReductionAdditional[ec,area,Yr(2031)] = 0.286
  ReductionAdditional[ec,area,Yr(2032)] = 0.286
  ReductionAdditional[ec,area,Yr(2033)] = 0.286
  ReductionAdditional[ec,area,Yr(2034)] = 0.286
  ReductionAdditional[ec,area,Yr(2035)] = 0.286
  ReductionAdditional[ec,area,Yr(2036)] = 0.286
  ReductionAdditional[ec,area,Yr(2037)] = 0.286
  ReductionAdditional[ec,area,Yr(2038)] = 0.286
  ReductionAdditional[ec,area,Yr(2039)] = 0.286
  ReductionAdditional[ec,area,Yr(2040)] = 0.286
  ReductionAdditional[ec,area,Yr(2041)] = 0.286
  ReductionAdditional[ec,area,Yr(2042)] = 0.286
  ReductionAdditional[ec,area,Yr(2043)] = 0.286
  ReductionAdditional[ec,area,Yr(2044)] = 0.286
  ReductionAdditional[ec,area,Yr(2045)] = 0.286
  ReductionAdditional[ec,area,Yr(2046)] = 0.286
  ReductionAdditional[ec,area,Yr(2047)] = 0.286
  ReductionAdditional[ec,area,Yr(2048)] = 0.286
  ReductionAdditional[ec,area,Yr(2049)] = 0.286
  ReductionAdditional[ec,area,Yr(2050)] = 0.286

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2026)] = 1.08
  AnnualAdjustment[ec,area,Yr(2027)] = 1.18
  AnnualAdjustment[ec,area,Yr(2028)] = 1.30
  AnnualAdjustment[ec,area,Yr(2029)] = 1.45
  AnnualAdjustment[ec,area,Yr(2030)] = 1.60
  AnnualAdjustment[ec,area,Yr(2031)] = 1.71
  AnnualAdjustment[ec,area,Yr(2032)] = 1.85
  AnnualAdjustment[ec,area,Yr(2033)] = 1.95
  AnnualAdjustment[ec,area,Yr(2034)] = 2.14
  AnnualAdjustment[ec,area,Yr(2035)] = 2.24
  AnnualAdjustment[ec,area,Yr(2036)] = 2.34
  AnnualAdjustment[ec,area,Yr(2037)] = 2.44
  AnnualAdjustment[ec,area,Yr(2038)] = 2.60
  AnnualAdjustment[ec,area,Yr(2039)] = 2.70
  AnnualAdjustment[ec,area,Yr(2040)] = 2.82
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

  for year in years
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1.05461*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,tech,ec,area,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  # Policy costs have been adjusted since 2022 was removed. Need to check for accuracy.
  # NC 06/20/2024.
  PolicyCost[ec,area,Yr(2026)] = 4

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, eu in Enduses
    @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
       DmdTotal[ec,area,year]
    PInvExo[eu,tech,ec,area,year] = PInvExo[eu,tech,ec,area,year]+
       PolicyCost[ec,area,year]*DmdFrac[eu,tech,ec,area,year]
  end
    
  #WriteDisk(db,"$Input/PInvExo",PInvExo)
  WriteDisk(db,"$Input/DInvExo",PInvExo)
  
  #
  # Select Sets for Policy
  #  
  area = Select(Area,"AB")
  ec = Select(EC,"Cement")
  tech = Select(Tech,"Gas")
  years = collect(Yr(2026):Yr(2050))

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #  
  ReductionAdditional[ec,area,Yr(2026)] = 0.435
  ReductionAdditional[ec,area,Yr(2027)] = 0.435
  ReductionAdditional[ec,area,Yr(2028)] = 0.435
  ReductionAdditional[ec,area,Yr(2029)] = 0.435
  ReductionAdditional[ec,area,Yr(2030)] = 0.435
  ReductionAdditional[ec,area,Yr(2031)] = 0.435
  ReductionAdditional[ec,area,Yr(2032)] = 0.435
  ReductionAdditional[ec,area,Yr(2033)] = 0.435
  ReductionAdditional[ec,area,Yr(2034)] = 0.435
  ReductionAdditional[ec,area,Yr(2035)] = 0.435
  ReductionAdditional[ec,area,Yr(2036)] = 0.435
  ReductionAdditional[ec,area,Yr(2037)] = 0.435
  ReductionAdditional[ec,area,Yr(2038)] = 0.435
  ReductionAdditional[ec,area,Yr(2039)] = 0.435
  ReductionAdditional[ec,area,Yr(2040)] = 0.435
  ReductionAdditional[ec,area,Yr(2041)] = 0.435
  ReductionAdditional[ec,area,Yr(2042)] = 0.435
  ReductionAdditional[ec,area,Yr(2043)] = 0.435
  ReductionAdditional[ec,area,Yr(2044)] = 0.435
  ReductionAdditional[ec,area,Yr(2045)] = 0.435
  ReductionAdditional[ec,area,Yr(2046)] = 0.435
  ReductionAdditional[ec,area,Yr(2047)] = 0.435
  ReductionAdditional[ec,area,Yr(2048)] = 0.435
  ReductionAdditional[ec,area,Yr(2049)] = 0.435
  ReductionAdditional[ec,area,Yr(2050)] = 0.435

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ec,area,Yr(2026)] = 1.08
  AnnualAdjustment[ec,area,Yr(2027)] = 1.18
  AnnualAdjustment[ec,area,Yr(2028)] = 1.30
  AnnualAdjustment[ec,area,Yr(2029)] = 1.35
  AnnualAdjustment[ec,area,Yr(2030)] = 1.68
  AnnualAdjustment[ec,area,Yr(2031)] = 1.78
  AnnualAdjustment[ec,area,Yr(2032)] = 1.97
  AnnualAdjustment[ec,area,Yr(2033)] = 2.12
  AnnualAdjustment[ec,area,Yr(2034)] = 2.45
  AnnualAdjustment[ec,area,Yr(2035)] = 2.55
  AnnualAdjustment[ec,area,Yr(2036)] = 2.75
  AnnualAdjustment[ec,area,Yr(2037)] = 2.95
  AnnualAdjustment[ec,area,Yr(2038)] = 3.15
  AnnualAdjustment[ec,area,Yr(2039)] = 3.35
  AnnualAdjustment[ec,area,Yr(2040)] = 3.45
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

  for year in years
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1.05461*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,tech,ec,area,years);
  
  #
  #########################
  #
  # Program Costs $M,Read PolicyCost(Area,Year), EcoPerformance Industry Standard + EcoPerformance Large Emitters Bonus
  # Policy costs have been adjusted since 2022 was removed. Need to check for accuracy.
  # NC 06/20/2024.
  PolicyCost[ec,area,Yr(2026)] = 3.9

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, eu in Enduses
    @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
       DmdTotal[ec,area,year]
    PInvExo[eu,tech,ec,area,year] = PInvExo[eu,tech,ec,area,year]+
       PolicyCost[ec,area,year]*DmdFrac[eu,tech,ec,area,year]
  end
    
  #WriteDisk(db,"$Input/PInvExo",PInvExo)
  WriteDisk(db,"$Input/DInvExo",PInvExo)

end

function PolicyControl(db)
  @info "Ind_EIP_Cement.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
