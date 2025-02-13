#
# Trans_MS_LDV_Electric.jl
#
# Targets for ZEV market shares, 20% by 2026, 60% by 2030
# and 100% by 2035
# Aligned to TC Base ZEV forecast from Sept 10, 2024
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
  (; Area,EC,Enduse,Enduses) = data 
  (; Nation,Tech) = data
  (; ANMap,ICEMarketChange,ICEMarketShareNew) = data
  (; ICEMarketShareOld,MSFPVBase,MSFTarget,MSFTargetSum,xMMSF) = data

  #
  # Electric LDVs (EVs and Hybrids)
  #
  # EV Input data is Transport Canada forecast for all EV/Hybrids 
  # as a % of personal vehicles
  #
  Passenger = Select(EC,"Passenger")
  BC = Select(Area,"BC")
  AB = Select(Area,"AB")
  SK = Select(Area,"SK")
  MB = Select(Area,"MB")
  ON = Select(Area,"ON")
  QC = Select(Area,"QC")
  NB = Select(Area,"NB")
  NS = Select(Area,"NS")
  PE = Select(Area,"PE")
  NL = Select(Area,"NL")
  areas = Select(Area,["BC","AB","SK","MB","ON","QC","NB","NS","PE","NL"])
  LDVElectric = Select(Tech,"LDVElectric")
  LDTElectric = Select(Tech,"LDTElectric")
  LDVHybrid = Select(Tech,"LDVHybrid");
  LDTHybrid = Select(Tech,"LDTHybrid");

  years = collect(Yr(2016):Yr(2050))
  #                                  2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  MSFTarget[LDVElectric,BC,years] = [0.002 0.003 0.008 0.019 0.023 0.030 0.049 0.060 0.061 0.065 0.073 0.112 0.160 0.205 0.247 0.265 0.273 0.281 0.288 0.288 0.292 0.293 0.294 0.295 0.296 0.297 0.299 0.300 0.301 0.302 0.304 0.305 0.306 0.308 0.309]                           
  MSFTarget[LDVElectric,AB,years] = [0.000 0.000 0.001 0.001 0.001 0.003 0.007 0.008 0.009 0.016 0.021 0.021 0.031 0.044 0.079 0.116 0.142 0.172 0.181 0.193 0.196 0.196 0.196 0.197 0.197 0.198 0.198 0.198 0.199 0.199 0.200 0.200 0.201 0.201 0.202] 
  MSFTarget[LDVElectric,SK,years] = [0.000 0.000 0.000 0.000 0.001 0.001 0.002 0.003 0.003 0.006 0.009 0.009 0.014 0.021 0.039 0.058 0.072 0.088 0.093 0.122 0.124 0.124 0.125 0.125 0.126 0.126 0.127 0.127 0.128 0.128 0.129 0.129 0.130 0.130 0.131] 
  MSFTarget[LDVElectric,MB,years] = [0.000 0.000 0.000 0.001 0.001 0.002 0.004 0.006 0.008 0.013 0.018 0.018 0.028 0.040 0.073 0.107 0.132 0.160 0.169 0.182 0.184 0.184 0.184 0.185 0.185 0.186 0.186 0.187 0.187 0.188 0.188 0.188 0.189 0.189 0.190] 
  MSFTarget[LDVElectric,ON,years] = [0.001 0.001 0.003 0.003 0.005 0.007 0.018 0.019 0.018 0.031 0.041 0.037 0.052 0.070 0.116 0.167 0.204 0.242 0.257 0.256 0.259 0.260 0.261 0.262 0.262 0.263 0.264 0.264 0.265 0.266 0.266 0.267 0.268 0.268 0.269] 
  MSFTarget[LDVElectric,QC,years] = [0.002 0.003 0.008 0.015 0.019 0.022 0.038 0.058 0.076 0.064 0.089 0.122 0.165 0.206 0.239 0.266 0.285 0.300 0.302 0.304 0.310 0.311 0.314 0.316 0.318 0.320 0.322 0.325 0.327 0.329 0.332 0.334 0.336 0.339 0.341] 
  MSFTarget[LDVElectric,NB,years] = [0.000 0.000 0.000 0.001 0.001 0.002 0.006 0.011 0.013 0.020 0.026 0.025 0.036 0.050 0.087 0.129 0.159 0.193 0.204 0.236 0.240 0.240 0.241 0.242 0.243 0.244 0.245 0.245 0.246 0.247 0.248 0.249 0.250 0.250 0.251] 
  MSFTarget[LDVElectric,NS,years] = [0.000 0.000 0.000 0.001 0.001 0.004 0.008 0.011 0.011 0.023 0.031 0.030 0.045 0.064 0.113 0.166 0.204 0.247 0.260 0.290 0.293 0.294 0.295 0.296 0.297 0.298 0.299 0.300 0.301 0.302 0.303 0.304 0.305 0.306 0.307] 
  MSFTarget[LDVElectric,PE,years] = [0.000 0.000 0.000 0.001 0.001 0.007 0.010 0.015 0.014 0.025 0.033 0.030 0.043 0.058 0.098 0.143 0.176 0.212 0.229 0.253 0.258 0.261 0.264 0.267 0.270 0.272 0.275 0.278 0.280 0.283 0.285 0.287 0.290 0.292 0.294] 
  MSFTarget[LDVElectric,NL,years] = [0.000 0.000 0.000 0.000 0.000 0.001 0.004 0.005 0.004 0.011 0.016 0.015 0.024 0.034 0.062 0.093 0.116 0.144 0.154 0.212 0.215 0.216 0.218 0.219 0.220 0.222 0.223 0.225 0.226 0.228 0.229 0.230 0.232 0.233 0.235]

  #                                  2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  MSFTarget[LDTElectric,BC,years] = [0.004 0.006 0.017 0.044 0.051 0.067 0.100 0.124 0.126 0.136 0.153 0.235 0.334 0.429 0.518 0.557 0.575 0.591 0.606 0.607 0.616 0.618 0.621 0.624 0.627 0.631 0.634 0.637 0.641 0.644 0.647 0.651 0.654 0.658 0.662]
  MSFTarget[LDTElectric,AB,years] = [0.001 0.001 0.002 0.004 0.005 0.009 0.020 0.024 0.027 0.049 0.066 0.065 0.098 0.140 0.249 0.366 0.449 0.544 0.575 0.615 0.623 0.624 0.626 0.628 0.629 0.631 0.633 0.635 0.637 0.639 0.641 0.643 0.645 0.647 0.650]
  MSFTarget[LDTElectric,SK,years] = [0.000 0.000 0.001 0.002 0.003 0.006 0.011 0.015 0.016 0.033 0.046 0.047 0.074 0.109 0.201 0.298 0.368 0.450 0.476 0.629 0.638 0.639 0.643 0.646 0.649 0.652 0.655 0.658 0.662 0.665 0.668 0.671 0.675 0.678 0.681]
  MSFTarget[LDTElectric,MB,years] = [0.000 0.000 0.001 0.002 0.004 0.006 0.013 0.020 0.025 0.042 0.058 0.058 0.089 0.129 0.235 0.346 0.426 0.518 0.547 0.590 0.598 0.599 0.601 0.603 0.604 0.606 0.608 0.610 0.612 0.614 0.616 0.618 0.620 0.622 0.625]
  MSFTarget[LDTElectric,ON,years] = [0.001 0.003 0.007 0.006 0.010 0.018 0.040 0.042 0.042 0.069 0.091 0.083 0.118 0.158 0.263 0.379 0.463 0.552 0.587 0.585 0.593 0.595 0.597 0.599 0.602 0.604 0.606 0.608 0.610 0.612 0.614 0.616 0.618 0.620 0.622]
  MSFTarget[LDTElectric,QC,years] = [0.003 0.005 0.011 0.020 0.028 0.035 0.059 0.091 0.121 0.101 0.142 0.194 0.261 0.326 0.378 0.423 0.452 0.476 0.480 0.483 0.493 0.496 0.500 0.504 0.508 0.512 0.516 0.520 0.524 0.528 0.532 0.536 0.541 0.545 0.549]
  MSFTarget[LDTElectric,NB,years] = [0.000 0.000 0.000 0.001 0.002 0.005 0.012 0.021 0.025 0.039 0.052 0.050 0.073 0.101 0.176 0.260 0.320 0.391 0.413 0.480 0.487 0.487 0.490 0.492 0.494 0.496 0.498 0.501 0.503 0.505 0.507 0.509 0.512 0.514 0.516]
  MSFTarget[LDTElectric,NS,years] = [0.000 0.000 0.000 0.001 0.002 0.006 0.012 0.018 0.017 0.036 0.049 0.048 0.072 0.102 0.182 0.268 0.329 0.398 0.420 0.469 0.476 0.477 0.479 0.481 0.483 0.485 0.487 0.489 0.491 0.493 0.495 0.497 0.500 0.502 0.504]
  MSFTarget[LDTElectric,PE,years] = [0.000 0.000 0.001 0.002 0.002 0.013 0.016 0.025 0.025 0.043 0.056 0.052 0.074 0.100 0.169 0.247 0.306 0.369 0.398 0.441 0.450 0.455 0.461 0.466 0.471 0.477 0.482 0.487 0.492 0.497 0.501 0.506 0.510 0.515 0.519]
  MSFTarget[LDTElectric,NL,years] = [0.000 0.000 0.000 0.001 0.001 0.002 0.008 0.011 0.009 0.025 0.035 0.034 0.053 0.076 0.138 0.208 0.260 0.323 0.345 0.476 0.484 0.486 0.490 0.494 0.498 0.501 0.505 0.508 0.512 0.515 0.519 0.523 0.527 0.530 0.534]
 
  #                                2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  MSFTarget[LDVHybrid,BC,years] = [0.001 0.002 0.005 0.007 0.006 0.010 0.011 0.015 0.013 0.014 0.014 0.021 0.026 0.032 0.036 0.034 0.034 0.031 0.031 0.031 0.030 0.029 0.027 0.026 0.024 0.023 0.022 0.020 0.019 0.017 0.016 0.014 0.013 0.011 0.009]
  MSFTarget[LDVHybrid,AB,years] = [0.000 0.000 0.000 0.000 0.001 0.001 0.002 0.003 0.003 0.005 0.007 0.006 0.009 0.013 0.022 0.029 0.035 0.038 0.042 0.044 0.043 0.043 0.043 0.042 0.041 0.041 0.040 0.040 0.039 0.038 0.038 0.037 0.037 0.036 0.035]
  MSFTarget[LDVHybrid,SK,years] = [0.000 0.000 0.000 0.000 0.000 0.001 0.001 0.001 0.001 0.003 0.004 0.004 0.006 0.009 0.015 0.021 0.025 0.028 0.030 0.039 0.039 0.038 0.038 0.037 0.037 0.036 0.035 0.035 0.034 0.033 0.033 0.032 0.032 0.031 0.030]
  MSFTarget[LDVHybrid,MB,years] = [0.000 0.000 0.000 0.001 0.001 0.002 0.002 0.003 0.003 0.005 0.007 0.007 0.010 0.014 0.025 0.033 0.040 0.044 0.049 0.051 0.051 0.051 0.050 0.050 0.049 0.049 0.048 0.048 0.047 0.046 0.046 0.045 0.045 0.044 0.043]
  MSFTarget[LDVHybrid,ON,years] = [0.001 0.002 0.003 0.001 0.001 0.002 0.004 0.005 0.005 0.008 0.009 0.008 0.011 0.014 0.023 0.032 0.039 0.045 0.046 0.045 0.045 0.044 0.043 0.042 0.041 0.040 0.039 0.039 0.038 0.037 0.036 0.035 0.035 0.034 0.033]
  MSFTarget[LDVHybrid,QC,years] = [0.003 0.004 0.009 0.011 0.011 0.015 0.014 0.022 0.034 0.026 0.034 0.048 0.063 0.078 0.084 0.083 0.082 0.075 0.079 0.077 0.076 0.074 0.072 0.069 0.067 0.065 0.062 0.060 0.057 0.055 0.052 0.050 0.047 0.045 0.042]
  MSFTarget[LDVHybrid,NB,years] = [0.000 0.000 0.000 0.001 0.001 0.002 0.003 0.007 0.007 0.011 0.014 0.013 0.018 0.024 0.040 0.054 0.065 0.073 0.080 0.091 0.090 0.090 0.089 0.088 0.087 0.086 0.085 0.084 0.083 0.081 0.080 0.079 0.078 0.077 0.076]
  MSFTarget[LDVHybrid,NS,years] = [0.000 0.000 0.000 0.001 0.001 0.003 0.004 0.006 0.005 0.010 0.013 0.013 0.018 0.025 0.042 0.056 0.067 0.075 0.081 0.088 0.088 0.088 0.086 0.085 0.084 0.083 0.081 0.080 0.079 0.078 0.077 0.075 0.074 0.073 0.072]
  MSFTarget[LDVHybrid,PE,years] = [0.000 0.000 0.000 0.001 0.001 0.003 0.004 0.013 0.010 0.017 0.021 0.019 0.025 0.033 0.051 0.072 0.085 0.099 0.102 0.108 0.107 0.103 0.100 0.097 0.094 0.091 0.088 0.086 0.083 0.080 0.077 0.075 0.072 0.070 0.068]
  MSFTarget[LDVHybrid,NL,years] = [0.000 0.000 0.000 0.000 0.000 0.001 0.002 0.004 0.003 0.007 0.010 0.010 0.014 0.020 0.034 0.046 0.056 0.064 0.070 0.093 0.092 0.091 0.090 0.088 0.087 0.085 0.083 0.082 0.080 0.079 0.077 0.075 0.074 0.072 0.070]

  #                                2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  MSFTarget[LDTHybrid,BC,years] = [0.003 0.004 0.011 0.016 0.013 0.022 0.021 0.030 0.026 0.030 0.030 0.044 0.055 0.067 0.075 0.072 0.071 0.065 0.065 0.065 0.063 0.061 0.058 0.055 0.052 0.049 0.046 0.043 0.040 0.037 0.033 0.030 0.027 0.024 0.020]
  MSFTarget[LDTHybrid,AB,years] = [0.001 0.001 0.001 0.002 0.002 0.005 0.007 0.009 0.008 0.015 0.021 0.020 0.028 0.040 0.068 0.091 0.110 0.121 0.133 0.139 0.138 0.138 0.136 0.134 0.132 0.130 0.128 0.127 0.125 0.123 0.121 0.119 0.117 0.116 0.114]
  MSFTarget[LDTHybrid,SK,years] = [0.000 0.000 0.001 0.001 0.002 0.004 0.005 0.007 0.007 0.015 0.021 0.021 0.031 0.045 0.079 0.106 0.128 0.142 0.156 0.200 0.199 0.198 0.195 0.191 0.189 0.186 0.183 0.180 0.177 0.174 0.171 0.167 0.164 0.161 0.158]
  MSFTarget[LDTHybrid,MB,years] = [0.000 0.000 0.001 0.002 0.002 0.005 0.007 0.009 0.010 0.016 0.022 0.022 0.032 0.046 0.079 0.107 0.129 0.144 0.158 0.167 0.167 0.166 0.164 0.163 0.161 0.159 0.157 0.156 0.154 0.152 0.150 0.148 0.146 0.144 0.142]
  MSFTarget[LDTHybrid,ON,years] = [0.002 0.004 0.007 0.003 0.003 0.006 0.008 0.012 0.010 0.017 0.020 0.019 0.025 0.033 0.052 0.073 0.088 0.102 0.106 0.103 0.103 0.101 0.099 0.097 0.095 0.093 0.091 0.089 0.087 0.085 0.083 0.082 0.080 0.078 0.076]
  MSFTarget[LDTHybrid,QC,years] = [0.004 0.006 0.012 0.016 0.016 0.023 0.021 0.034 0.054 0.042 0.054 0.076 0.100 0.124 0.133 0.132 0.130 0.120 0.126 0.123 0.121 0.118 0.114 0.111 0.107 0.103 0.099 0.096 0.092 0.088 0.084 0.080 0.076 0.072 0.068]
  MSFTarget[LDTHybrid,NB,years] = [0.000 0.001 0.001 0.001 0.002 0.004 0.007 0.013 0.014 0.021 0.028 0.026 0.036 0.049 0.081 0.110 0.132 0.148 0.162 0.184 0.183 0.183 0.180 0.178 0.177 0.174 0.172 0.171 0.169 0.167 0.165 0.162 0.160 0.158 0.156]
  MSFTarget[LDTHybrid,NS,years] = [0.000 0.000 0.001 0.001 0.001 0.004 0.005 0.009 0.008 0.015 0.021 0.021 0.029 0.040 0.067 0.091 0.109 0.121 0.131 0.143 0.143 0.142 0.140 0.138 0.136 0.135 0.133 0.131 0.129 0.127 0.125 0.123 0.121 0.119 0.117]
  MSFTarget[LDTHybrid,PE,years] = [0.000 0.000 0.000 0.002 0.003 0.006 0.006 0.022 0.018 0.030 0.037 0.033 0.044 0.057 0.089 0.125 0.148 0.171 0.177 0.188 0.186 0.180 0.175 0.170 0.165 0.160 0.155 0.150 0.145 0.141 0.136 0.132 0.128 0.123 0.119]
  MSFTarget[LDTHybrid,NL,years] = [0.000 0.000 0.000 0.000 0.001 0.002 0.004 0.008 0.006 0.016 0.023 0.022 0.031 0.044 0.075 0.104 0.126 0.142 0.156 0.209 0.208 0.206 0.202 0.199 0.196 0.192 0.189 0.185 0.182 0.178 0.175 0.171 0.168 0.164 0.160]

  #
  # Set Territories equal to AB since BC is now an outlier in terms of ZEV market shares
  # Matt Lewis July 12 2019
  #
  ####################################
  eu_p = Select(Enduse, "Carriage")
  t_p  = Select(Tech, "LDVGasoline")
  ec_p = Select(EC, "Passenger")
  a_p  = Select(Area, "SK")
  y_p = Yr(2042)
  ####################################
  years = collect(Future:Yr(2050))
  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  areas = Select(Area,["NT","NU","YT"])
  AB = Select(Area,"AB")
  for year in years, area in areas, tech in techs
    MSFTarget[tech,area,year] = MSFTarget[tech,AB,year]
  end

  #
  # Set YT equal to BC since they have similar ZEV targets
  # Matt Lewis Sept 18 2020
  #  
  YT = Select(Area,"YT");
  BC = Select(Area,"BC");
  for year in years, tech in techs
    MSFTarget[tech,YT,year] = MSFTarget[tech,BC,year]
  end
  #######################
  print("\nMSFTarget :", MSFTarget[t_p,a_p,y_p])
  #######################


  # 
  # Baseline MarketShare for Personal Vehicles
  #   
  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1.0)
  techs = Select(Tech,(from = "LDVGasoline",to = "LDTFuelCell"))
  years = collect(Future:Yr(2050))
  for year in years, area in areas, enduse in Enduses
    MSFPVBase[area,year] = sum(xMMSF[enduse,tech,Passenger,area,year] for tech in techs)
  end
  #######################
  print("\nMSFPVBase :", MSFPVBase[a_p,y_p])
  #######################

  #
  # Recalculate Market Share TargetEVInput for E2020 passenger market shares
  #  
  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  for year in years, area in areas, tech in techs
    MSFTarget[tech,area,year] = MSFTarget[tech,area,year]*MSFPVBase[area,year]
  end
  #######################
  print("\nMSFTarget recalc:", MSFTarget[t_p,a_p,y_p])
  #######################
  

  for year in years, area in areas
    MSFTargetSum[area,year] = sum(MSFTarget[tech,area,year] for tech in techs)
  end
  #######################
  print("\nMSFTargetSum :", MSFTargetSum[a_p,y_p])
  #######################

  #
  # Code below replicates weighting in ZEV_Prov to match existing Ref21 - Ian 08/31/21
  # 
  techs = Select(Tech,["LDVGasoline","LDVDiesel","LDVNaturalGas","LDVPropane",
                       "LDVEthanol","LDTGasoline","LDTDiesel",
                       "LDTNaturalGas","LDTPropane","LDTEthanol"])
  for year in years, area in areas, enduse in Enduses
    ICEMarketShareOld[area,year] = sum(xMMSF[enduse,tech,Passenger,area,year] for tech in techs)
  end
  #######################
  print("\n ICEMarketShareOld :", ICEMarketShareOld[a_p,y_p])
  #######################

  techs = Select(Tech,(from = "LDVGasoline",to = "LDTFuelCell"))
  for year in years, area in areas
    ICEMarketShareNew[area,year] = MSFPVBase[area,year]-MSFTargetSum[area,year]

    @finite_math ICEMarketChange[area,year] = ICEMarketShareNew[area,year]/
      ICEMarketShareOld[area,year]
  end
    
  for year in years, area in areas, tech in techs, enduse in Enduses
    xMMSF[enduse,tech,Passenger,area,year] = xMMSF[enduse,tech,Passenger,area,year]*
      ICEMarketChange[area,year]
  end
  #######################
  print("\n xMMSF recalc:", xMMSF[eu_p,t_p,ec_p,a_p,y_p])
  #######################

  techs = Select(Tech,["LDVElectric","LDTElectric","LDVHybrid","LDTHybrid"])
  for year in years, area in areas, tech in techs, enduse in Enduses
    xMMSF[enduse,tech,Passenger,area,year] = MSFTarget[tech,area,year]
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
