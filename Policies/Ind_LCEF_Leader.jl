#
# Ind_LCEF_Leader.jl - - Device Retrofit
# NRCan Energy Management Program
# Energy impacts are input directly as provided by NRCan.  Note program costs are as provided for
# Ref18 since no new estimates were provided. (RW 06 02 2021)
# Edited by RST 02Aug2022, re-tuning for Ref22
#

using SmallModel

module Ind_LCEF_Leader

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
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Adjustment for energy savings rebound
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  FractionRemovedAnnually::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fraction of Energy Requirements Removed (Btu/Btu)
  ReductionAdditional::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
end

function AllocateReduction(data::IControl,enduses,techs,ecs,areas,years)
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
    DmdTotal[year] = sum(DmdRef[enduse,tech,ec,area,year] for enduse in enduses, tech in techs, ec in ecs, area in areas)
  end

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
  #Fraction Removed each Year
  #  
  for year in years
    @finite_math FractionRemovedAnnually[year] = ReductionAdditional[year]/DmdTotal[year]
  end

  #
  #Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas, year in years
    DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year]+ 
                                         (DERRef[enduse,tech,ec,area,year]*FractionRemovedAnnually[year])
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end

function IndPolicy(db::String)
  data = IControl(; db)
  (; Input) = data
  (; ECs,Enduse,Enduses,Nation,Tech) = data 
  (; ANMap,AnnualAdjustment,DInvExo,DmdFrac,DmdRef,DmdTotal) = data
  (;ReductionAdditional,PolicyCost,xInflation) = data

  #
  # Select Sets for Policy
  #  
  nation = Select(Nation,"CN")
  areas = findall(ANMap[:,nation] .== 1.0)
  enduses = Select(Enduse,"Heat")
  
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #
  years = collect(Yr(2022):Yr(2050))

  #
  # Change the reductions targeted in this case rather than the adjustment
  #
  ReductionAdditional[Yr(2026)] = 0.9292
  ReductionAdditional[Yr(2027)] = 0.8584
  ReductionAdditional[Yr(2028)] = 1.2876
  ReductionAdditional[Yr(2029)] = 2.6168
  ReductionAdditional[Yr(2030)] = 2.6460
  ReductionAdditional[Yr(2031)] = 2.6460
  ReductionAdditional[Yr(2032)] = 2.6460
  ReductionAdditional[Yr(2033)] = 2.6460
  ReductionAdditional[Yr(2034)] = 3.0460
  ReductionAdditional[Yr(2035)] = 3.1060
  ReductionAdditional[Yr(2036)] = 3.2060
  ReductionAdditional[Yr(2037)] = 3.3460
  ReductionAdditional[Yr(2038)] = 3.4460
  ReductionAdditional[Yr(2039)] = 3.5460
  ReductionAdditional[Yr(2040)] = 3.6460
  ReductionAdditional[Yr(2041)] = 3.299
  ReductionAdditional[Yr(2042)] = 3.299
  ReductionAdditional[Yr(2043)] = 3.299
  ReductionAdditional[Yr(2044)] = 3.299
  ReductionAdditional[Yr(2045)] = 3.299
  ReductionAdditional[Yr(2046)] = 3.299
  ReductionAdditional[Yr(2047)] = 3.299
  ReductionAdditional[Yr(2048)] = 3.299
  ReductionAdditional[Yr(2049)] = 3.299
  ReductionAdditional[Yr(2050)] = 3.299

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #  
  AnnualAdjustment[Yr(2026)] = 1.300
  AnnualAdjustment[Yr(2027)] = 0.887
  AnnualAdjustment[Yr(2028)] = 0.905
  AnnualAdjustment[Yr(2029)] = 1.000
  AnnualAdjustment[Yr(2030)] = 1.100
  AnnualAdjustment[Yr(2031)] = 1.200
  AnnualAdjustment[Yr(2032)] = 1.300
  AnnualAdjustment[Yr(2033)] = 1.400
  AnnualAdjustment[Yr(2034)] = 1.500
  AnnualAdjustment[Yr(2035)] = 1.600
  AnnualAdjustment[Yr(2036)] = 1.700
  AnnualAdjustment[Yr(2037)] = 1.800
  AnnualAdjustment[Yr(2038)] = 1.850
  AnnualAdjustment[Yr(2039)] = 1.900
  AnnualAdjustment[Yr(2040)] = 1.950
  AnnualAdjustment[Yr(2041)] = 1.183
  AnnualAdjustment[Yr(2042)] = 1.183
  AnnualAdjustment[Yr(2043)] = 1.183
  AnnualAdjustment[Yr(2044)] = 1.183
  AnnualAdjustment[Yr(2045)] = 1.183
  AnnualAdjustment[Yr(2046)] = 1.183
  AnnualAdjustment[Yr(2047)] = 1.183
  AnnualAdjustment[Yr(2048)] = 1.183
  AnnualAdjustment[Yr(2049)] = 1.183
  AnnualAdjustment[Yr(2050)] = 1.183

  tech_e = Select(Tech,!=("Electric"))
  tech_s = Select(Tech,!=("Steam"))
  techs = intersect(tech_e,tech_s)
  if techs != []
    for year in years
      ReductionAdditional[year] = ReductionAdditional[year]/1.05461*AnnualAdjustment[year]
    end

    AllocateReduction(data,enduses,techs,ECs,areas,years)
  end

  #
  # Program Costs, Read PolicyCost 
  # 
  PolicyCost[Yr(2026)] = 167.5

  # Investment costs have been updated due to the year 2023 being removed. Check for accuracy later.
  # NC 06/20/2024
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #
  for enduse in enduses, tech in techs, ec in ECs, area in areas, year in years
    DmdFrac[enduse,tech,ec,area,year] = DmdRef[enduse,tech,ec,area,year]/DmdTotal[year]
    DInvExo[enduse,tech,ec,area,year] = DInvExo[enduse,tech,ec,area,year]+PolicyCost[year]*
                                        DmdFrac[enduse,tech,ec,area,year]/xInflation[area,Yr(2015)]
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

end

function PolicyControl(db)
  @info "Ind_LCEF_Leader.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
