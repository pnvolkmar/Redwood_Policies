#
# Ind_NG.jl - Process Retrofit
# Electricity Conservation Framework, Commercial Buildings Process Improvements
# Input direct energy savings and expenditures provided by Ontario
# see ON_CDM_DSM3.xlsx (RW 09/16/2021)
#
# Last updated by Kevin Palmer-Wilson on 2023-06-09
#

using SmallModel

module Ind_NG

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
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
  DEEARef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEEA") # [Enduse,Tech,EC,Area,Year] Average Device Efficiency (Btu/Btu)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  ECUF::VariableArray{3} = ReadDisk(db,"MOutput/ECUF") # [ECC,Area,Year] Capital Utilization Fraction
  PER::VariableArray{5} = ReadDisk(db,"$Outpt/PER") # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  PERReduction::VariableArray{5} = ReadDisk(db,"$Input/PERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  # PERReductionStart::VariableArray{5} = ReadDisk(db,"$Input/PERReductionStart") # [Enduse,Tech,EC,Area,Year] Fraction of Process Energy Removed from Previous Policies ((mmBtu/Yr)/(mmBtu/Yr))
  PERRRExo::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Adjustment for energy savings rebound
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
  Increment::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Annual increment for rebound adjustment
  PERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PERReductionAdditional::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Fraction of Process Energy Removed added by this Policy ((mmBtu/Yr)/(mmBtu/Yr))
  PERRemoved::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Policy-specific Process Energy Removed ((mmBtu/Yr)/Yr)
  PERRemovedTotal::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Policy-specific Total Process Energy Removed (mmBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
  Reduction::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionAdditional::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data,db,enduses,ecs,tech,area,years)
  (; Outpt) = data
  (; EC,ECC,ECCs,ECs) = data
  (; CERSM,PERRemoved,PERRRExo,DEEARef,DmdRef,DmdTotal) = data
  (; ECUF,ReductionAdditional) = data
  
  #
  # Total Demands
  #  
  for year in years
    DmdTotal[year] = sum(DmdRef[eu,tech,ec,area,year] for ec in ecs, eu in enduses)
  end

  #
  # Multiply by DEEA if input values reflect expected Dmd savings
  #  
  for year in years, ec in ecs, eu in enduses
    @finite_math PERRemoved[eu,tech,ec,area,year] = 1000000*
      ReductionAdditional[tech,year]*DEEARef[eu,tech,ec,area,year]/
        CERSM[eu,ec,area,year]*DmdRef[eu,tech,ec,area,year]/DmdTotal[year]
  end

  for year in years, ec in ecs, eu in enduses
    ecc = Select(ECC,EC[ec])
    if ecc != []
      @finite_math PERRemoved[eu,tech,ec,area,year] = PERRemoved[eu,tech,ec,area,year]/
        ECUF[ecc,area,year]
    end
  end

  for year in years, ec in ecs, eu in enduses
    PERRRExo[eu,tech,ec,area,year] = PERRRExo[eu,tech,ec,area,year]+
      PERRemoved[eu,tech,ec,area,year]
  end

  WriteDisk(db,"$Outpt/PERRRExo",PERRRExo)
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC) = data
  (; Enduse,Enduses) = data
  (; Tech,Techs,Years) = data
  (; AnnualAdjustment) = data
  (; Expenses,Increment) = data
  (; PERRemoved) = data
  (; PERRemovedTotal,PInvExo) = data
  (; Reduction,ReductionAdditional) = data
  (; xInflation) = data

  #
  # Note that Promula file has inputs for 'Increment' that doesn't actually do anything
  # so I left inputs out for now - Ian 02/07/25
  #
  for year in Years, tech in Techs
    AnnualAdjustment[tech,year] = 1.0
    Increment[tech,year] = 0
  end

  #
  # Natural Gas
  #
  # Select Sectors Included
  # Select all industrial sectors except pipelines
  #  
  ecs = Select(EC,(from="Food",to="OnFarmFuelUse"))
  area = Select(Area,"ON")
  tech = Select(Tech,"Gas")

  #
  # PJ Reductions in end-use sectors
  #
  Reduction[tech,Yr(2023)] = 1.879
  Reduction[tech,Yr(2024)] = 1.206
  Reduction[tech,Yr(2025)] = 1.042
  Reduction[tech,Yr(2026)] = 1.970
  Reduction[tech,Yr(2027)] = 3.200
  Reduction[tech,Yr(2028)] = 4.000
  Reduction[tech,Yr(2029)] = 1.540
  Reduction[tech,Yr(2030)] = 1.440
  Reduction[tech,Yr(2031)] = 1.340
  Reduction[tech,Yr(2032)] = 1.240
  Reduction[tech,Yr(2033)] = 1.140
  Reduction[tech,Yr(2034)] = 1.040
  Reduction[tech,Yr(2035)] = 0.940
  Reduction[tech,Yr(2036)] = 0.840
  Reduction[tech,Yr(2037)] = 0.830
  Reduction[tech,Yr(2038)] = 0.820
  Reduction[tech,Yr(2039)] = 0.830
  Reduction[tech,Yr(2040)] = 0.830
  Reduction[tech,Yr(2041)] = 1.838
  Reduction[tech,Yr(2042)] = 1.838
  Reduction[tech,Yr(2043)] = 1.838
  Reduction[tech,Yr(2044)] = 1.838
  Reduction[tech,Yr(2045)] = 1.838
  Reduction[tech,Yr(2046)] = 1.838
  Reduction[tech,Yr(2047)] = 1.838
  Reduction[tech,Yr(2048)] = 1.838
  Reduction[tech,Yr(2049)] = 1.838
  Reduction[tech,Yr(2050)] = 1.838

  AnnualAdjustment[tech,Yr(2023)] = 1.200
  AnnualAdjustment[tech,Yr(2024)] = 0.400
  AnnualAdjustment[tech,Yr(2025)] = 0.350
  AnnualAdjustment[tech,Yr(2026)] = 0.330
  AnnualAdjustment[tech,Yr(2027)] = 0.310
  AnnualAdjustment[tech,Yr(2028)] = 0.300
  AnnualAdjustment[tech,Yr(2029)] = 0.295
  AnnualAdjustment[tech,Yr(2030)] = 0.290
  AnnualAdjustment[tech,Yr(2031)] = 0.280
  AnnualAdjustment[tech,Yr(2032)] = 0.270
  AnnualAdjustment[tech,Yr(2033)] = 0.275
  AnnualAdjustment[tech,Yr(2034)] = 0.276
  AnnualAdjustment[tech,Yr(2035)] = 0.277
  AnnualAdjustment[tech,Yr(2036)] = 0.278
  AnnualAdjustment[tech,Yr(2037)] = 0.279
  AnnualAdjustment[tech,Yr(2038)] = 0.280
  AnnualAdjustment[tech,Yr(2039)] = 0.281
  AnnualAdjustment[tech,Yr(2040)] = 0.282
  AnnualAdjustment[tech,Yr(2041)] = 0.283
  AnnualAdjustment[tech,Yr(2042)] = 0.284
  AnnualAdjustment[tech,Yr(2043)] = 0.285
  AnnualAdjustment[tech,Yr(2044)] = 0.286
  AnnualAdjustment[tech,Yr(2045)] = 0.287
  AnnualAdjustment[tech,Yr(2046)] = 0.288
  AnnualAdjustment[tech,Yr(2047)] = 0.289
  AnnualAdjustment[tech,Yr(2048)] = 0.290
  AnnualAdjustment[tech,Yr(2049)] = 0.291
  AnnualAdjustment[tech,Yr(2050)] = 0.292

  years = collect(Yr(2023):Yr(2050))
  for year in years
    ReductionAdditional[tech,year] = Reduction[tech,year]/1.054615*
    AnnualAdjustment[tech,year]
  end
  
  AllocateReduction(data,db,Enduses,ecs,tech,area,years)
  
  #
  # Retrofit Costs
  #
  # Exclude Rubber and Transport Equipment to avoid excessive % investment
  # jumps that cause TIM problems (RW 10/10/18)
  #
  ecs_r = Select(EC,!=("Rubber"))
  ecs_t = Select(EC,!=("TransportEquipment"))
  ecs = intersect(ecs,ecs_r,ecs_t)

  #
  # Program Costs ($M,nominal), Read Expenses(Tech,Year)
  #
  Expenses[tech,Yr(2023)]=17.828
  Expenses[tech,Yr(2024)]=18.185
  Expenses[tech,Yr(2025)]=18.547
  Expenses[tech,Yr(2026)]=19.033
  Expenses[tech,Yr(2027)]=19.569
  Expenses[tech,Yr(2028)]=20.160
  Expenses[tech,Yr(2029)]=20.563
  Expenses[tech,Yr(2030)]=20.974
  Expenses[tech,Yr(2031)]=21.394
  Expenses[tech,Yr(2032)]=21.822
  Expenses[tech,Yr(2033)]=22.258
  Expenses[tech,Yr(2034)]=22.703
  Expenses[tech,Yr(2035)]=23.167
  Expenses[tech,Yr(2036)]=23.620
  Expenses[tech,Yr(2037)]=24.093
  Expenses[tech,Yr(2038)]=24.575
  Expenses[tech,Yr(2039)]=25.066
  Expenses[tech,Yr(2040)]=25.567
  Expenses[tech,Yr(2041)]=25.537
  Expenses[tech,Yr(2042)]=26.047
  Expenses[tech,Yr(2043)]=26.568
  Expenses[tech,Yr(2044)]=27.099
  Expenses[tech,Yr(2045)]=27.642
  Expenses[tech,Yr(2046)]=28.194
  Expenses[tech,Yr(2047)]=28.758
  Expenses[tech,Yr(2048)]=29.333
  Expenses[tech,Yr(2049)]=29.920
  Expenses[tech,Yr(2050)]=30.519

  for year in years
    Expenses[tech,year] = Expenses[tech,year]/xInflation[area,year]
  end

  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  # 
  for year in years, enduse in Enduses, ec in ecs
    #
    # TODOJulia: Statement below in Promula isn't in a loop so it is evaluating
    # the first value
    #
    #PERRemoved[enduse,tech,ec,area,year] = max(PERRemoved[enduse,tech,ec,area,year], 0.00001)
     PERRemoved[first(enduse),tech,first(ec),area,year] = max(PERRemoved[first(enduse),tech,first(ec),area,year], 0.00001)
  end
  for year in years
    PERRemovedTotal[tech,year] = 
      sum(PERRemoved[enduse,tech,ec,area,year] for ec in ecs, enduse in Enduses)
  end

  Heat = Select(Enduse,"Heat")
  for year in years, ec in ecs
    @finite_math PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      Expenses[tech,year]*sum(PERRemoved[eu,tech,ec,area,Yr(2021)] for eu in Enduses)/
          PERRemovedTotal[tech,Yr(2021)]
  end
  WriteDisk(db,"$Input/PInvExo",PInvExo)  
  #
  ######################
  #
  for year in Years, tech in Techs
    AnnualAdjustment[tech,year] = 1.0
    Increment[tech,year] = 0
  end

  #
  # Natural Gas
  #
  # Select Sectors Included
  # Select all industrial sectors except pipelines
  #  
  ecs = Select(EC,(from="Food",to="OnFarmFuelUse"))
  area = Select(Area,"BC")
  tech = Select(Tech,"Gas")

  #
  # PJ Reductions in end-use sectors
  #
  Reduction[tech,Yr(2023)] = 0.63
  Reduction[tech,Yr(2024)] = 0.99
  Reduction[tech,Yr(2025)] = 1.39
  Reduction[tech,Yr(2026)] = 1.86
  Reduction[tech,Yr(2027)] = 2.38
  Reduction[tech,Yr(2028)] = 2.38
  Reduction[tech,Yr(2029)] = 2.38
  Reduction[tech,Yr(2030)] = 2.38
  Reduction[tech,Yr(2031)] = 2.38
  Reduction[tech,Yr(2032)] = 2.38
  Reduction[tech,Yr(2033)] = 2.38
  Reduction[tech,Yr(2034)] = 2.38
  Reduction[tech,Yr(2035)] = 2.38
  Reduction[tech,Yr(2036)] = 2.38
  Reduction[tech,Yr(2037)] = 2.38
  Reduction[tech,Yr(2038)] = 2.38
  Reduction[tech,Yr(2039)] = 2.38
  Reduction[tech,Yr(2040)] = 2.38
  Reduction[tech,Yr(2041)] = 2.38
  Reduction[tech,Yr(2042)] = 2.38
  Reduction[tech,Yr(2043)] = 2.38
  Reduction[tech,Yr(2044)] = 2.38
  Reduction[tech,Yr(2045)] = 2.38
  Reduction[tech,Yr(2046)] = 2.38
  Reduction[tech,Yr(2047)] = 2.38
  Reduction[tech,Yr(2048)] = 2.38
  Reduction[tech,Yr(2049)] = 2.38
  Reduction[tech,Yr(2050)] = 2.38

  AnnualAdjustment[tech,Yr(2023)] = 2.400
  AnnualAdjustment[tech,Yr(2024)] = 1.000
  AnnualAdjustment[tech,Yr(2025)] = 0.900
  AnnualAdjustment[tech,Yr(2026)] = 0.600
  AnnualAdjustment[tech,Yr(2027)] = 0.200
  AnnualAdjustment[tech,Yr(2028)] = 0.150
  AnnualAdjustment[tech,Yr(2029)] = 0.200
  AnnualAdjustment[tech,Yr(2030)] = 0.150
  AnnualAdjustment[tech,Yr(2031)] = 0.209
  AnnualAdjustment[tech,Yr(2032)] = 0.217
  AnnualAdjustment[tech,Yr(2033)] = 0.155
  AnnualAdjustment[tech,Yr(2034)] = 0.153
  AnnualAdjustment[tech,Yr(2035)] = 0.151
  AnnualAdjustment[tech,Yr(2036)] = 0.150
  AnnualAdjustment[tech,Yr(2037)] = 0.151
  AnnualAdjustment[tech,Yr(2038)] = 0.152
  AnnualAdjustment[tech,Yr(2039)] = 0.153
  AnnualAdjustment[tech,Yr(2040)] = 0.154
  AnnualAdjustment[tech,Yr(2041)] = 0.155
  AnnualAdjustment[tech,Yr(2042)] = 0.156
  AnnualAdjustment[tech,Yr(2043)] = 0.157
  AnnualAdjustment[tech,Yr(2044)] = 0.158
  AnnualAdjustment[tech,Yr(2045)] = 0.159
  AnnualAdjustment[tech,Yr(2046)] = 0.160
  AnnualAdjustment[tech,Yr(2047)] = 0.161
  AnnualAdjustment[tech,Yr(2048)] = 0.162
  AnnualAdjustment[tech,Yr(2049)] = 0.163
  AnnualAdjustment[tech,Yr(2050)] = 0.164

  years = collect(Yr(2023):Yr(2050))
  for year in years
    ReductionAdditional[tech,year] = Reduction[tech,year]/1.054615*
    AnnualAdjustment[tech,year]
  end
  
  AllocateReduction(data,db,Enduses,ecs,tech,area,years)
  
  #
  # Retrofit Costs
  #
  # Exclude Rubber and Transport Equipment to avoid excessive % investment
  # jumps that cause TIM problems (RW 10/10/18)
  #
  ecs_r = Select(EC,!=("Rubber"))
  ecs_t = Select(EC,!=("TransportEquipment"))
  ecs = intersect(ecs,ecs_r,ecs_t)

  #
  # Program Costs ($M,nominal), Read Expenses(Tech,Year)
  #
  Expenses[tech,Yr(2023)]=6.848
  Expenses[tech,Yr(2024)]=7.585
  Expenses[tech,Yr(2025)]=8.071
  Expenses[tech,Yr(2026)]=8.963
  Expenses[tech,Yr(2027)]=9.600

  years = collect(Yr(2023):Yr(2027))
  for year in years
    Expenses[tech,year] = Expenses[tech,year]/xInflation[area,year]
  end

  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  # 
  for year in years, enduse in Enduses, ec in ecs
    #
    # TODOJulia: Statement below in Promula isn't in a loop so it is evaluating
    # the first value
    #
    #PERRemoved[enduse,tech,ec,area,year] = max(PERRemoved[enduse,tech,ec,area,year], 0.00001)
    PERRemoved[first(enduse),tech,first(ec),area,year] = max(PERRemoved[first(enduse),tech,first(ec),area,year], 0.00001)
  end
  for year in years
    PERRemovedTotal[tech,year] = 
      sum(PERRemoved[enduse,tech,ec,area,year] for ec in ecs, enduse in Enduses)
  end

  Heat = Select(Enduse,"Heat")
  for year in years, ec in ecs
    @finite_math PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      Expenses[tech,year]*sum(PERRemoved[eu,tech,ec,area,Yr(2021)] for eu in Enduses)/
          PERRemovedTotal[tech,Yr(2021)]
  end
  WriteDisk(db,"$Input/PInvExo",PInvExo)  
  
  #
  ######################
  #
  for year in Years, tech in Techs
    AnnualAdjustment[tech,year] = 1.0
    Increment[tech,year] = 0
  end

  #
  # Natural Gas
  #
  # Select Sectors Included
  # Select all industrial sectors except pipelines
  #  
  ecs = Select(EC,(from="Food",to="OnFarmFuelUse"))
  area = Select(Area,"MB")
  tech = Select(Tech,"Gas")

  #
  # PJ Reductions in end-use sectors
  #
  Reduction[tech,Yr(2023)] = 0.467
  Reduction[tech,Yr(2024)] = 0.467
  Reduction[tech,Yr(2025)] = 0.467
  Reduction[tech,Yr(2026)] = 0.467
  Reduction[tech,Yr(2027)] = 0.467
  Reduction[tech,Yr(2028)] = 0.467
  Reduction[tech,Yr(2029)] = 0.467
  Reduction[tech,Yr(2030)] = 0.467
  Reduction[tech,Yr(2031)] = 0.467
  Reduction[tech,Yr(2032)] = 0.467
  Reduction[tech,Yr(2033)] = 0.467
  Reduction[tech,Yr(2034)] = 0.467
  Reduction[tech,Yr(2035)] = 0.467
  Reduction[tech,Yr(2036)] = 0.467
  Reduction[tech,Yr(2037)] = 0.467
  Reduction[tech,Yr(2038)] = 0.467
  Reduction[tech,Yr(2039)] = 0.467
  Reduction[tech,Yr(2040)] = 0.467
  Reduction[tech,Yr(2041)] = 0.467
  Reduction[tech,Yr(2042)] = 0.467
  Reduction[tech,Yr(2043)] = 0.467
  Reduction[tech,Yr(2044)] = 0.467
  Reduction[tech,Yr(2045)] = 0.467
  Reduction[tech,Yr(2046)] = 0.467
  Reduction[tech,Yr(2047)] = 0.467
  Reduction[tech,Yr(2048)] = 0.467
  Reduction[tech,Yr(2049)] = 0.467
  Reduction[tech,Yr(2050)] = 0.467

  AnnualAdjustment[tech,Yr(2023)] = 1.00
  AnnualAdjustment[tech,Yr(2024)] = 0.250
  AnnualAdjustment[tech,Yr(2025)] = 0.150
  AnnualAdjustment[tech,Yr(2026)] = 0.050
  AnnualAdjustment[tech,Yr(2027)] = 0.051
  AnnualAdjustment[tech,Yr(2028)] = 0.052
  AnnualAdjustment[tech,Yr(2029)] = 0.045
  AnnualAdjustment[tech,Yr(2030)] = 0.044
  AnnualAdjustment[tech,Yr(2031)] = 0.043
  AnnualAdjustment[tech,Yr(2032)] = 0.042
  AnnualAdjustment[tech,Yr(2033)] = 0.040
  AnnualAdjustment[tech,Yr(2034)] = 0.040
  AnnualAdjustment[tech,Yr(2035)] = 0.080
  AnnualAdjustment[tech,Yr(2036)] = 0.080
  AnnualAdjustment[tech,Yr(2037)] = 0.080
  AnnualAdjustment[tech,Yr(2038)] = 0.070
  AnnualAdjustment[tech,Yr(2039)] = 0.060
  AnnualAdjustment[tech,Yr(2040)] = 0.059
  AnnualAdjustment[tech,Yr(2041)] = 0.070
  AnnualAdjustment[tech,Yr(2042)] = 0.070
  AnnualAdjustment[tech,Yr(2043)] = 0.070
  AnnualAdjustment[tech,Yr(2044)] = 0.070
  AnnualAdjustment[tech,Yr(2045)] = 0.070
  AnnualAdjustment[tech,Yr(2046)] = 0.070
  AnnualAdjustment[tech,Yr(2047)] = 0.070
  AnnualAdjustment[tech,Yr(2048)] = 0.070
  AnnualAdjustment[tech,Yr(2049)] = 0.070
  AnnualAdjustment[tech,Yr(2050)] = 0.070

  years = collect(Yr(2023):Yr(2050))
  for year in years
    ReductionAdditional[tech,year] = Reduction[tech,year]/1.054615*
    AnnualAdjustment[tech,year]
  end
  
  AllocateReduction(data,db,Enduses,ecs,tech,area,years)
  
  #
  # Retrofit Costs
  #
  # Exclude Rubber and Transport Equipment to avoid excessive % investment
  # jumps that cause TIM problems (RW 10/10/18)
  #
  ecs_r = Select(EC,!=("Rubber"))
  ecs_t = Select(EC,!=("TransportEquipment"))
  ecs = intersect(ecs,ecs_r,ecs_t)

  #
  # Program Costs ($M,nominal), Read Expenses(Tech,Year)
  #
  Expenses[tech,Yr(2023)]=5.736

  years = Yr(2023)
  for year in years
    Expenses[tech,year] = Expenses[tech,year]/xInflation[area,year]
  end

  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  # 
  for year in years, enduse in Enduses, ec in ecs
    #
    # TODOJulia: Statement below in Promula isn't in a loop so it is evaluating
    # the first value
    #
    #PERRemoved[enduse,tech,ec,area,year] = max(PERRemoved[enduse,tech,ec,area,year], 0.00001)
    PERRemoved[first(enduse),tech,first(ec),area,year] = max(PERRemoved[first(enduse),tech,first(ec),area,year], 0.00001)
  end
  for year in years
    PERRemovedTotal[tech,year] = 
      sum(PERRemoved[enduse,tech,ec,area,year] for ec in ecs, enduse in Enduses)
  end

  Heat = Select(Enduse,"Heat")
  for year in years, ec in ecs
    @finite_math PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+
      Expenses[tech,year]*sum(PERRemoved[eu,tech,ec,area,Yr(2021)] for eu in Enduses)/
          PERRemovedTotal[tech,Yr(2021)]
  end
  WriteDisk(db,"$Input/PInvExo",PInvExo) 
end

function PolicyControl(db)
  @info "Ind_NG.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
     PolicyControl(DB)
end

end
