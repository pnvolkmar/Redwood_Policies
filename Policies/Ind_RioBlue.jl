#
# Ind_RioBlue.jl
#
# Designed to model the ilmenite smelting technology integrated into metallurgical complex in
# Sorel-Tracy QC
# The BlueSmelting project is an ilmenite smelting technology that could generate 95% less
# greenhouse gas emissions than RTFT’s current reduction process, enabling the production of
# high-grade titanium dioxide feedstock, steel and metal powders with a drastically reduced
# carbon footprint.
#

using SmallModel

module Ind_RioBlue

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

function IndPolicy(db)
  data = IControl(; db)
  (; Input,Outpt) = data
  (; Area,EC,Enduse,Enduses) = data 
  (; Nation,Tech) = data
  (; Year) = data
  (; AnnualAdjustment) = data
  (; DmdFrac,DmdRef,DmdTotal) = data
  (; FractionRemovedAnnually,PERRef) = data
  (; PERRRExo,PInvExo,PolicyCost,ReductionAdditional) = data
  (; ReductionTotal) = data

  @. AnnualAdjustment = 1.0

  QC = Select(Area,"QC")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share,Read ReductionAdditional(Area,Year)
  #  
  ReductionAdditional[QC,Yr(2024)] = 0.748
  ReductionAdditional[QC,Yr(2025)] = 1.495
  ReductionAdditional[QC,Yr(2026)] = 2.243
  ReductionAdditional[QC,Yr(2027)] = 2.990
  ReductionAdditional[QC,Yr(2028)] = 3.738
  ReductionAdditional[QC,Yr(2029)] = 4.485
  ReductionAdditional[QC,Yr(2030)] = 5.233
  ReductionAdditional[QC,Yr(2031)] = 5.233
  ReductionAdditional[QC,Yr(2032)] = 5.233
  ReductionAdditional[QC,Yr(2033)] = 5.233
  ReductionAdditional[QC,Yr(2034)] = 5.233
  ReductionAdditional[QC,Yr(2035)] = 5.233

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements 
  #  
  AnnualAdjustment[QC,Yr(2024)] = 0.980
  AnnualAdjustment[QC,Yr(2025)] = 1.000
  AnnualAdjustment[QC,Yr(2026)] = 1.050
  AnnualAdjustment[QC,Yr(2027)] = 1.080
  AnnualAdjustment[QC,Yr(2028)] = 1.130
  AnnualAdjustment[QC,Yr(2029)] = 1.190
  AnnualAdjustment[QC,Yr(2030)] = 1.200
  AnnualAdjustment[QC,Yr(2031)] = 1.300
  AnnualAdjustment[QC,Yr(2032)] = 1.380
  AnnualAdjustment[QC,Yr(2033)] = 1.420
  AnnualAdjustment[QC,Yr(2034)] = 1.600
  AnnualAdjustment[QC,Yr(2035)] = 1.680

  #
  # Program Costs $M
  #  
  PolicyCost[QC,Yr(2024)] = 15.9
  PolicyCost[QC,Yr(2025)] = 15.9
  PolicyCost[QC,Yr(2026)] = 15.9
  PolicyCost[QC,Yr(2027)] = 15.9
  PolicyCost[QC,Yr(2028)] = 15.9
  PolicyCost[QC,Yr(2029)] = 15.9
  PolicyCost[QC,Yr(2030)] = 15.9
  
  #
  # Select Sets for Policy
  #  
  CN = Select(Nation,"CN")
  areas = Select(Area,"QC")
  ecs = Select(EC,"OtherNonferrous")
  years = Select(Year,(from="2024",to="2035"))
  techs = Select(Tech,"Coal")
  enduses = Select(Enduse,"Heat")

  for year in years, area in areas
    ReductionAdditional[area,year] = ReductionAdditional[area,year]/1.05461*
      AnnualAdjustment[area,year]
    
    #
    # Total Demands
    #    
    DmdTotal[area,year] = 
      sum(DmdRef[eu,tech,ec,area,year] for ec in ecs, tech in techs, eu in enduses)

    #
    # Accumulate ReductionAdditional and apply to reference case demands
    #    
    ReductionAdditional[area,year] = max(ReductionAdditional[area,year]-
      ReductionTotal[area,year-1],0)
    ReductionTotal[area,year] = ReductionAdditional[area,year]+
      ReductionTotal[area,year-1]

    #
    # Fraction Removed each Year
    #    
    @finite_math FractionRemovedAnnually[area,year] = ReductionAdditional[area,year]/
      DmdTotal[area,year]

    #
    # Energy Requirements Removed due to Program
    #    
    for ec in ecs, tech in techs, eu in enduses
      PERRRExo[eu,tech,ec,area,year] = PERRRExo[eu,tech,ec,area,year]+
        (PERRef[eu,tech,ec,area,year]*FractionRemovedAnnually[area,year])
    end
    
  end
  
  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  for year in years, area in areas, ec in ecs, tech in techs
    for eu in Enduses
     @finite_math DmdFrac[eu,tech,ec,area,year] = DmdRef[eu,tech,ec,area,year]/
       DmdTotal[area,year]
    end
    
    Heat = Select(Enduse,"Heat")
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      sum(PolicyCost[area,year]*DmdFrac[eu,tech,ec,area,year] for eu in Enduses)
  end
  
  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "Ind_RioBlue.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
