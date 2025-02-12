#
# Ind_MS_IronSteel.jl - Energy for NZA
#
# Net-Zero Accelerator (NZA) Algoma Steel + Arcelor-Mittal reductions are -7.2 Mt
# in 2030 via Natural Gas DRI-EAF (RW 09.24.2021)
# Edited by RST 01Aug2022, re-tuning for Ref22
# Edited by NC 07Sep2023, re-tuning for Ref24
#

using SmallModel

module Ind_MS_IronSteel

import ...SmallModel: ReadDisk,WriteDisk,Select,Yr
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

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
  CTech::SetArray = ReadDisk(db,"$Input/CTechKey")
  CTechDS::SetArray = ReadDisk(db,"$Input/CTechDS")
  CTechs::Vector{Int} = collect(Select(CTech))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Fuels::Vector{Int} = collect(Select(Fuel))
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
  CFraction::VariableArray{5} = ReadDisk(db,"$Input/CFraction") # [Enduse,Tech,EC,Area,Year] Fraction of Production Capacity open to Conversion ($/$)
  CMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/CMSM0") # [Enduse,Tech,CTech,EC,Area,Year] Conversion Market Share Multiplier ($/$)
  CnvrtEU::VariableArray{4} = ReadDisk(db,"$Input/CnvrtEU") # Conversion Switch [Enduse,EC,Area]
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  Endogenous::Float64 = ReadDisk(db,"E2020DB/Endogenous")[1] # [tv] Endogenous = 1
  Exogenous::Float64 = ReadDisk(db,"E2020DB/Exogenous")[1] # [tv] Exogenous = 0
  FsFracMax::VariableArray{5} = ReadDisk(db,"$Input/FsFracMax") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  FsFracMin::VariableArray{5} = ReadDisk(db,"$Input/FsFracMin") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  FsPOCX::VariableArray{5} = ReadDisk(db,"$Input/FsPOCX") # [Fuel,EC,Poll,Area,Year] Feedstock Marginal Pollution Coefficients (Tonnes/TBtu)
  MMSF::VariableArray{5} = ReadDisk(db,"$Outpt/MMSF") # [Enduse,Tech,EC,Area,Year] Ref Case Market Share Fraction ($/$)
  MMSFRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/MMSF") # [Enduse,Tech,EC,Area,Year] Ref Case Market Share Fraction ($/$)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Process Efficiency Max. Mult. ($/Btu/($/Btu))
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  POCX::VariableArray{6} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)
  xFsFrac::VariableArray{5} = ReadDisk(db,"$Input/xFsFrac") # [Fuel,Tech,EC,Area,Year] Feedstock Demands Fuel/Tech Split (Fraction)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input) = data    
  (; Area,CTech,CTechs,EC) = data 
  (; Enduse,Enduses,Fuel,FuelEP) = data
  (; Poll,Polls,Tech,Techs,Year,Years) = data
  (; CFraction,CMSM0,CnvrtEU,Endogenous) = data
  (; FsFracMin,FsFracMax,FsPOCX,PEMM,POCX) = data
  (; xFsFrac,xMMSF) = data

  ON = Select(Area,"ON")
  IronSteel = Select(EC,"IronSteel")
  enduses = Select(Enduse,["Heat","OthSub"])
  Electric = Select(Tech,"Electric")
  Gas = Select(Tech,"Gas")
  Coal = Select(Tech,"Coal")
  
  #
  # Specify values for desired fuel shares (xMMSF)
  # 
  for enduse in enduses
    xMMSF[enduse,Electric,IronSteel,ON,Yr(2025)] = 0.10
    xMMSF[enduse,Gas,IronSteel,ON,Yr(2025)] = 0.80
    xMMSF[enduse,Coal,IronSteel,ON,Yr(2025)] = 0.1
  end
  years = collect(Yr(2026):Yr(2027))
  for year in years, enduse in enduses
    xMMSF[enduse,Electric,IronSteel,ON,year] = 0.03
    xMMSF[enduse,Gas,IronSteel,ON,year] = 0.87
    xMMSF[enduse,Coal,IronSteel,ON,year] = 0.1
  end
  for enduse in enduses
    xMMSF[enduse,Electric,IronSteel,ON,Yr(2028)] = 0.65
    xMMSF[enduse,Gas,IronSteel,ON,Yr(2028)] = 0.25
    xMMSF[enduse,Coal,IronSteel,ON,Yr(2028)] = 0.10

    xMMSF[enduse,Electric,IronSteel,ON,Yr(2029)] = 1.00
    xMMSF[enduse,Gas,IronSteel,ON,Yr(2029)] = 0.00
    xMMSF[enduse,Coal,IronSteel,ON,Yr(2029)] = 0.00
  end

  #
  # Hold marginal fuel share at 2030 average values per e-mail from Robin
  # Ian 11/09/21
  #  
  years = collect(Yr(2030):Yr(2050));
  for year in years, enduse in enduses
    xMMSF[enduse,Electric,IronSteel,ON,year] = 0.10
    xMMSF[enduse,Gas,IronSteel,ON,year] = 0.80
    xMMSF[enduse,Coal,IronSteel,ON,year] = 0.1
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF);

  #
  # Hydrogen substitution 0.4 TJ of natural gas replaces 1 TJ of Coke for Iron & Steel
  # Source: Industry_tuning5.xlsx
  # from Robin White
  # Hydrogen substitution - 13% of coke in 2025,increasing to 100% of coke by 2043
  #
  
  # 
  # xFsFrac(Coke,Tech,EC,Area,Year)=x
  # xFsFrac(NaturalGas,Tech,EC,Area,Year)=(1-x)*0.4
  # 
  Coke = Select(Fuel,"Coke");
  NaturalGas = Select(Fuel,"NaturalGas");

  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2025)] = 0.862
  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2026)] = 0.862
  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2027)] = 0.862
  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2028)] = 0.499
  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2029)] = 0.103
  xFsFrac[Coke,Coal,IronSteel,ON,Yr(2030)] = 0.103

  years = collect(Yr(2031):Yr(2050))
  for year in years
    xFsFrac[Coke,Coal,IronSteel,ON,year] = 0.113
  end

  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2025)] = 0.139
  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2026)] = 0.139
  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2027)] = 0.139
  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2028)] = 0.503
  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2029)] = 0.897
  xFsFrac[NaturalGas,Coal,IronSteel,ON,Yr(2030)] = 0.897
  years = collect(Yr(2031):Yr(2050))
  for year in years
    xFsFrac[NaturalGas,Coal,IronSteel,ON,year] = 0.877
  end

  # 
  # Constrain FsFrac to match old policy impact (FsFrac < 1.0)
  # 
  years = collect(Yr(2025):Yr(2050))
  for year in years
    FsFracMax[NaturalGas,Coal,IronSteel,ON,year] = 
      xFsFrac[NaturalGas,Coal,IronSteel,ON,year]
    FsFracMin[NaturalGas,Coal,IronSteel,ON,year] = 
      xFsFrac[NaturalGas,Coal,IronSteel,ON,year]
  end

  CoalFuel = Select(Fuel,"Coal")
  for year in years
    FsFracMax[CoalFuel,Coal,IronSteel,ON,year] = 
      xFsFrac[CoalFuel,Coal,IronSteel,ON,year]
    FsFracMax[Coke,Coal,IronSteel,ON,year] = 
      xFsFrac[Coke,Coal,IronSteel,ON,year]
  end

  # 
  # Assign emission factors for natural gas since none in history
  #   
  # Apply only to GHGs per e-mail from Howard - Ian 09/26/24
  #
  years = collect(Yr(2025):Final)
  polls = Select(Poll,["CO2","CH4","N2O","SF6","PFC","HFC"])
  Heat = Select(Enduse,"Heat")
  NaturalGasEP = Select(FuelEP,"NaturalGas")

  for year in years, poll in polls
    FsPOCX[NaturalGas,IronSteel,poll,ON,year] = 
      POCX[Heat,NaturalGasEP,IronSteel,poll,ON,year]
  end

  WriteDisk(db,"$Input/xFsFrac",xFsFrac)
  WriteDisk(db,"$Input/FsPOCX",FsPOCX)
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)

  years = collect(Yr(2025):Yr(2030))
  GasTech = Select(Tech,"Gas")
  for year in years, enduse in Enduses
    PEMM[enduse,GasTech,IronSteel,ON,year] = 
      PEMM[enduse,GasTech,IronSteel,ON,year] * 2.0
  end
  
  WriteDisk(db,"$CalDB/PEMM",PEMM)

  for year in years, tech in Techs, enduse in Enduses
    CnvrtEU[enduse,IronSteel,ON,year] = Endogenous
    CFraction[enduse,tech,IronSteel,ON,year] = 1.0
  end

  for year in years, ctech in CTechs, tech in Techs, enduse in Enduses
    CMSM0[enduse,tech,ctech,IronSteel,ON,year] = -170.0
  end  

  CoalCTech = Select(CTech,"Coal")
  for year in years, tech in Techs,enduse in Enduses
    CMSM0[enduse,tech,CoalCTech,IronSteel,ON,year] = -5.0
  end

  WriteDisk(db,"$Input/CnvrtEU",CnvrtEU)
  WriteDisk(db,"$Input/CFraction",CFraction)
  WriteDisk(db,"$CalDB/CMSM0",CMSM0)
end

function PolicyControl(db)
  @info "Ind_MS_IronSteel - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
