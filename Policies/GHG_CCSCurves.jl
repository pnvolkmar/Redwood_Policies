#
# GHG_CCSCurves.jl
#

using SmallModel

module GHG_CCSCurves

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  CalDB::String = "MCalDB"
  Input::String = "MInput"
  Outpt::String = "MOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  SqA0::VariableArray{3} = ReadDisk(db,"MEInput/SqA0") # [ECC,Area,Year] A Term in eCO2 Sequestering Curve (CDN 1999$)
  SqB0::VariableArray{3} = ReadDisk(db,"MEInput/SqB0") # [ECC,Area,Year] B Term in eCO2 Sequestering Curve(CDN 1999$)
  SqC0::VariableArray{3} = ReadDisk(db,"MEInput/SqC0") # [ECC,Area,Year] C Term in eCO2 Sequestering Curve (CDN 1999$)
  SqCCThreshold::VariableArray{3} = ReadDisk(db,"MEInput/SqCCThreshold") # [ECC,Area,Year] Levelized Cost Threshold for Sequestering Curve (2016 CN$/Tonne)
  SqCCSw::VariableArray{3} = ReadDisk(db,"MEInput/SqCCSw") # [ECC,Area,Year] Sequestering Capital Cost Switch (1=CC Curve)
  SqTransStorageCost::VariableArray{2} = ReadDisk(db,"MEInput/SqTransStorageCost") # [Area,Year] Sequestering Transportation and Storage Costs (2016 CN$/tonne CO2e)

  # Scratch Variables
  SqC0Mult::VariableArray{1} = zeros(Float64,length(Year)) # [Year]
end

function ReadTerms(data,ecc2,A,B,C,Th)
  (; Areas,ECC,Nation,Years) = data
  (; ANMap) = data
  (; SqA0,SqB0,SqC0,SqCCThreshold) = data

  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))
  ecc = Select(ECC,ecc2)
  for year in Years, area in cn_areas
    SqA0[ecc,area,year] = A
    SqB0[ecc,area,year] = B
    SqC0[ecc,area,year] = C
    SqCCThreshold[ecc,area,year] = Th
  end
  
  return
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,AreaDS,Areas,ECC,Nation) = data 
  (; Years) = data
  (; SqCCSw,ANMap,SqA0,SqB0,SqC0) = data
  (; SqCCThreshold,SqC0Mult,SqTransStorageCost) = data

  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))
  eccs = Select(ECC,["PulpPaperMills","Petrochemicals","OtherChemicals","Fertilizer",
                      "Petroleum","Cement","IronSteel","Aluminum","OtherNonferrous",
                      "HeavyOilMining","LightOilMining","SAGDOilSands","CSSOilSands","OilSandsMining",
                      "OilSandsUpgraders","SweetGasProcessing","UnconventionalGasProduction",
                      "SourGasProcessing","UtilityGen"])

  # SqCCSq = 3 is "SqCC = SqCCLevelized/Inflation(2016)/(SqCCR+SqOCF)*Inflation"
  for year in Years, area in Areas, ecc in eccs
    SqCCSw[ecc,area,year] = 3
  end
  
  WriteDisk(db,"MEInput/SqCCSw",SqCCSw)

  eccs = Select(ECC,["PulpPaperMills","Fertilizer","Petroleum","Cement","IronSteel",
                      "Aluminum","OtherNonferrous","SAGDOilSands","CSSOilSands","OilSandsMining",
                      "OilSandsUpgraders","SweetGasProcessing","SourGasProcessing"])

  # 
  # Source: "CCS Curves Percent Reduction v4.1.xlsx" - Jeff Amlin 10/26/21
  # SqA0 - Intercept
  # SqB0 - Cost Slope 
  # SqC0 - CCS Potential    
  # SqCCThreshold - minimun value for CCS
  # 
  
  # /                 ECC                     SqA0           SqB0        SqC0    SqCCThreshold
  ReadTerms(data,"PulpPaperMills",       1.80234E+21,   -9.63586,   0.35175,    90.00)
  ReadTerms(data,"Fertilizer",           647118.2344,   -3.17925,   0.56905,    30.00)
  ReadTerms(data,"Petroleum",            1449030171,    -4.25037,   0.50250,    50.00)
  ReadTerms(data,"Cement",               4.21563E+13,   -6.54597,   0.60054,    85.00)
  ReadTerms(data,"IronSteel",            4.65289E+17,   -8.30618,   0.30163,    80.00)
  ReadTerms(data,"Aluminum",             3771377.887,   -3.71224,   0.86480,    155.00)
  ReadTerms(data,"OtherNonferrous",      4.34133E+15,   -7.81964,   0.50295,    80.00)
  ReadTerms(data,"SAGDOilSands",         3.52031E+31,   -13.43649,  0.80400,    150.00)
  ReadTerms(data,"CSSOilSands",          3.52031E+31,   -13.43649,  0.80400,    150.00)
  ReadTerms(data,"OilSandsMining",       1.42335E+34,   -14.36966,  0.60300,    165.00)
  ReadTerms(data,"OilSandsUpgraders",    1.24152E+28,   -12.18405,  0.80400,    130.00)
  ReadTerms(data,"SweetGasProcessing",   1796.881113,   -1.30184,   0.91169,    20.00)
  ReadTerms(data,"SourGasProcessing",    1796.881113,   -1.30184,   0.91169,    20.00)

  # 
  # Heavy Oil in SK uses Cement for now - from Gavin - Jeff Amlin 11/03/22
  # 
  HeavyOilMining = Select(ECC,"HeavyOilMining")
  Cement = Select(ECC,"Cement")
  SK = Select(Area,"SK")
  SqA0[HeavyOilMining,SK,Years] = SqA0[Cement,SK,Years]
  SqB0[HeavyOilMining,SK,Years] = SqB0[Cement,SK,Years]
  SqC0[HeavyOilMining,SK,Years] = SqC0[Cement,SK,Years]
  SqCCThreshold[HeavyOilMining,SK,Years] = SqCCThreshold[Cement,SK,Years]

  # 
  # Electric Generation uses Cement for now - Jeff Amlin 11/03/22
  #  
  UtilityGen = Select(ECC,"UtilityGen")
  SqA0[UtilityGen,cn_areas,Years] = SqA0[Cement,cn_areas,Years]
  SqB0[UtilityGen,cn_areas,Years] = SqB0[Cement,cn_areas,Years]
  SqC0[UtilityGen,cn_areas,Years] = SqC0[Cement,cn_areas,Years]
  SqCCThreshold[UtilityGen,cn_areas,Years] = SqCCThreshold[Cement,cn_areas,Years]

  # 
  # Petrochemicals and Other Chemicals use Pulp and Paper Mills
  # 
  chems = Select(ECC,["Petrochemicals", "OtherChemicals"])
  PulpPaperMills = Select(ECC,"PulpPaperMills")
  for year in Years, area in cn_areas, ecc in chems
    SqA0[ecc,area,year] = SqA0[PulpPaperMills,area,year] 
    SqB0[ecc,area,year] = SqB0[PulpPaperMills,area,year] 
    SqC0[ecc,area,year] = SqC0[PulpPaperMills,area,year] 
    SqCCThreshold[ecc,area,year] = SqCCThreshold[PulpPaperMills,area,year]
  end

  # 
  # Trend for availability of CCS
  # 
  @. SqC0Mult = 1
  SqC0Mult[Yr(2022)] = 0.25
  SqC0Mult[Yr(2026)] = 0.5
  years = collect(Yr(2023):Yr(2025))
  for year in years
    SqC0Mult[year] = SqC0Mult[year-1] + (SqC0Mult[Yr(2026)] - 
      SqC0Mult[Yr(2022)]) / (2026-2022)
  end
  
  years = collect(Yr(2027):Yr(2039))
  for year in years
    SqC0Mult[year] = SqC0Mult[year-1] + (SqC0Mult[Yr(2040)] - 
      SqC0Mult[Yr(2026)]) / (2040-2026)
  end

  # 
  # Apply trend to only sectors covered by CFR
  #   
  eccs = Select(ECC,["SAGDOilSands","CSSOilSands","OilSandsMining","OilSandsUpgraders","HeavyOilMining","Petroleum"])
  for year in Years, area in cn_areas, ecc in eccs
    SqC0[ecc,area,year] = SqC0[ecc,area,year] * SqC0Mult[year]
  end

  WriteDisk(db,"MEInput/SqA0", SqA0)
  WriteDisk(db,"MEInput/SqB0", SqB0)
  WriteDisk(db,"MEInput/SqC0", SqC0)
  WriteDisk(db,"MEInput/SqCCThreshold", SqCCThreshold)

  # 
  # Transportation + storage cost per t CO2 (2016 CAD)
  # Source Samuel Lord CCS presentation  
  # Source: "CCS Curves Percent Reduction v3.1.xlsx" - Jeff Amlin 10/03/21
  # 
  
  SqTransStorageCost[Select(AreaDS,"Ontario"),1] =                 160
  SqTransStorageCost[Select(AreaDS,"Quebec"),1] =                  200
  SqTransStorageCost[Select(AreaDS,"British Columbia"),1] =        50
  SqTransStorageCost[Select(AreaDS,"Alberta"),1] =                 20
  SqTransStorageCost[Select(AreaDS,"Manitoba"),1] =                100
  SqTransStorageCost[Select(AreaDS,"Saskatchewan"),1] =            20
  SqTransStorageCost[Select(AreaDS,"Nova Scotia"),1] =             240
  SqTransStorageCost[Select(AreaDS,"Newfoundland"),1] =            400
  SqTransStorageCost[Select(AreaDS,"New Brunswick"),1] =           200
  SqTransStorageCost[Select(AreaDS,"Prince Edward Island"),1] =    300
  SqTransStorageCost[Select(AreaDS,"Yukon Territory"),1] =         300
  SqTransStorageCost[Select(AreaDS,"Northwest Territory"),1] =     400
  SqTransStorageCost[Select(AreaDS,"Nunavut"),1] =                 600

  for year in Years, area in cn_areas
    SqTransStorageCost[area,year] = SqTransStorageCost[area,1]
  end

  WriteDisk(db,"MEInput/SqTransStorageCost", SqTransStorageCost)
end

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))

  SqEnMap::VariableArray{1} = ReadDisk(db,"$Input/SqEnMap") # [Enduse] Sequestering Enduse Map (1=include)

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input,Outpt) = data
  (; Enduse,EnduseDS,Enduses) = data
  (; SqEnMap) = data
  
  for enduse in Enduses
    SqEnMap[enduse] = 1.0
  end
  
  SqEnMap[Select(Enduse, "OffRoad")] = 1.0

  WriteDisk(db,"$Input/SqEnMap", SqEnMap)
end

function PolicyControl(db)
  @info "GHG_CCSCurves.jl - PolicyControl"
  MacroPolicy(db)
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
