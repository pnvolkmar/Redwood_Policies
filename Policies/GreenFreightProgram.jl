#
# GreenFreightProgram.jl - Device Retrofit
#

using SmallModel

module GreenFreightProgram

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr,Zero
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name
  RefNameDB::String = ReadDisk(db,"E2020DB/RefNameDB") #  Reference Case Name

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
  DER::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/DER",Future) # [Enduse,Tech,EC,Area,Future] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERReductionStart::VariableArray{4} = ReadDisk(db,"$Input/DERReduction",Zero) # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  Dmd::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/Dmd",Future) # [Enduse,Tech,EC,Area,Future] Demand (TBtu/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  Adjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Feedback Adjustment Variable
  DERReductionAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Fraction of Device Energy Removed added by this Policy ((mmBtu/Yr)/(mmBtu/Yr))
  DERRemoved::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Device Energy Removed ((mmBtu/Yr)/Yr)
  DERRemovedTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Device Energy Removed (mmBtu/Yr)
  DERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Device Energy Removed (mmBtu/Yr)
  DmdSavings::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions after this Policy is added (TBtu/Yr)
  DmdSavingsAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from this Policy (TBtu/Yr)
  DmdSavingsStart::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from Previous Policies (TBtu/Yr)
  DmdSavingsTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand Reductions after this Policy is added (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fraction of Energy Requirements Removed (Btu/Btu)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data,DmdTotal,year,enduse,tech,ec,areas)
  (; Dmd) = data
  (; DERReduction,DERReductionStart) = data
  (; DERReductionAdditional) = data
  (; DmdSavings) = data
  (; DmdSavingsAdditional,DmdSavingsStart) = data
  (; DmdSavingsTotal) = data
  (; ReductionAdditional) = data

  #
  # Reductions from Previous Policies
  # 
  for area in areas
    DmdSavingsStart[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      DERReductionStart[enduse,tech,ec,area]
  end

  #
  # Additional demand reduction is transformed to be a fraction of total demand 
  #  
  for area in areas
    DERReductionAdditional[enduse,tech,ec,area] = ReductionAdditional[year]/DmdTotal
  end

  #
  # Demand reductions from this Policy
  #  
  for area in areas
    DmdSavingsAdditional[enduse,tech,ec,area] = Dmd[enduse,tech,ec,area]*
      DERReductionAdditional[enduse,tech,ec,area]
  end

  #
  # Combine reductions from previous policies with reductions from this policy
  #  
  for area in areas 
    DmdSavings[enduse,tech,ec,area] = DmdSavingsStart[enduse,tech,ec,area]+
      DmdSavingsAdditional[enduse,tech,ec,area]
  end
  
  DmdSavingsTotal[year] = sum(DmdSavings[enduse,tech,ec,area] for area in areas);

  #
  # Cumulative reduction fraction (DERReduction)
  #
  for area in areas
    DERReduction[enduse,tech,ec,area,year] = DmdSavingsTotal[year]/DmdTotal
  end

  return
  
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input,Outpt) = data
  (; EC,Enduse) = data 
  (; Nation,Tech) = data
  (; Adjustment,ANMap,db,DER) = data
  (; DERReduction) = data
  (; DERRemovedTotal,DERRRExo) = data
  (; DInvExo,Dmd) = data
  (; Expenses,FractionRemovedAnnually) = data
  (; ReductionAdditional,xInflation) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)
  Freight = Select(EC,"Freight");
  Carriage = Select(Enduse,"Carriage")
  HDV8Diesel = Select(Tech,"HDV8Diesel")

  #
  # Policy results is a reduction in demand (PJ) converted to TBtu
  #  
  years = collect(Yr(2022):Yr(2032))
  
  ReductionAdditional[years] = [
  # /  2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032
       0.0    1.47   2.94   2.94   2.94   1.47   0.0    0.0    0.0    0.0    0.0
       ]
  for year in years
    ReductionAdditional[year] = ReductionAdditional[year]/1.054615
  end

  #
  # Add adjustment after first year to account for feedback
  # 
  # Adjusted adjustment to account for schedule shift to 2024 - BB Dec 8 2021
  #   
  for year in years
    Adjustment[year] = 1.0
  end
  
  years = collect(Yr(2023):Yr(2027))
  for year in years
    Adjustment[year] = Adjustment[year-1]+0.02
  end
  
  years = collect(Yr(2028):Yr(2032))
  for year in years
    Adjustment[year] = Adjustment[year-1]+0.04
  end

  years = collect(Yr(2022):Yr(2032))
  for year in years
    ReductionAdditional[year] = ReductionAdditional[year]*Adjustment[year]
  end

  DmdTotal = sum(Dmd[Carriage,HDV8Diesel,Freight,area] for area in areas)

  for year in years
    AllocateReduction(data,DmdTotal,year,Carriage,HDV8Diesel,Freight,areas)
  end
  
  #
  # Fraction Removed each Year
  #  
  for year in years
    FractionRemovedAnnually[year] = ReductionAdditional[year]/DmdTotal
  end

  #
  # Energy Requirements Removed due to Program
  #  
  for area in areas, year in years
    DERRRExo[Carriage,HDV8Diesel,Freight,area,year] = DER[Carriage,HDV8Diesel,Freight,area]*
                                                      FractionRemovedAnnually[year]
  end

  WriteDisk(db,"$Input/DERReduction",DERReduction);
  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo);

  #
  # Program Costs
  #  
  years = collect(Yr(2022):Yr(2032))
  Expenses[years] =[
  # / 2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032
    0.0   50    50    50    50    0     0     0    0      0     0
  ]
  for year in years
    Expenses[year] = Expenses[year]/1000000
  end

  #
  # Allocate Program Costs to each Enduse,Tech,EC,and Area
  # 
  for year in years
    DERRemovedTotal[year] = sum(DERRRExo[Carriage,HDV8Diesel,Freight,area,year] for area in areas)
  end

  for area in areas, year in years
    @finite_math DInvExo[Carriage,HDV8Diesel,Freight,area,year] = 
      DInvExo[Carriage,HDV8Diesel,Freight,area,year]+
        (Expenses[year]/xInflation[area,year]*
          DERRRExo[Carriage,HDV8Diesel,Freight,area,year]/DERRemovedTotal[year])
  end

  WriteDisk(db,"$Input/DInvExo",DInvExo); 
end

function PolicyControl(db)
  @info "GreenFreightProgram.jl - PolicyControl";
  TransPolicy(db);
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
