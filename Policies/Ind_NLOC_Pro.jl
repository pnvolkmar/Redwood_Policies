#
# Ind_NLOC_Pro.jl - Process Retrofit
#
# Quebec's EcoPerformance Program. RW 08/01/2019
# Includes federal bonification from LCEF leadership funds
# GHG/Energy reductions and investment data from 
# TEQ-ClasseurderapportdesGES - ÉcoPerf.xlsx (RW 06/02/2021)
# Updated program costs and tuning adjustment factors (RST 06Sept2022)
#

using SmallModel

module Ind_NLOC_Pro

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

  DEEARef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEEA") # [Enduse,Tech,EC,Area,Year] Average Device Efficiency (Btu/Btu)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  PERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PER") # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  
  # Scratch Variables
  AnnualAdjustment::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Adjustment for energy savings rebound
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Total Demand (TBtu/Yr)
  FractionRemovedAnnually::VariableArray{3} = zeros(Float64,length(EC),length(Area),length(Year)) # [Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
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
  (; ReductionAdditional) = data

  @. AnnualAdjustment = 1.0

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  # Provincial TJ reductions by fuel share, Read ReductionAdditional(Area,Year)
  #  
  ecs = Select(EC,"OtherChemicals")
  areas = Select(Area,"NL")

  ReductionAdditional[ecs,areas,Yr(2024)] = 2.00
  ReductionAdditional[ecs,areas,Yr(2025)] = 2.00
  ReductionAdditional[ecs,areas,Yr(2026)] = 2.00
  ReductionAdditional[ecs,areas,Yr(2027)] = 2.00
  ReductionAdditional[ecs,areas,Yr(2028)] = 1.51
  ReductionAdditional[ecs,areas,Yr(2029)] = 1.40
  ReductionAdditional[ecs,areas,Yr(2030)] = 1.30
  ReductionAdditional[ecs,areas,Yr(2031)] = 1.25
  ReductionAdditional[ecs,areas,Yr(2032)] = 1.24
  ReductionAdditional[ecs,areas,Yr(2033)] = 1.23
  ReductionAdditional[ecs,areas,Yr(2034)] = 2.21
  ReductionAdditional[ecs,areas,Yr(2035)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2036)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2037)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2038)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2039)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2040)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2041)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2042)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2043)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2044)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2045)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2046)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2047)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2048)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2049)] = 1.21
  ReductionAdditional[ecs,areas,Yr(2050)] = 1.21

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[ecs,areas,Yr(2023)] = 0.200
  AnnualAdjustment[ecs,areas,Yr(2024)] = 0.200
  AnnualAdjustment[ecs,areas,Yr(2025)] = 0.190
  AnnualAdjustment[ecs,areas,Yr(2026)] = 0.180
  AnnualAdjustment[ecs,areas,Yr(2027)] = 0.170
  AnnualAdjustment[ecs,areas,Yr(2028)] = 0.160
  AnnualAdjustment[ecs,areas,Yr(2029)] = 0.150
  AnnualAdjustment[ecs,areas,Yr(2030)] = 0.140
  AnnualAdjustment[ecs,areas,Yr(2031)] = 0.130
  AnnualAdjustment[ecs,areas,Yr(2032)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2033)] = 0.110
  AnnualAdjustment[ecs,areas,Yr(2034)] = 0.090
  AnnualAdjustment[ecs,areas,Yr(2035)] = 0.080
  AnnualAdjustment[ecs,areas,Yr(2036)] = 0.070
  AnnualAdjustment[ecs,areas,Yr(2037)] = 0.060
  AnnualAdjustment[ecs,areas,Yr(2038)] = 0.050
  AnnualAdjustment[ecs,areas,Yr(2039)] = 0.040
  AnnualAdjustment[ecs,areas,Yr(2040)] = 0.020
  AnnualAdjustment[ecs,areas,Yr(2041)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2042)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2043)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2044)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2045)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2046)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2047)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2048)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2049)] = 0.120
  AnnualAdjustment[ecs,areas,Yr(2050)] = 0.120

  years = collect(Yr(2023):Yr(2050))
  techs = Select(Tech,["LPG","Gas"])
  for year in years, area in areas, ec in ecs
    ReductionAdditional[ec,area,year] = ReductionAdditional[ec,area,year]/
      1.05461*AnnualAdjustment[ec,area,year]
  end
  
  AllocateReduction(data,Enduses,techs,ecs,areas,years);
  
end

function PolicyControl(db)
  @info "Ind_NLOC_Pro.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
