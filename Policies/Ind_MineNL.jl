#
# Ind_MineNL.jl
#
# Adjustment file to keep emissions growth constant over the projection 
# period upon recommendation from NL. The shift to underground mining and 
# expansion of Voisey Bay project will result in constant approximately 
# 5% growth in emissions annually throughout the projection period.
# Modelled as by shifting demand annually
#

using SmallModel

module Ind_MineNL

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
    DmdTotal[area,year] = sum(DmdRef[eu,tech,ec,area,year] for ec in ecs,
      tech in techs,eu in enduses)
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
  # Fraction Removed each Year
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
  (; Area,EC,Enduse) = data
  (; Tech) = data
  (; AnnualAdjustment) = data
  (; PolicyCost,ReductionAdditional) = data
  
  @. AnnualAdjustment = 1.0

  KJBtu = 1.054615

  NL = Select(Area,"NL")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial PJ reductions by fuel share
  #
  
  ReductionAdditional[NL,Yr(2024)] = 0.1295
  ReductionAdditional[NL,Yr(2025)] = 0.1536
  ReductionAdditional[NL,Yr(2026)] = 0.2893
  ReductionAdditional[NL,Yr(2027)] = 0.2335
  ReductionAdditional[NL,Yr(2028)] = 0.1591
  ReductionAdditional[NL,Yr(2029)] = 0.0606
  ReductionAdditional[NL,Yr(2030)] = 0.0100
  ReductionAdditional[NL,Yr(2031)] = -0.0644
  ReductionAdditional[NL,Yr(2032)] = -0.1877
  ReductionAdditional[NL,Yr(2033)] = -0.2574
  ReductionAdditional[NL,Yr(2034)] = -0.3261
  ReductionAdditional[NL,Yr(2035)] = -0.4041

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #
  
  AnnualAdjustment[NL,Yr(2024)] = 0.980
  AnnualAdjustment[NL,Yr(2025)] = 1.090
  AnnualAdjustment[NL,Yr(2026)] = 1.050
  AnnualAdjustment[NL,Yr(2027)] = 1.080
  AnnualAdjustment[NL,Yr(2028)] = 1.130
  AnnualAdjustment[NL,Yr(2029)] = 1.190
  AnnualAdjustment[NL,Yr(2030)] = 1.200
  AnnualAdjustment[NL,Yr(2031)] = 1.300
  AnnualAdjustment[NL,Yr(2032)] = 1.380
  AnnualAdjustment[NL,Yr(2033)] = 1.420
  AnnualAdjustment[NL,Yr(2034)] = 1.600
  AnnualAdjustment[NL,Yr(2035)] = 1.680

  #
  # Convert from TJ to TBtu
  #
  
  @. ReductionAdditional = ReductionAdditional/KJBtu*AnnualAdjustment

  #
  # Program Costs $M
  #
  
  PolicyCost[NL,Yr(2024)] = 0
  PolicyCost[NL,Yr(2025)] = 0
  PolicyCost[NL,Yr(2026)] = 0
  PolicyCost[NL,Yr(2027)] = 0
  PolicyCost[NL,Yr(2028)] = 0
  PolicyCost[NL,Yr(2029)] = 0
  PolicyCost[NL,Yr(2030)] = 0
  PolicyCost[NL,Yr(2031)] = 0
  PolicyCost[NL,Yr(2032)] = 0
  PolicyCost[NL,Yr(2033)] = 0
  PolicyCost[NL,Yr(2034)] = 0
  PolicyCost[NL,Yr(2035)] = 0

  years = collect(Yr(2024):Yr(2035))
  ecs = Select(EC,"OtherMetalMining")
  techs = Select(Tech,["Oil","Gas"])
  enduses = Select(Enduse,"Heat")
  
  AllocateReduction(data,enduses,techs,ecs,NL,years)
end

function PolicyControl(db)
  @info "Ind_MineNL.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
