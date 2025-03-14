#
# CAC_NS_AirQualityReg.jl
#
# This TXP models the Nova Scotia Air Quality Regulations for Utility Electric Generation.
#Prepared by Audrey Bernard 07/13/2021.
#

using SmallModel

module CAC_NS_AirQualityReg

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CAC_NS_AirQualityRegData
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

  # Scratch Variables
  tmp::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Temporary holder variable for read-in of the xGoalPol tables
end

function CapData(data,m,e,a,p)
  (; Area,ECC,Market) = data 
  (; PCovs,Poll) = data
  (; AreaMarket,CapTrade,ECCMarket,ECoverage,PCovMarket) = data
  (; PollMarket,MaxIter) = data

  markets = Select(Market,"Market($m)")
  eccs = Select(ECC,e)
  areas = Select(Area,a)
  polls = Select(Poll,p)

  # 
  #  Set market switches
  #
  years = collect(Future:Yr(2050))
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
  
  for year in years, market in markets
    CapTrade[market,year] = 2
  end

  #
  # Maximum Number of Iterations
  #
  MaxIter[1] = max(MaxIter[1],1)
end

function CAC_NS_AirQualityRegDataPolicy(db)
  data = CAC_NS_AirQualityRegData(; db)
  (; AreaMarket,CapTrade,ECCMarket,ECoverage,MaxIter) = data
  (; PCovMarket,PollMarket) = data
  (; tmp,xGoalPol) = data
  
  # 
  # Data for Emissions Caps
  # 

  # 
  # Nova Scotia
  #
  #             Market   ECC                Area   Poll                  
  CapData(data, 16,     "UtilityGen",      "NS",  "SOX")
  read_years = collect(Yr(2013):Yr(2050))
  #                   2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp[read_years] = [72500,   72500,   60900,   60900,   60900,   60900,   60900,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250,   36250]
  write_years = collect(Future:Final)
  incorrect_years = collect(Yr(2017):(Yr(2017)+length(write_years)-1)) # TODO Promula get the correct years written 
  xGoalPol[16,write_years] = tmp[incorrect_years]

  #             Market   ECC                Area   Poll                  
  CapData(data, 96,     "UtilityGen",      "NS",  "NOX")
  tmp .= 0
  #                   2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050  
  tmp[read_years] = [21365,   21365,   19228,   19228,   19228,   19228,   19228,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955,   14955]
  xGoalPol[96,write_years] = tmp[incorrect_years] # TODO Promula get the correct years written

  # Removing Caps for Hg since CAC_ElecGen_NS.txp is setting caps on Hg. Audrey 22/11/04
  # 
  # Select Market(97), ECC(UtilityGen), Area(NS), Poll(Hg), Year(Future-2050)
  # CapData
  # /Area            ECC                     Poll     Unit          2013     2014     2015     2016     2017     2018     2019     2020     2021     2022     2023     2024     2025     2026     2027     2028     2029     2030     2031     2032     2033     2034     2035     2036     2037     2038     2039     2040     2041     2042     2043     2044     2045     2046     2047     2048     2049     2050 
  # Nova Scotia      Utility Generation      Hg       Tonnes       70000    70000    70000    70000    70000    70000    70000    65000    45000    45000    45000    45000    45000    45000    45000    45000    45000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    35000    
    
  WriteDisk(db,"SInput/AreaMarket",AreaMarket)
  WriteDisk(db,"SInput/CapTrade",CapTrade)
  WriteDisk(db,"SInput/ECCMarket",ECCMarket)
  WriteDisk(db,"SInput/ECoverage",ECoverage)
  # WriteDisk(db,"SInput/PCovMarket",PCovMarket) # TODO Promula: This never gets written in Promula
  WriteDisk(db,"SInput/PollMarket",PollMarket)
  WriteDisk(db,"SInput/xGoalPol",xGoalPol)
  
  WriteDisk(db,"SInput/MaxIter",MaxIter)
end
  
function PolicyControl(db)
  @info "CAC_NS_AirQualityReg.jl - PolicyControl"
  CAC_NS_AirQualityRegDataPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
