#
# QC_EcoPerf_Com.jl - Process Retrofit
#
# Quebec program
# More information about this policy is available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx
#
# Last edited by Kevin Palmer-Wilson on 2023-06-09
#

using SmallModel

module QC_EcoPerf_Com

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
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
  Dmd::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/Dmd",Future) # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  PER::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/PER",Future) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  PERReductionStart::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  Adjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Feedback Adjustment Variable
  DmdSavings::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions after this Policy is added (TBtu/Yr)
  DmdSavingsAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from this Policy (TBtu/Yr)
  DmdSavingsStart::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from Previous Policies (TBtu/Yr)
  DmdSavingsTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand Reductions after this Policy is added (TBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PERReductionAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Fraction of Process Energy Removed added by this Policy ((mmBtu/Yr)/(mmBtu/Yr))
  PERRemoved::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Removed ((mmBtu/Yr)/Yr)
  PERRemovedTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::CControl,year,areas,techs,enduses)
  (; ECs) = data
  (; Dmd,DmdSavings,DmdSavingsAdditional,DmdSavingsStart) = data
  (; DmdSavingsTotal,DmdTotal,PERReduction) = data
  (; PERReductionAdditional,PERReductionStart) = data
  (; ReductionAdditional) = data

  #
  # Total Demands
  #  
  DmdTotal[year] = sum(Dmd[enduse,tech,ec,area]
    for enduse in enduses, tech in techs, ec in ECs, area in areas)
  
  #
  # Reductions from Previous Policies
  #  
  for enduse in enduses, tech in techs, ec in ECs, area in areas
    DmdSavingsStart[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      PERReductionStart[enduse,tech,ec,area,year]
  end

  #
  # Additional demand reduction is transformed to be a fraction of total demand 
  #  
  for enduse in enduses, tech in techs, ec in ECs, area in areas
    PERReductionAdditional[enduse,tech,ec,area] = 
      ReductionAdditional[year]/DmdTotal[year]
  end

  #
  # Demand reductions from this Policy
  #  
  for enduse in enduses, tech in techs, ec in ECs, area in areas
    DmdSavingsAdditional[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      PERReductionAdditional[enduse,tech,ec,area]
  end

  #
  # Combine reductions from previous policies with reductions from this policy
  #  
  for enduse in enduses, tech in techs, ec in ECs, area in areas
    DmdSavings[enduse,tech,ec,area] = DmdSavingsStart[enduse,tech,ec,area]+
      DmdSavingsAdditional[enduse,tech,ec,area]
  end
  
  DmdSavingsTotal[year] = sum(DmdSavings[enduse,tech,ec,area]
    for enduse in enduses, tech in techs, ec in ECs, area in areas)

  #
  # Cumulative reduction fraction (PERReduction)
  #  
  for enduse in enduses, tech in techs, ec in ECs, area in areas
    PERReduction[enduse,tech,ec,area,year] = 
      DmdSavingsTotal[year]/DmdTotal[year]
  end  
  
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input,Outpt) = data
  (; Area,ECs,Enduse,Tech,Year) = data
  (; DmdTotal,Expenses,FractionRemovedAnnually,PER) = data
  (; PERReduction,PERRRExo,PInvExo) = data
  (; PERRRExoTotal,ReductionAdditional,xInflation) = data

  #   
  # Select Sets for Policy
  #  
  area = Select(Area,"QC")
  techs = Select(Tech,["Gas","Coal","Oil"])
  enduses = Select(Enduse,["Heat","AC"])
  years = collect(Yr(2022):Yr(2030))    
  
  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #  
  for year in years
    ReductionAdditional[year] = 0.292/1.054615
  end

  #
  # Add adjustment after first year to account for feedback
  #  
  ReductionAdditional[Yr(2022)] = ReductionAdditional[Yr(2022)] * 1.08
  ReductionAdditional[Yr(2023)] = ReductionAdditional[Yr(2023)] * 1.11
  ReductionAdditional[Yr(2024)] = ReductionAdditional[Yr(2024)] * 1.15
  ReductionAdditional[Yr(2025)] = ReductionAdditional[Yr(2025)] * 1.20
  ReductionAdditional[Yr(2026)] = ReductionAdditional[Yr(2026)] * 1.26
  ReductionAdditional[Yr(2027)] = ReductionAdditional[Yr(2027)] * 1.31
  ReductionAdditional[Yr(2028)] = ReductionAdditional[Yr(2028)] * 1.36
  ReductionAdditional[Yr(2029)] = ReductionAdditional[Yr(2029)] * 1.42
  ReductionAdditional[Yr(2030)] = ReductionAdditional[Yr(2030)] * 1.47

  #
  # Read Adjustment
  #
  # / 2022  2023  2024  2025  2026  2027  2028  2029  2030
  #   1.08  1.11  1.15  1.20  1.26  1.31  1.36  1.42  1.47  
  # ReductionAdditional=ReductionAdditional*Adjustment
  #
  
  for year in years
    AllocateReduction(data,year,area,techs,enduses)
  end

  #
  # Fraction Removed each Year
  # 
  for year in years
    @finite_math FractionRemovedAnnually[year] =
      (ReductionAdditional[year]/DmdTotal[year])-
      (ReductionAdditional[year-1]/DmdTotal[year-1])
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, ec in ECs, year in years
    PERRRExo[enduse,tech,ec,area,year] = PER[enduse,tech,ec,area]*
      FractionRemovedAnnually[year]
  end

  WriteDisk(db,"$Input/PERReduction",PERReduction)
  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)

  # 
  # Program Costs
  #     
  years = Select(Year,(from = "2022", to = "2030"))
  Expenses[years] = [
  #  2022 2023 2024 2025 2026 2027 2028 2029 2030
       0    0    0    0    0    0    0    0    0 
  ]
  for year in years
    Expenses[year]=Expenses[year]/xInflation[area,Yr(2017)]
  end
    
  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  #  
  for year in years
    PERRRExoTotal[year] = sum(PERRRExo[enduse,tech,ec,area,year]
      for enduse in enduses, tech in techs, ec in ECs)
  end
  
  Heat = Select(Enduse,"Heat")
  for tech in techs, ec in ECs, year in years
    @finite_math PInvExo[Heat,tech,ec,area,year] = 
      PInvExo[Heat,tech,ec,area,year]+Expenses[year]*
        sum(PERRRExo[enduse,tech,ec,area,year] for enduse in enduses)/
          PERRRExoTotal[year]
  end
  
  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "QC_EcoPerf_Com.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
