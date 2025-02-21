#
# CarbonTax_Fed_170.jl - Federal Carbon Levy
#

using SmallModel

module CarbonTax_Fed_170

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
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnCoverage::VariableArray{3} = ReadDisk(db,"EGInput/UnCoverage") # [Unit,Poll,Year] Fraction of Unit Covered in Emission Market (1=100% Covered)
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnSector::Array{String} = ReadDisk(db,"EGInput/UnSector") # [Unit] Unit Type (Utility or Industry)
  xETAPr::VariableArray{2} = ReadDisk(db,"SInput/xETAPr") # [Market,Year] Exogenous Cost of Emission Trading Allowances (1985 US$/Tonne)
  xExchangeRate::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRate") # [Area,Year] Local Currency/US$ Exchange Rate (Local/US$)
  xExchangeRateNation::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRateNation") # [Nation,Year] Local Currency/US\$ Exchange Rate (Local/US\$)
  xInflationNation::VariableArray{2} = ReadDisk(db,"MInput/xInflationNation") # [Nation,Year] Inflation Index
  xPolTot::VariableArray{5} = ReadDisk(db,"SInput/xPolTot") # [ECC,Poll,PCov,Area,Year] Historical Pollution (Tonnes/Yr)

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
  (; PollMarket,xPolTot,UnArea,UnCoverage) = data
  (; UnOnLine,UnSector,xETAPr) = data
  (; xExchangeRate,xExchangeRateNation,xInflationNation) = data

  #########################
  #
  # Federal Carbon Tax
  #
  market = 131

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

  areas = Select(Area,["AB","MB","ON","SK","NS","NL","NB","PE","YT","NU"])
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

  eccs = Select(ECC,["SingleFamily","MultiFamily","OtherResidential",
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
  for year in years,pcov in pcovs,poll in polls,ecc in eccs
    ECoverage[ecc,poll,pcov,Select(Area,"AB"),year] = 0.236
    ECoverage[ecc,poll,pcov,Select(Area,"MB"),year] = 0.097
    ECoverage[ecc,poll,pcov,Select(Area,"NB"),year] = 0.007
    ECoverage[ecc,poll,pcov,Select(Area,"NL"),year] = 0.113
    ECoverage[ecc,poll,pcov,Select(Area,"NS"),year] = 0.074
    ECoverage[ecc,poll,pcov,Select(Area,"NU"),year] = 0.585
    ECoverage[ecc,poll,pcov,Select(Area,"ON"),year] = 0.198
    ECoverage[ecc,poll,pcov,Select(Area,"SK"),year] = 0.085
    ECoverage[ecc,poll,pcov,Select(Area,"YT"),year] = 0.083
    ECoverage[ecc,poll,pcov,Select(Area,"PE"),year] = 0.000
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
      if (AreaMarket[area,market,Current] == 1) &&
         (ECCMarket[ecc,market,Current] == 1)  &&
         (UnOnLine[unit] > 0)
        for year in years, poll in polls
          UnCoverage[unit,poll,year] = 1.0
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
    PolCovRef[ecc,poll,pcov,area,year] = xPolTot[ecc,poll,pcov,area,year]*
      ECoverage[ecc,poll,pcov,area,year]*PolConv[poll]
  end

  WriteDisk(db,"SInput/BaPolCov",PolCovRef)

  #########################
  # 
  # The Federal Carbon Tax becomes effective in April, 2019. 
  # Carbon Prices are in nominal CN$/tonne. Convert to real US$/tonne.
  #
  CN = Select(Nation,"CN")
  US = Select(Nation,"US")
  xETAPr[market,Yr(2019)] = 20.00/xExchangeRateNation[CN,Yr(2019)]/xInflationNation[US,Yr(2019)]*9/12
  xETAPr[market,Yr(2020)] = 30.00/xExchangeRateNation[CN,Yr(2020)]/xInflationNation[US,Yr(2020)]
  xETAPr[market,Yr(2021)] = 40.00/xExchangeRateNation[CN,Yr(2021)]/xInflationNation[US,Yr(2021)]
  years = collect(Yr(2022):YrFinal)
  for year in years
    xETAPr[market,year] = 40.00/xExchangeRateNation[CN,year]/xInflationNation[US,year]
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
  @info"CarbonTax_Fed_170.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
