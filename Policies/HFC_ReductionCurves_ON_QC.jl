#
# HFC_ReductionCurves_ON_QC.jl - HFC Reduction Curves
#

using SmallModel

module HFC_ReductionCurves_ON_QC

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
  (; MEA0,MEB0,MECoeff,MEC0) = data
  Coeffs = collect(1:3)
  years = collect(Yr(2011):Yr(2019))
  for year in years, coeff in Coeffs
    MECoeff[coeff,year] = MECoeff[coeff,year-1] + (MECoeff[coeff,Yr(2020)] - 
      MECoeff[coeff,Yr(2010)]) / (2020-2010) 
  end
  
  years = collect(Yr(2021):Yr(2029))
  for year in years, coeff in Coeffs
    MECoeff[coeff,year] = MECoeff[coeff,year-1] + (MECoeff[coeff,Yr(2030)] - 
      MECoeff[coeff,Yr(2020)]) / (2030-2020) 
  end 
  
  years = collect(Yr(2031):Final)
  for year in years, coeff in Coeffs
    MECoeff[coeff,year] = MECoeff[coeff,Yr(2030)]
  end

  # 
  # Start curves in 2021, so as not to interfere with historical values of AB Cap-and-trade
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
  (; Area,ECC) = data
  (; Poll,Years) = data
  (; MEA0,MEB0,MECoeff,MEC0,MEPriceSw) = data

  for year in Years
    MEPriceSw[year] = 1
  end
  
  WriteDisk(db,"MEInput/MEPriceSw",MEPriceSw)

  # 
  # Source: "Non-CO2 Cost Curves for Jeff.xlsx" from Glasha 8/29/15
  # All Sectors
  #  
  Coeffs = collect(1:3)
  areas = Select(Area,["ON","QC"])
  SingleFamily = Select(ECC,"SingleFamily")
  HFC = Select(Poll,"HFC")
  MECoeff[Coeffs,Yr(2010)] = [3.63098,  -0.74908,  0.52583]
  MECoeff[Coeffs,Yr(2020)] = [3.63098,  -0.74908,  0.52583]
  MECoeff[Coeffs,Yr(2030)] = [1.20609,  -0.59925,  0.78994]
  InterpolateCoefficients(data,SingleFamily,HFC,areas)
  eccs = Select(ECC,(from = "SingleFamily",to = "CoalMining"))
  for year in Years, area in areas, ecc in eccs
    MEA0[ecc,HFC,area,year] = MEA0[SingleFamily,HFC,area,year]
    MEB0[ecc,HFC,area,year] = MEB0[SingleFamily,HFC,area,year] 
    MEC0[ecc,HFC,area,year] = MEC0[SingleFamily,HFC,area,year]
  end

  WriteDisk(db,"MEInput/MEA0",MEA0)
  WriteDisk(db,"MEInput/MEB0",MEB0)
  WriteDisk(db,"MEInput/MEC0",MEC0)
end

function PolicyControl(db)
  @info "HFC_ReductionCurves_ON_QC.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
