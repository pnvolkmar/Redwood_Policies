#
# CFS_LiquidMarket_CN.jl
#

using SmallModel

module CFS_LiquidMarket_CN

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  EIType::SetArray = ReadDisk(db,"E2020DB/EITypeKey")
  EITypeDS::SetArray = ReadDisk(db,"E2020DB/EITypeDS")
  EITypes::Vector{Int} = collect(Select(EIType))
  ES::SetArray = ReadDisk(db,"E2020DB/ESKey")
  ESDS::SetArray = ReadDisk(db,"E2020DB/ESDS")
  ESs::Vector{Int} = collect(Select(ES))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Market::SetArray = ReadDisk(db,"E2020DB/MarketKey")
  Markets::Vector{Int} = collect(Select(Market))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation 
  AreaMarket::VariableArray{3} = ReadDisk(db,"SInput/AreaMarket") # [Area,Market,Year] Areas included in Market
  CapTrade::VariableArray{2} = ReadDisk(db,"SInput/CapTrade") # [Market,Year] Emission Trading Switch (5=GHG Cap and Trade,6=CFS Market)
  CgCredits::VariableArray{2} = ReadDisk(db,"SInput/CgCredits") # [Market,Year] CFS Credits for Cogeneration (Tonnes/GWh)
  CgDemandRef::VariableArray{4} = ReadDisk(BCNameDB,"SOutput/CgDemand") # [Fuel,ECC,Area,Year] Cogeneration Demands (TBtu/Yr)
  CoverageCFS::VariableArray{4} = ReadDisk(db,"SInput/CoverageCFS") # [Fuel,ECC,Area,Year] Coverage for CFS (1=Covered)
  CreditsFossilLimit::VariableArray{3} = ReadDisk(db,"SInput/CreditsFossilLimit") # [ECC,Area,Year] Limit Fossil Credits used to meet Obligations (Tonnes/Tonne)
  CreditSwitch::VariableArray{4} = ReadDisk(db,"SInput/CreditSwitch") # [Fuel,ECC,Area,Year] Switch to Indicate Fuels which must Purchase CFS Credits (1=Purchase)
  DemandCFSRef::VariableArray{4} = ReadDisk(BCNameDB,"SOutput/DemandCFS") # [Fuel,ECC,Area,Year] Energy Demands for CFS (TBtu/Yr)
  DirectCredits::VariableArray{2} = ReadDisk(db,"SInput/DirectCredits") # [Market,Year] Direct Emission Reduction Credits (Tonnes/Tonnes)
  DmdFuelTechRef::VariableArray{6} = ReadDisk(BCNameDB,"$Outpt/DmdFuelTech") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands in Reference Case  (TBtu/Yr)
  ECCMarket::VariableArray{3} = ReadDisk(db,"SInput/ECCMarket") # [ECC,Market,Year] Economic Categories included in Market
  EIAverage::VariableArray{2} = ReadDisk(db,"SInput/EIAverage") # [Market,Year] Weighted Average EI of Stream (Tonne/TBtu)
  EICreditMult::VariableArray{6} = ReadDisk(db,"$Input/EICreditMult") # [Enduse,Fuel,Tech,EC,Area,Year] Multipler for CFS Credits (Tonne/Tonne)
  EIGoal::VariableArray{6} = ReadDisk(db,"$Outpt/EIGoal") # [Enduse,Fuel,Tech,EC,Area,Year] Emission Intensity Goal for CFS (Tonnes/TBtu)
  EIGoalCFS::VariableArray{4} = ReadDisk(db,"SInput/EIGoalCFS") # [Fuel,ES,Area,Year] Emission Intensity Goal for CFS (Tonnes/TBtu)
  EINationRef::VariableArray{4} = ReadDisk(BCNameDB,"SOutput/EINation") # [EIType,Fuel,Nation,Year] Emission Intensity (Tonnes/TBtu)
  EIOfficial::VariableArray{3} = ReadDisk(db,"SInput/EIOfficial") # [Fuel,Area,Year] Official Value for Emission Intensity (Tonnes/TBtu)
  EIReduction::VariableArray{2} = ReadDisk(db,"SInput/EIReduction") # [Market,Year] EI Reduction Requirement (Tonne/TBtu)
  EIStreamCredit::VariableArray{2} = ReadDisk(db,"SInput/EIStreamCredit") # [Market,Year] Stream Credit Reference Emission Intensity (Tonnes/TBtu)
  Enforce::VariableArray{1} = ReadDisk(db,"SInput/Enforce") # [Market] First Year CFS Limits are Enforced (Year)
  ETABY::VariableArray{1} = ReadDisk(db,"SInput/ETABY") # [Market] Base Year for CFS (Year)
  ETADAP::VariableArray{2} = ReadDisk(db,"SInput/ETADAP") # [Market,Year] Cost of Domestic Allowances from Government (Real US$/Tonne)
  ETAFAP::VariableArray{2} = ReadDisk(db,"SInput/ETAFAP") # [Market,Year] Cost of Exogenous Credit Grant (US$/Tonne)
  ETAIncr::VariableArray{2} = ReadDisk(db,"SInput/ETAIncr") # [Market,Year] Increment in Allowance Price if Goal is not met ($/$)
  ETRSw::VariableArray{1} = ReadDisk(db,"SInput/ETRSw") # [Market] Permit Cost Switch (1=Iterate Credits,2=Iterate Emissions,0=Exogenous)
  EuDemandRef::VariableArray{4} = ReadDisk(BCNameDB,"SOutput/EuDemand") # [Fuel,ECC,Area,Year] Enduse Energy Demands (TBtu/Yr)
  FuCredits::VariableArray{2} = ReadDisk(db,"SInput/FuCredits") # [Market,Year] Fugitive Emission Reduction Credits (Tonnes/Tonnes)
  ISaleSw::VariableArray{2} = ReadDisk(db,"SInput/ISaleSw") # [Market,Year] Switch for Unlimited Sales (1=International Permits,2=Domestic Permits)
  MaxIter::VariableArray{1} = ReadDisk(db,"SInput/MaxIter") # Maximum Number of Iterations (Number)  
  ObligatedCFS::VariableArray{3} = ReadDisk(db,"SInput/ObligatedCFS") # [ECC,Area,Year] Obligated Sectors for CFS Emission Reductions (1=Obligated)
  OverLimit::VariableArray{2} = ReadDisk(db,"SInput/OverLimit") # [Market,Year] Overage Limit as a Fraction (Tonne/Tonne)
  PBnkSw::VariableArray{2} = ReadDisk(db,"SInput/PBnkSw") # [Market,Year] Credit Banking Switch (1=Buy and Sell Out of Inventory)
  PollMarket::VariableArray{3} = ReadDisk(db,"SInput/PollMarket") # [Poll,Market,Year] Pollutants included in Market
  SqCredits::VariableArray{2} = ReadDisk(db,"SInput/SqCredits") # [Market,Year] Sequestering Credits (Tonnes/Tonnes)
  SqC0::VariableArray{3} = ReadDisk(db,"MEInput/SqC0") # [ECC,Area,Year] C Term in eCO2 Sequestering Curve (2012 CN$)
  xExchangeRateNation::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRateNation") # [Nation,Year] Local Currency/US\$ Exchange Rate (Local/US\$)
  xFSell::VariableArray{2} = ReadDisk(db,"SInput/xFSell") # [Market,Year] Exogenous Federal Permits Sold (Tonnes/Yr)
  xInflationNation::VariableArray{2} = ReadDisk(db,"MInput/xInflationNation") # [Nation,Year] Inflation Index
  xISell::VariableArray{2} = ReadDisk(db,"SInput/xISell") # [Market,Year] Exogenous Credit Grant (Tonnes/Yr)

  # Scratch Variables
  # BaseYearCFS   'Base year for Emission Reductions and Electricity Demands (Year)' 
  DemandFossil::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Fossil Fuel Demands (TBtu/Yr)
  DemandPassenger::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Renewable Passenger Fuel Demands (TBtu/Yr)
  DemandRenew::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Renewable Fuel Demands (TBtu/Yr)
  EICreditMultMult::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Multipler for Multiplier for CFS Credits (Tonne/Tonne)
  EIStreamReference::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Stream Reference Emission Intensity (Tonnes/TBtu)
  # KJBtu    'Kilo Joule per BTU'   
  TransMultiplier::VariableArray{1} = zeros(Float64,length(Fuel)) # [Fuel] Multipler for transportation credits (1/1)
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Input,Outpt) = data
  (; Area,Areas,EC,ECs,ECC,ECCs) = data
  (; Enduses,EITypes) = data
  (; ES,ESs,Fuel,Fuels) = data
  (; Nation,Poll,Polls) = data
  (; Tech,Techs,Year,Years) = data
  (; ANMap,AreaMarket,CapTrade,CgCredits,CgDemandRef) = data
  (; CoverageCFS,CreditsFossilLimit,CreditSwitch,DemandCFSRef) = data
  (; DemandFossil,DemandRenew,DirectCredits) = data
  (; DmdFuelTechRef,ECCMarket,EIAverage,EICreditMult) = data
  (; EICreditMultMult,EIGoal,EIGoalCFS,EINationRef,EIOfficial) = data
  (; EIReduction,EIStreamCredit,EIStreamReference,Enforce) = data
  (; ETABY,ETADAP,ETAFAP,ETAIncr,ETRSw,EuDemandRef,FuCredits) = data
  (; ISaleSw,MaxIter,ObligatedCFS,OverLimit,PBnkSw,PollMarket) = data
  (; SqCredits,SqC0,xExchangeRateNation) = data
  (; xFSell,xInflationNation,xISell) = data

  #########################
  #
  market = 205

  #
  ########################
  #
  # First Year CFS Limits are Enforced
  #
  Enforce[market] = 2022
  WriteDisk(db,"SInput/Enforce",Enforce)
  Current = Int(Enforce[market]-ITime+1)
  years = collect(Current:Final)

  #
  ########################
  #
  # Base year for Emission Reductions and Electricity Demands
  #
  ETABY[market] = 2022
  WriteDisk(db,"SInput/ETABY",ETABY)
  BaseYearCFS = Int(ETABY[market]-ITime+1)

  #
  ########################
  #
  # Areas Covered
  #
  for year in years, area in Areas
    AreaMarket[area,market,year] = 0
  end

  areas = Select(Area,["ON","QC","BC","AB","MB","SK","NB","NS","NL","PE","YT","NT","NU"])
  for year in years, area in areas
    AreaMarket[area,market,year] = 1
  end
  WriteDisk(db,"SInput/AreaMarket",AreaMarket)

  #
  ########################
  #
  # Sector Coverages
  #
  for year in years, ecc in ECCs
    ECCMarket[ecc,market,year] = 1
  end
  WriteDisk(db,"SInput/ECCMarket",ECCMarket)

  #
  ########################
  #
  # Emissions Covered
  #
  for year in years,poll in Polls
    PollMarket[poll,market,year] = 0
  end

  polls = Select(Poll,["CO2","CH4","N2O","SF6","PFC","HFC"])
  for year in years, poll in polls
    PollMarket[poll,market,year] = 1
  end
  WriteDisk(db,"SInput/PollMarket",PollMarket)

  #
  ########################
  #
  # Emission Trading Switch (5=GHG Cap and Trade, 6=CFS Market)
  #
  for year in years
    CapTrade[market,year] = 6
  end
  WriteDisk(db,"SInput/CapTrade",CapTrade)

  #
  ########################
  #
  # Credit Cost Switch
  #
  ETRSw[market] = 1
  WriteDisk(db,"SInput/ETRSw",ETRSw)

  #
  ########################
  #
  # Maximum Number of Iterations
  #
  MaxIter[1] = max(MaxIter[1],1)
  WriteDisk(db,"SInput/MaxIter",MaxIter)

  #
  ########################
  #
  # Overage Limit (Fraction)
  #
  for year in years
    OverLimit[market,year] = 0.001
  end
  WriteDisk(db,"SInput/OverLimit",OverLimit)

  #
  ########################
  #
  # Price change increment
  #
  for year in years
    ETAIncr[market,year] = 0.75
  end
  WriteDisk(db,"SInput/ETAIncr",ETAIncr)

  #
  ########################
  #
  # Credit Banking Switch
  #
  for year in years
    PBnkSw[market,year] = 1
  end
  WriteDisk(db,"SInput/PBnkSw",PBnkSw)

  #
  ########################
  #
  # Tech Fund Credits
  #
  # Unlimited Tech Fund Credits (TIF)
  #
  for year in years
    ISaleSw[market,year] = 2
  end
  WriteDisk(db,"SInput/ISaleSw",ISaleSw)

  #
  # Tech Fund Credit Prices (default is high price)
  #
  CN = Select(Nation,"CN")
  US = Select(Nation,"US")
  for year in years
    ETADAP[market,year] = 1000/xExchangeRateNation[CN,year]/
      xInflationNation[US,year]
  end
  WriteDisk(db,"SInput/ETADAP",ETADAP)

  #
  # Unlimited Tech Fund Credits
  #
  for year in years
    xFSell[market,year] = 1e12
  end
  WriteDisk(db,"SInput/xFSell",xFSell)

  #
  ########################
  #
  # Coverage for CFS Liquid Market
  #

  #
  # Liquid Stream
  #
  eccs = Select(ECC,["Wholesale","Retail","Warehouse","Information",
    "Offices","Education","Health","OtherCommercial","NGDistribution",
    "OilPipeline","NGPipeline",
    "Food","Textiles","Lumber","Furniture","PulpPaperMills","Petrochemicals",
    "IndustrialGas","OtherChemicals","Fertilizer","Petroleum","Rubber",
    "Cement","Glass","LimeGypsum","OtherNonMetallic","IronSteel","Aluminum",
    "OtherNonferrous","TransportEquipment","OtherManufacturing",
    "IronOreMining","OtherMetalMining","NonMetalMining","LightOilMining",
    "HeavyOilMining","FrontierOilMining","PrimaryOilSands","SAGDOilSands",
    "CSSOilSands","OilSandsMining","OilSandsUpgraders","ConventionalGasProduction",
    "SweetGasProcessing","UnconventionalGasProduction","SourGasProcessing",
    "LNGProduction","CoalMining","Construction","OnFarmFuelUse",
    "Passenger","Freight","AirPassenger","AirFreight","ResidentialOffRoad",
    "CommercialOffRoad","UtilityGen"])
    
    fuels = Select(Fuel,["AviationGasoline","Biodiesel","Biojet","Diesel",
                         "Ethanol","Gasoline","JetFuel","Kerosene"])

    for year in years, area in areas, ecc in eccs, fuel in fuels
      CoverageCFS[fuel,ecc,area,year] = 1
    end

  #
  # Transportation
  #
  eccs = Select(ECC,["Passenger","Freight","ResidentialOffRoad","CommercialOffRoad"])
  fuels = Select(Fuel,["Electric","Hydrogen","LPG","NaturalGas","RNG"])
  for year in years, area in areas, ecc in eccs, fuel in fuels
    CoverageCFS[fuel,ecc,area,year] = 1
  end

  #
  # Gaseous Stream
  #
  eccs = Select(ECC,["Wholesale","Retail","Warehouse","Information",
    "Offices","Education","Health","OtherCommercial","NGDistribution",
    "OilPipeline","NGPipeline",
    "Food","Textiles","Lumber","Furniture","PulpPaperMills","Petrochemicals",
    "IndustrialGas","OtherChemicals","Fertilizer","Petroleum","Rubber",
    "Cement","Glass","LimeGypsum","OtherNonMetallic","IronSteel","Aluminum",
    "OtherNonferrous","TransportEquipment","OtherManufacturing",
    "IronOreMining","OtherMetalMining","NonMetalMining","LightOilMining",
    "HeavyOilMining","FrontierOilMining","PrimaryOilSands","SAGDOilSands",
    "CSSOilSands","OilSandsMining","OilSandsUpgraders","ConventionalGasProduction",
    "SweetGasProcessing","UnconventionalGasProduction","SourGasProcessing",
    "LNGProduction","CoalMining","Construction","OnFarmFuelUse","UtilityGen"])
    
  fuels = Select(Fuel,["Hydrogen","LPG","NaturalGas","RNG"])
  
  for year in years, area in areas, ecc in eccs, fuel in fuels
    CoverageCFS[fuel,ecc,area,year] = 1
  end

  WriteDisk(db,"SInput/CoverageCFS",CoverageCFS)

  #
  ########################
  #
  for year in years, area in areas, ecc in ECCs
    CreditsFossilLimit[ecc,area,year] = 0.10
  end

  WriteDisk(db,"SInput/CreditsFossilLimit",CreditsFossilLimit)

  #
  ########################
  #
  # Switch to Indicate Fuels which must Purchase CFS Credits
  #
  for year in years, area in areas, ecc in ECCs, fuel in Fuels
    CreditSwitch[fuel,ecc,area,year] = 0.0
  end

  fuels = Select(Fuel,["AviationGasoline","Diesel","Gasoline","JetFuel","Kerosene"])
  for year in years, area in areas,ecc in ECCs,fuel in fuels
    CreditSwitch[fuel,ecc,area,year] = 1.0
  end
  for area in areas,ecc in ECCs,fuel in fuels
    CreditSwitch[fuel,ecc,area,Yr(2022)] = 0.5
  end

  WriteDisk(db,"SInput/CreditSwitch",CreditSwitch)

  #
  ########################
  #
  # Liquid Market Sectors Obligated to meet CFS
  #
  eccs = Select(ECC,["OilPipeline","Petroleum","LightOilMining","HeavyOilMining",
      "PrimaryOilSands","SAGDOilSands","CSSOilSands","OilSandsMining",
      "OilSandsUpgraders","BiofuelProduction","H2Production"])
  for year in years, area in areas, ecc in eccs
    ObligatedCFS[ecc,area,year] = 1.0
  end
  
  WriteDisk(db,"SInput/ObligatedCFS",ObligatedCFS)

  #
  ########################
  #
  # Official Value (National) for Emission Intensity
  #
  KJBtu = 1.054615
  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)

  for year in Years, area in areas,fuel in Fuels
    EIOfficial[fuel,area,year] = 
      sum(EINationRef[ei,fuel,CN,BaseYearCFS] for ei in EITypes)
  end
  coal = Select(Fuel,"Coal")
  
  #
  # Source: "Default CIs for Jeff.xlsx" from Matt Lewis email 6/22/21
  # 
  area1 = 1
  fuels = Select(Fuel,["Gasoline","Diesel","Kerosene","JetFuel","Ethanol",
                       "Biodiesel","Biojet","NaturalGas","RNG","LPG","Hydrogen"])
  # EIOfficial
  # Fuel type      (g CO2e/MJ)
  # Liquid             91.4
  EIOfficial[Select(Fuel,"Gasoline"),area1,Current]   = 94.8*KJBtu*1000
  EIOfficial[Select(Fuel,"Diesel"),area1,Current]     = 93.2*KJBtu*1000
  # EIOfficial[Select(Fuel,"LFO"),area1,Current]      = 93.3*KJBtu*1000
  # EIOfficial[Select(Fuel,"HFO"),area1,Current]      = 93.6*KJBtu*1000
  EIOfficial[Select(Fuel,"Kerosene"),area1,Current]   = 85.2*KJBtu*1000
  # "AviationGasoline"
  EIOfficial[Select(Fuel,"JetFuel"),area1,Current]    = 88.0*KJBtu*1000
  EIOfficial[Select(Fuel,"Ethanol"),area1,Current]    = 49.0*KJBtu*1000
  EIOfficial[Select(Fuel,"Biodiesel"),area1,Current]  = 26.0*KJBtu*1000
  # EIOfficial[Select(Fuel,"HDRD"),area1,Current]     = 29.0*KJBtu*1000
  # "HDRD in LFO"                                    = 29.0*KJBtu*1000
  EIOfficial[Select(Fuel,"Biojet"),area1,Current]     = 30.0*KJBtu*1000
  EIOfficial[Select(Fuel,"NaturalGas"),area1,Current] = 78.37*KJBtu*1000
  EIOfficial[Select(Fuel,"RNG"),area1,Current]        = 8.09*KJBtu*1000
  EIOfficial[Select(Fuel,"LPG"),area1,Current]        = 75.0*KJBtu*1000
  EIOfficial[Select(Fuel,"Hydrogen"),area1,Current]   = 3.29*KJBtu*1000
 
  #
  # Increase EI of Hydrogen since it is now blue Hydrogen - Jeff Amlin 8/17/23
  # This needs to be check by Matt or someone at AMD - Jeff Amlin 8/17/23
  #
  EIOfficial[Select(Fuel,"Hydrogen"),area1,Current]   = 15.0*KJBtu*1000
  
  areas = findall(AreaMarket[:,market,Current] .== 1)
  
  for year in Years, area in areas, fuel in fuels
    EIOfficial[fuel,area,year] = EIOfficial[fuel,area1,Current]
  end

  #
  # Electricity
  #
  # Source: Schedule 6, section 9, page 158 of CG2 Regulatory Text
  # https://laws-lois.justice.gc.ca/PDF/SOR-2022-140.pdf
  # The carbon intensity of electricity in a province in which a charging
  # station is located, in gCO2e/MJ
  #
  Electric = Select(Fuel,"Electric")
  # Read EIOfficial\28(Area,Fuel,Year)
  EIOfficial[Electric,Select(Area,"BC"),Current] =  11.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"AB"),Current] = 218.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"SK"),Current] = 237.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"MB"),Current] =   7.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"ON"),Current] =  14.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"QC"),Current] =   5.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"NB"),Current] =  89.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"NS"),Current] = 224.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"PE"),Current] =   2.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"NL"),Current] =  16.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"NU"),Current] = 313.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"YT"),Current] =  30.0*KJBtu*1000
  EIOfficial[Electric,Select(Area,"NT"),Current] =  71.0*KJBtu*1000

  areas = findall(AreaMarket[:,market,Current] .== 1)

  for year in Years, area in areas
    EIOfficial[Electric,area,year] = EIOfficial[Electric,area,Current]
  end

  WriteDisk(db,"SInput/EIOfficial",EIOfficial)

  #
  ########################
  #
  # National Weighted Average EI of Stream
  #

  areas = findall(ANMap[:,CN] .== 1)

  for year in Years, area in areas, ecc in ECCs, fuel in Fuels
    DemandCFSRef[fuel,ecc,area,year] = 
      (EuDemandRef[fuel,ecc,area,year]+CgDemandRef[fuel,ecc,area,year])*
      CoverageCFS[fuel,ecc,area,year]
  end

  for year in Years
    @finite_math EIAverage[market,year] = sum(EIOfficial[fuel,area,year]*
      DemandCFSRef[fuel,ecc,area,year] for area in areas, ecc in ECCs, fuel in Fuels)/
      sum(DemandCFSRef[fuel,ecc,area,year] for area in areas, ecc in ECCs, fuel in Fuels)
  end

  WriteDisk(db,"SInput/EIAverage",EIAverage) 
  
  areas = findall(AreaMarket[:,market,Current] .== 1)

  #
  ########################
  #
  # Emission Intensity Reduction Requirement
  #
  # "Description: The proposed Clean Fuel Regulations would require liquid
  # fossil fuel primary suppliers (i.e. producers and importers) to reduce 
  # the carbon intensity (CI) of the liquid fossil fuels they produce in 
  # and import into Canada from 2016 CI levels by 2.4 gCO2e/MJ in 2022,
  # increasing to 12 gCO2e/MJ in 2030." from Canada Gazette, Part I,
  # Volume 154, Number 51: Clean Fuel Regulations, December 19, 2020
  # - Jeff Amlin 05/24/21
  # Revised from Lewis,Matthew email sent: Tuesday, April 12, 2022 3:17 PM
  # - Jeff Amlin 04/13/22
  #
  for year in Years
    EIReduction[market,year] = 0
  end

  EIReduction[market,Yr(2022)] =  0.00
  EIReduction[market,Yr(2023)] =  3.50
  EIReduction[market,Yr(2024)] =  5.00
  EIReduction[market,Yr(2025)] =  6.50
  EIReduction[market,Yr(2026)] =  8.00
  EIReduction[market,Yr(2027)] =  9.50
  EIReduction[market,Yr(2028)] = 11.00
  EIReduction[market,Yr(2029)] = 12.50
  EIReduction[market,Yr(2030)] = 14.00

  years = collect(Yr(2022):Yr(2030))
  for year in years
    EIReduction[market,year] = EIReduction[market,year]*KJBtu*1000
  end

  years = collect(Yr(2031):Final)
  for year in years
    EIReduction[market,year] = EIReduction[market,year-1]
  end
  WriteDisk(db,"SInput/EIReduction",EIReduction)

  #
  ########################
  #
  # Stream Credit Reference Emisssion Intensity
  #
  fuels = Select(Fuel,["AviationGasoline","Diesel","Gasoline","JetFuel","Kerosene","LPG","NaturalGas"])
  for year in Years
    DemandFossil[year] = sum(DemandCFSRef[fuel,ecc,area,year]*
      CoverageCFS[fuel,ecc,area,year] for area in areas, ecc in ECCs, fuel in fuels)
  end

  fuels = Select(Fuel,["Biodiesel","Biojet","Ethanol","Electric","Hydrogen","RNG"])
  for year in Years
    DemandRenew[year] = sum(DemandCFSRef[fuel,ecc,area,year]*
      CoverageCFS[fuel,ecc,area,year] for area in areas, ecc in ECCs, fuel in fuels)
  end

  for year in Years
    @finite_math EIStreamCredit[market,year] = (EIAverage[market,year]-
      EIReduction[market,year])*DemandFossil[year]/(DemandFossil[year]+
        DemandRenew[year])
  end

  #
  # Revised from Lewis,Matthew email sent: Tuesday, April 12, 2022 3:17 PM
  # - Jeff Amlin 04/13/22
  #
  for year in Years
    EIStreamReference[year] = 89.2
  end
  EIStreamReference[Yr(2022)] = 89.2
  EIStreamReference[Yr(2023)] = 89.2
  EIStreamReference[Yr(2024)] = 87.9
  EIStreamReference[Yr(2025)] = 86.6
  EIStreamReference[Yr(2026)] = 85.3
  EIStreamReference[Yr(2027)] = 84.0
  EIStreamReference[Yr(2028)] = 82.7
  EIStreamReference[Yr(2029)] = 81.4
  EIStreamReference[Yr(2030)] = 80.1
  
  years = collect(Yr(2031):Yr(2050))
  for year in years
    EIStreamReference[year] = EIStreamReference[Yr(2030)]
  end

  years = collect(Current:Final)
  for year in Years
    EIStreamReference[year] = EIStreamReference[year]*KJBtu*1000
  end

  for year in Years
    EIStreamCredit[market,year] = EIStreamReference[year]-EIReduction[market,year]
  end

  WriteDisk(db,"SInput/EIStreamCredit",EIStreamCredit)

  #
  ########################
  #
  # Emission Intensity Goal for CFS 
  #
  areas = Areas
  electric = Select(Fuel, "Electric")
  transport = Select(ES, "Transport")
  row = Select(Area, "ROW")
  yr2050 = Select(Year, "2050")
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 = 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)
  for year in Years, area in areas, es in ESs, fuel in Fuels
    EIGoalCFS[fuel,es,area,year] = 0
  end
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  #
  # Fossil Fuels (which are not Low Carbon Fuels)
  #
  fuels = Select(Fuel,["AviationGasoline","Diesel","Gasoline","JetFuel","Kerosene"])
  for year in Years, area in areas, es in ESs, fuel in fuels
    EIGoalCFS[fuel,es,area,year] = EIOfficial[fuel,area,year]-EIReduction[market,year]
  end
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  #
  # Low Carbon Fuels (including Low Carbon Fossil Fuels)
  #
  fuels = Select(Fuel,["Biodiesel","Biojet","Ethanol"])
  for year in Years, area in areas, es in ESs, fuel in fuels
    EIGoalCFS[fuel,es,area,year] = EIStreamCredit[market,year]
  end
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  #
  # Gaseous Stream is based on Natural Gas
  #
  fuels = Select(Fuel,["Hydrogen","LPG","NaturalGas","RNG"])
  for year in Years, area in areas, es in ESs, fuel in fuels
    EIGoalCFS[fuel,es,area,year] = EIOfficial[Select(Fuel,"NaturalGas"),area,year]
  end
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  WriteDisk(db,"SInput/EIGoalCFS", EIGoalCFS)

  #
  #########################
  #
  # Cogeneration Credits
  # Source: "Credits are based on the following emissions standards:
  #          boiler emission intensity of 223t CO2/GWh(thermal),
  #          the Alberta electricity grid emission intensity of 670t CO2/GWh(electric)"
  # Source: "Low Carbon Intensity electricity generation (ie solar panels and wind
  #          turbines) are only granted credits when they are directly producing
  #          electricity for a refinery or upgrader. I think this means cogeneration
  #          is out as a way to generate credits."
  #          From: Matthew Lewis Email on Friday, May 28, 2021 10:57 AM
  #          Jeff Amlin 6/22/21
  #
  for year in years
    CgCredits[market,year] = 0
  end

  WriteDisk(db,"SInput/CgCredits",CgCredits)

  #
  ########################
  #
  for year in years
    DirectCredits[market,year] = 1
  end
  DirectCredits[market,Yr(2022)] = 0.5
  WriteDisk(db,"SInput/DirectCredits",DirectCredits)

  for year in years
    FuCredits[market,year] = 1
  end
  FuCredits[market,Yr(2022)] = 0.5
  WriteDisk(db,"SInput/FuCredits",FuCredits)

  for year in years
    SqCredits[market,year] = 1
  end
  SqCredits[market,Yr(2022)] = 0.5
  WriteDisk(db,"SInput/SqCredits",SqCredits)

  #########################
  #
  # No new building between 2027 and 2030
  #
  eccs = Select(ECC,["SAGDOilSands","CSSOilSands","OilSandsMining","OilSandsUpgraders","HeavyOilMining","Petroleum"])
  years = collect(Yr(2027):Yr(2031))
  for year in years, area in areas, ecc in eccs
    SqC0[ecc,area,year] = 0.0
  end
  years = collect(Yr(2032):Yr(2035))
  for year in years, area in areas, ecc in eccs
    SqC0[ecc,area,year] = SqC0[ecc,area,year-1]+(SqC0[ecc,area,Yr(2036)]- 
      SqC0[ecc,area,Yr(2031)])/(2036-2031)
  end
  WriteDisk(db,"MEInput/SqC0",SqC0)

  #
  # Transportation vehicles receive a multiplier to credits when switching from
  # gasoline. Values below provided by Matt on 02/14/20
  #
  # 4.1x - Electric vehicles for light- and medium-duty application (replacing gasoline)                                    
  # 5.0x - Electric vehicles for on-road heavy-duty applications and off-road vehicles (replacing diesel)
  # 3.3x - Electric trains
  # 3.1x - Electric commercial marine vessels
  # 2.0x - Hydrogen fuel cell vehicles for light- and medium-duty applications (replacing gasoline)      
  # 1.9x - Hydrogen fuel cell vehicles for on-road heavy-duty applications and off-road vehicles (replacing diesel)
  #
  # Note, after a DBClose, CloseDB, all sets are reset
  # 
  
  # areas = Areas
  
  for year in Years, area in areas, ec in ECs, tech in Techs, fuel in Fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 1.0
  end

  fuels = Select(Fuel,"Electric")
  ecs =  Select(EC,"Passenger")

  techs = Select(Tech,["LDVElectric","LDVHybrid","LDTElectric","LDTHybrid"])
  for year in Years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 4.1
  end

  techs = Select(Tech,"TrainElectric")
  for year in Years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 3.3
  end

  ecs =  Select(EC,["Freight","ResidentialOffRoad","CommercialOffRoad"])
  techs = Select(Tech,["HDV2B3Electric","HDV45Electric","HDV67Electric","HDV8Electric","OffRoad"])
  for year in Years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 5.0
  end

  fuels = Select(Fuel,"Hydrogen")

  ecs =  Select(EC,"Passenger")
  techs = Select(Tech,["LDVFuelCell","LDTFuelCell","BusFuelCell","TrainFuelCell"])
  for year in Years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 2.0
  end

  ecs =  Select(EC,["Freight","ResidentialOffRoad","CommercialOffRoad"])
  techs = Select(Tech,["HDV2B3FuelCell","HDV45FuelCell","HDV67FuelCell","HDV8FuelCell",
                      "TrainFuelCell","MarineFuelCell","OffRoad"])
  for year in Years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses 
    EICreditMult[enduse,fuel,tech,ec,area,year] = 1.9
  end

  #
  # "Credit for residential charging of electric vehicles would be phased
  # out by the end of 2035 for charging stations installed by the end of 
  # 2030. Any residential charging station installed after the end of 2030
  # would not be eligible for credits after 2030." Canada Gazette, Part I,
  # Volume 154, Number 51: Clean Fuel Regulations,December 19, 2020.
  #
  # "Our working assumption was that 80% of residential charging is done at home.
  # I note in the RIAS that this was changed to 72%, so essentially we need a 
  # schedule of electric credits from LDV Electric, LDT Electric, LDV Hybrid 
  # and LDT Hybrid from 2031 to 2035. This schedule will account for the charging
  # of pre 2031 residential vehicles, plus 28% of incremental vehicles up to 2035.
  # For 2036 onwards, the restriction is just 28% of all electric demand from LDV
  # Electric, LDT Electric, LDV Hybrid and LDT Hybrid." 
  # From: Matthew Lewis Email on Monday, October 24, 2022 12:49 PM
  # Jeff Amlin 10/24/22
  #
  # Revised assumptions: Creditable ZEVs are public charging (28%)
  # and smart meter home charging (variable). New schedule below combines
  # these assumptions with post 2030 phase out.
  # Matt Lewis March 1 2023
  #
  ecs =  Select(EC,"Passenger")
  fuels = Select(Fuel,"Electric")
  techs = Select(Tech,["LDVElectric","LDVHybrid","LDTElectric","LDTHybrid"])
  years_mult = Select(Year,( from = "2022",to = "2035"))
  #! format: off
  EICreditMultMult[years_mult] = [
    #2022 2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035
     0.38 0.41 0.43 0.46 0.48 0.51 0.53 0.56 0.58 0.54 0.49 0.43 0.36 0.28
  ]
  for year in years_mult
    print("\nYear: ")
    print(Year[year])
    print(" MultMult: ")
    print(EICreditMultMult[year])
  end
  years = collect(Yr(2036):Yr(2050))
  for year in years
    EICreditMultMult[year] = EICreditMultMult[Yr(2035)]
  end

  years = collect(Yr(2022):Yr(2050))
  for year in years, area in areas, ec in ecs, tech in techs, fuel in fuels, enduse in Enduses
    EICreditMult[enduse,fuel,tech,ec,area,year] = 
      EICreditMult[enduse,fuel,tech,ec,area,year]*EICreditMultMult[year]
  end
  years = collect(Current:Final)
  
  WriteDisk(db,"$Input/EICreditMult",EICreditMult)
  
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  es = Select(ES,"Transport")
  for year in years, area in areas, ec in ECs, tech in Techs, fuel in Fuels, enduse in Enduses
    EIGoal[enduse,fuel,tech,ec,area,year] = EIGoalCFS[fuel,es,area,year]
  end

  fuels = Select(Fuel,["Electric","Hydrogen","LPG","NaturalGas","RNG"])
  for year in years, area in areas, ec in ECs, tech in Techs, fuel in Fuels, enduse in Enduses
    EIGoal[enduse,fuel,tech,ec,area,year] = EIStreamCredit[market,year]*
      EICreditMult[enduse,fuel,tech,ec,area,year]
  end
  WriteDisk(db,"$Outpt/EIGoal",EIGoal)
  
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)


  for year in years, area in areas, fuel in fuels
    @finite_math EIGoalCFS[fuel,es,area,year] = 
      sum(EIGoal[enduse,fuel,tech,ec,area,year]*
        DmdFuelTechRef[enduse,fuel,tech,ec,area,year] for ec in ECs,
          tech in Techs,enduse in Enduses)/
            sum(DmdFuelTechRef[enduse,fuel,tech,ec,area,year] for ec in ECs,
              tech in Techs,enduse in Enduses)
  end
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  WriteDisk(db,"SInput/EIGoalCFS", EIGoalCFS)
  
  loc1 = EIGoalCFS[electric,transport,row,yr2050]
  loc2 += 1
  print("\nEIGoalCFS[electric,transport,row,yr2050] = ")
  print(loc1)
  print(" Iter No: ")
  print(loc2)

  #########################
  #
  # There is an exogenous grant of 1.4 million credits in 2024 for 
  # the transition of the renewable fuel regulation to the CFR. 
  # This was supplied by carbon markets bureau, the group that will
  # be operating the credit market.
  #
  for year in years
    ETAFAP[market,year] = 0
    xISell[market,year] = 0
  end
  xISell[market,Yr(2024)] = 1400000

  WriteDisk(db,"SInput/ETAFAP",ETAFAP)
  WriteDisk(db,"SInput/xISell",xISell)
end

function PolicyControl(db)
  @info "CFS_LiquidMarket_CN.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
