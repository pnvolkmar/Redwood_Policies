#
# Retro_Device_Com_NG.jl - Device Retrofit
# Natural Gas Conservation Framework, Commercial Buildings Process Improvements
# Input direct energy savings and expenditures provided by Ontario
# see ON_CDM_DSM3.xlsx (RW 09/16/2021)
#
# Last updated by Kevin Palmer-Wilson on 2023-06-09
#

using SmallModel

module Retro_Device_Com_NG

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
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
  CERSM::VariableArray{4} = ReadDisk(db,"$CalDB/CERSM") # [Enduse,EC,Area,Year] Capital Energy Requirement (Btu/Btu)
  DER::VariableArray{5} = ReadDisk(db,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERReductionStart::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  ECUF::VariableArray{3} = ReadDisk(db,"MOutput/ECUF") # [ECC,Area,Year] Capital Utilization Fraction
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Adjustment for energy savings rebound
  DERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Device Energy Removed (mmBtu/Yr)
  DERReductionAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Fraction of Device Energy Removed added by this Policy ((mmBtu/Yr)/(mmBtu/Yr))
  DERRemoved::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Policy-specific Device Energy Removed ((mmBtu/Yr)/Yr)
  DERRemovedTotal::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Policy-specific Total Device Energy Removed (mmBtu/Yr)
  DmFracExcluded::VariableArray{4} = zeros(Float64,length(Enduse),length(EC),length(Area),length(Year)) # [Enduse,EC,Area,Year] Total DmFrac for Fuels Excluded from Policy (Btu/Btu/Yr)
  DmFracGR::VariableArray{4} = zeros(Float64,length(Enduse),length(Fuel),length(EC),length(Area)) # [Enduse,Fuel,EC,Area] Growth Rate in Demand Fuel Fraction (Btu/Btu/Yr)
  DmFracIncluded::VariableArray{4} = zeros(Float64,length(Enduse),length(EC),length(Area),length(Year)) # [Enduse,EC,Area,Year] Total DmFrac for Fuels Included in Policy (Btu/Btu/Yr)
  DmdSavings::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions after this Policy is added (TBtu/Yr)
  DmdSavingsAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from this Policy (TBtu/Yr)
  DmdSavingsStart::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Demand Reductions from Previous Policies (TBtu/Yr)
  DmdSavingsTotal::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Total Demand Reductions after this Policy is added (TBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Fraction of Energy Requirements Removed (Btu/Btu)
  Increment::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] annual increment for rebound adjustment
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  Reduction::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionAdditional::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data,db,enduses,tech,area,years)
  (; Outpt) = data
  (; EC,ECC,ECCs,ECs) = data
  (; CERSM,DERRemoved,DERRRExo,DmdRef,DmdTotal,ECUF) = data
  (; ReductionAdditional) = data
  
  #
  # Total Demands
  #  
  for year in years
    DmdTotal[year] = sum(DmdRef[eu,tech,ec,area,year] for ec in ECs,eu in enduses)
  end
  
  #
  # Multiply by DEEA if input values reflect expected Dmd savings
  #  
  for year in years, ec in ECs, eu in enduses
    @finite_math DERRemoved[eu,tech,ec,area,year] = 1000000*ReductionAdditional[tech,year]/
      CERSM[eu,ec,area,year]*DmdRef[eu,tech,ec,area,year]/DmdTotal[year]
  end

  for year in years, ec in ECs, ecc in ECCs, eu in enduses
    if EC[ec] == ECC[ecc]
      @finite_math DERRemoved[eu,tech,ec,area,year] = 
        DERRemoved[eu,tech,ec,area,year]/ECUF[ecc,area,year]
    end
    
  end

  for year in years, ec in ECs, eu in enduses
    DERRRExo[eu,tech,ec,area,year] = DERRRExo[eu,tech,ec,area,year]+
      DERRemoved[eu,tech,ec,area,year]
  end
  
  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end #Procedure AllocateReduction


function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area,ECs) = data
  (; Enduse) = data
  (; Tech,Techs) = data
  (; Years) = data
  (; AnnualAdjustment) = data
  (; DERRemoved) = data
  (; DERRemovedTotal) = data
  (; DInvExo) = data
  (; Expenses,Increment) = data
  (; Reduction,ReductionAdditional) = data
  (; xInflation) = data

  for year in Years,tech in Techs
    AnnualAdjustment[tech,year] = 1.0
    Increment[tech,year] = 0
  end

  #
  # Select Sets for Policy
  #  
  area = Select(Area,"ON")
  enduses = Select(Enduse,["Heat","AC"])
  tech = Select(Tech,"Gas")
  years = collect(Yr(2022):Yr(2050))
  
  #
  # PJ Reductions in end-use sectors
  #
  #! format: off
  Reduction[tech,years] = [
    # 2022  2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
    2.1     2.9     3.6     4.4     5.2     6.0     6.8     7.6     7.3     7.5     7.7     8.0     8.2     8.5     8.7     9.0     9.2     9.5     9.7     10.0    10.3    10.6    10.8    11.1    11.4    11.7    12.1    12.4    12.7
  ]
  #! format: on

  for year in years
    ReductionAdditional[tech,year] = Reduction[tech,year]-Reduction[tech,year-1]
  end

  years = collect(Yr(2022):Yr(2034))
  for year in years
    Increment[tech,year] = 0.05
  end

  years = collect(Yr(2035):Final)
  for year in years
    Increment[tech,year] = 0.07
  end

  years = collect(Yr(2022):Yr(2050))
  for year in years
    AnnualAdjustment[tech,year] = AnnualAdjustment[tech,year-1]+Increment[tech,year]
    ReductionAdditional[tech,year] = ReductionAdditional[tech,year]/
      1.054615*AnnualAdjustment[tech,year]
  end
  
  AllocateReduction(data,db,enduses,tech,area,years)
    #
  # Program Costs
  #
  #! format: off
  Expenses[tech,years] = [
    # 2022  2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
    29.7    31.1    32.5    34.0    35.6    37.2    38.0    38.7    39.5    40.3    41.1    41.9    42.8    43.6    44.5    45.4    46.3    47.2    48.1    49.1    50.1    51.1    52.1    53.2    54.2    55.3    56.4    57.5    58.7
  ]
  for year in years
    Expenses[tech,year] = Expenses[tech,year]
  end
  
  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  #  
  for year in years
    DERRemovedTotal[tech,year] = 
      sum(DERRemoved[enduse,tech,ec,area,year] for ec in ECs,enduse in enduses)
  end

  for year in years, ec in ECs, eu in enduses
    @finite_math DInvExo[eu,tech,ec,area,year] = DInvExo[eu,tech,ec,area,year]+
      Expenses[tech,year]/xInflation[area,year]*DERRemoved[eu,tech,ec,area,year]/
        DERRemovedTotal[tech,year]
  end

  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Retro_Device_Com_NG.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
