#
# CAC_ON_CarbonBlack.jl
#
# This TXP models Ontario's Carbon Black Industry Standard for Cabot Canada Ltd. located in Sarnia and Birla Carbon in Hamilton.
# As of October 2023, the Standard is in proposal stage, so this regulation will be in the AM scenario. 
#
# Updated by Jocelyn Tong 2024-10-31
#

using SmallModel

module CAC_ON_CarbonBlack

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CAC_ON_CarbonBlackData
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
# The caps are estimated in "SO2_CarbonBlack_ON_2024AM_analysis.xlsx" file.  
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
  years = collect(Yr(2028):Yr(2050))
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

function CAC_ON_CarbonBlackDataPolicy(data)
  (; db) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage) = data
  (; MaxIter,PCovMarket,PollMarket,xGoalPol,tmp) = data

  read_years = collect(Yr(2028):Yr(2050))
  write_years = collect(Yr(2025):Final)
  # 
  # Ontario
  # 
  #             Market  ECC                Area   Poll 
  CapData(data, 154,     "OtherChemicals", "ON",  "SOX")

  #                  2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050  
  tmp[read_years] = [8040,4435, 717, 725, 735, 745, 755, 766, 777, 789, 801, 814, 827, 827, 827, 827, 827, 827, 827, 827, 827, 827, 827]
  xGoalPol[18,write_years] = tmp[write_years] # extract 2028-Last elements from tmp
  
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
  @info "CAC_ON_CarbonBlack.jl - PolicyControl"
  data = CAC_ON_CarbonBlackData(; db)
  CAC_ON_CarbonBlackDataPolicy(data)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
