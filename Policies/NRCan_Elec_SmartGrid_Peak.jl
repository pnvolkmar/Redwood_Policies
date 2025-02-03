#
# NRCan_Elec_SmartGrid_Peak.jl
#
# Program: https://natural-resources.canada.ca/climate-change/green-infrastructure-programs/smart-grids/19793
#

using SmallModel

module NRCan_Elec_SmartGrid_Peak

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
  db::String

  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
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
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ECCMap::VariableArray{2} = ReadDisk(db,"$Input/ECCMap") # [EC,ECC] # EC TO ECC Map
  xDmd::VariableArray{5} = ReadDisk(db,"$Input/xDmd") # [Enduse,Tech,EC,Area,Year] Total Energy Demand (TBtu/Yr)
  xPkSav::VariableArray{4} = ReadDisk(db,"$Input/xPkSav") # [Enduse,EC,Area,Year] Peak Savings from Programs (MW)
  xPkSavECC::VariableArray{3} = ReadDisk(db,"SInput/xPkSavECC") # [ECC,Area,Year] Peak Savings from Programs (MW)

  # Scratch Variables
  TotDmd::VariableArray{2} = zeros(Float64,length(Tech),length(Area)) # [Tech,Area] Sector Enduse Demands (mmBTU/Yr)
  TotPkSav::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sector Demand Reductions (MW)
end

function ResPolicy(db)
  data = RControl(; db)
  (; Input) = data
  (; Area,Areas,ECCMap,ECCs,ECs) = data 
  (; Enduses,Tech,Techs) = data
  (; TotDmd,TotPkSav,xDmd,xPkSav,xPkSavECC) = data

  # 
  # Enduse split based on demands in 2014
  #   
  TotDmd[Techs,Areas] = sum(xDmd[eu,Techs,ec,Areas,Yr(2014)] for eu in Enduses,ec in ECs)

  # 
  # Electric Peak Savings
  #  
  Electric = Select(Tech,"Electric")
  ON = Select(Area,"ON")
  TotPkSav[ON,Yr(2019):Yr(2026)] = [6,23,47,81,122,169,210,233]
  years = collect(Yr(2027):Final)
  for year in years
    TotPkSav[ON,year] = TotPkSav[ON,Yr(2026)]
  end

  # 
  # Allocate Demand Reduction to all Enduses
  #  
  years = collect(Future:Final)
  for eu in Enduses, ec in ECs, year in years 
    xPkSav[eu,ec,ON,year] = xPkSav[eu,ec,ON,year] + TotPkSav[ON,year] * 
    	xDmd[eu,Electric,ec,ON,Yr(2014)]/TotDmd[Electric,ON]/1.04 
  end
    
  # 
  # Total across enduses
  #   
  years = collect(Future:Final)
  for year in years, ec in ECs, ecc in ECCs, eu in Enduses
    if ECCMap[ec,ecc] == 1
      xPkSavECC[ecc,ON,year] = sum(xPkSav[eu,ec,ON,year])
    end
    
  end
      
  WriteDisk(db,"$Input/xPkSav",xPkSav)
  WriteDisk(db,"SInput/xPkSavECC",xPkSavECC)
end

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ECCMap::VariableArray{2} = ReadDisk(db,"$Input/ECCMap") # [EC,ECC] # EC TO ECC Map
  xDmd::VariableArray{5} = ReadDisk(db,"$Input/xDmd") # [Enduse,Tech,EC,Area,Year] Energy Demand (TBtu/Yr)
  xPkSav::VariableArray{4} = ReadDisk(db,"$Input/xPkSav") # [Enduse,EC,Area,Year] Peak Savings from Programs (MW)
  xPkSavECC::VariableArray{3} = ReadDisk(db,"SInput/xPkSavECC") # [ECC,Area,Year] Peak Savings from Programs (MW)

  # Scratch Variables
  TotDmd::VariableArray{2} = zeros(Float64,length(Tech),length(Area)) # [Tech,Area] Sector Enduse Demands (mmBTU/Yr)
  TotPkSav::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sector Demand Reductions (MW)
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,Areas,ECCMap,ECCs,ECs) = data 
  (; Enduses,Tech,Techs) = data 
  (; TotDmd,TotPkSav,xDmd,xPkSav,xPkSavECC) = data

  # 
  # Enduse split based on demands in 2014
  #   
  TotDmd[Techs,Areas] = 
    sum(xDmd[eu,Techs,ec,Areas,Yr(2014)] for eu in Enduses, ec in ECs)

  # 
  # Electric Peak Savings
  #  
  Electric = Select(Tech,"Electric")
  ON = Select(Area,"ON")
  TotPkSav[ON,Yr(2019):Yr(2026)] = [3,14,27,48,72,99,123,136]
  years = collect(Yr(2027):Final)
  for year in years
    TotPkSav[ON,year] = TotPkSav[ON,Yr(2026)]
  end

  # 
  # Allocate Demand Reduction to all Enduses
  #  
  years = collect(Future:Final)
  for year in years, ec in ECs, eu in Enduses
    xPkSav[eu,ec,ON,year] = xPkSav[eu,ec,ON,year] + TotPkSav[ON,year] * 
      xDmd[eu,Electric,ec,ON,Yr(2014)]/TotDmd[Electric,ON]/1.04
  end

  # 
  # Total across enduses
  #   
  years = collect(Future:Final)
  for year in years, ec in ECs, ecc in ECCs, eu in Enduses
    if ECCMap[ec,ecc] == 1
      xPkSavECC[ecc,ON,year] = sum(xPkSav[eu,ec,ON,year])
    end
    
  end
    
  WriteDisk(db,"$Input/xPkSav",xPkSav)
  WriteDisk(db,"SInput/xPkSavECC",xPkSavECC)
end

function PolicyControl(db)
  @info "NRCan_Elec_SmartGrid_Peak.jl - PolicyControl"
  ResPolicy(db)
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
