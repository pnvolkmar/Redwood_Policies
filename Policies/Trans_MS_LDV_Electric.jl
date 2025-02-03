#
# Trans_MS_LDV_Electric.jl
#
# Targets for ZEV market shares in Transportation by Matt Lewis, June 16 2023
# Includes BC and QC ZEV mandate and Federal Subsidy
# Revised structure Jeff Amlin 07/20/21
# Consistent with CP = 170 and the EPA Final Rule (ie Biden rule)
# Updated with Transport Canada's ZEV BAU from Sept 6 2022
# 2025 14.6%, 2030 36.7%, 2040 59%
#

using SmallModel

module Trans_MS_LDV_Electric

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
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
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
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
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  ICEMarketChange::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Change in ICEMarketShares after EV Change
  ICEMarketShareNew::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Recalculated market share of ICE passenger vehicle sales
  ICEMarketShareOld::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Base market share of ICE passenger vehicle sales
  MSFPVBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sum of Personal Vehicle Market Shares in Base
  MSFTarget::VariableArray{3} = zeros(Float64,length(Tech),length(Area),length(Year)) # [Tech,Area,Year] Target Market Share for Policy Vehicles (Driver/Driver)
  MSFTargetSum::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Target Market Share for Policy Vehicles (Driver/Driver)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC) = data 
  (; Nation,Tech) = data
  (; ANMap,ICEMarketChange,ICEMarketShareNew) = data
  (; ICEMarketShareOld,MSFPVBase,MSFTarget,MSFTargetSum,xMMSF) = data

  Passenger = Select(EC,"Passenger");
  areas = Select(Area,["BC","AB","SK","MB","ON","QC","NB","NS","PE","NL"])
  years = collect(Yr(2016):Yr(2050));

  LDVElectric = Select(Tech,"LDVElectric");
  
  #
  # TODOJulia - create an equation for each Area for example MSFTarget[LDVElectric,BC,years] .= [  do we need the "."? - Jeff Amlin 6/3/24
  #
 MSFTarget[LDVElectric,areas,years] .= [
  # 2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
    0.002 0.003 0.008 0.020 0.021 0.027 0.041 0.046 0.054 0.061 0.072 0.089 0.111 0.138 0.172 0.186 0.199 0.215 0.231 0.246 0.247 0.248 0.249 0.250 0.251 0.252 0.253 0.254 0.256 0.257 0.258 0.259 0.260 0.261 0.263 # British Columbia                            
    0.000 0.000 0.000 0.001 0.001 0.002 0.006 0.007 0.009 0.011 0.015 0.019 0.024 0.028 0.033 0.036 0.039 0.042 0.045 0.048 0.048 0.050 0.054 0.057 0.061 0.065 0.070 0.074 0.079 0.084 0.090 0.096 0.102 0.109 0.116 # Alberta and the Territories
    0.000 0.000 0.000 0.001 0.001 0.002 0.004 0.006 0.009 0.010 0.014 0.018 0.024 0.029 0.036 0.039 0.042 0.046 0.049 0.053 0.053 0.056 0.060 0.065 0.070 0.075 0.080 0.086 0.092 0.099 0.106 0.113 0.121 0.130 0.139 # Saskatchewan
    0.000 0.000 0.000 0.001 0.001 0.002 0.005 0.007 0.010 0.012 0.017 0.022 0.028 0.034 0.040 0.044 0.048 0.052 0.055 0.059 0.059 0.062 0.066 0.071 0.076 0.081 0.086 0.092 0.098 0.104 0.111 0.119 0.126 0.135 0.144 # Manitoba
    0.000 0.002 0.002 0.003 0.003 0.006 0.015 0.014 0.020 0.021 0.028 0.033 0.039 0.044 0.048 0.051 0.055 0.058 0.062 0.067 0.067 0.069 0.074 0.079 0.084 0.089 0.095 0.101 0.108 0.115 0.123 0.131 0.139 0.148 0.158 # Ontario
    0.002 0.004 0.010 0.017 0.022 0.028 0.047 0.056 0.063 0.077 0.092 0.120 0.152 0.188 0.235 0.264 0.294 0.329 0.356 0.390 0.393 0.395 0.398 0.401 0.404 0.407 0.410 0.413 0.416 0.420 0.423 0.426 0.429 0.432 0.436 # Quebec
    0.000 0.000 0.000 0.001 0.001 0.002 0.005 0.008 0.011 0.011 0.016 0.020 0.026 0.032 0.039 0.042 0.046 0.050 0.053 0.057 0.057 0.060 0.064 0.069 0.074 0.078 0.084 0.089 0.095 0.101 0.107 0.114 0.122 0.129 0.138 # New Brunswick
    0.000 0.000 0.000 0.001 0.001 0.003 0.007 0.012 0.015 0.015 0.021 0.027 0.034 0.042 0.051 0.055 0.059 0.064 0.068 0.073 0.073 0.076 0.081 0.087 0.093 0.099 0.105 0.112 0.119 0.126 0.134 0.143 0.152 0.162 0.172 # Nova Scotia
    0.000 0.000 0.000 0.001 0.001 0.007 0.009 0.011 0.013 0.018 0.024 0.029 0.035 0.041 0.046 0.050 0.054 0.059 0.064 0.069 0.069 0.073 0.079 0.085 0.092 0.098 0.105 0.113 0.120 0.129 0.138 0.147 0.158 0.169 0.180 # Prince Edward Island
    0.000 0.000 0.000 0.000 0.000 0.001 0.003 0.003 0.004 0.005 0.007 0.010 0.013 0.017 0.022 0.024 0.026 0.029 0.032 0.034 0.035 0.037 0.040 0.044 0.048 0.051 0.055 0.059 0.063 0.067 0.072 0.077 0.082 0.088 0.094 # Newfoundland and Labrador
  ]

  LDTElectric = Select(Tech,"LDTElectric");
  MSFTarget[LDTElectric,areas,years] .= [
  # 2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  0.004 0.006 0.018 0.043 0.053 0.071 0.108 0.120 0.142 0.161 0.189 0.235 0.295 0.367 0.457 0.495 0.531 0.574 0.616 0.658 0.661 0.663 0.666 0.669 0.673 0.676 0.679 0.683 0.686 0.690 0.693 0.697 0.700 0.704 0.708
  0.001 0.001 0.002 0.003 0.005 0.010 0.021 0.025 0.036 0.041 0.057 0.072 0.091 0.110 0.128 0.140 0.150 0.163 0.173 0.186 0.186 0.194 0.207 0.222 0.237 0.253 0.270 0.288 0.307 0.327 0.349 0.372 0.397 0.424 0.452
  0.000 0.000 0.001 0.001 0.002 0.006 0.010 0.014 0.020 0.024 0.034 0.043 0.057 0.070 0.084 0.093 0.100 0.110 0.117 0.126 0.127 0.133 0.143 0.154 0.165 0.177 0.190 0.204 0.218 0.234 0.251 0.269 0.288 0.309 0.331
  0.000 0.000 0.001 0.002 0.004 0.006 0.013 0.019 0.028 0.034 0.048 0.061 0.078 0.095 0.114 0.124 0.134 0.146 0.155 0.166 0.167 0.174 0.187 0.200 0.215 0.229 0.244 0.260 0.278 0.296 0.315 0.336 0.359 0.383 0.408
  0.001 0.003 0.008 0.006 0.011 0.018 0.043 0.041 0.056 0.060 0.081 0.095 0.112 0.127 0.140 0.149 0.160 0.171 0.183 0.195 0.195 0.202 0.216 0.230 0.246 0.262 0.279 0.298 0.318 0.339 0.361 0.385 0.410 0.437 0.466
  0.002 0.004 0.009 0.018 0.026 0.029 0.049 0.058 0.065 0.080 0.096 0.125 0.159 0.196 0.245 0.275 0.306 0.343 0.371 0.407 0.410 0.412 0.415 0.419 0.422 0.425 0.428 0.431 0.435 0.438 0.441 0.445 0.448 0.451 0.455
  0.000 0.000 0.000 0.001 0.002 0.005 0.013 0.019 0.025 0.027 0.038 0.049 0.064 0.078 0.094 0.103 0.111 0.122 0.129 0.139 0.139 0.145 0.156 0.168 0.180 0.191 0.204 0.217 0.231 0.246 0.263 0.280 0.298 0.317 0.338
  0.000 0.000 0.000 0.001 0.002 0.006 0.013 0.023 0.028 0.028 0.040 0.051 0.066 0.081 0.098 0.106 0.114 0.124 0.132 0.141 0.142 0.147 0.157 0.168 0.179 0.191 0.203 0.216 0.230 0.245 0.261 0.278 0.295 0.314 0.335
  0.000 0.000 0.001 0.002 0.002 0.013 0.017 0.020 0.025 0.033 0.044 0.054 0.066 0.077 0.087 0.095 0.103 0.111 0.121 0.130 0.132 0.139 0.150 0.162 0.175 0.187 0.201 0.215 0.231 0.247 0.264 0.283 0.303 0.324 0.347
  0.000 0.000 0.000 0.001 0.001 0.002 0.010 0.011 0.015 0.018 0.027 0.036 0.049 0.063 0.079 0.088 0.097 0.108 0.116 0.126 0.127 0.136 0.149 0.162 0.176 0.188 0.202 0.216 0.231 0.247 0.264 0.283 0.303 0.324 0.347
  ]

  LDVHybrid = Select(Tech,"LDVHybrid");
  MSFTarget[LDVHybrid,areas,years] .= [
  # 2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  0.001 0.002 0.005 0.007 0.006 0.009 0.009 0.011 0.011 0.014 0.014 0.016 0.018 0.022 0.025 0.024 0.025 0.024 0.025 0.026 0.025 0.024 0.023 0.022 0.021 0.020 0.018 0.017 0.016 0.015 0.013 0.012 0.011 0.009 0.008
  0.000 0.000 0.000 0.001 0.001 0.001 0.002 0.002 0.003 0.003 0.005 0.006 0.007 0.008 0.009 0.009 0.009 0.009 0.010 0.011 0.011 0.011 0.012 0.012 0.013 0.013 0.014 0.015 0.016 0.016 0.017 0.018 0.019 0.019 0.020
  0.000 0.000 0.000 0.001 0.001 0.001 0.002 0.003 0.004 0.004 0.006 0.008 0.010 0.012 0.014 0.014 0.015 0.015 0.016 0.017 0.017 0.017 0.018 0.019 0.020 0.021 0.022 0.023 0.025 0.026 0.027 0.028 0.030 0.031 0.032
  0.000 0.000 0.000 0.001 0.000 0.002 0.002 0.003 0.004 0.005 0.007 0.008 0.010 0.012 0.014 0.014 0.014 0.014 0.016 0.017 0.017 0.017 0.018 0.019 0.020 0.021 0.022 0.023 0.025 0.026 0.027 0.028 0.030 0.031 0.033
  0.001 0.002 0.002 0.001 0.001 0.002 0.003 0.004 0.005 0.005 0.006 0.007 0.008 0.009 0.010 0.010 0.010 0.011 0.011 0.012 0.012 0.012 0.012 0.013 0.013 0.014 0.014 0.015 0.015 0.016 0.017 0.017 0.018 0.019 0.019
  0.003 0.004 0.011 0.013 0.012 0.018 0.017 0.021 0.028 0.031 0.035 0.047 0.058 0.071 0.083 0.083 0.084 0.083 0.093 0.099 0.097 0.094 0.091 0.088 0.085 0.082 0.079 0.076 0.073 0.070 0.067 0.063 0.060 0.057 0.054
  0.000 0.000 0.000 0.001 0.001 0.002 0.003 0.005 0.006 0.006 0.008 0.011 0.013 0.016 0.018 0.018 0.019 0.019 0.021 0.022 0.022 0.022 0.024 0.025 0.026 0.028 0.029 0.030 0.032 0.033 0.035 0.036 0.038 0.040 0.042
  0.000 0.000 0.000 0.000 0.001 0.002 0.003 0.006 0.007 0.007 0.009 0.012 0.014 0.017 0.019 0.019 0.020 0.020 0.021 0.022 0.022 0.023 0.024 0.025 0.026 0.027 0.029 0.030 0.031 0.033 0.034 0.035 0.037 0.038 0.040
  0.000 0.000 0.000 0.001 0.002 0.003 0.004 0.010 0.010 0.012 0.016 0.019 0.021 0.023 0.024 0.025 0.026 0.027 0.028 0.029 0.029 0.029 0.030 0.031 0.032 0.033 0.034 0.035 0.036 0.037 0.037 0.038 0.039 0.040 0.041
  0.000 0.000 0.000 0.000 0.000 0.001 0.001 0.002 0.003 0.003 0.005 0.006 0.008 0.010 0.012 0.012 0.013 0.013 0.014 0.015 0.015 0.016 0.017 0.018 0.019 0.020 0.020 0.021 0.022 0.023 0.024 0.025 0.026 0.027 0.028
  ]

  LDTHybrid = Select(Tech,"LDTHybrid");
  MSFTarget[LDTHybrid,areas,years] .= [
  # 2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  0.003 0.003 0.011 0.016 0.014 0.023 0.023 0.029 0.029 0.036 0.037 0.044 0.049 0.057 0.066 0.064 0.066 0.063 0.066 0.070 0.067 0.065 0.062 0.059 0.056 0.052 0.049 0.046 0.043 0.039 0.036 0.032 0.029 0.025 0.021
  0.001 0.001 0.001 0.002 0.002 0.005 0.007 0.009 0.011 0.013 0.018 0.023 0.026 0.031 0.035 0.035 0.037 0.036 0.040 0.042 0.041 0.043 0.045 0.047 0.050 0.052 0.055 0.057 0.060 0.063 0.066 0.069 0.072 0.076 0.079
  0.000 0.000 0.001 0.001 0.001 0.003 0.004 0.007 0.009 0.011 0.015 0.020 0.024 0.029 0.033 0.033 0.035 0.035 0.038 0.040 0.040 0.041 0.043 0.046 0.048 0.051 0.053 0.056 0.058 0.061 0.064 0.067 0.070 0.073 0.077
  0.001 0.000 0.001 0.002 0.002 0.004 0.007 0.008 0.011 0.013 0.018 0.023 0.028 0.034 0.038 0.038 0.041 0.041 0.045 0.047 0.047 0.048 0.051 0.054 0.057 0.060 0.063 0.066 0.070 0.073 0.077 0.081 0.085 0.089 0.093
  0.002 0.004 0.008 0.003 0.003 0.006 0.008 0.012 0.014 0.015 0.017 0.022 0.024 0.026 0.028 0.029 0.030 0.032 0.033 0.034 0.034 0.034 0.036 0.037 0.039 0.040 0.042 0.044 0.045 0.047 0.049 0.051 0.053 0.055 0.057
  0.003 0.005 0.010 0.014 0.015 0.019 0.018 0.021 0.029 0.033 0.036 0.049 0.061 0.074 0.087 0.086 0.088 0.086 0.097 0.103 0.101 0.098 0.095 0.092 0.089 0.086 0.083 0.079 0.076 0.073 0.070 0.066 0.063 0.059 0.056
  0.000 0.001 0.001 0.001 0.002 0.004 0.007 0.012 0.014 0.015 0.020 0.026 0.031 0.038 0.043 0.043 0.046 0.046 0.050 0.053 0.052 0.055 0.057 0.061 0.064 0.067 0.071 0.074 0.078 0.081 0.085 0.089 0.093 0.098 0.102
  0.000 0.000 0.001 0.001 0.001 0.005 0.006 0.012 0.013 0.012 0.017 0.022 0.027 0.032 0.036 0.036 0.038 0.038 0.041 0.043 0.043 0.044 0.046 0.048 0.051 0.053 0.055 0.058 0.060 0.063 0.066 0.069 0.072 0.075 0.078
  0.000 0.000 0.000 0.002 0.003 0.006 0.007 0.018 0.018 0.022 0.029 0.035 0.039 0.044 0.046 0.048 0.050 0.052 0.054 0.056 0.054 0.055 0.057 0.059 0.061 0.063 0.064 0.066 0.068 0.070 0.072 0.074 0.076 0.078 0.080
  0.000 0.000 0.000 0.000 0.001 0.002 0.004 0.008 0.011 0.012 0.017 0.023 0.029 0.036 0.043 0.044 0.047 0.048 0.052 0.055 0.055 0.058 0.061 0.065 0.069 0.072 0.075 0.079 0.082 0.085 0.089 0.093 0.096 0.100 0.104
  ]

  #
  # Set Territories equal to AB since BC is now an outlier in terms of ZEV market shares
  # Matt Lewis July 12 2019
  #
  years = collect(Future:Yr(2050))
  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  areas = Select(Area,["NT","NU"])
  AB = Select(Area,"AB")
  for tech in techs, area in areas, year in years
    MSFTarget[tech,area,year] = MSFTarget[tech,AB,year]
  end

  #
  # Set YT equal to BC since they have similar ZEV targets
  # Matt Lewis Sept 18 2020
  #  
  YT = Select(Area,"YT");
  BC = Select(Area,"BC");
  for tech in techs, year in years
    MSFTarget[techs,YT,years] = MSFTarget[techs,BC,years]
  end

  # 
  # Baseline MarketShare for Personal Vehicles
  #   
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1);
  techs = Select(Tech,(from="LDVGasoline",to="LDTFuelCell"))
  for area in areas, year in years
    MSFPVBase[area,year] = sum(xMMSF[1,tech,Passenger,area,year] for tech in techs)
  end

  #
  # Recalculate Market Share TargetEVInput for E2020 passenger market shares
  #  
  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  for tech in techs, area in areas, year in years
    MSFTarget[tech,area,year] = MSFTarget[tech,area,year] * MSFPVBase[area,year]
  end

  for area in areas, year in years
    MSFTargetSum[area,year] = sum(MSFTarget[tech,area,year] for tech in techs)
  end

  #
  # Code below replicates weighting in ZEV_Prov to match existing Ref23 - Ian 08/31/21
  # 
  techs = Select(Tech,["LDVGasoline","LDVDiesel","LDVNaturalGas","LDVPropane",
                       "LDVEthanol","LDTGasoline","LDTDiesel",
                       "LDTNaturalGas","LDTPropane","LDTEthanol"])
  for area in areas, year in years
    ICEMarketShareOld[area,year] = sum(xMMSF[1,tech,Passenger,area,year] for tech in techs)
  end

  techs = Select(Tech,(from="LDVGasoline",to="LDTFuelCell"))
    
  for area in areas, year in years
    ICEMarketShareNew[area,year] = MSFPVBase[area,year]-MSFTargetSum[area,year]
  end
    
  for area in areas, year in years
    @finite_math ICEMarketChange[area,year] = ICEMarketShareNew[area,year]/
      ICEMarketShareOld[area,year]
  end
     
  for tech in techs, area in areas, year in years
    xMMSF[1,tech,Passenger,area,year] = xMMSF[1,tech,Passenger,area,year]*
      ICEMarketChange[area,year]
  end

  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  for tech in techs, area in areas, year in years
    xMMSF[1,tech,Passenger,area,year] = MSFTarget[tech,area,year]
  end

  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)  
end

function PolicyControl(db)
  @info ("Trans_MS_LDV_Electric - PolicyControl");
  TransPolicy(db);
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
