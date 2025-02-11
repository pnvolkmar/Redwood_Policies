#
# Res_CGHG.jl - Process Retrofit
#
# This policy file simulates the impact of NRCan's Canada Greener Home Grant (CGHG) program.
# 
# The Canada Greener Homes Grant (CGHG) provides up to 700,000 grants of up to $5,000 to help 
# homeowners make energy efficient retrofits to their homes, such as better insulation. A list 
# of eligible retrofits under CGHG can be found here (https://bit.ly/2W1VAzh). To participate
# in CGHG, homeowners must have a registered energy advisor complete pre- and post-retrofit
# EnerGuide evaluations of their home, for which they will be reimbursed up to a maximum of $600.
# CGHG is funded to provide grants to homeowners for eligible retrofits and evaluations 
# retroactive to Dec 2020, and until March 2027.
#
# The policy is assumed by NRCan to reduce energy demand by an average of 23 GJ/house/year, for a 
# total reduction of 16.1 PJ  when the program concludes (see assumptions here: 
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\_Annual Updates\2019_Update\Policies\Buildings\NRCan\CGHG\CGHG energy savings and emissions reductions targets assumptions and methodology.docx
#
# The policy reduces energy demand by 16.1 PJ in 2026 in the residential sector. 
# The assumption is that reductions increase linearly from 2021 to 2026 to reach that target.
# We assume that 116 667 houses per year are retrofitted per year, at a cost of $5000 each ($583.3 million per year)
# Last updated by Yang Li on 2024-06-12
#

using SmallModel

module Res_CGHG

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
  db::String
  
  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
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
  Dmd::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/Dmd",Future) # [Enduse,Tech,EC,Area] Demand (TBtu/Yr)
  PER::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/PER",Future) # [Enduse,Tech,EC,Area] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  PERReductionStart::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflationNation::VariableArray{2} = ReadDisk(db,"MInput/xInflationNation") # [Nation,Year] Inflation Index ($/$)

  # Scratch Variables
  Adjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Feedback Adjustment Variable
  DmdSavings::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions after this Policy is added (TBtu/Yr)
  DmdSavingsAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from this Policy (TBtu/Yr)
  DmdSavingsStart::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from Previous Policies (TBtu/Yr)
  DmdSavingsTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand Reductions after this Policy is added (TBtu/Yr)
  # DmdTotal      'Total Demand (TBtu/Yr)'
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PERReductionAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Fraction of Process Energy Removed added by this Policy ((mmBtu/Yr)/(mmBtu/Yr))
  PERRemoved::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Removed ((mmBtu/Yr)/Yr)
  PERRemovedTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::RControl,year,areas,ecs,techs,enduses)
  (; ECs) = data
  (; Dmd,DmdSavings,DmdSavingsAdditional,DmdSavingsStart) = data
  (; DmdSavingsTotal,PERReduction,PERReductionAdditional) = data
  (; PERReductionStart,ReductionAdditional,PER) = data
  
  DmdTotal = sum(Dmd[enduse,tech,ec,area] for enduse in enduses, tech in techs,
    ec in ECs, area in areas)
  loc1 = sum(PER[enduse,tech,ec,area] for enduse in enduses, tech in techs,
    ec in ECs, area in areas)
  print("\nDmdTotal: ", DmdTotal)
  print("\nPERTotal: ", loc1)

  #
  # Reductions from Previous Policies
  # 
  for enduse in enduses, tech in techs, ec in ecs, area in areas
    DmdSavingsStart[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      PERReductionStart[enduse,tech,ec,area,year]
  end

  #
  # Additional demand reduction is transformed to be a fraction of total demand 
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas
    @finite_math PERReductionAdditional[enduse,tech,ec,area] = 
      ReductionAdditional[year]/DmdTotal
  end

  #
  # Demand reductions from this Policy
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas
    DmdSavingsAdditional[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      PERReductionAdditional[enduse,tech,ec,area];
  end

  #
  # Combine reductions from previous policies with reductions from this policy
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas
    DmdSavings[enduse,tech,ec,area] = DmdSavingsStart[enduse,tech,ec,area]+
      DmdSavingsAdditional[enduse,tech,ec,area]
  end
  
  DmdSavingsTotal[year] = 
    sum(DmdSavings[enduse,tech,ec,area] for enduse in enduses,tech in techs,ec in ECs,area in areas);

  #
  # Cumulative reduction fraction (PERReduction)
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas
    @finite_math PERReduction[enduse,tech,ec,area,year] = DmdSavingsTotal[year]/DmdTotal
  end
  
  return(DmdTotal)
end

function ResPolicy(db)
  data = RControl(; db)
  (; Input,Outpt) = data
  (; ECs,Enduse) = data 
  (; Nation,Techs) = data
  
  (; Adjustment,ANMap,Dmd) = data
  (; Expenses) = data
  (; FractionRemovedAnnually,PER,PERReduction) = data
  (; PERRemovedTotal,PERRRExo,PInvExo) = data
  (; ReductionAdditional,xInflationNation) = data
  
  # 
  # Select Sets for Policy
  #  
  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)
  enduses = Select(Enduse,["Heat","AC"])
  years = collect(Yr(2023):Yr(2026))

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #  
  ReductionAdditional[Yr(2023)] = 8.1
  ReductionAdditional[Yr(2024)] = 10.7
  ReductionAdditional[Yr(2025)] = 13.4
  ReductionAdditional[Yr(2026)] = 16.1

  for year in years
    ReductionAdditional[year] = ReductionAdditional[year]/1.054615
  end

  #
  # Add adjustment after first year to account for feedback
  # TODO Promula: This is coded in such a way that implies the coder believed
  # Adjustment was set to 1 for all years, which is not what happens - PNV Feb 11 2025
  # 
  for year in years
    Adjustment[year] = 1.00
  end
  
  for year in years
    Adjustment[year] = Adjustment[year-1]+0.03
    ReductionAdditional[year] = ReductionAdditional[year]*Adjustment[year]
  end

  DmdTotal = AllocateReduction(data,Yr(2023),areas,ECs,Techs,enduses)
  DmdTotal = AllocateReduction(data,Yr(2024),areas,ECs,Techs,enduses)
  DmdTotal = AllocateReduction(data,Yr(2025),areas,ECs,Techs,enduses)
  DmdTotal = AllocateReduction(data,Yr(2026),areas,ECs,Techs,enduses)

  #
  # Fraction Removed each Year
  #  
  for year in years
    @finite_math FractionRemovedAnnually[year] = ReductionAdditional[year]/DmdTotal-
      ReductionAdditional[year-1]/DmdTotal
  end
  
  #
  # Energy Requirements Removed due to Program
  #  
  for year in years, area in areas, ec in ECs, tech in Techs, eu in enduses
    PERRRExo[eu,tech,ec,area,year] = PER[eu,tech,ec,area]*FractionRemovedAnnually[year]
  end

  #
  ########################
  #
  WriteDisk(db,"$Input/PERReduction",PERReduction)
  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)

  #
  ########################
  #
  # Program Costs
  #   
  Expenses[Yr(2023)] = 583.3 
  Expenses[Yr(2024)] = 583.3
  Expenses[Yr(2025)] = 583.3
  Expenses[Yr(2026)] = 583.3

  for year in years
    Expenses[year] = Expenses[year]/1e6/xInflationNation[CN,year]
  end
  
  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  #  
  for year in years
    PERRemovedTotal[year] = sum(PERRRExo[eu,tech,ec,area,year] 
                           for area in areas, ec in ECs, tech in Techs, eu in enduses)                        
  end
  
  Heat = Select(Enduse,"Heat")
  for area in areas, ec in ECs, tech in Techs, year in years
    @finite_math PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      Expenses[year]*sum(PERRRExo[eu,tech,ec,area,year]/
        PERRemovedTotal[year] for eu in enduses)
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "Res_CGHG.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
