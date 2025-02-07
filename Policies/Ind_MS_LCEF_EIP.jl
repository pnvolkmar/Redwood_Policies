#
# Ind_MS_LCEF_EIP.jl - Energy for NZA
# Net-Zero Accelerator (NZA) Algoma Steel + Arcelor-Mittal reductions are -7.2 Mt
# in 2030 via Natural Gas DRI-EAF (RW 09.24.2021)
# Edited by RST 01Aug2022, re-tuning for Ref22
# Edited by NC 07Sep2023, re-tuning for Ref24

using SmallModel

module Ind_MS_LCEF_EIP

import ...SmallModel: ReadDisk,WriteDisk,Select
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
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  PI::SetArray = ReadDisk(db,"$Input/PIKey")
  PIDS::SetArray = ReadDisk(db,"$Input/PIDS")
  PIs::Vector{Int} = collect(Select(PI))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] device Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,Enduse,Tech) = data 
  (; DInvExo,PolicyCost,xInflation,xMMSF) = data
  
  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"CoalMining")
  area = Select(Area,"BC")
  Electric = Select(Tech,"Electric")
  Gas = Select(Tech,"Gas")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2025):Yr(2030))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.807
    xMMSF[enduse,Gas,ec,area,year] = 0.183
  end
  years = collect(Yr(2031):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.507
    xMMSF[enduse,Gas,ec,area,year] = 0.483
  end
  
  year = Yr(2025)
  PolicyCost[year] = 33.671
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"OffRoad")
  ec = Select(EC,"OtherMetalMining")
  area = Select(Area,"ON")
  Electric = Select(Tech,"Electric")
  Oil = Select(Tech,"Oil")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2025):Yr(2027))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.004
    xMMSF[enduse,Oil,ec,area,year] = 0.976
  end
  years = collect(Yr(2028):Yr(2030))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.003
    xMMSF[enduse,Oil,ec,area,year] = 0.979
  end
  years = collect(Yr(2031):Yr(2035))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.002
    xMMSF[enduse,Oil,ec,area,year] = 0.979
  end
  years = collect(Yr(2036):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.001
    xMMSF[enduse,Oil,ec,area,year] = 0.979
  end
  
  year = Yr(2025)
  PolicyCost[year] = 29.520
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"OtherMetalMining")
  area = Select(Area,"NL")
  Electric = Select(Tech,"Electric")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2027):Yr(2030))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.900
  end
  years = collect(Yr(2031):Yr(2040))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.400
  end
  
  year = Yr(2027)
  PolicyCost[year] = 141.936
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"PulpPaperMills")
  area = Select(Area,"BC")
  Electric = Select(Tech,"Electric")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2026):Yr(2030))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.200
  end
  years = collect(Yr(2031):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.080
  end
  
  year = Yr(2026)
  PolicyCost[year] = 29.757
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"OffRoad")
  ec = Select(EC,"OtherMetalMining")
  area = Select(Area,"MB")
  Electric = Select(Tech,"Electric")
  Oil = Select(Tech,"Oil")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2028):Yr(2031))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.030
    xMMSF[enduse,Oil,ec,area,year] = 0.770
  end
  years = collect(Yr(2032):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.005
    xMMSF[enduse,Oil,ec,area,year] = 0.795
  end
  
  year = Yr(2028)
  PolicyCost[year] = 53.570
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2
  
  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"Petrochemicals")
  area = Select(Area,"ON")
  Electric = Select(Tech,"Electric")
  Gas = Select(Tech,"Gas")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = collect(Yr(2027):Yr(2033))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.60
    xMMSF[enduse,Gas,ec,area,year] = 0.380
  end
  years = collect(Yr(2034):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.020
    xMMSF[enduse,Gas,ec,area,year] = 0.940
  end
  
  year = Yr(2026)
  PolicyCost[year] = 1.80
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2

  #
  # Substitution of biomass for natural gas occurs through the
  # provision of process heat used in cement
  #  
  enduse = Select(Enduse,"Heat")
  ec = Select(EC,"OtherChemicals")
  area = Select(Area,"AB")
  Electric = Select(Tech,"Electric")
  Gas = Select(Tech,"Gas")

  #
  # Specify values for desired fuel shares (xMMSF)
  #
  years = Yr(2027)
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.2950
    xMMSF[enduse,Gas,ec,area,year] = 0.550
  end
  years = collect(Yr(2028):Yr(2050))
  for year in years
    xMMSF[enduse,Electric,ec,area,year] = 0.1550
    xMMSF[enduse,Gas,ec,area,year] = 0.690
  end
  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
  
  year = Yr(2026)
  PolicyCost[year] = 4.90
  DInvExo[enduse,Electric,ec,area,year] = DInvExo[enduse,Electric,ec,area,year]+PolicyCost[year]/
                                          xInflation[area,year]/2
  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Ind_MS_LCEF_EIP.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
