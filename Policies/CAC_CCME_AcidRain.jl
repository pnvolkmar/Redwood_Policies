#
# CAC_CCME_AcidRain.jl
#
# This TXP models Province-Wide Cap as part of the CCME Acid Rain Strategy.
# Prepared by Audrey Bernard 07/07/2021.
#

using SmallModel

module CAC_CCME_AcidRain

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CAC_CCME_AcidRainData
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
end

# 
# Emission Caps
# The caps are Emission Cap.xls from Jack Buchanan of Environment Canada.
#

function CapData(data,m,e,a,p)
  (; Area,ECC,Market) = data 
  (; PCovs,Poll,) = data
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
  years = collect(Future:Yr(2050))
  for year in years, market in markets
    CapTrade[market,year] = 2
  end
  
  #
  # Maximum Number of Iterations 
  #
  MaxIter[1] = max(MaxIter[1],1)
end

function CAC_CCME_AcidRainDataPolicy(data)
  (; db) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage) = data
  (; MaxIter,PCovMarket,PollMarket,xGoalPol) = data

  # 
  # Data for Emissions Caps
  # CCME Acid Rain target for ON is 442.5 kt - see ON Acid Rain 
  # Provincial Cap.xlxs for recalculation (updated by Stephanie August 20, 2012)
  #

  # 
  # Ontario
  # 
  #             Market  ECC                Area   Poll 
  CapData(data, 9,     "OtherNonferrous", "ON",  "SOX")

  #        2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp = [332059,  341780,  351500,  260500,  263500,  325500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500,  342500]
  xGoalPol[9,Future:Yr(2050)] = tmp[(end-Yr(2050)+Future):(end)] # extract Future-Last elements from tmp
  # 
  # Quebec
  # 
  #             Market   ECC                Area   Poll 
  CapData(data, 49,     "OtherNonferrous", "QC",  "SOX")

  #        2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp = [223913,  225780,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648,  227648]
  xGoalPol[49,Future:Yr(2050)] = tmp[(end-Yr(2050)+Future):(end)] # extract Future-Last elements from tmp
  
  # 
  # New Brunswick
  # 
  #             Market   ECC                Area   Poll 
  CapData(data, 70,     "OtherNonferrous", "NB",  "SOX")
  
  #       2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp = [78110,   78868,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627,   79627]
  xGoalPol[70,Future:Yr(2050)] = tmp[(end-Yr(2050)+Future):(end)] # extract Future-Last elements from tmp
  
  # 
  # Nova Scotia
  # 
  #             Market   ECC           Area   Poll 
  CapData(data, 17,     "UtilityGen", "NS",  "SOX")
  
  #       2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp = [69500,   69500,   58170,   58170,   58170,   58170,   58170,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750,   34750]
  xGoalPol[17,Future:Yr(2050)] = tmp[(end-Yr(2050)+Future):(end)] # extract Future-Last elements from tmp
  
  # 
  # Newfoundland
  # 
  #             Market   ECC              Area   Poll 
  CapData(data, 32,     "IronOreMining", "NL",  "SOX")
  
  #       2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp = [55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561,   55561]
  xGoalPol[32,Future:Yr(2050)] = tmp[(end-Yr(2050)+Future):(end)] # extract Future-Last elements from tmp
    
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
  @info "CAC_CCME_AcidRain.jl - PolicyControl"
  data = CAC_CCME_AcidRainData(; db)
  CAC_CCME_AcidRainDataPolicy(data)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
