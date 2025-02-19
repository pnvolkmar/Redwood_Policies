#
# CAC_ELYSIS.jl
#
# This TXP models the adoption of ELYSIS technology in aluminum facilities across Canada.
#

using SmallModel

module CAC_ELYSIS

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CAC_ELYSISData
  db::String

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Market::SetArray = ReadDisk(db,"E2020DB/MarketKey")
  Markets::Vector{Int} = collect(Select(Market))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  PCov::SetArray = ReadDisk(db,"E2020DB/PCovKey")
  PCovDS::SetArray = ReadDisk(db,"E2020DB/PCovDS")
  PCovs::Vector{Int} = collect(Select(PCov))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  AreaMarket::VariableArray{3} = ReadDisk(db,"SInput/AreaMarket") # [Area,Market,Year] Areas included in Market
  CapTrade::VariableArray{2} = ReadDisk(db,"SInput/CapTrade") # [Market,Year] Emission Cap and Trading Switch (1=Trade,Cap Only=2)
  ECCMarket::VariableArray{3} = ReadDisk(db,"SInput/ECCMarket") # [ECC,Market,Year] Economic Categories included in Market
  ECoverage::VariableArray{5} = ReadDisk(db,"SInput/ECoverage") # [ECC,Poll,PCov,Area,Year] Policy Coverage Switch (1=Covered)
  MaxIter::VariableArray{1} = ReadDisk(db,"SInput/MaxIter") # [Year] Maximum Number of Iterations (Number)
  PCovMarket::VariableArray{3} = ReadDisk(db,"SInput/PCovMarket") # [PCov,Market,Year] Types of Pollution included in Market
  PollMarket::VariableArray{3} = ReadDisk(db,"SInput/PollMarket") # [Poll,Market,Year] Pollutants included in Market
  RPolicy::VariableArray{4} = ReadDisk(db,"SOutput/RPolicy") # [ECC,Poll,Area,Year] Provincial Reduction (Tonnes/Tonnes)
  xGoalPol::VariableArray{2} = ReadDisk(db,"SInput/xGoalPol") # [Market,Year] Pollution Goal (Tonnes/Yr)

  # Scratch
  tmp::VariableArray{1} = zeros(Float64,length(Years)) # Create temporary variable with dim years
end

# 
# Emission Caps
# The caps are estimated in "CAC_ELYSIS_2024AM_analysis.xlsx" file. 
#

function CapData(data,m,e,a,p)
  (; Area,ECC,Market) = data 
  (; PCovs,Poll,Years) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage) = data
  (; MaxIter,PCovMarket,PollMarket) = data

  markets = Select(Market,"Market($m)")
  eccs = Select(ECC,!=(e))
  areas = Select(Area,a)
  polls = Select(Poll,p)

  # 
  #  Set market switches
  # 
  years = collect(Last:Yr(2050))
  for year in years, market in markets, area in areas
    AreaMarket[area,market,year] = 1
  end
  for year in years, market in markets, ecc in eccs
    ECCMarket[ecc,market,year] = 1
  end
  for year in years, market in markets, pcov in PCovs
    PCovMarket[pcov,market,year] = 1
  end
  for year in years, market in markets, poll in polls
    PollMarket[poll,market,year] = 1
  end
  for year in years, area in areas, pcov in PCovs, poll in polls, ecc in eccs
    ECoverage[ecc,poll,pcov,area,year] = 1
  end
  years = collect(Last:Yr(2050))
  for year in years, market in markets
    CapTrade[market,year] = 0
  end
  years = collect(Yr(2025):Yr(2050))
  for year in years, market in markets
    CapTrade[market,year] = 2
  end
  
  #
  # Maximum Number of Iterations 
  #
  for year in Years
    MaxIter[year] = max(MaxIter[year],1)
  end
end

function CAC_ELYSISDataPolicy(data)
  (; db) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage) = data
  (; MaxIter,PCovMarket,PollMarket,xGoalPol,tmp) = data

  # 
  # Data for Emissions Caps
  # CCME Acid Rain target for ON is 442.5 kt - see ON Acid Rain 
  # Provincial Cap.xlxs for recalculation (updated by Stephanie August 20, 2012)
  #
  read_years = collect(Yr(2025):Yr(2050))
  write_years = collect(Yr(2025):Final)
  # 
  # Quebec
  # 
  #             Market  ECC                Area   Poll 
  CapData(data, 18,     "Aluminum", "QC",  "SOX")

  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050  
  tmp[read_years] = [57701, 58140, 58589, 59084, 59681, 57049, 57380, 57702, 57994, 58291, 52771, 53101, 53409, 53640, 53885, 51498, 51498, 51498, 51498, 51498, 51498, 51498, 51498, 51498, 51498, 51498]
  xGoalPol[18,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  #
  #             Market  ECC         Area   Poll 
  CapData(data, 19, "Aluminum", "QC", "COX")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050
  tmp[read_years] = [358334, 360922, 363584, 366550, 370137, 356361, 358332, 360259, 362011, 363801, 315115, 317039, 318845, 320185, 321630, 305464, 305464, 305464, 305464, 305464, 305464, 305464, 305464, 305464, 305464, 305464]        
  xGoalPol[19,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  #
  #             Market  ECC         Area   Poll 
  CapData(data, 20, "Aluminum", "QC", "PMT")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [4762, 4805, 4846, 4888, 4938, 4358, 4384, 4408, 4432, 4456, 4028, 4055, 4081, 4103, 4124, 4115, 4115, 4115, 4115, 4115, 4115, 4115, 4115, 4115, 4115, 4115]
  xGoalPol[20,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  #
  #             Market  ECC         Area   Poll 
  CapData(data, 21, "Aluminum", "QC", "PM10")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [3494, 3529, 3559, 3590, 3630, 3206, 3224, 3246, 3264, 3283, 2968, 2991, 3014, 3030, 3046, 3042, 3042, 3042, 3042, 3042, 3042, 3042, 3042, 3042, 3042, 3042]
  xGoalPol[21,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  #             Market  ECC         Area   Poll 
  CapData(data, 22, "Aluminum", "QC", "PM25")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [2985, 3010, 3033, 3059, 3090, 2677, 2693, 2708, 2723, 2738, 2533, 2550, 2567, 2580, 2593, 2583, 2583, 2583, 2583, 2583, 2583, 2583, 2583, 2583, 2583, 2583]
  xGoalPol[22,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  # 
  # BC
  # 
  #             Market  ECC         Area   Poll 
  CapData(data, 23, "Aluminum", "BC", "SOX")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [4851, 4652, 4437, 4208, 3963, 3560, 3350, 3173, 3035, 2915, 2540, 2463, 2408, 2373, 2368, 2276, 2276, 2276, 2276, 2276, 2276, 2276, 2276, 2276, 2276, 2276]
  xGoalPol[23,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  #             Market  ECC         Area   Poll 
  CapData(data, 24, "Aluminum", "BC", "COX")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [28323, 27160, 25893, 24553, 23115, 20915, 19675, 18634, 17817, 17115, 14266, 13837, 13528, 13333, 13306, 12712, 12712, 12712, 12712, 12712, 12712, 12712, 12712, 12712, 12712, 12712]
  xGoalPol[24,write_years] = tmp[write_years] # extract Future-Last elements from tmp
  
  # 
  # Ontario
  # 
  
  #             Market  ECC         Area   Poll 
  CapData(data, 25, "Aluminum", "ON", "COX")
  #                   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050   
  tmp[read_years] = [20, 19, 19, 18, 17, 16, 15, 14, 14, 14, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
  xGoalPol[25,write_years] = tmp[write_years] # extract Future-Last elements from tmp

  WriteDisk(db,"SInput/AreaMarket",AreaMarket)
  WriteDisk(db,"SInput/ECCMarket",ECCMarket)
  WriteDisk(db,"SInput/ECoverage",ECoverage)
  WriteDisk(db,"SInput/CapTrade",CapTrade)
  WriteDisk(db,"SInput/PCovMarket",PCovMarket)
  WriteDisk(db,"SInput/PollMarket",PollMarket)
  WriteDisk(db,"SInput/xGoalPol",xGoalPol)

  WriteDisk(db,"SInput/MaxIter",MaxIter)    
end

function PolicyControl(db)
  @info "CAC_ELYSIS.jl - PolicyControl"
  data = CAC_ELYSISData(; db)
  CAC_ELYSISDataPolicy(data)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
