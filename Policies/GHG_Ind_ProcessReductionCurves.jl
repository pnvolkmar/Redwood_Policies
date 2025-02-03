#
# GHG_Ind_ProcessReductionCurves.jl - GHG Non-CO2 Cost Curves
#

using SmallModel

module GHG_Ind_ProcessReductionCurves

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
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  MEA0::VariableArray{4} = ReadDisk(db,"MEInput/MEA0") # [ECC,Poll,Area,Year] A Term in eCO2 Reduction Curve (CDN 1999$)
  MEB0::VariableArray{4} = ReadDisk(db,"MEInput/MEB0") # [ECC,Poll,Area,Year] B Term in eCO2 Reduction Curve (CDN 1999$)
  MEC0::VariableArray{4} = ReadDisk(db,"MEInput/MEC0") # [ECC,Poll,Area,Year] C Term in eCO2 Reduction Curve (CDN 1999$)
  MEPriceSw::VariableArray{1} = ReadDisk(db,"MEInput/MEPriceSw") # [Year] Process Emission Reduction Curve Price Switch (1=Endogenous,0=Exogenous)

  # Scratch Variables
  MECoeff::VariableArray{2} = zeros(Float64,3,length(Year)) # [Coeff,Year] Process Emission Reduction Coefficients
end

function InterpolateCoefficients(data,ecc,poll,areas)
  (; MECoeff,MEA0,MEB0,MEC0) = data

  [MECoeff[:,year] = MECoeff[:,year-1] + (MECoeff[:,Yr(2020)] - MECoeff[:,Yr(2010)]) / 
    (2020-2010) for year in Yr(2011):Yr(2019)]
  [MECoeff[:,year] = MECoeff[:,year-1] + (MECoeff[:,Yr(2030)] - MECoeff[:,Yr(2020)]) / 
    (2030-2020) for year in Yr(2021):Yr(2029)]
  years = collect(Yr(2031):Final)
  for year in years
    MECoeff[:,year] = MECoeff[:,Yr(2030)]
  end

  # 
  # Start curves in 2021,so as not to interfere with historical values of AB Cap-and-trade
  #   
  years = collect(Future:Final)
  for year in years, area in areas
    MEA0[ecc,poll,area,year] = MECoeff[1,year]
    MEB0[ecc,poll,area,year] = MECoeff[2,year] 
    MEC0[ecc,poll,area,year] = MECoeff[3,year] 
  end
  
  return
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Areas,ECC) = data
  (; Nation) = data 
  (; Poll) = data
  (; ANMap,MEA0,MEB0,MECoeff,MEC0,MEPriceSw) = data

  @. MEPriceSw = 1
  WriteDisk(db,"MEInput/MEPriceSw",MEPriceSw)

  # 
  # Source: "Non-CO2 Cost Curves for Jeff.xlsx" from Glasha 8/29/15
  # 
  # Reduce curves to remove historical reductions - Jeff Amlin 10/13/18
  # From Glasha email 10/12/18 "With $30 tonne we would shift the curves
  # for Alberta by the amounts in yellow ($30 Price) below:
  # 
  # Sector          Poll Price   2020    2030
  # Aluminum      PFC   10      22%     20%
  #                       30    40%     41%
  # Elec Util       SF6 10      33%     33%
  #                   30        42%     42%
  # Coal Mining   CH4   10      49%     49%
  #                   30        59%     57%
  # All Sectors   HFC   10      32%     61%
  #                   30        41%     68%
  # OtherNonFerrous SF6 10      98%     98%
  #                   30        98%     98%
  # Fertilizer    N2O   10      51%     51%
  #             30      76%     76%
  # Computers     SF6   10      3%      2%
  #              30     7%      4%
  # Elec Equip      PFC 10      3%      2%
  #                   30        7%      4%
  # 
  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))
  # 
  Aluminum = Select(ECC,"Aluminum")
  PFC = Select(Poll,"PFC")
  MECoeff[:,Yr(2010)] = [20.78692199,  -1.101752773,  0.584812905]
  MECoeff[:,Yr(2020)] = [23.53425032,  -1.158258778,  0.581597782]
  MECoeff[:,Yr(2030)] = [50.54261718,  -1.415875789,  0.577228335]
  MEC0[Aluminum,PFC,cn_areas,Yr(2020)] = MEC0[Aluminum,PFC,cn_areas,Yr(2020)] * (1-0.40)
  MEC0[Aluminum,PFC,cn_areas,Yr(2020)] = MEC0[Aluminum,PFC,cn_areas,Yr(2020)] * (1-0.41)
  InterpolateCoefficients(data,Aluminum,PFC,cn_areas)
  # 
  OtherNonferrous = Select(ECC,"OtherNonferrous")
  SF6 = Select(Poll,"SF6")
  MECoeff[:,Yr(2010)] = [0.005,  -3.25288E-30,  0.980770]
  MECoeff[:,Yr(2020)] = [0.005,  -3.25288E-30,  0.980806163]
  MECoeff[:,Yr(2030)] = [0.005,  -3.25288E-30,  0.980806163]
  MEC0[OtherNonferrous,SF6,cn_areas,Yr(2020)] = MEC0[OtherNonferrous,SF6,cn_areas,Yr(2020)] * (1-0.98)
  MEC0[OtherNonferrous,SF6,cn_areas,Yr(2020)] = MEC0[OtherNonferrous,SF6,cn_areas,Yr(2020)] * (1-0.98)
  InterpolateCoefficients(data,OtherNonferrous,SF6,cn_areas)
  # 
  UtilityGen = Select(ECC,"UtilityGen")
  MECoeff[:,Yr(2010)] = [3.108060923,  -0.62832103,  0.57888]
  MECoeff[:,Yr(2020)] = [3.108060923,  -0.62832103,  0.57888]
  MECoeff[:,Yr(2030)] = [3.108060923,  -0.62832103,  0.57888]
  MEC0[UtilityGen,SF6,cn_areas,Yr(2020)] = MEC0[UtilityGen,SF6,cn_areas,Yr(2020)] * (1-0.42)
  MEC0[UtilityGen,SF6,cn_areas,Yr(2020)] = MEC0[UtilityGen,SF6,cn_areas,Yr(2020)] * (1-0.42)
  InterpolateCoefficients(data,UtilityGen,SF6,cn_areas)
  # 
  CoalMining = Select(ECC,"CoalMining")
  CH4 = Select(Poll,"CH4")
  MECoeff[:,Yr(2010)] = [9.726227941,  -1.587315697,  0.627707851]
  MECoeff[:,Yr(2020)] = [9.753432944,  -1.578589183,  0.618905364]
  MECoeff[:,Yr(2030)] = [1.675236552,  -0.630231596,  0.679465609]
  MEC0[CoalMining,CH4,cn_areas,Yr(2020)] = MEC0[CoalMining,CH4,cn_areas,Yr(2020)] * 
    (1-0.59)
  MEC0[CoalMining,CH4,cn_areas,Yr(2020)] = MEC0[CoalMining,CH4,cn_areas,Yr(2020)] * 
    (1-0.57)
  InterpolateCoefficients(data,CoalMining,CH4,cn_areas)
  # 
  OtherManufacturing = Select(ECC,"OtherManufacturing")
  MECoeff[:,Yr(2010)] = [16.04980207,  -1.056183671,  0.705728166]
  MECoeff[:,Yr(2020)] = [105.0311018,  -1.133560846,  0.236699947]
  MECoeff[:,Yr(2030)] = [83.20436779,  -0.903121774,  0.186493423]
  MEC0[OtherManufacturing,SF6,cn_areas,Yr(2020)] = MEC0[OtherManufacturing,SF6,cn_areas,Yr(2020)] * (1-0.07)
  MEC0[OtherManufacturing,SF6,cn_areas,Yr(2020)] = MEC0[OtherManufacturing,SF6,cn_areas,Yr(2020)] * (1-0.04)
  InterpolateCoefficients(data,OtherManufacturing,SF6,cn_areas)
  # 
  MECoeff[:,Yr(2010)] = [16.04980207,  -1.056183671 ,  0.705728166]
  MECoeff[:,Yr(2020)] = [105.0311018,  -1.133560846,  0.236699947]
  MECoeff[:,Yr(2030)] = [83.20436779,  -0.903121774,  0.186493423]
  MEC0[OtherManufacturing,PFC,cn_areas,Yr(2020)] = MEC0[OtherManufacturing,PFC,cn_areas,Yr(2020)] * (1-0.07)
  MEC0[OtherManufacturing,PFC,cn_areas,Yr(2020)] = MEC0[OtherManufacturing,PFC,cn_areas,Yr(2020)] * (1-0.04)
  InterpolateCoefficients(data,OtherManufacturing,PFC,cn_areas)
  # 
  Fertilizer = Select(ECC,"Fertilizer")
  N2O = Select(Poll,"N2O")
  MECoeff[:,Yr(2010)] = [15.76492894,  -1.324467998,  0.8925]
  MECoeff[:,Yr(2020)] = [15.76492894,  -1.324467998,  0.8925]
  MECoeff[:,Yr(2030)] = [15.76492894,  -1.324467998,  0.8925]
  MEC0[Fertilizer,N2O,cn_areas,Yr(2020)] = MEC0[Fertilizer,N2O,cn_areas,Yr(2020)] * (1-0.76)
  MEC0[Fertilizer,N2O,cn_areas,Yr(2020)] = MEC0[Fertilizer,N2O,cn_areas,Yr(2020)] * (1-0.76)
  InterpolateCoefficients(data,Fertilizer,N2O,cn_areas)

  WriteDisk(db,"MEInput/MEA0",MEA0)
  WriteDisk(db,"MEInput/MEB0",MEB0)
  WriteDisk(db,"MEInput/MEC0",MEC0)
end

function PolicyControl(db)
  @info "GHG_Ind_ProcessReductionCurves.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
