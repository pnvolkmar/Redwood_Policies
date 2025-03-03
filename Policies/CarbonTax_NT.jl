#
# CarbonTax_NT.jl - Federal Carbon Tax for NT
#

using SmallModel

module CarbonTax_NT

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String

  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Market::SetArray = ReadDisk(db,"E2020DB/MarketKey")
  Markets::Vector{Int} = collect(Select(Market))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  PCov::SetArray = ReadDisk(db,"E2020DB/PCovKey")
  PCovDS::SetArray = ReadDisk(db,"E2020DB/PCovDS")
  PCovs::Vector{Int} = collect(Select(PCov))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  AreaMarket::VariableArray{3} = ReadDisk(db,"SInput/AreaMarket") # [Area,Market,Year] Areas included in Market
  CapTrade::VariableArray{2} = ReadDisk(db,"SInput/CapTrade") # [Market,Year] Emission Cap and Trading Switch (1=Trade,Cap Only=2)
  CBSw::VariableArray{2} = ReadDisk(db,"SInput/CBSw") # [Market,Year] Switch to send Government Revenues to TIM (1=Yes)
  CoverNew::VariableArray{4} = ReadDisk(db,"EGInput/CoverNew") # [Plant,Poll,Area,Year] Fraction of New Plants Covered in Emissions Market (1=100% Covered)
  ECCMarket::VariableArray{3} = ReadDisk(db,"SInput/ECCMarket") # [ECC,Market,Year] Economic Categories included in Market
  ECoverage::VariableArray{5} = ReadDisk(db,"SInput/ECoverage") # [ECC,Poll,PCov,Area,Year] Emissions Coverage Before Gratis Permits (1=Covered)
  Enforce::VariableArray{1} = ReadDisk(db,"SInput/Enforce") # [Market] First Year Market Limits are Enforced (Year)
  ETABY::VariableArray{1} = ReadDisk(db,"SInput/ETABY") # [Market] Beginning Year for Emission Trading Allowances (Year)
  ETAPr::VariableArray{2} = ReadDisk(db,"SOutput/ETAPr") # [Market,Year] Cost of Emission Trading Allowances (US$/Tonne)
  PCost::VariableArray{4} = ReadDisk(db,"SOutput/PCost") # [ECC,Poll,Area,Year] Permit Cost (Real $/Tonnes)
  PCovMap::VariableArray{5} = ReadDisk(db,"SInput/PCovMap") # [FuelEP,ECC,PCov,Area,Year] Pollution Coverage Map (1=Mapped)
  PCovMarket::VariableArray{3} = ReadDisk(db,"SInput/PCovMarket") # [PCov,Market,Year] Types of Pollution included in Market
  PolConv::VariableArray{1} = ReadDisk(db,"SInput/PolConv") # [Poll] Pollution Conversion Factor (convert GHGs to eCO2)
  PolCovRef::VariableArray{5} = ReadDisk(db,"SInput/BaPolCov") #[ECC,Poll,PCov,Area,Year]  Reference Case Covered Pollution (Tonnes/Yr)
  PollMarket::VariableArray{3} = ReadDisk(db,"SInput/PollMarket") # [Poll,Market,Year] Pollutants included in Market
  PolTotRef::VariableArray{5} = ReadDisk(BCNameDB,"SOutput/PolTot") # [ECC,Poll,PCov,Area,Year] Reference Pollution (Tonnes/Yr)
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnCoverage::VariableArray{3} = ReadDisk(db,"EGInput/UnCoverage") # [Unit,Poll,Year] Fraction of Unit Covered in Emission Market (1=100% Covered)
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnSector::Array{String} = ReadDisk(db,"EGInput/UnSector") # [Unit] Unit Type (Utility or Industry)
  xETAPr::VariableArray{2} = ReadDisk(db,"SInput/xETAPr") # [Market,Year] Exogenous Cost of Emission Trading Allowances (1985 US$/Tonne)
  xExchangeRate::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRate") # [Area,Year] Local Currency/US$ Exchange Rate (Local/US$)
  xExchangeRateNation::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRateNation") # [Nation,Year] Local Currency/US\$ Exchange Rate (Local/US\$)
  xInflationNation::VariableArray{2} = ReadDisk(db,"MInput/xInflationNation") # [Nation,Year] Inflation Index

  # Scratch Variables
  # YrFinal  'Final Year for GHG Market or Tax (Year)'
end

function GetUnitSets(data,unit)
  (; Area,ECC) = data
  (; UnArea,UnSector) = data

  #
  # This procedure selects the sets for a particular unit
  #
  
  if (UnArea[unit] !== "") && (UnSector[unit] !== "")
    # genco = Select(GenCo,UnGenCo[unit])
    # plant = Select(Plant,UnPlant[unit])
    # node = Select(Node,UnNode[unit])
    area = Select(Area,UnArea[unit])
    ecc = Select(ECC,UnSector[unit])
    return area,ecc
    # return genco,plant,node,area,ecc
  end
end

function DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

    areas = findall(AreaMarket[:,market,YrFinal] .== 1)
    eccs =  findall(ECCMarket[:,market,YrFinal] .== 1)    
    pcovs = findall(PCovMarket[:,market,YrFinal] .== 1) 
    polls = findall(PollMarket[:,market,YrFinal] .== 1) 
    years = collect(Current:YrFinal)
    return areas,eccs,pcovs,polls,years
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,Areas,ECC,ECCs) = data
  (; FuelEP) = data
  (; Nation,PCov,PCovs) = data
  (; Plants) = data
  (; Poll,Polls,Units,Years) = data
  (; AreaMarket,CapTrade,CBSw,CoverNew) = data
  (; ECCMarket,ECoverage,Enforce,ETABY,ETAPr) = data
  (; PCost,PCovMap,PCovMarket,PolConv,PolCovRef) = data
  (; PollMarket,PolTotRef,UnArea,UnCoverage) = data
  (; UnSector,xETAPr) = data
  (; xExchangeRate,xExchangeRateNation,xInflationNation) = data

  #########################
  #
  # Federal Carbon Tax for NT
  #
  market = 128

  #########################
  #
  # Market Timing
  #
  Enforce[market] = 2019
  YrFinal = Int(2050 - ITime + 1)
  ETABY[market] = Enforce[market]
  Current = Int(Enforce[market] - ITime + 1)
  Prior = Int(Current - 1)

  WriteDisk(db,"SInput/Enforce",Enforce)
  WriteDisk(db,"SInput/ETABY",ETABY)

  years::Vector{Int} = collect(Current:YrFinal)
  
  #########################
  #
  # Areas Covered
  #
  for year in years, area in Areas
    AreaMarket[area,market,year] = 0
  end

  areas = Select(Area,"NT")
  for year in years, area in areas
    AreaMarket[area,market,year] = 1
  end
  WriteDisk(db,"SInput/AreaMarket",AreaMarket)

  #########################
  #
  # Emissions Covered
  #
  for year in years, poll in Polls
    PollMarket[poll,market,year] = 0
  end

  polls = Select(Poll,["CO2","CH4","N2O"])
  for year in years, poll in polls
    PollMarket[poll,market,year] = 1
  end
  WriteDisk(db,"SInput/PollMarket",PollMarket)

  #########################
  #
  # Type of Emissions Covered
  #
  for year in years, pcov in PCovs
    PCovMarket[pcov,market,year] = 0
  end

  pcovs = Select(PCov,["Energy","Oil","NaturalGas","Cogeneration","Flaring"])
  for year in years, pcov in pcovs
    PCovMarket[pcov,market,year] = 1
  end
  WriteDisk(db,"SInput/PCovMarket",PCovMarket)

  #########################
  #
  # Sector Coverages
  #
  for year in years, ecc in ECCs
    ECCMarket[ecc,market,year] = 0
  end

  eccs = Select(ECC,["SingleFamilyDetached","SingleFamilyAttached","MultiFamily","OtherResidential",
            "Wholesale","Retail","Warehouse","Information","Offices","Education",
            "Health","OtherCommercial","NGDistribution","OilPipeline",
            "Textiles","OtherManufacturing",
            "Construction","Forestry","Furniture",
            "Passenger","Freight","AirPassenger","AirFreight","ResidentialOffRoad","CommercialOffRoad",
            "H2Production","BiofuelProduction","Steam","OnFarmFuelUse"])
  for year in years, ecc in eccs
    ECCMarket[ecc,market,year] = 1
  end
      
  #
  # Miscellaneous holds government revenues and is not covered
  #
  Miscellaneous = Select(ECC,"Miscellaneous")
  for year in years
    ECCMarket[Miscellaneous,market,year] = 0
  end
  WriteDisk(db,"SInput/ECCMarket",ECCMarket)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # Exemption for OnfarmFuelUse Gasoline and Diesel
  #
  Diesel = Select(FuelEP,"Diesel")
  Gasoline = Select(FuelEP,"Gasoline")
  OnFarmFuelUse = Select(ECC,"OnFarmFuelUse")
  for year in years, area in areas, pcov in pcovs
    PCovMap[Diesel,OnFarmFuelUse,pcov,area,year] = 0
    PCovMap[Gasoline,OnFarmFuelUse,pcov,area,year] = 0
  end
  WriteDisk(db,"SInput/PCovMap",PCovMap)

  #
  # Sector Coverages (exclude Venting and Fugitives (Process) from Oil and Gas)
  #
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    ECoverage[ecc,poll,pcov,area,year] = 1.0
  end
  
  #
  # Fraction of flights for carbon pricing coverage  
  # Source: BM Coverage assessment tool 2023-2030 - Post Cabinet decision (21.02.2023).xlsx
  # From: Fred 21.02.2023
  #
  
  eccs = Select(ECC,["AirPassenger","AirFreight"])
  for year in years, pcov in pcovs, poll in polls, ecc in eccs
    ECoverage[ecc,poll,pcov,Select(Area,"NT"),year] = 0.256
  end
  WriteDisk(db,"SInput/ECoverage",ECoverage)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # Coverage of Electric Utility and Cogeneration units 
  #
  for unit in Units
      if (UnArea[unit] !== "") && (UnSector[unit] !== "")
      area,ecc = GetUnitSets(data,unit)
      for year in years
        if (AreaMarket[area,market,year] == 1) && (ECCMarket[ecc,market,year] == 1)
          for poll in polls
            UnCoverage[unit,poll,year] = 1.0
          end
        end
      end
    end
  end
  WriteDisk(db,"EGInput/UnCoverage",UnCoverage)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  UtilityGen = Select(ECC,"UtilityGen")
  for year in years, area in areas, poll in polls, plant in Plants
    if ECCMarket[UtilityGen,market,year] == 1
      CoverNew[plant,poll,area,year] = 1
    end
  end
  WriteDisk(db,"EGInput/CoverNew",CoverNew)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # GHG Market (CapTrade=5)
  #

  for year in years
    CapTrade[market,year] = 0
  end

  years = collect(Prior:YrFinal)
  for year in years
    CapTrade[market,year] = 5
  end
  years = collect(Current:YrFinal)
  WriteDisk(db,"SInput/CapTrade",CapTrade)

  #
  # Emissions Fee goes to Government Revenues (CBSw=2.0)
  #
  for year in years
    CBSw[market,year] = 2.0
  end
  WriteDisk(db,"SInput/CBSw",CBSw)

  #########################
  #
  # Reference Case Covered Emissions (PolCov)
  # 

  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
  
    #
    # Covered Emissions 
    #
    PolCovRef[ecc,poll,pcov,area,year] = PolTotRef[ecc,poll,pcov,area,year]*
      ECoverage[ecc,poll,pcov,area,year]*PolConv[poll]
  end

  WriteDisk(db,"SInput/BaPolCov",PolCovRef)

  #########################
  # 
  # Carbon Tax - For NT,
  # the Provincial Carbon Tax becomes effective in Sept, 2019. 
  # Carbon Prices are in nominal CN$/tonne
  #
  CN = Select(Nation,"CN")
  US = Select(Nation,"US")
  # xETAPr[market,Yr(2017)] =  0.00/xExchangeRateNation[CN,Yr(2017)]/xInflationNation[US,Yr(2017)]
  # xETAPr[market,Yr(2018)] =  0.00/xExchangeRateNation[CN,Yr(2018)]/xInflationNation[US,Yr(2018)]
  # xETAPr[market,Yr(2019)] = 20.00/xExchangeRateNation[CN,Yr(2019)]/xInflationNation[US,Yr(2019)]*4/12
  # xETAPr[market,Yr(2020)] = 30.00/xExchangeRateNation[CN,Yr(2020)]/xInflationNation[US,Yr(2020)]
  # xETAPr[market,Yr(2021)] = 40.00/xExchangeRateNation[CN,Yr(2021)]/xInflationNation[US,Yr(2021)]
  # xETAPr[market,Yr(2022)] = 50.00/xExchangeRateNation[CN,Yr(2022)]/xInflationNation[US,Yr(2022)]
  xETAPr[market,Yr(2023)] = 65.00/xExchangeRateNation[CN,Yr(2023)]/xInflationNation[US,Yr(2023)]
  xETAPr[market,Yr(2024)] = 80.00/xExchangeRateNation[CN,Yr(2024)]/xInflationNation[US,Yr(2024)]
  xETAPr[market,Yr(2025)] = 95.00/xExchangeRateNation[CN,Yr(2025)]/xInflationNation[US,Yr(2025)]
  xETAPr[market,Yr(2026)] = 110.00/xExchangeRateNation[CN,Yr(2026)]/xInflationNation[US,Yr(2026)]
  xETAPr[market,Yr(2027)] = 125.00/xExchangeRateNation[CN,Yr(2027)]/xInflationNation[US,Yr(2027)]
  xETAPr[market,Yr(2028)] = 140.00/xExchangeRateNation[CN,Yr(2028)]/xInflationNation[US,Yr(2028)]
  xETAPr[market,Yr(2029)] = 155.00/xExchangeRateNation[CN,Yr(2029)]/xInflationNation[US,Yr(2029)]
  years0 = collect(Yr(2030):YrFinal)
  for year in years0
    xETAPr[market,year] = 170.00/xExchangeRateNation[CN,year]/xInflationNation[US,year]
  end

  for year in Years
    ETAPr[market,year] = xETAPr[market,year]*xInflationNation[US,year]
  end

  WriteDisk(db,"SOutput/ETAPr",ETAPr)
  WriteDisk(db,"SInput/xETAPr",xETAPr)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  for year in years, area in areas, poll in polls, ecc in eccs
    PCost[ecc,poll,area,year] = ETAPr[market,year]/PolConv[poll]/
      xInflationNation[US,year]*xExchangeRate[area,year]
  end

  WriteDisk(db,"SOutput/PCost",PCost)  
end

function PolicyControl(db)
  @info "CarbonTax_NT.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
