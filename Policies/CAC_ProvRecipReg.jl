#
# CAC_ProvRecipReg.jl
#
# This TXP Models the emission reductions for the AB and BC Recipricating Engine Regulations
# Note, on Jan 25th, 2013, the fixes were incorporated into this jl. See them below. Matt
# Note that the tables contain historical data; these values are only in the temp variables
# and the overwrite of model variables should start in the first forecast year using the 2020-Final
# pointer. - Hilary 15.04.14
#

using SmallModel

module CAC_ProvRecipReg

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String

  Input::String = "IInput"
  Outpt::String = "IOutput"
  CalDB::String = "ICalDB"
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
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Generation Flag (1 or 2 is Industrial Generation)
  UnNation::Array{String} = ReadDisk(db,"EGInput/UnNation") # [Unit] Nation
  UnPRSw::VariableArray{3} = ReadDisk(db,"EGInput/UnPRSw") # [Unit,Poll,Year] Pollution Reduction Switch (Number)
  UnSector::Array{String} = ReadDisk(db,"EGInput/UnSector") # [Unit] Unit Type (Utility or Industry)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xMERM::VariableArray{4} = ReadDisk(db,"MEInput/xMERM") # [ECC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)
  xPRExp::VariableArray{4} = ReadDisk(db,"SInput/xPRExp") # [ECC,Poll,Area,Year] Exogenous Reduction Private Expenses (Million $/Yr)
  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [FuelEP,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)
  xUnRP::VariableArray{4} = ReadDisk(db,"EGInput/xUnRP") # [Unit,FuelEP,Poll,Year] Pollution Reduction (Tonnes/Tonnes)

  # Scratch Variables
  Change::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Change in Policy Variable
  Temp::VariableArray{5} = zeros(Float64,length(ECC),length(Poll),length(Area),length(FuelEP),length(Year)) # [ECC,Poll,Area,FuelEP,Year] Scratch Variable for Input
  TempCost::VariableArray{3} = zeros(Float64,length(ECC),length(Area),length(Year)) # [ECC,Area,Year] Scratch Input Variable
  TempProcess::VariableArray{4} = zeros(Float64,length(ECC),length(Poll),length(Area),length(Year)) # [ECC,Poll,Area,Year] Scratch Variable for Input for Process
end

function ApplyToCogeneration(data,fueleps,poll,years,eccs,area)
  (; Area,ECC) = data
  (; TempProcess,UnArea,UnNation,UnCogen,UnPRSw,UnSector,xUnRP) = data

  unit1 = findall(UnNation .== "CN")
  unit2 = findall(UnCogen .> (0.0))
  units = intersect(unit1,unit2)
  for ecc in eccs, unit in units
    if (UnSector[unit] == ECC[ecc]) && (UnArea[unit] == Area[area])
      [xUnRP[unit,fuelep,poll,year] = xUnRP[unit,fuelep,poll,year] + 
        TempProcess[ecc,poll,area,year] for fuelep in fueleps, year in years]
      for year in years
        UnPRSw[unit,poll,year] = 2
      end
      
    end
    
  end
  
  return
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,ECC) = data 
  (; FuelEP) = data
  (; Poll) = data
  (; Temp,TempProcess) = data
  (; UnPRSw) = data
  (; xMERM,xRM,xUnRP) = data

  # 
  # Emission Reductions from AB and BC Recip Regs
  # Darryl Provided the Provincial Emission reductions and the equavilent emission reductions are applied to E2020 Projections
  # 
  # Alberta Emission Reductions
  NOX = Select(Poll, "NOX")
  AB = Select(Area,"AB")
  #                 ECC                            Poll  Area                FuelEP           Year             2013    2014    2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"HeavyOilMining"),              NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"LightOilMining"),              NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  AB, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  
  #                 ECC                            Poll  Area                FuelEP           Year             2013    2014    2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"HeavyOilMining"),              NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"LightOilMining"),              NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  AB, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  
  #                 ECC                            Poll  Area                FuelEP           Year             2013    2014    2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"HeavyOilMining"),              NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"LightOilMining"),              NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  AB, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  
  eccs = Select(ECC,["LightOilMining","HeavyOilMining","FrontierOilMining","ConventionalGasProduction","SweetGasProcessing","UnconventionalGasProduction","SourGasProcessing"])
  fueleps = Select(FuelEP,["NaturalGas","NaturalGasRaw","LPG"])
  for ecc in eccs
  ec = Select(EC,filter(x -> x in EC,[ECC[ecc]]))
    if ec != []
      ec = ec[1]
      [xRM[fuelep,ec,NOX,AB,year] = xRM[fuelep,ec,NOX,AB,year] - 
        Temp[ecc,NOX,AB,fuelep,year] for fuelep in fueleps, year in Yr(2022):Final]
    end
    
  end

  eccs = Select(ECC,["HeavyOilMining","LightOilMining","SourGasProcessing","SweetGasProcessing","UnconventionalGasProduction","ConventionalGasProduction"])
  #                        ECC                            Poll  Area  Year             2013    2014    2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  TempProcess[Select(ECC,"HeavyOilMining"),              NOX,  AB,   Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  TempProcess[Select(ECC,"LightOilMining"),              NOX,  AB,   Yr(2013):Final] = [0.009,  0.019,  0.029,  0.039,  0.048,  0.058,  0.068,  0.077,  0.087,  0.097,  0.106,  0.116,  0.125,  0.135,  0.145,  0.154,  0.164,  0.173,  0.183,  0.193,  0.201,  0.210,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219,  0.219]
  TempProcess[Select(ECC,"SourGasProcessing"),           NOX,  AB,   Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  TempProcess[Select(ECC,"SweetGasProcessing"),          NOX,  AB,   Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  TempProcess[Select(ECC,"UnconventionalGasProduction"), NOX,  AB,   Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  TempProcess[Select(ECC,"ConventionalGasProduction"),   NOX,  AB,   Yr(2013):Final] = [0.009,  0.020,  0.030,  0.039,  0.049,  0.059,  0.068,  0.078,  0.087,  0.096,  0.106,  0.115,  0.125,  0.134,  0.144,  0.153,  0.162,  0.172,  0.181,  0.191,  0.199,  0.208,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217,  0.217]
  
  years = collect(Yr(2022):Final)
  for ecc in eccs, year in years
    xMERM[ecc,NOX,AB,year] = xMERM[ecc,NOX,AB,year] - TempProcess[ecc,NOX,AB,year]
  end

  ApplyToCogeneration(data,fueleps,NOX,Yr(2022):Final,eccs,AB)

  # 
  # British Columbia Emission Reductions
  # 
  BC = Select(Area,"BC")
  #                 ECC                            Poll  Area                FuelEP           Year             2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.0097,  0.0192,  0.0288,  0.0384,  0.0476,  0.0574,  0.0663,  0.0761,  0.0848,  0.0947,  0.1036,  0.1125,  0.1225,  0.1313,  0.1400,  0.1500,  0.1587,  0.1680,  0.1773,  0.1858,  0.1944,  0.2031,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1263,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  
  #                 ECC                            Poll  Area                FuelEP           Year             2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.0097,  0.0192,  0.0288,  0.0384,  0.0476,  0.0574,  0.0663,  0.0761,  0.0848,  0.0947,  0.1036,  0.1125,  0.1225,  0.1313,  0.1400,  0.1500,  0.1587,  0.1680,  0.1773,  0.1858,  0.1944,  0.2031,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1263,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  
  #                 ECC                            Poll  Area                FuelEP           Year             2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.0097,  0.0192,  0.0288,  0.0384,  0.0476,  0.0574,  0.0663,  0.0761,  0.0848,  0.0947,  0.1036,  0.1125,  0.1225,  0.1313,  0.1400,  0.1500,  0.1587,  0.1680,  0.1773,  0.1858,  0.1944,  0.2031,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1263,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  
  eccs = Select(ECC,["LightOilMining","SourGasProcessing","SweetGasProcessing","UnconventionalGasProduction","ConventionalGasProduction"])
  fueleps = Select(FuelEP,["NaturalGas","NaturalGasRaw","LPG"])
  for ecc in eccs
  ec = Select(EC,filter(x -> x in EC,[ECC[ecc]]))
    if ec != []
      ec = ec[1]
      [xRM[fuelep,ec,NOX,BC,year] = xRM[fuelep,ec,NOX,BC,year] - 
        Temp[ecc,NOX,BC,fuelep,year] for fuelep in fueleps, year in Yr(2022):Final]
    end
    
  end
  
  #                        ECC                            Poll  Area  Year             2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050
  TempProcess[Select(ECC,"LightOilMining"),              NOX,  BC,   Yr(2013):Final] = [0.0097,  0.0192,  0.0288,  0.0384,  0.0476,  0.0574,  0.0663,  0.0761,  0.0848,  0.0947,  0.1036,  0.1125,  0.1225,  0.1313,  0.1400,  0.1500,  0.1587,  0.1680,  0.1773,  0.1858,  0.1944,  0.2031,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117,  0.2117]
  TempProcess[Select(ECC,"SourGasProcessing"),           NOX,  BC,   Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  TempProcess[Select(ECC,"SweetGasProcessing"),          NOX,  BC,   Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1263,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  TempProcess[Select(ECC,"UnconventionalGasProduction"), NOX,  BC,   Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]
  TempProcess[Select(ECC,"ConventionalGasProduction"),   NOX,  BC,   Yr(2013):Final] = [0.0089,  0.0178,  0.0267,  0.0357,  0.0447,  0.0537,  0.0627,  0.0718,  0.0809,  0.0899,  0.0990,  0.1081,  0.1172,  0.1264,  0.1355,  0.1446,  0.1537,  0.1628,  0.1718,  0.1809,  0.1894,  0.1981,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062,  0.2062]

  [xMERM[ecc,NOX,BC,year] = xMERM[ecc,NOX,BC,year] - 
    TempProcess[ecc,NOX,BC,year] for ecc in eccs, year in Yr(2022):Final]

  ApplyToCogeneration(data,fueleps,NOX,Yr(2022):Final,eccs,BC)

  # 
  # Note, the following block of code is additional changes introduced by Daryl and Andy
  # on January 24th in a file called Fix_CAC_ProvRecipReg.txp
  # I have consolidated the two files by adding in the changes to xRM and xMERM introduced
  # in that file below. Matt Jan 25th, 2013.
  # Changes are additive, meaning xRM and xMERM are not being overwritten, just modified.
  # 
  # Start Fix_CAC_ProvRecipReg.txp*****************************************************
  # 
  # ***********************
  # Emission Reductions from AB and BC Recip Regs
  # Darryl Provided the Provincial Emission reductions and the equavilent emission reductions are applied to E2020 Projections
  # 
  # Jan 24: Fix to BC for the ProvRecip Reg, but not to AB for the ProvRecip. AB remains as-is. Fixes for Federal BLIERs errors are in seperate txp. LCamacho.
  # ************************
  # Changes to BC only.
  # British Columbia Emission Reductions
  #
  
  #                 ECC                            Poll  Area                FuelEP           Year              2013      2014      2015      2016      2017      2018      2019      2020      2021      2022      2023      2024      2025      2026      2027      2028      2029      2030      2031      2032      2033      2034      2035      2036      2037      2038      2039      2040      2041      2042      2043      2044      2045      2046      2047      2048      2049      2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "NaturalGas"),    Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  
  #                 ECC                            Poll  Area                FuelEP           Year              2013      2014      2015      2016      2017      2018      2019      2020      2021      2022      2023      2024      2025      2026      2027      2028      2029      2030      2031      2032      2033      2034      2035      2036      2037      2038      2039      2040      2041      2042      2043      2044      2045      2046      2047      2048      2049      2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "NaturalGasRaw"), Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  
  #                 ECC                            Poll  Area                FuelEP           Year              2013      2014      2015      2016      2017      2018      2019      2020      2021      2022      2023      2024      2025      2026      2027      2028      2029      2030      2031      2032      2033      2034      2035      2036      2037      2038      2039      2040      2041      2042      2043      2044      2045      2046      2047      2048      2049      2050
  Temp[Select(ECC,"LightOilMining"),              NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SourGasProcessing"),           NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"SweetGasProcessing"),          NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"UnconventionalGasProduction"), NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  Temp[Select(ECC,"ConventionalGasProduction"),   NOX,  BC, Select(FuelEP, "LPG"),           Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  
  eccs = Select(ECC,["LightOilMining","SourGasProcessing","SweetGasProcessing","UnconventionalGasProduction","ConventionalGasProduction"])
  fueleps = Select(FuelEP,["NaturalGas","NaturalGasRaw","LPG"])
  for ecc in eccs
  ec = Select(EC,filter(x -> x in EC,[ECC[ecc]]))
    if ec != []
      ec = ec[1]
      [xRM[fuelep,ec,NOX,BC,year] = xRM[fuelep,ec,NOX,BC,year] - 
        Temp[ecc,NOX,BC,fuelep,year] for fuelep in fueleps, year in Yr(2022):Final]
    end
    
  end
  
  #                        ECC                            Poll  Area  Year              2013      2014      2015      2016      2017      2018      2019      2020      2021      2022      2023      2024      2025      2026      2027      2028      2029      2030      2031      2032      2033      2034      2035      2036      2037      2038      2039      2040      2041      2042      2043      2044      2045      2046      2047      2048      2049      2050
  TempProcess[Select(ECC,"LightOilMining"),              NOX,  BC,   Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  TempProcess[Select(ECC,"SourGasProcessing"),           NOX,  BC,   Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  TempProcess[Select(ECC,"SweetGasProcessing"),          NOX,  BC,   Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  TempProcess[Select(ECC,"UnconventionalGasProduction"), NOX,  BC,   Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  TempProcess[Select(ECC,"ConventionalGasProduction"),   NOX,  BC,   Yr(2013):Final] = [-0.0037,  -0.0068,  -0.0092,  -0.0129,  -0.0147,  -0.0198,  -0.0208,  -0.0217,  -0.0223,  -0.0229,  -0.0236,  -0.0246,  -0.0254,  -0.0263,  -0.0273,  -0.0281,  -0.0295,  -0.0307,  -0.0320,  -0.0333,  -0.0341,  -0.0348,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357,  -0.0357]
  
  years = collect(Yr(2022):Final)
  for ecc in eccs, year in years
    xMERM[ecc,NOX,BC,year] = xMERM[ecc,NOX,BC,year] - TempProcess[ecc,NOX,BC,year]
  end

  ApplyToCogeneration(data,fueleps,NOX,Yr(2022):Final,eccs,BC)
  
  WriteDisk(db,"MEInput/xMERM",xMERM)
  WriteDisk(db,"$Input/xRM",xRM)
  WriteDisk(db,"EGInput/xUnRP",xUnRP)
  WriteDisk(db,"EGInput/UnPRSw",UnPRSw)
end

function PolicyControl(db)
  @info "CAC_ProvRecipReg.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
