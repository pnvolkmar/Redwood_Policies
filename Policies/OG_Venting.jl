#
# OG_Venting.jl
#

using SmallModel

module OG_Venting

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
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  VnA0::VariableArray{2} = ReadDisk(db,"MEInput/VnA0") # [ECC,Area] A Term in Venting Reduction Curve (??)
  VnB0::VariableArray{2} = ReadDisk(db,"MEInput/VnB0") # [ECC,Area] B Term in Venting Reduction Curve (??)
  VnC0::VariableArray{3} = ReadDisk(db,"MEInput/VnC0") # [ECC,Area,Year] C Term in Venting Reduction Curve (??)
  VnCCA0::VariableArray{2} = ReadDisk(db,"MEInput/VnCCA0") # [ECC,Area] A Term in Venting Reduction Capital Cost Curve ($/$)
  VnCCB0::VariableArray{2} = ReadDisk(db,"MEInput/VnCCB0") # [ECC,Area] B Term in Venting Reduction Capital Cost Curve ($/$)
  VnCCC0::VariableArray{3} = ReadDisk(db,"MEInput/VnCCC0") # [ECC,Area,Year] C Term in Venting Reduction Capital Cost Curve ($/$)
  VnC2H6PerCH4::VariableArray{3} = ReadDisk(db,"MEInput/VnC2H6PerCH4") # [ECC,Area,Year] C2H6 Captured per CH4 Captured (Tonnes/Tonne CH4)
  VnCH4CapturedFraction::VariableArray{3} = ReadDisk(db,"MEInput/VnCH4CapturedFraction") # [ECC,Area,Year] Fraction of CH4 Reduction which is Captured (Tonnes/Tonnes)
  VnCH4FlaredPOCF::VariableArray{4} = ReadDisk(db,"MEInput/VnCH4FlaredPOCF") # [ECC,Poll,Area,Year] Pollution Coefficient for Flared CH4 (Tonnes/Tonnes)
  VnGFr::VariableArray{3} = ReadDisk(db,"MEInput/VnGFr") # [ECC,Area,Year] Venting Reduction Grant Fraction ($/$)
  VnOCF::VariableArray{3} = ReadDisk(db,"MEInput/VnOCF") # [ECC,Area,Year] Venting Reduction Operating Cost Factor ($/$)
  VnPL::VariableArray{3} = ReadDisk(db,"MEInput/VnPL") # [ECC,Area,Year] Venting Reduction Physical Lifetime (Years)
  VnPOCF::VariableArray{4} = ReadDisk(db,"MEInput/VnPOCF") # [ECC,Poll,Area,Year] Venting Reduction Emission Factor (Tonnes/Tonne CH4)
  # VnPolSwitch::VariableArray{4} = ReadDisk(db,"SInput/VnPolSwitch") # [ECC,Poll,Area,Year] Venting Pollution Switch (0=Exogenous)
  VnPriceSw::VariableArray{1} = ReadDisk(db,"MEInput/VnPriceSw") # [Year] Venting Reduction Curve Price Switch (1=Endogenous,0=Exogenous)
  xVnPrice::VariableArray{3} = ReadDisk(db,"MEInput/xVnPrice") # [ECC,Area,Year] Exogenous Price for Venting Reduction Curve ($/Tonne)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Areas,ECC,ECCs,Poll) = data
  (; Years) = data
  (; VnA0,VnB0,VnC0,VnCCA0,VnCCB0,VnCCC0,VnC2H6PerCH4) = data
  (; VnCH4CapturedFraction,VnCH4FlaredPOCF,VnGFr,VnOCF) = data
  (; VnPL,VnPOCF,VnPriceSw,xInflation,xVnPrice) = data

  #
  # Venting Reduction Curve Coefficients
  #  
  eccs = Select(ECC,"LightOilMining")
  for area in Areas, ecc in eccs
    VnA0[ecc,area] = 1.85601
    VnB0[ecc,area] = -0.78771
  end
  
  for year in Years, area in Areas, ecc in eccs
    VnC0[ecc,area,year] = 0.92446
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"])
  for area in Areas, ecc in eccs
    VnA0[ecc,area] = 1.87465
    VnB0[ecc,area] = -0.60289
  end
  
  for year in Years, area in Areas, ecc in eccs
    VnC0[ecc,area,year] = 0.93798
  end
  
  WriteDisk(db,"MEInput/VnA0",VnA0)
  WriteDisk(db,"MEInput/VnB0",VnB0)
  WriteDisk(db,"MEInput/VnC0",VnC0)

  #
  # Venting Reduction Capital Cost Curve Coefficients
  #
  eccs = Select(ECC,"LightOilMining")
  for area in Areas, ecc in eccs
    VnCCA0[ecc,area] =    3.17029
    VnCCB0[ecc,area] =   -0.53467
  end
  
  for year in Years, area in Areas, ecc in eccs
    VnCCC0[ecc,area,year] = 1591.93768
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"]) 
  for area in Areas, ecc in eccs
    VnCCA0[ecc,area] =   8.56275
    VnCCB0[ecc,area] =  -0.66629
  end
  
  for year in Years, area in Areas, ecc in eccs
    VnCCC0[ecc,area,year] = 1317.01993
  end
  
  WriteDisk(db,"MEInput/VnCCA0",VnCCA0)
  WriteDisk(db,"MEInput/VnCCB0",VnCCB0)
  WriteDisk(db,"MEInput/VnCCC0",VnCCC0)

  #
  # Flaring venting emissions reduces CH4, but increases CO2.
  # Source: VentingMethane_VOC_CO2_C2H6_Calculation.xlsx from an
  # email from Glasha Obrekht - Jeff Amlin 2/3/14
  #  
  for year in Years, area in Areas, ecc in ECCs
    VnC2H6PerCH4[ecc,area,year] = 0
  end
  
  eccs = Select(ECC,"LightOilMining")
  for year in Years, area in Areas, ecc in eccs
    VnC2H6PerCH4[ecc,area,year] = 0.1085
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"])
  for year in Years, area in Areas, ecc in eccs
    VnC2H6PerCH4[ecc,area,year] = 0.0069
  end
  
  WriteDisk(db,"MEInput/VnC2H6PerCH4",VnC2H6PerCH4)
  #
  for year in Years, area in Areas, ecc in ECCs
    VnCH4CapturedFraction[ecc,area,year] = 0.5
  end
  
  WriteDisk(db,"MEInput/VnCH4CapturedFraction",VnCH4CapturedFraction)
  #
  @. VnCH4FlaredPOCF = 0
  CO2 = Select(Poll,"CO2")
  eccs = Select(ECC,"LightOilMining")
  for year in Years, area in Areas, ecc in eccs
    VnCH4FlaredPOCF[ecc,CO2,area,year] = 2.4014
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"])
  for year in Years, area in Areas, ecc in eccs
    VnCH4FlaredPOCF[ecc,CO2,area,year] = 1.5041
  end
  
  WriteDisk(db,"MEInput/VnCH4FlaredPOCF",VnCH4FlaredPOCF)
  #
  @. VnGFr = 0.0
  WriteDisk(db,"MEInput/VnGFr",VnGFr)
  #
  @. VnOCF = 0.21
  WriteDisk(db,"MEInput/VnOCF",VnOCF)
  #
  @. VnPL = 15
  WriteDisk(db,"MEInput/VnPL",VnPL)
  #
  CO2 = Select(Poll,"CO2")
  eccs = Select(ECC,"LightOilMining")
  for year in Years, area in Areas, ecc in eccs
    VnPOCF[ecc,CO2,area,year] = 0.1887
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"])
  for year in Years, area in Areas, ecc in eccs
    VnPOCF[ecc,CO2,area,year] = 0.0573
  end
  
  VOC = Select(Poll,"VOC")
  eccs = Select(ECC,"LightOilMining")
  for year in Years, area in Areas, ecc in eccs
    VnPOCF[ecc,VOC,area,year] = 0.4057
  end
  
  eccs = Select(ECC,["HeavyOilMining","PrimaryOilSands"])
  for year in Years, area in Areas, ecc in eccs
    VnPOCF[ecc,VOC,area,year] = 0.0528
  end
  
  WriteDisk(db,"MEInput/VnPOCF",VnPOCF)

  # 
  # ************************
  # *
  # * If active, this would overwrite the values from OG_MRA.txp - Jeff Amlin 10/16/22
  # 
  # *Define Variable
  # *VnPolSwitch(ECC,Poll,Area,Year) 'Venting Pollution Switch (0=Exogenous)',
  # * Disk(SInput,VnPolSwitch(ECC,Poll,Area,Year))
  # *End Define Variable
  # *
  # *Select ECC(LightOilMining, HeavyOilMining, PrimaryOilSands)
  # *VnPolSwitch=1
  # *Select ECC*
  # *Write Disk(VnPolSwitch)
  # *
  # ************************
  # 

  @. VnPriceSw = 0
  years = collect(Future:Final)
  for year in years
    VnPriceSw[year] = 1
  end
  
  WriteDisk(db,"MEInput/VnPriceSw",VnPriceSw)
  
  #
  years = collect(Future:Final)
  eccs = Select(ECC,["LightOilMining","HeavyOilMining","PrimaryOilSands"])
  for ecc in eccs, area in Areas, year in years
    xVnPrice[ecc,area,year] = 50.00/xInflation[area,Yr(2013)]
  end
  
  WriteDisk(db,"MEInput/xVnPrice",xVnPrice)
end

function PolicyControl(db)
  @info "OG_Venting.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
