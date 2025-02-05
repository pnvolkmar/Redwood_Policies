#
# CAC_MSAPR.jl
#
# This TXP Models the emission reductions for the MSAPR Reg
# It covers reciprocating engines (sweet and sour natural gas sectors, pipelines)
# boilers and heaters (various industrial sectors), and the cement sector
# Adapted from CAC_ProvRecipReg.jl by Matt Lewis October 18, 2016
#
# Changed line 97 from 2015 to Future - Andy 18.10.02
#
# Added Cement reductions for ON and BC and modified Cement reductions for QC based on 
# Information received from Bao Nguyen (Metals and Minerals Processing division, ECCC)
# Regarding MSAPR reg and implementation of SCNR systems in 3 facilities. 
# See MSAPR_Cement_220929.xlsx for details - Audrey 22.10.03 
#

using SmallModel

module CAC_MSAPR

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
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB")#  Base Case Name

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
  Temp::VariableArray{3} = zeros(Float64,length(ECC),length(Year),length(Area)) # [ECC,Year,Area] Scratch Variable for Input
end

function ApplyToCogeneration(data,poll,years)
  (; Area,Areas,ECC,ECCs,FuelEPs) = data
  (; Temp,UnArea,UnNation,UnCogen,UnPRSw,UnSector,xUnRP) = data

  unit1 = findall(UnNation .== "CN")
  unit2 = findall(UnCogen .> (0.0))
  units = intersect(unit1,unit2)
  for area in Areas, ecc in ECCs, unit in units
    if (UnSector[unit] == ECC[ecc]) && (UnArea[unit] == Area[area])
      [xUnRP[unit,fuelep,poll,year] = xUnRP[unit,fuelep,poll,year] + 
        Temp[ecc,year,area] for fuelep in FuelEPs, year in years]
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
  (; Area,Areas,EC,ECC,ECCs) = data
  (; FuelEPs) = data
  (; Poll) = data
  (; Temp) = data
  (; UnPRSw) = data
  (; xMERM,xRM,xUnRP) = data

  # 
  # Nox Emission Reductions
  # 
  NOX = Select(Poll, "NOX")
  AB = Select(Area,"AB")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"CSSOilSands"),                 Yr(2015):Final, AB] = [0.000,  0.091,  0.103,  0.073,  0.054,  0.057,  0.056,  0.068,  0.090,  0.076,  0.063,  0.071,  0.076,  0.072,  0.068,  0.064,  0.062,  0.060,  0.057,  0.054,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053,  0.053]
  Temp[Select(ECC,"Fertilizer"),                  Yr(2015):Final, AB] = [0.000,  0.015,  0.009,  0.011,  0.009,  0.010,  0.010,  0.010,  0.010,  0.009,  0.008,  0.008,  0.007,  0.006,  0.006,  0.006,  0.005,  0.007,  0.006,  0.031,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030,  0.030]
  Temp[Select(ECC,"HeavyOilMining"),              Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.097,  0.103,  0.109,  0.115,  0.120,  0.414,  0.417,  0.417,  0.418,  0.418,  0.419,  0.419,  0.419,  0.419,  0.419,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418,  0.418]
  Temp[Select(ECC,"IndustrialGas"),               Yr(2015):Final, AB] = [0.000,  0.037,  0.028,  0.022,  0.013,  0.220,  0.285,  0.305,  0.305,  0.303,  0.296,  0.293,  0.288,  0.285,  0.288,  0.284,  0.283,  0.294,  0.294,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300,  0.300]
  Temp[Select(ECC,"LightOilMining"),              Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.089,  0.094,  0.098,  0.102,  0.105,  0.372,  0.371,  0.370,  0.370,  0.371,  0.374,  0.380,  0.387,  0.395,  0.403,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412,  0.412]
  Temp[Select(ECC,"OilSandsUpgraders"),           Yr(2015):Final, AB] = [0.000,  0.029,  0.034,  0.024,  0.018,  0.019,  0.019,  0.023,  0.032,  0.027,  0.023,  0.027,  0.029,  0.028,  0.027,  0.026,  0.025,  0.025,  0.024,  0.023,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022]
  Temp[Select(ECC,"OtherChemicals"),              Yr(2015):Final, AB] = [0.000,  0.034,  0.026,  0.020,  0.012,  0.201,  0.258,  0.276,  0.275,  0.272,  0.265,  0.262,  0.257,  0.255,  0.258,  0.254,  0.253,  0.262,  0.261,  0.264,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263,  0.263]
  Temp[Select(ECC,"Petrochemicals"),              Yr(2015):Final, AB] = [0.000,  0.006,  0.005,  0.004,  0.002,  0.038,  0.049,  0.053,  0.053,  0.052,  0.050,  0.050,  0.048,  0.048,  0.048,  0.046,  0.046,  0.047,  0.046,  0.046,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.001,  0.001,  0.001,  0.001,  0.001,  0.001,  0.030,  0.030,  0.029,  0.029,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028,  0.028]
  Temp[Select(ECC,"SAGDOilSands"),                Yr(2015):Final, AB] = [0.000,  0.074,  0.081,  0.056,  0.041,  0.041,  0.040,  0.047,  0.059,  0.048,  0.039,  0.043,  0.045,  0.042,  0.039,  0.037,  0.035,  0.034,  0.031,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029,  0.029]
  Temp[Select(ECC,"SourGasProcessing"),           Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.091,  0.095,  0.099,  0.103,  0.107,  0.377,  0.378,  0.380,  0.381,  0.382,  0.382,  0.389,  0.394,  0.397,  0.400,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404,  0.404]
  Temp[Select(ECC,"UnconventionalGasProduction"), Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.097,  0.100,  0.104,  0.108,  0.112,  0.399,  0.401,  0.404,  0.406,  0.407,  0.408,  0.412,  0.415,  0.414,  0.412,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411]
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.092,  0.096,  0.099,  0.103,  0.107,  0.379,  0.380,  0.381,  0.382,  0.383,  0.384,  0.391,  0.395,  0.398,  0.402,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406,  0.406]
  Temp[Select(ECC,"ConventionalGasProduction"),   Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.097,  0.100,  0.104,  0.108,  0.112,  0.399,  0.401,  0.404,  0.406,  0.407,  0.408,  0.412,  0.415,  0.414,  0.412,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411,  0.411]
  
 
  BC = Select(Area,"BC")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"LightOilMining"),              Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.066,  0.068,  0.068,  0.068,  0.068,  0.232,  0.224,  0.218,  0.212,  0.207,  0.204,  0.202,  0.200,  0.200,  0.200,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202,  0.202]
  Temp[Select(ECC,"OtherChemicals"),              Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.028,  0.028,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129,  0.129]
  Temp[Select(ECC,"OtherNonferrous"),             Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.143,  0.140,  0.155,  0.152,  0.149,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146,  0.146]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.015,  0.015,  0.015,  0.015,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014]
  Temp[Select(ECC,"SourGasProcessing"),           Yr(2015):Final, BC] = [0.000,  0.004,  0.005,  0.004,  0.006,  0.063,  0.061,  0.058,  0.056,  0.054,  0.176,  0.173,  0.170,  0.171,  0.171,  0.171,  0.170,  0.171,  0.171,  0.171,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170,  0.170]
  Temp[Select(ECC,"UnconventionalGasProduction"), Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.056,  0.054,  0.052,  0.051,  0.051,  0.176,  0.173,  0.172,  0.172,  0.172,  0.171,  0.171,  0.170,  0.169,  0.168,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167]
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, BC] = [0.000,  0.004,  0.005,  0.004,  0.006,  0.063,  0.061,  0.058,  0.056,  0.054,  0.175,  0.172,  0.170,  0.171,  0.170,  0.170,  0.169,  0.170,  0.171,  0.170,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169,  0.169]
  Temp[Select(ECC,"ConventionalGasProduction"),   Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.056,  0.054,  0.052,  0.051,  0.051,  0.175,  0.172,  0.171,  0.171,  0.171,  0.171,  0.170,  0.169,  0.168,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167,  0.167]
  Temp[Select(ECC,"Cement"),                      Yr(2015):Final, BC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213,  0.213]

  MB = Select(Area,"MB")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"LightOilMining"),              Yr(2015):Final, MB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.159,  0.175,  0.190,  0.206,  0.221,  0.447,  0.453,  0.455,  0.458,  0.461,  0.464,  0.467,  0.470,  0.473,  0.476,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479,  0.479]

  NB = Select(Area,"NB")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"NonMetalMining"),              Yr(2015):Final, NB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.011,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010,  0.010]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, NB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.001,  0.001,  0.001,  0.001,  0.001,  0.001,  0.001,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002]

  NL = Select(Area,"NL")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"FrontierOilMining"),           Yr(2015):Final, NL] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.066,  0.069,  0.071,  0.074,  0.077,  0.217,  0.218,  0.383,  0.386,  0.387,  0.389,  0.396,  0.405,  0.412,  0.417,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424,  0.424]

  NT = Select(Area,"NT")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"FrontierOilMining"),           Yr(2015):Final, NT] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.115,  0.126,  0.138,  0.150,  0.164,  0.477,  0.483,  0.486,  0.489,  0.492,  0.495,  0.498,  0.501,  0.504,  0.508,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511,  0.511]
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, NT] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.294,  0.352,  0.420,  0.474,  0.474,  0.474,  0.480,  0.483,  0.486,  0.489,  0.492,  0.495,  0.498,  0.502,  0.505,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508,  0.508]
  
  NS = Select(Area,"NS")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, NS] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.083,  0.091,  0.099,  0.110,  0.122,  0.466,  0.486,  0.489,  0.492,  0.495,  0.498,  0.502,  0.505,  0.508,  0.511,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514]
  Temp[Select(ECC,"ConventionalGasProduction"),   Yr(2015):Final, NS] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.077,  0.084,  0.092,  0.102,  0.114,  0.432,  0.469,  0.489,  0.492,  0.495,  0.498,  0.502,  0.505,  0.508,  0.511,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514]

  ON = Select(Area,"ON")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"Fertilizer"),                  Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.016,  0.016,  0.015,  0.015,  0.015,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014]
  Temp[Select(ECC,"IndustrialGas"),               Yr(2015):Final, ON] = [0.000,  0.019,  0.015,  0.015,  0.012,  0.010,  0.015,  0.013,  0.016,  0.015,  0.012,  0.012,  0.012,  0.011,  0.012,  0.011,  0.010,  0.010,  0.011,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014,  0.014]
  Temp[Select(ECC,"LightOilMining"),              Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.176,  0.197,  0.220,  0.246,  0.275,  0.480,  0.486,  0.489,  0.492,  0.495,  0.498,  0.502,  0.505,  0.508,  0.511,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514]
  Temp[Select(ECC,"OtherChemicals"),              Yr(2015):Final, ON] = [0.000,  0.019,  0.015,  0.015,  0.011,  0.010,  0.015,  0.013,  0.016,  0.015,  0.012,  0.012,  0.012,  0.011,  0.013,  0.011,  0.011,  0.010,  0.011,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015]
  Temp[Select(ECC,"OtherNonferrous"),             Yr(2015):Final, ON] = [0.000,  0.121,  0.093,  0.128,  0.116,  0.089,  0.099,  0.092,  0.082,  0.079,  0.081,  0.077,  0.071,  0.068,  0.070,  0.070,  0.067,  0.065,  0.066,  0.029,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068,  0.068]
  Temp[Select(ECC,"Petrochemicals"),              Yr(2015):Final, ON] = [0.000,  0.018,  0.014,  0.014,  0.011,  0.010,  0.015,  0.012,  0.016,  0.014,  0.012,  0.012,  0.012,  0.010,  0.012,  0.011,  0.010,  0.009,  0.010,  0.014,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013,  0.013]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, ON] = [0.000,  0.000,  0.002,  0.002,  0.002,  0.002,  0.004,  0.004,  0.004,  0.004,  0.010,  0.011,  0.010,  0.010,  0.011,  0.014,  0.018,  0.021,  0.021,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022,  0.022]
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.168,  0.186,  0.205,  0.226,  0.249,  0.452,  0.458,  0.461,  0.464,  0.467,  0.470,  0.472,  0.475,  0.478,  0.481,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485,  0.485]
  Temp[Select(ECC,"ConventionalGasProduction"),   Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.178,  0.197,  0.217,  0.240,  0.264,  0.480,  0.486,  0.489,  0.492,  0.495,  0.498,  0.501,  0.504,  0.508,  0.511,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514,  0.514]
  Temp[Select(ECC,"Cement"),                      Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078,  0.078]

  QC = Select(Area,"QC")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"Aluminum"),                    Yr(2015):Final, QC] = [0.000,  0.002,  0.002,  0.002,  0.002,  0.001,  0.002,  0.002,  0.003,  0.003,  0.004,  0.002,  0.001,  0.001,  0.002,  0.002,  0.002,  0.002,  0.002,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003]
  Temp[Select(ECC,"IndustrialGas"),               Yr(2015):Final, QC] = [0.000,  0.200,  0.143,  0.131,  0.094,  0.095,  0.091,  0.074,  0.066,  0.059,  0.045,  0.042,  0.033,  0.024,  0.027,  0.021,  0.017,  0.014,  0.011,  0.010,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007,  0.007]
  Temp[Select(ECC,"IronSteel"),                   Yr(2015):Final, QC] = [0.000,  0.002,  0.000,  0.001,  0.000,  0.002,  0.003,  0.003,  0.003,  0.004,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.003,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002,  0.002]
  Temp[Select(ECC,"OtherChemicals"),              Yr(2015):Final, QC] = [0.000,  0.238,  0.189,  0.192,  0.147,  0.158,  0.160,  0.137,  0.128,  0.119,  0.095,  0.092,  0.073,  0.056,  0.064,  0.051,  0.041,  0.035,  0.029,  0.027,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019,  0.019]
  Temp[Select(ECC,"OtherNonferrous"),             Yr(2015):Final, QC] = [0.000,  0.088,  0.164,  0.151,  0.129,  0.099,  0.105,  0.097,  0.096,  0.090,  0.088,  0.082,  0.074,  0.067,  0.065,  0.063,  0.058,  0.060,  0.061,  0.063,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062,  0.062]
  Temp[Select(ECC,"Petrochemicals"),              Yr(2015):Final, QC] = [0.000,  0.055,  0.043,  0.044,  0.035,  0.038,  0.039,  0.034,  0.031,  0.029,  0.023,  0.022,  0.017,  0.013,  0.015,  0.011,  0.009,  0.007,  0.006,  0.005,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004,  0.004]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, QC] = [0.000,  0.000,  0.009,  0.010,  0.012,  0.012,  0.015,  0.015,  0.015,  0.015,  0.015,  0.026,  0.024,  0.030,  0.032,  0.044,  0.044,  0.046,  0.046,  0.046,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045,  0.045]
  Temp[Select(ECC,"Cement"),                      Yr(2015):Final, QC] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105,  0.105]
  
  SK = Select(Area,"SK")
  #                 ECC                            Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"Fertilizer"),                  Yr(2015):Final, SK] = [0.000,  0.150,  0.084,  0.093,  0.074,  0.099,  0.096,  0.080,  0.075,  0.068,  0.059,  0.057,  0.048,  0.039,  0.038,  0.033,  0.030,  0.029,  0.025,  0.024,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020,  0.020]
  Temp[Select(ECC,"HeavyOilMining"),              Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.096,  0.101,  0.106,  0.111,  0.116,  0.412,  0.414,  0.416,  0.419,  0.422,  0.427,  0.437,  0.447,  0.459,  0.471,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484,  0.484]
  Temp[Select(ECC,"LightOilMining"),              Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.070,  0.072,  0.074,  0.075,  0.076,  0.265,  0.260,  0.255,  0.252,  0.249,  0.248,  0.249,  0.251,  0.254,  0.258,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265,  0.265]
  Temp[Select(ECC,"NonMetalMining"),              Yr(2015):Final, SK] = [0.000,  0.144,  0.063,  0.034,  0.000,  0.001,  0.005,  0.013,  0.002,  0.059,  0.064,  0.078,  0.068,  0.072,  0.074,  0.073,  0.072,  0.089,  0.087,  0.088,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086,  0.086]
  Temp[Select(ECC,"OilSandsUpgraders"),           Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.005,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011,  0.011]
  Temp[Select(ECC,"OtherChemicals"),              Yr(2015):Final, SK] = [0.000,  0.591,  0.418,  0.408,  0.303,  0.292,  0.287,  0.225,  0.210,  0.188,  0.133,  0.128,  0.094,  0.060,  0.079,  0.053,  0.038,  0.033,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021,  0.021]
  Temp[Select(ECC,"PulpPaperMills"),              Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.000,  0.014,  0.016,  0.015,  0.014,  0.015,  0.016,  0.016,  0.016,  0.015,  0.016,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015,  0.015]
  Temp[Select(ECC,"SourGasProcessing"),           Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.001,  0.001,  0.129,  0.139,  0.150,  0.164,  0.175,  0.481,  0.492,  0.498,  0.501,  0.509,  0.512,  0.516,  0.520,  0.523,  0.527,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531]
  Temp[Select(ECC,"UnconventionalGasProduction"), Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.129,  0.139,  0.149,  0.160,  0.170,  0.479,  0.485,  0.488,  0.491,  0.494,  0.497,  0.500,  0.503,  0.506,  0.510,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513]
  Temp[Select(ECC,"SweetGasProcessing"),          Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.001,  0.001,  0.129,  0.139,  0.150,  0.164,  0.175,  0.481,  0.492,  0.498,  0.501,  0.509,  0.512,  0.516,  0.520,  0.523,  0.527,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531,  0.531]
  Temp[Select(ECC,"ConventionalGasProduction"),   Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.129,  0.139,  0.149,  0.160,  0.170,  0.479,  0.485,  0.488,  0.491,  0.494,  0.497,  0.500,  0.503,  0.506,  0.510,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513,  0.513]
  

  for area in Areas, ecc in ECCs
    ec = Select(EC,filter(x -> x in EC,[ECC[ecc]]))
    if ec != []
      ec = ec[1]
      [xRM[fuelep,ec,NOX,area,year] = xRM[fuelep,ec,NOX,area,year] - 
        Temp[ecc,year,area] for fuelep in FuelEPs, year in Future:Final]
    end
    
  end
  
  years = collect(Future:Final)
  for ecc in ECCs, area in Areas, year in years
    xMERM[ecc,NOX,area,year] = xMERM[ecc,NOX,area,year] - Temp[ecc,year,area]
  end

  ApplyToCogeneration(data,NOX,Future:Final)

  WriteDisk(db,"MEInput/xMERM",xMERM)
  WriteDisk(db,"$Input/xRM",xRM)
  WriteDisk(db,"EGInput/xUnRP",xUnRP)
  WriteDisk(db,"EGInput/UnPRSw",UnPRSw)
end

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB")#  Base Case Name

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
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMERM::VariableArray{4} = ReadDisk(db,"MEInput/xMERM") # [ECC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)
  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [FuelEP,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Change::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Change in Policy Variable
  Temp::VariableArray{3} = zeros(Float64,length(ECC),length(Year),length(Area)) # [ECC,Year,Area] Scratch Variable for Input
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area,EC,ECC) = data 
  (; FuelEPs) = data
  (; Poll) = data
  (; Temp,xMERM,xRM) = data

  NOX = Select(Poll,"NOX")

  AB = Select(Area,"AB")
  ON = Select(Area,"ON")
  SK = Select(Area,"SK")
  #                 ECC           Year          Area   2015    2016    2017    2018    2019    2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040    2041    2042    2043    2044    2045    2046    2047    2048    2049    2050
  Temp[Select(ECC,"NGPipeline"), Yr(2015):Final, AB] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.022,  0.022,  0.022,  0.022,  0.022,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046,  0.046]
  Temp[Select(ECC,"NGPipeline"), Yr(2015):Final, ON] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.066,  0.066,  0.066,  0.066,  0.066,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101,  0.101]
  Temp[Select(ECC,"NGPipeline"), Yr(2015):Final, SK] = [0.000,  0.000,  0.000,  0.000,  0.000,  0.347,  0.347,  0.347,  0.347,  0.347,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443,  0.443]
  
  areas = Select(Area,["AB","ON","SK"])
  eccs = Select(ECC,"NGPipeline")
  for area in areas, ecc in eccs
    ec = Select(EC,filter(x -> x in EC,[ECC[ecc]]))
    if ec != []
      ec = ec[1]
      [xRM[fuelep,ec,NOX,area,year] = xRM[fuelep,ec,NOX,area,year] - 
        Temp[ecc,year,area] for fuelep in FuelEPs, year in Future:Final]
    end
    
  end

  [xMERM[ecc,NOX,area,year] = xMERM[ecc,NOX,area,year] - 
    Temp[ecc,year,area] for ecc in eccs, area in areas, year in Future:Final]

  WriteDisk(db,"MEInput/xMERM",xMERM)
  WriteDisk(db,"$Input/xRM",xRM)
end

function PolicyControl(db)
  @info "CAC_MSAPR.jl - PolicyControl"
  IndPolicy(db)
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
