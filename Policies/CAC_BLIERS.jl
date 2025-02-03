#
# CAC_BLIERS.jl
# 
# This TXP models the BLIERS for other non-ferrous as part of the AQMS strategy.
# Prepared by Audrey Bernard 07/13/2021.
#

using SmallModel

module CAC_BLIERS

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CAC_BLIERSData
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
  MaxIter::VariableArray{1} = ReadDisk(db,"SInput/MaxIter") # Maximum Number of Iterations (Number)
  PCovMarket::VariableArray{3} = ReadDisk(db,"SInput/PCovMarket") # [PCov,Market,Year] Types of Pollution included in Market
  PollMarket::VariableArray{3} = ReadDisk(db,"SInput/PollMarket") # [Poll,Market,Year] Pollutants included in Market
  RPolicy::VariableArray{4} = ReadDisk(db,"SOutput/RPolicy") # [ECC,Poll,Area,Year] Provincial Reduction (Tonnes/Tonnes)
  xGoalPol::VariableArray{2} = ReadDisk(db,"SInput/xGoalPol") # [Market,Year] Pollution Goal (Tonnes/Yr)
end

# 
# Emission Caps
# The caps are Emission Cap.xls from Jack Buchanan of Environment Canada. 
# 
# Input starts from the first available data year (currently 2013) but is only 
# applied starting in year Future in the procedure. 
# 
# Input data is sensitive to column location.
#

function CapData(data,m,e,a,p)
  (; Area,ECC,Market) = data 
  (; PCovs,Poll) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage,MaxIter) = data
  (; PCovMarket,PollMarket) = data

  markets = Select(Market,"Market($m)")
  eccs = Select(ECC,e)
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
  
  years = collect(Future:Yr(2050))
  for year in years, market in markets
    CapTrade[market,year] = 2
  end

  #
  # Maximum Number of Iterations
  #
  MaxIter[1] = max(MaxIter[1],1)
end

function CAC_BLIERSDataPolicy(db)
  data = CAC_BLIERSData(; db)
  (; AreaMarket,CapTrade,ECCMarket,ECoverage) = data
  (; MaxIter,PCovMarket,PollMarket,xGoalPol) = data

  # 
  # Data for Emissions Caps
  # 

  # 
  # Quebec
  # BMS BLIER Economics xls (updated by Stephanie per Andy on August 22, 2012)
  #
  #             Market   ECC                Area   Poll                     2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  CapData(data, 42,     "OtherNonferrous", "QC",  "SOX")
  xGoalPol[     42,                                       Yr(2013):Yr(2050)] = [26087,   24220,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352,   22352]
  
  CapData(data, 87,     "OtherNonferrous", "QC",  "PMT")
  xGoalPol[     87,                                       Yr(2013):Yr(2050)] = [887,     825,     762,     762,     762,     62,      762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,    762,      762,     762,     762,     762,     762,     762,     762,     762] 
  
  CapData(data, 88,     "OtherNonferrous", "QC",  "PM10")
  xGoalPol[     88,                                       Yr(2013):Yr(2050)] = [887,     825,     762,     762,     762,     62,      762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,    762,      762,     762,     762,     762,     762,     762,     762,     762] 
  
  CapData(data, 89,     "OtherNonferrous", "QC",  "PM25")
  xGoalPol[     89,                                       Yr(2013):Yr(2050)] = [887,     825,     762,     762,     762,     62,      762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,    762,      762,     762,     762,     762,     762,     762,     762,     762] 
  
  CapData(data, 92,     "OtherNonferrous", "QC",  "BC")
  xGoalPol[     92,                                       Yr(2013):Yr(2050)] = [887,     825,     762,     762,     762,     62,      762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,     762,    762,      762,     762,     762,     762,     762,     762,     762,     762] 

  # 
  # Ontario    
  # 2018/01/15, Andy - As recommended by Glasha /Grace - Cap for Ontario OtherNonferrous. 
  # Previously at 91Kt and now changed cap to values from 2016 - end. 
  # To resolve the sharp decrease from 2015 to 2016 
  # (Last historical year to first projection year). 
  # Please refer to the email from Grace on shared drive
  # T:\CACs\Policy Files\2017
  # "CAPS and Percentage Reductions dec2 (9) v1.xlsx"
  #  
  #             Market   ECC                Area   Poll                     2013      2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  CapData(data, 6,      "OtherNonferrous", "ON",  "SOX")
  xGoalPol[     6,                                        Yr(2013):Yr(2050)] = [110441,   100720,  91000,   182000,  179000,  117000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000,  100000]

  CapData(data, 84,     "OtherNonferrous", "ON",  "PMT")
  xGoalPol[     84,                                       Yr(2013):Yr(2050)] = [2766,     3246,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726]

  CapData(data, 85,     "OtherNonferrous", "ON",  "PM10")
  xGoalPol[     85,                                       Yr(2013):Yr(2050)] = [2766,     3246,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726]

  CapData(data, 86,     "OtherNonferrous", "ON",  "PM25")
  xGoalPol[     86,                                       Yr(2013):Yr(2050)] = [2766,     3246,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726]

  CapData(data, 90,     "OtherNonferrous", "ON",  "BC")
  xGoalPol[     90,                                       Yr(2013):Yr(2050)] = [2766,     3246,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726,    3726]

  # 
  # British Columbia
  # 
  # BMS BLIER Economics xls (updated by Stephanie per Andy on August 22, 2012)
  #
  #             Market    ECC                Area   Poll                      2013      2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  CapData(data, 72,      "OtherNonferrous", "BC",  "SOX")
  xGoalPol[     72,                                         Yr(2013):Yr(2050)] = [4634,     5002,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369,    5369]

  CapData(data, 77,      "OtherNonferrous", "BC",  "PMT")
  xGoalPol[     77,                                         Yr(2013):Yr(2050)] = [155,      278,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401]  

  CapData(data, 78,      "OtherNonferrous", "BC",  "PM10")
  xGoalPol[     78,                                         Yr(2013):Yr(2050)] = [155,      278,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401]  

  CapData(data, 79,      "OtherNonferrous", "BC",  "PM25")
  xGoalPol[     79,                                         Yr(2013):Yr(2050)] = [155,      278,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401]  

  CapData(data, 80,      "OtherNonferrous", "BC",  "BC")
  xGoalPol[     80,                                         Yr(2013):Yr(2050)] = [155,      278,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401,     401]  

  # 
  # New Brunswick
  # BMS BLIERS Economics xls (updated by Liliana per Andy on August 22, 2012)
  # P2 Notice for BMS provided by Sector Lead
  #
  #             Market     ECC                Area   Poll                     2013      2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  CapData(data, 83,       "OtherNonferrous", "NB",  "SOX")
  xGoalPol[     83,                                         Yr(2013):Yr(2050)] = [9390,     8632,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873,    7873] 

  CapData(data, 100,      "OtherNonferrous", "NB",  "PMT")
  xGoalPol[     100,                                        Yr(2013):Yr(2050)] = [47,       46,      45,      45,      45,      45,      45,     45,       45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45] 

  CapData(data, 101,      "OtherNonferrous", "NB",  "PM10")
  xGoalPol[     101,                                        Yr(2013):Yr(2050)] = [47,       46,      45,      45,      45,      45,      45,     45,       45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45] 

  CapData(data, 102,      "OtherNonferrous", "NB",  "PM25")
  xGoalPol[     102,                                        Yr(2013):Yr(2050)] = [47,       46,      45,      45,      45,      45,      45,     45,       45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45] 

  CapData(data, 103,      "OtherNonferrous", "NB",  "BC")
  xGoalPol[     103,                                        Yr(2013):Yr(2050)] = [47,       46,      45,      45,      45,      45,      45,     45,       45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45,      45] 

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
  @info "CAC_BLIERS.jl - PolicyControl"
  CAC_BLIERSDataPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
