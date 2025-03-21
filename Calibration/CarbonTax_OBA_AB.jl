#
# CarbonTax_OBA_AB.jl - Alberta Carbon Tax with OBA
#

using SmallModel

module CarbonTax_OBA_AB

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
  Offset::SetArray = ReadDisk(db,"E2020DB/OffsetKey")
  OffsetDS::SetArray = ReadDisk(db,"E2020DB/OffsetDS")
  Offsets::Vector{Int} = collect(Select(Offset))
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
  DriverBaseline::VariableArray{3} = ReadDisk(db,"MInput/DriverBaseline") # [ECC,Area,Year] Emissions Baseline Economic Driver (Various Units/Yr)
  ECCMarket::VariableArray{3} = ReadDisk(db,"SInput/ECCMarket") # [ECC,Market,Year] Economic Categories included in Market
  ECoverage::VariableArray{5} = ReadDisk(db,"SInput/ECoverage") # [ECC,Poll,PCov,Area,Year] Emissions Coverage Before Gratis Permits (1=Covered)
  EIBaseline::VariableArray{5} = ReadDisk(db,"SInput/EIBaseline") # [ECC,Poll,PCov,Area,Year] Emission Intensity Baseline (Tonnes/Driver)
  Enforce::VariableArray{1} = ReadDisk(db,"SInput/Enforce") # [Market] First Year Market Limits are Enforced (Year)
  EuFPol::VariableArray{5} = ReadDisk(db,"SOutput/EuFPol") #[FuelEP,ECC,Poll,Area,Year]  Energy Pollution with Cogeneration (Tonnes/Yr)
  ETABY::VariableArray{1} = ReadDisk(db,"SInput/ETABY") # [Market] Beginning Year for Emission Trading Allowances (Year)
  ETADAP::VariableArray{2} = ReadDisk(db,"SInput/ETADAP") # [Market,Year] Cost of Domestic Allowances from Government (1985 US$/Tonne)
  ETAFAP::VariableArray{2} = ReadDisk(db,"SInput/ETAFAP") # [Market,Year] Cost of Foreign Allowances ($/Tonne)
  ETAMax::VariableArray{2} = ReadDisk(db,"SInput/ETAMax") # [Market,Year] Maximum Price for Allowances ($/Tonne)
  ETAMin::VariableArray{2} = ReadDisk(db,"SInput/ETAMin") # [Market,Year] Minimum Price for Allowances ($/Tonne)
  ETAPr::VariableArray{2} = ReadDisk(db,"SOutput/ETAPr") # [Market,Year] Cost of Emission Trading Allowances (US$/Tonne)
  ExYear::VariableArray{1} = ReadDisk(db,"SInput/ExYear") # [Market] Year to Define Existing Plants (Year)
  FacSw::VariableArray{1} = ReadDisk(db,"SInput/FacSw") # [Market] Facility Level Intensity Target Switch (1=Facility Target)
  FBuyFr::VariableArray{2} = ReadDisk(db,"SInput/FBuyFr") # [Market,Year] Federal (Domestic) Permits Fraction Bought (Tonnes/Tonnes)
  GoalPolSw::VariableArray{1} = ReadDisk(db,"SInput/GoalPolSw") # [Market] Pollution Goal Switch (1=Gratis Permits,0=Exogenous)
  # TODO fix GPEUSw to be dimensioned by market on the database. 
  # GPEUSw::VariableArray{1} = ReadDisk(db,"SInput/GPEUSw") # [Market] Gratis Permit Allocation Switch (1=Grandfather, 2=Output, 0=Exogenous)
  GratSw::VariableArray{1} = ReadDisk(db,"SInput/GratSw") # [Market] Gratis Permit Allocation Switch (1=Grandfather,2=Output,0=Exogenous)
  ISaleSw::VariableArray{2} = ReadDisk(db,"SInput/ISaleSw") # [Market,Year] Switch for Unlimited Sales (1=International Permits,2=Domestic Permits)
  OBAFraction::VariableArray{3} = ReadDisk(db,"SInput/OBAFraction") # [ECC,Area,Year] Output-Based Allocation Fraction (Tonne/Tonne)
  OffMktFr::VariableArray{4} = ReadDisk(db,"SInput/OffMktFr") # [ECC,Area,Market,Year] Fraction of Offsets allocated to each Market (Tonne/Tonne)
  OffNew::VariableArray{4} = ReadDisk(db,"EGInput/OffNew") # [Plant,Poll,Area,Year] Offset Permits for New Plants (Tonnes/TBtu)
  PBnkSw::VariableArray{2} = ReadDisk(db,"SInput/PBnkSw") # [Market,Year] Credit Banking Switch (1=Buy and Sell Out of Inventory)
  PCost::VariableArray{4} = ReadDisk(db,"SOutput/PCost") # [ECC,Poll,Area,Year] Permit Cost (Real $/Tonnes)
  PCovMarket::VariableArray{3} = ReadDisk(db,"SInput/PCovMarket") # [PCov,Market,Year] Types of Pollution included in Market
  PolConv::VariableArray{1} = ReadDisk(db,"SInput/PolConv") # [Poll] Pollution Conversion Factor (convert GHGs to eCO2)
  PolCovRef::VariableArray{5} = ReadDisk(db,"SInput/BaPolCov") #[ECC,Poll,PCov,Area,Year]  Reference Case Covered Pollution (Tonnes/Yr)
  PollMarket::VariableArray{3} = ReadDisk(db,"SInput/PollMarket") # [Poll,Market,Year] Pollutants included in Market
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCode::Array{String} = ReadDisk(db,"EGInput/UnCode") # [Unit] Unit Code
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnCoverage::VariableArray{3} = ReadDisk(db,"EGInput/UnCoverage") # [Unit,Poll,Year] Fraction of Unit Covered in Emission Market (1=100% Covered)
  UnF1::Array{String} = ReadDisk(db,"EGInput/UnF1") # [Unit] Fuel Source 1
  UnFlFr::VariableArray{3} = ReadDisk(db,"EGOutput/UnFlFr") # [Unit,FuelEP,Year] Fuel Fraction (Btu/Btu)
  UnGenCo::Array{String} = ReadDisk(db,"EGInput/UnGenCo") # [Unit] Generating Company
  UnNode::Array{String} = ReadDisk(db,"EGInput/UnNode") # [Unit] Transmission Node
  UnOffsets::VariableArray{3} = ReadDisk(db,"EGInput/UnOffsets") # [Unit,Poll,Year] Offsets (Tonnes/GWh) 
  UnOnLine::VariableArray{1} = ReadDisk(db,"EGInput/UnOnLine") # [Unit] On-Line Date (Year)
  UnPGratis::VariableArray{3} = ReadDisk(db,"EGOutput/UnPGratis") # [Unit,Poll,Year] Gratis Permits (Tonnes/Yr)
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnSector::Array{String} = ReadDisk(db,"EGInput/UnSector") # [Unit] Unit Type (Utility or Industry)
  xDriver::VariableArray{3} = ReadDisk(db,"MInput/xDriver") # [ECC,Area,Year] Gross Output (Real M$/Yr)
  xETAPr::VariableArray{2} = ReadDisk(db,"SInput/xETAPr") # [Market,Year] Exogenous Cost of Emission Trading Allowances (Real US$/Tonne)
  xExchangeRate::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRate") # [Area,Year] Local Currency/US$ Exchange Rate (Local/US$)
  xExchangeRateNation::VariableArray{2} = ReadDisk(db,"MInput/xExchangeRateNation") # [Nation,Year] Local Currency/US\$ Exchange Rate (Local/US\$)
  xFSell::VariableArray{2} = ReadDisk(db,"SInput/xFSell") # [Market,Year] Exogenous Federal Permits Sold (Tonnes/Yr)
  xGoalPol::VariableArray{2} = ReadDisk(db,"SInput/xGoalPol") # [Market,Year] Pollution Goal (Tonnes eCO2/Yr)
  xGPNew::VariableArray{5} = ReadDisk(db,"EGInput/xGPNew") # [FuelEP,Plant,Poll,Area,Year] Gratis Permits for New Plants (kg/MWh)
  xInflationNation::VariableArray{2} = ReadDisk(db,"MInput/xInflationNation") # [Nation,Year] Inflation Index
  xISell::VariableArray{2} = ReadDisk(db,"SInput/xISell") # [Market,Year] Exogenous International Permits Sold (Tonnes/Yr)
  xPGratis::VariableArray{5} = ReadDisk(db,"SInput/xPGratis") # [ECC,Poll,PCov,Area,Year] Exogenous Gratis Permits (Tonnes/Yr)
  xPolCap::VariableArray{5} = ReadDisk(db,"SInput/xPolCap") # [ECC,Poll,PCov,Area,Year] Exogenous Emissions Cap (Tonnes/Yr)
  xPolTot::VariableArray{5} = ReadDisk(db,"SInput/xPolTot") # [ECC,Poll,PCov,Area,Year] Historical Pollution (Tonnes/Yr)
  xUnDmd::VariableArray{3} = ReadDisk(db,"EGInput/xUnDmd") # [Unit,FuelEP,Year] Historical Unit Energy Demands (TBtu)
  xUnEGA::VariableArray{2} = ReadDisk(db,"EGInput/xUnEGA") # [Unit,Year] Generation in Reference Case (GWh) 
  xUnFlFr::VariableArray{3} = ReadDisk(db,"EGInput/xUnFlFr") # [Unit,FuelEP,Year] Fuel Fraction (Btu/Btu)
  xUnGP::VariableArray{4} = ReadDisk(db,"EGInput/xUnGP") # [Unit,FuelEP,Poll,Year] Unit Intensity Target or Gratis Permits (kg/MWh)
  xUnPol::VariableArray{4} = ReadDisk(db,"EGInput/xUnPol") # [Unit,FuelEP,Poll,Year] Historical Pollution (Tonnes)
  ReC0::VariableArray{3} = ReadDisk(db,"MEInput/ReC0") # [Offset,Area,Year] C Term in Reduction Curve (Tonnes/Yr)
  RePollutant::Array{String} = ReadDisk(db,"MEInput/RePollutant") # [Offset] Reduction Main Pollutant (Name)
  ReReductionsX::VariableArray{3} = ReadDisk(db,"MEInput/ReReductionsX") # [Offset,Area,Year] Reductions Exogenous (Tonnes/Yr)
  SqPGMult::VariableArray{4} = ReadDisk(db,"SInput/SqPGMult") # [ECC,Poll,Area,Year] Sequestering Gratis Permit Multiplier (Tonne/Tonne)

  # Scratch Variables
  EIBase::VariableArray{4} = zeros(Float64,length(ECC),length(Poll),length(PCov),length(Area)) # [ECC,Poll,PCov,Area] Emission Intensity Baseline (Tonnes/Driver)
  EIBaseRawNG::VariableArray{4} = zeros(Float64,length(ECC),length(Poll),length(PCov),length(Year)) # [ECC,Poll,PCov,Year] Raw Natural Gas Baseline Emission Intensity (Tonnes/Driver)
  OBA::VariableArray{5} = zeros(Float64,length(ECC),length(Poll),length(PCov),length(Area),length(Year)) # [ECC,Poll,PCov,Area,Year] Output-Based Allocations (Tonnes/Driver)
  OBACogen::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Output-Based Allocations for Cogeneration Generation (Tonnes/GWh)
  OBAElectric::VariableArray{3} = zeros(Float64,length(Plant),length(FuelEP),length(Year)) # [Plant,FuelEP,Year] Output-Based Allocations for Electric Generation (Tonnes/GWh)
  OBANaturalGasNew::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Output-Based Allocations for New Natural Gas Generation (Tonnes/GWh)
  OBAOffsets::VariableArray{2} = zeros(Float64,length(Plant),length(Year)) # [Plant,Year] Output-Based Allocations for Electric Generation (Tonnes/GWh)
  OBARawNG::VariableArray{4} = zeros(Float64,length(ECC),length(Poll),length(PCov),length(Year)) # [ECC,Poll,PCov,Year] Output-Based Allocations for Raw Natural Gas (Tonnes/Driver)
  OBASpecial::VariableArray{2} = zeros(Float64,length(ECC),length(Year)) # [ECC,Year] Output-Based Allocations for Special Sectors (Tonnes/Driver)
  OffsetConv::VariableArray{1} = zeros(Float64,length(Offset)) # [Offset] Pollution Conversion Factor (convert GHGs to eCO2)
  RePotential::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Potential Offsets (Tonne/Yr)
  ReReductionsAB::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Historical Alberta Offsets (Tonnes/Yr)
  # YrFinal  'Final Year for GHG Market or Tax (Year)'
end

function GetUnitSets(data,unit)
  (; Area,ECC,Plant) = data
  (; UnArea,UnPlant,UnSector) = data

  #
  # This procedure selects the sets for a particular unit
  #
  # EmptyString = ""
  if (UnPlant[unit] !== "") && (UnArea[unit] !== "") && (UnSector[unit] !== "")
    # genco = Select(GenCo,UnGenCo[unit])
    plant = Select(Plant,UnPlant[unit])
    # node = Select(Node,UnNode[unit])
    area = Select(Area,UnArea[unit])
    ecc = Select(ECC,UnSector[unit])
    return plant,area,ecc
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
  (; FuelEP,FuelEPs) = data
  (; Nation,Offsets) = data
  (; PCov,PCovs,Plant,Plants,Poll,Polls) = data
  (; Units,Years) = data
  (; AreaMarket,CapTrade,CBSw,CoverNew) = data
  (; DriverBaseline) = data
  (; ECCMarket,ECoverage,EIBase,EIBaseline,EIBaseRawNG) = data
  (; Enforce,EuFPol) = data
  (; ETABY,ETADAP,ETAFAP,ETAMax,ETAMin,ETAPr,ExYear,FacSw) = data 
  # (; GPEUSw) = data # TODO fix GPEUSw on database
  (; FBuyFr,GoalPolSw,GratSw,ISaleSw,OBA,OBAElectric) = data
  (; OBAFraction,OBANaturalGasNew) = data
  (; OffsetConv,OffMktFr,OffNew,PBnkSw,PCost,PCovMarket,PolConv) = data
  (; OBAOffsets) = data
  (; PolCovRef,PollMarket,xPolTot,RePotential) = data
  (; ReReductionsAB,UnArea,UnCoverage) = data
  (; UnF1,UnOffsets,UnOnLine,UnPGratis) = data
  (; UnPlant,UnSector,xDriver,xETAPr) = data
  (; xExchangeRate,xExchangeRateNation,xFSell,xGoalPol,xGPNew) = data
  (; xInflationNation,xISell,xPGratis,xPolCap,xUnEGA) = data
  (; xUnEGA,xUnFlFr,xUnGP,xUnPol,SqPGMult) = data
  (; ReC0,RePollutant,ReReductionsX) = data
    
  #########################
  #
  # Reference Case Economic Driver
  #
  for year in Years, area in Areas, ecc in ECCs
    DriverBaseline[ecc,area,year] = xDriver[ecc,area,year]
  end
  WriteDisk(db,"MInput/DriverBaseline",DriverBaseline)

  #########################
  #
  # Alberta Carbon Tax with OBA
  #
  market = 142

  #########################
  #
  # Market Timing
  #
  Enforce[market] = 2018
  YrFinal = Yr(2050)
  ETABY[market] = Enforce[market]
  Current = Int(Enforce[market])-ITime+1
  Prior = Current-1

  WriteDisk(db,"SInput/Enforce",Enforce)
  WriteDisk(db,"SInput/ETABY",ETABY)

  years = collect(Current:YrFinal)

  #########################
  #
  # Areas Covered
  #
  for year in years,area in Areas
    AreaMarket[area,market,year] = 0
  end

  areas = Select(Area,"AB")
  for year in years,area in areas
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

  polls = Select(Poll,["CO2","CH4","N2O","SF6","PFC","HFC"])
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

  pcovs = Select(PCov)
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

  eccs = Select(ECC,["NGPipeline",
            "Food","Lumber","PulpPaperMills",
            "Petrochemicals","IndustrialGas","OtherChemicals","Fertilizer",
            "Petroleum","Rubber","Cement","Glass","LimeGypsum","OtherNonMetallic",
            "IronSteel","Aluminum","OtherNonferrous",
            "TransportEquipment",
            "IronOreMining","OtherMetalMining","NonMetalMining",
            "LightOilMining","HeavyOilMining","FrontierOilMining","PrimaryOilSands",
            "SAGDOilSands","CSSOilSands","OilSandsMining","OilSandsUpgraders",
            "ConventionalGasProduction","SweetGasProcessing","UnconventionalGasProduction","SourGasProcessing",
            "LNGProduction","CoalMining",
            "UtilityGen"])
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
  # Sector Coverages (exclude Venting and Fugitives (Process) from Oil and Gas)
  #
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    ECoverage[ecc,poll,pcov,area,year] = 1.0
  end

  pcovs = Select(PCov,["Venting","Process"])
  eccs = Select(ECC,["LightOilMining","HeavyOilMining","FrontierOilMining"])
  for year in years, area in areas, pcov in pcovs
    if PCovMarket[pcov,market,year] == 1
      for ecc in eccs
        if ECCMarket[ecc,market,year] == 1
          for poll in polls
            ECoverage[ecc,poll,pcov,area,year] = 0.0
          end
        end
      end
    end
  end
  WriteDisk(db,"SInput/ECoverage",ECoverage)

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

  ExYear[market] = 2020
  WriteDisk(db,"SInput/ExYear",ExYear)

  #
  # Facility level intensity target (FacSw=1)
  #
  FacSw[market] = 1
  WriteDisk(db,"SInput/FacSw",FacSw)

  #
  # Electric Utility Gratis Permits are Output Based (GPEUSw=4)
  #
  # TODO fix GPEUSw to be dimensioned by market on the database.
  # GPEUSw[market]=4
  # WriteDisk(db,"SInput/GPEUSw",GPEUSw)
  
  #
  # Emissions goal base on Gratis Permits (GoalPolSw=1)
  #
  GoalPolSw[market] = 1
  WriteDisk(db,"SInput/GoalPolSw",GoalPolSw)

  #
  # Gratis Permits base on OBPS (GratSw=2)
  #
  GratSw[market] = 2
  WriteDisk(db,"SInput/GratSw",GratSw)

  #
  # Credit Banking Switch (1=Buy and Sell Out of Inventory)
  #
  for year in years
    PBnkSw[market,year] = 1
  end
  WriteDisk(db,"SInput/PBnkSw",PBnkSw)

  #
  # Offsets
  #
  
  eccs = Select(ECC,["Forestry","CropProduction","AnimalProduction","SolidWaste","Wastewater"])
  for year in years, area in areas, ecc in eccs
    OffMktFr[ecc,area,market,year] = 0.0
  end
  WriteDisk(db,"SInput/OffMktFr",OffMktFr)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # All Electric Generation Units are Covered including Cogeneration
  # Diesel Generation exempt for NL, YT, and NU in Federal OBA - Jacob Rattray
  #
  for unit in Units
    if (UnPlant[unit] !== "") && (UnArea[unit] !== "") && (UnSector[unit] !== "")
      plant,area,ecc = GetUnitSets(data,unit)
      for year in years
        if (AreaMarket[area,market,year] == 1) && (ECCMarket[ecc,market,year] == 1)
          for poll in polls
            UnCoverage[unit,poll,year] = 1
          end
          if ((Area[area] == "NL") || (Area[area] == "YT") || (Area[area] == "NU")) && (UnF1[unit] == "Diesel")
            for poll in polls
              UnCoverage[unit,poll,year] = 0
            end
          end
        end
      end
    end
  end
  WriteDisk(db,"EGInput/UnCoverage",UnCoverage)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  #
  # Coverage of new electric generating units
  # Diesel Generation exempt for NL, YT, and NU in Federal OBA - Jacob Rattray
  #
  UtilityGen = Select(ECC,"UtilityGen")
  for year in years, area in areas, poll in polls, plant in Plants
    if ECCMarket[UtilityGen,market,year] == 1
      CoverNew[plant,poll,area,year] = 1 
    end
    if ((Area[area] == "NL") || (Area[area] == "YT") || (Area[area] == "NU")) && Plant[plant] == "OGCT"
      CoverNew[plant,poll,area,year] = 0 
    end
  end
  WriteDisk(db,"EGInput/CoverNew",CoverNew)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # Reference Case Emissions
  # 
  
  #########################
  #
  # Emissions Intensity from Baseline
  #
  years = collect(Yr(2013):Yr(2015))
  for area in areas, pcov in PCovs, poll in polls, ecc in eccs
    @finite_math EIBase[ecc,poll,pcov,area] = sum(xPolTot[ecc,poll,pcov,area,year]*
      PolConv[poll]*ECoverage[ecc,poll,pcov,area,YrFinal] for year in years)/
        sum(DriverBaseline[ecc,area,year] for year in years)
  end
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    EIBaseline[ecc,poll,pcov,area,year] = EIBase[ecc,poll,pcov,area]
  end

  WriteDisk(db,"SInput/EIBaseline",EIBaseline)

  NaturalGas = Select(PCov,"NaturalGas")
  NaturalGasRaw = Select(FuelEP,"NaturalGasRaw")
  AB = Select(Area,"AB")
  for year in years, poll in polls, ecc in eccs
    @finite_math EIBaseRawNG[ecc,poll,NaturalGas,year]=
      EuFPol[NaturalGasRaw,ecc,poll,AB,year]*PolConv[poll]/
        DriverBaseline[ecc,AB,year]
  end  

  #########################
  #
  # OBA Fraction
  #
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = 0.00
  end
  for area in areas, ecc in eccs
    OBAFraction[ecc,area,Yr(2018)] = 0.90
    OBAFraction[ecc,area,Yr(2019)] = 0.90
    OBAFraction[ecc,area,Yr(2020)] = 0.90
    OBAFraction[ecc,area,Yr(2021)] = 0.89
    OBAFraction[ecc,area,Yr(2022)] = 0.88
    years = collect(Yr(2023):Yr(2030))
    for year in years
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,year-1]-0.02
    end
    years = collect(Yr(2031):Final)
    for year in years
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,Yr(2030)]
    end
  end
  
  areas,eccs,pcovs,polls,years = 
  DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  eccs = Select(ECC,["OilSandsMining","OilSandsUpgraders"])
  for area in areas, ecc in eccs
    OBAFraction[ecc,area,Yr(2023)] = 0.80
  end
  years = collect(Yr(2024):Yr(2028))
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,year-1]-0.02
  end
  years = collect(Yr(2029):Yr(2030))
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,year-1]-0.04
  end
  years = collect(Yr(2031):Final)
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,Yr(2030)]
  end
  
  areas,eccs,pcovs,polls,years = 
  DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  eccs = Select(ECC,["PrimaryOilSands","SAGDOilSands","CSSOilSands"])
  years = collect(Yr(2029):Yr(2030))
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,year-1]-0.04
  end
  years = collect(Yr(2031):Final)
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year] = OBAFraction[ecc,area,Yr(2030)]
  end
    
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # We need to exclude Producer Consumption of Natural Gas from the 
  # Carbon Tax through 2022, so assign an OBA Raw Natural Gas emissions
  # to negate the Carbon Tax. - Jeff Amlin 7/31/18
  #
  years = collect(Current:Yr(2022))
  for year in years, pcov in pcovs, poll in polls, ecc in eccs
    OBARawNG[ecc,poll,pcov,year] = EIBaseRawNG[ecc,poll,pcov,year]*1.00
  end

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #
  # OBA of actual OBA sectors will be higher than the OBA of Raw Natural Gas
  #  - Jeff Amlin 7/31/18
  #
  
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    OBA[ecc,poll,pcov,area,year] = max(EIBase[ecc,poll,pcov,area]*
      OBAFraction[ecc,area,year],OBARawNG[ecc,poll,pcov,year])
  end
  # TODO Promula the equation is OBAFraction=OBA/EIBase
  # OBAFraction[ecc,area,year]=OBA[ecc,poll,pcov,area,year]/EIBase[ecc,poll,pcov,area]
  # it doesn't make sense with the variables of the fraction, so I'm just guessing
  # as to what the equation should be
  poll = first(polls)
  pcov = first(pcovs)
  for year in years, area in areas, ecc in eccs
    OBAFraction[ecc,area,year]=OBA[ecc,poll,pcov,area,year]/EIBase[ecc,poll,pcov,area]
  end
  WriteDisk(db,"SInput/OBAFraction",OBAFraction)
  
  # 
  # OBA Fraction for Electric Utility Generation
  # TODO Promula: Jeff had commented this out until we figured out the code intention
  #
  UtilityGen = Select(ECC,"UtilityGen")
  OBA[UtilityGen,polls,pcovs,areas,years] .= 0.0
  polls = Select(Poll,"CO2")
  pcovs = Select(PCov,"Energy")
  OBAElectric[Plants,FuelEPs,years] .= 370.0
  years = collect(Yr(2030):YrFinal)
  OBAElectric[Plants,FuelEPs,years] .= 311.0
  years = collect(Yr(2023):Yr(2029))
  for year in years, fuelep in FuelEPs, plant in Plants
    OBAElectric[plant,fuelep,year] = OBAElectric[plant,fuelep,year-1]+
    (OBAElectric[plant,fuelep,Yr(2030)]-OBAElectric[plant,fuelep,Yr(2022)])/(2030-2022)
  end
  years = Select(Year)
  fueleps = Select(FuelEP,["Biomass","RNG","Waste"])
  OBAElectric[Plants,fueleps,years] .= 0.0
  fueleps = Select(FuelEP)

  #
  # New Natural Gas Units
  #
  plants = Select(Plant,["OGCT","OGCC","SmallOGCC","NGCCS"])
  for year in years
    OBANaturalGasNew[year] = 370.0
  end
  years = collect(Yr(2030):YrFinal)
  for year in years
    OBANaturalGasNew[year] = 311.0
  end
  years = collect(Yr(2023):Yr(2029))
  for year in years
    OBANaturalGasNew[year] = OBANaturalGasNew[year-1]+
      (OBANaturalGasNew[Yr(2030)]-OBANaturalGasNew[Yr(2022)])/(2030-2022)
  end
  years = Select(Year)
  #
  # Offsets for existing units
  #
  plants = Select(Plant,["OnshoreWind","SolarPV","SolarThermal"])
  OBAOffsets[plants,years] .= 370.0
  years = collect(Yr(2030):YrFinal)
  OBAOffsets[plants,years] .= 311.0
  years = collect(Yr(2023):Yr(2029))
  for year in years, plant in plants
    OBAOffsets[plant,year] = OBAOffsets[plant,year-1]+
      (OBAOffsets[plant,Yr(2030)]-OBAOffsets[plant,Yr(2022)])/(2030-2022)
  end
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  #########################
  #
  # Gratis Permits and Offsets for Electric Generation
  #
  for area in areas
    units = findall(UnArea[:] .== Area[area])
    if !isempty(units)
    
      #
      # Remove any existing Gratis Permits and Offsets 
      #
      for year in years, poll in polls, unit in units
        for fuelep in FuelEPs
          xUnGP[unit,fuelep,poll,year] = 0
        end
        UnOffsets[unit,poll,year] = 0      
      end
      
      #
      # Gratis Permits and Offsets are stored in CO2
      #
      CO2 = Select(Poll,"CO2")

      #
      # For each Covered Electric Generating Unit
      #
      for year in years, unit in units
        if UnCoverage[unit,CO2,year] == 1
          plant,area,ecc = GetUnitSets(data,unit)
          if ECCMarket[ecc,market,year] == 1

            #
            # Fossil Units get emissions credits
            #
            if (UnPlant[unit] == "OGCT") || (UnPlant[unit] == "SmallOGCC") ||
                (UnPlant[unit] == "OGCC") || (UnPlant[unit] == "OGSteam")  ||
                (UnPlant[unit] == "Coal") || (UnPlant[unit] == "CoalCCS")  ||
                (UnPlant[unit] == "NGCCS") || (UnPlant[unit] == "Biomass") ||
                (UnPlant[unit] == "Waste") || (UnPlant[unit] == "OtherGeneration")
              for fuelep in FuelEPs
                xUnGP[unit,fuelep,CO2,year] = OBAElectric[plant,fuelep,year]
              end
              if UnOnLine[unit] > 2020
                NG_Fuels = Select(FuelEP,["NaturalGas","NaturalGasRaw","CokeOvenGas","StillGas"])
                for fuelep in NG_Fuels
                  xUnGP[unit,fuelep,CO2,year] = OBANaturalGasNew[year]
                end
              end
            end
            
            #
            # Units which do not burn fuel are granted offsets
            #
            if (UnPlant[unit] == "OnshoreWind") || (UnPlant[unit] == "SolarPV") ||
                (UnPlant[unit] == "SolarThermal")
              UnOffsets[unit,CO2,year] = OBAOffsets[plant,year]
            end
          end
        end
      end
    end
  end

  WriteDisk(db,"EGInput/UnOffsets",UnOffsets)
  WriteDisk(db,"EGInput/xUnGP",xUnGP)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  #########################
  #
  # Reference Case Generation
  #
  
  #
  # The unit emissions caps (UnPGratis) and the credits for the
  # cogeneration units (UnPGratis) become part of the energy
  # emissions cap for each sector (xPolCap).
  #
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    xPolCap[ecc,poll,pcov,area,year] = 0.0
    PolCovRef[ecc,poll,pcov,area,year] = 0.0
  end

  Energy = Select(PCov,"Energy")

  for unit in Units
    if (UnPlant[unit] !== "") && (UnArea[unit] !== "") && (UnSector[unit] !== "")
      plant,area,ecc = GetUnitSets(data,unit)
      for year in years, poll in polls
        if (UnCoverage[unit,poll,year] == 1) && (AreaMarket[area,market,year] == 1) && (ECCMarket[ecc,market,year] == 1)
          
          UnPGratis[unit,poll,year] = sum(xUnGP[unit,fuelep,poll,year]*xUnEGA[unit,year]*
            xUnFlFr[unit,fuelep,year] for fuelep in FuelEPs)
          
          xPolCap[ecc,poll,Energy,area,year] = xPolCap[ecc,poll,Energy,area,year]+
            UnPGratis[unit,poll,year]
          
          PolCovRef[ecc,poll,Energy,area,year] = PolCovRef[ecc,poll,Energy,area,year]+
            sum(xUnPol[unit,fuelep,poll,year] for fuelep in FuelEPs)*PolConv[poll]
        end
      end
    end
  end

  WriteDisk(db,"EGOutput/UnPGratis",UnPGratis)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # New Units
  #

  # Select Poll(CO2)

  for year in years, area in areas, plant in Plants
    for fuelep in FuelEPs
      xGPNew[fuelep,plant,CO2,area,year] = 0.0
    end
    OffNew[plant,CO2,area,year] = 0
  end

  plants = Select(Plant,["OGCT","OGCC","SmallOGCC","NGCCS","OGSteam","Coal","CoalCCS","Biomass","Waste","OtherGeneration"])
  for year in years, area in areas, plant in plants, fuelep in FuelEPs
    xGPNew[fuelep,plant,CO2,area,year] = OBAElectric[plant,fuelep,year]
  end

  plants = Select(Plant,["OGCT","OGCC","SmallOGCC","NGCCS","OGSteam"])
  NaturalGas = Select(FuelEP,"NaturalGas")
  for year in years, area in areas, plant in plants
    xGPNew[NaturalGas,plant,CO2,area,year] = OBANaturalGasNew[year]
  end

  WriteDisk(db,"EGInput/OffNew",OffNew)
  WriteDisk(db,"EGInput/xGPNew",xGPNew)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # Exclude electric unit emissions which are computed above
  #
  eccs_UG = Select(ECC,!=("UtilityGen"))
  eccs_subset = intersect(eccs,eccs_UG)
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs_subset

    #
    # Covered Emissions 
    #
    PolCovRef[ecc,poll,pcov,area,year] = xPolTot[ecc,poll,pcov,area,year]*
      ECoverage[ecc,poll,pcov,area,year]*PolConv[poll]

    #
    # Emission Cap
    #
    xPolCap[ecc,poll,pcov,area,year] = OBA[ecc,poll,pcov,area,year]*
      DriverBaseline[ecc,area,year]
  end

  WriteDisk(db,"SInput/BaPolCov",PolCovRef)
  WriteDisk(db,"SInput/xPolCap",xPolCap)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #########################
  #
  # Emission Goal
  #
  for year in years
    xGoalPol[market,year] = sum(xPolCap[ecc,poll,pcov,area,year] for area in areas, 
      pcov in pcovs, poll in polls, ecc in eccs)
  end

  WriteDisk(db,"SInput/xGoalPol",xGoalPol)

  #########################
  #
  # Emission Credits are energy (xPolCap
  #
  for year in years, area in areas, pcov in pcovs, poll in polls, ecc in eccs
    xPGratis[ecc,poll,pcov,area,year] = xPolCap[ecc,poll,pcov,area,year]
  end

  WriteDisk(db,"SInput/xPGratis",xPGratis)

  #########################
  #
  # Unlimited Federal (TIF) Permits
  #
  for year in years
    ISaleSw[market,year] = 2
  end

  WriteDisk(db,"SInput/ISaleSw",ISaleSw)

  #########################
  # 
  # Backstop Prices in nominal CN$/tonne
  #
  CN = Select(Nation,"CN")
  US = Select(Nation,"US")
  ETADAP[market,Yr(2017)] =  0.00/xExchangeRateNation[CN,Yr(2017)]/xInflationNation[US,Yr(2017)]
  ETADAP[market,Yr(2018)] = 20.00/xExchangeRateNation[CN,Yr(2018)]/xInflationNation[US,Yr(2018)]
  ETADAP[market,Yr(2019)] = 20.00/xExchangeRateNation[CN,Yr(2019)]/xInflationNation[US,Yr(2019)]
  ETADAP[market,Yr(2020)] = 30.00/xExchangeRateNation[CN,Yr(2020)]/xInflationNation[US,Yr(2020)]
  ETADAP[market,Yr(2021)] = 40.00/xExchangeRateNation[CN,Yr(2021)]/xInflationNation[US,Yr(2021)]
  ETADAP[market,Yr(2022)] = 50.00/xExchangeRateNation[CN,Yr(2022)]/xInflationNation[US,Yr(2022)]
  years = collect(Yr(2023):YrFinal)
  for year in years
    ETADAP[market,year] = 50.00/xExchangeRateNation[CN,year]/xInflationNation[US,year]
  end

  WriteDisk(db,"SInput/ETADAP",ETADAP)

  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)

  #
  # Minimum Permit Prices in nominal CN$/tonne
  #
  for year in years
    ETAMin[market,year] = 0.25/xExchangeRateNation[CN,year]/xInflationNation[US,year]
  end

  WriteDisk(db,"SInput/ETAMin",ETAMin)

  #
  # First Tier Domestic TIF Permits (xFSell) are unlimited
  #
  for year in years
    xFSell[market,year] = 1e12
  end

  WriteDisk(db,"SInput/xFSell",xFSell)

  #
  # Do not buy back Domestic Permits
  #
  for year in years
    FBuyFr[market,year] = 0.0
  end

  WriteDisk(db,"SInput/FBuyFr",FBuyFr)

  #
  # International Permit Prices
  #
  for year in years
    ETAFAP[market,year] = 0.0
  end

  WriteDisk(db,"SInput/ETAFAP",ETAFAP)

  #
  # No International Permits (xISell)
  #
  for year in years
    xISell[market,year] = 0.0
  end

  WriteDisk(db,"SInput/xISell",xISell)

  #
  # Maximum Permit Prices in nominal CN$/tonne
  #
  for year in years
    ETAMax[market,year] = 170.00/xExchangeRateNation[CN,year]/
      xInflationNation[US,year]
  end

  WriteDisk(db,"SInput/ETAMax",ETAMax)

  #
  # Exogenous market price (xETAPr) is set equal to the
  # unlimited backstop price (ETADAP)
  #
  
  for year in Years
    xETAPr[market,year] = ETADAP[market,year]
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

  #########################
  #
  # Double Credits from Scotford Upgrader with Quest CCS,
  # but only for 10 years (until 2024). - Glasha 6/12/14
  #
  ecc = Select(ECC,"OilSandsUpgraders")
  CO2 = Select(Poll,"CO2")
  AB = Select(Area,"AB")

  years = collect(Yr(2018):Final)
  for year in years
    SqPGMult[ecc,CO2,AB,year] = 1.0
  end
  WriteDisk(db,"SInput/SqPGMult",SqPGMult)
  
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)


  #########################
  #
  # Backfill ReC0
  #
  years = collect(Yr(2000):Yr(2006))
  for year in years, offset in Offsets
    ReC0[offset,AB,year] = ReC0[offset,AB,Yr(2007)]
  end
  years = collect(Year)
  #
  # Convert reductions to eCO2
  #
  for offset in Offsets
    OffsetConv[offset] = 0.0
    for poll in polls
      if Poll[poll] == RePollutant[offset]
        OffsetConv[offset] = PolConv[poll]
      end
    end
  end
  
  #
  # Offset Potential
  #
  for year in Years
    RePotential[year] = sum(ReC0[offset,AB,year] for offset in Offsets)
  end

  #
  # Indicated Offset Construction
  #
  years = collect(Yr(2003):Yr(2013))
  for year in years
    ReReductionsAB[year] = 2.50*1e6
  end
  
  #
  # Scale to all types of Offsets
  #
  years = collect(Yr(2003):Yr(2013))
  for year in years, offset in Offsets
    @finite_math ReReductionsX[offset,AB,year] =
      ReC0[offset,AB,year]/RePotential[year]*ReReductionsAB[year]
  end

  #
  # Convert reductions from eCO2
  #
  years = collect(Yr(2003):Yr(2013))
  for  year in years, offset in Offsets, poll in polls
    if Poll[poll] == RePollutant[offset]
      ReReductionsX[offset,AB,year] = ReReductionsX[offset,AB,year]/PolConv[poll]
    else
      ReReductionsX[offset,AB,year] = 0.0
    end
  end
  
  years = collect(Yr(2014):YrFinal)
  for year in years, offset in Offsets
    ReReductionsX[offset,AB,year] = 
      max(ReReductionsX[offset,AB,Yr(2013)],ReReductionsX[offset,AB,year])
  end
  areas,eccs,pcovs,polls,years = 
    DefaultSets(data,AreaMarket,Current,ECCMarket,market,PCovMarket,PollMarket,YrFinal)
  
  WriteDisk(db,"MEInput/ReReductionsX",ReReductionsX)
end

function PolicyControl(db)
  @info "Calibration/CarbonTax_OBA_AB.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
