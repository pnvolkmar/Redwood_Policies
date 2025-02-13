#
# Ind_CleanBC_PP.jl - Device Retrofit
# Ind_CleanBC_PP.txp. Simulates investments from CleanBC into decarbonizing pulp and paper production.
# Reductions assumed to be non-incremental, txp is tuned to the base case. Reductions are assumed to come from
# energy efficiency. Aligned to numbers received from BC government or pulled from BC government website.
#

using SmallModel

module Ind_CleanBC_PP

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

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  DEEARef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEEA") # [Enduse,Tech,EC,Area,Year] Average Device Efficiency (Btu/Btu)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Year] Adjustment for energy savings rebound
  CCC::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DDD::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Total Policy Cost ($/TBtu)
  PolicyCostYr::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Annual Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [EC,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
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
  for ec in ecs, area in areas, year in years
    DmdTotal[ec,area,year] = sum(DmdRef[enduse,tech,ec,area,year] for enduse in enduses,
        tech in techs)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for ec in ecs, area in areas, year in years
    ReductionAdditional[ec,area,year] = max((ReductionAdditional[ec,area,year] - 
      ReductionTotal[ec,area,year-1]),0.0)
    ReductionTotal[ec,area,year] = ReductionAdditional[ec,area,year] + ReductionTotal[ec,area,year-1]
  end

  #
  # Fraction Removed each Year
  #  
  for ec in ecs, area in areas, year in years
    @finite_math FractionRemovedAnnually[ec,area,year] = ReductionAdditional[ec,area,year] / 
      DmdTotal[ec,area,year]
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas, year in years
    DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year]+ 
      DERRef[enduse,tech,ec,area,year]*FractionRemovedAnnually[ec,area,year]
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,Enduses) = data 
  (; Nation,Tech) = data
  (; AnnualAdjustment) = data
  (; DInvExo,DmdFrac,DmdRef,DmdTotal) = data
  (; PolicyCost,ReductionAdditional) = data

  KJBtu = 1.054615

  #
  # Select Policy Sets (Enduse,Tech,EC)
  #  
  CN = Select(Nation,"CN")
  years = collect(Yr(2023):Yr(2050))
  areas = Select(Area,"BC")
  ecs = Select(EC,"PulpPaperMills")
  techs = Select(Tech,["Coal","Oil","Gas"])

  #
  # Reductions in demand read in in TJ and converted to TBtu
  #  
  for year in years
    ReductionAdditional[ecs,areas,year] = 2.083
  end
  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,areas,Yr(2023)]=0.85
  AnnualAdjustment[ecs,areas,Yr(2024)]=1.00
  AnnualAdjustment[ecs,areas,Yr(2025)]=1.10
  AnnualAdjustment[ecs,areas,Yr(2026)]=1.15
  AnnualAdjustment[ecs,areas,Yr(2027)]=1.20
  AnnualAdjustment[ecs,areas,Yr(2028)]=1.30
  AnnualAdjustment[ecs,areas,Yr(2029)]=0.92
  AnnualAdjustment[ecs,areas,Yr(2030)]=1.25
  AnnualAdjustment[ecs,areas,Yr(2031)]=1.35
  AnnualAdjustment[ecs,areas,Yr(2032)]=1.48
  AnnualAdjustment[ecs,areas,Yr(2033)]=1.55
  AnnualAdjustment[ecs,areas,Yr(2034)]=1.65
  AnnualAdjustment[ecs,areas,Yr(2035)]=1.80
  AnnualAdjustment[ecs,areas,Yr(2036)]=1.90
  AnnualAdjustment[ecs,areas,Yr(2037)]=1.95
  AnnualAdjustment[ecs,areas,Yr(2038)]=2.00
  AnnualAdjustment[ecs,areas,Yr(2039)]=2.05
  AnnualAdjustment[ecs,areas,Yr(2040)]=2.10
  AnnualAdjustment[ecs,areas,Yr(2041)]=2.897
  AnnualAdjustment[ecs,areas,Yr(2042)]=3.05
  AnnualAdjustment[ecs,areas,Yr(2043)]=3.189
  AnnualAdjustment[ecs,areas,Yr(2044)]=3.326
  AnnualAdjustment[ecs,areas,Yr(2045)]=3.463
  AnnualAdjustment[ecs,areas,Yr(2046)]=3.597
  AnnualAdjustment[ecs,areas,Yr(2047)]=3.739
  AnnualAdjustment[ecs,areas,Yr(2048)]=3.884
  AnnualAdjustment[ecs,areas,Yr(2049)]=4.028
  AnnualAdjustment[ecs,areas,Yr(2050)]=4.174

  #
  # Convert from TJ to TBtu
  #  
  @. ReductionAdditional = ReductionAdditional/KJBtu*AnnualAdjustment

  AllocateReduction(data,Enduses,techs,ecs,areas,years)
  
  #
  # Program Costs $M  
  # 2022 has been removed so make sure that values are correct. NC 06/20/2024.
  #  
  PolicyCost[ecs,Yr(2023)] = 8.48

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs, eu in Enduses
    @finite_math DmdFrac[eu,tech,ec,area,year] = 
      DmdRef[eu,tech,ec,area,year]/DmdTotal[ec,area,year]
    DInvExo[eu,tech,ec,area,year] = DInvExo[eu,tech,ec,area,year]+
      PolicyCost[ec,year]*DmdFrac[eu,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Ind_CleanBC_PP.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
