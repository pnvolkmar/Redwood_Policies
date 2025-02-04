#
# AdjustCAC_Steel_2024.jl - This jl models the VOC in certain products (SOR/2021-268) Regulations
# 
# This TXP Models emission reductions to the Iron&Steel sector in Ontario
# These reductions are associated with the Algoma and Arcelor projects 
# Where conversion to DRI-EAF will lead to significant reductions from these 2 plants
# Since the impact of these projects is mostly captured in FsDmd, but no AP emissions are produced from it
# Pro-rating the impact to combustion and process emissions to obtain anticipated levels of emissions. 
# The assumptions were taken from 2022 Projection sent to EAD (Oct 21, 2022)_Iron&STeel.xlsx 
# Received from the Metals and Minerals Processing Division on Oct 21 2022
# Proportional reduction were applied to Ref22 to develop the Pollution Coefficient Reduction Multipliers
# See 2022 Iron&Steel projections_AB_221103.xlsx for detail calculations
# These assumptions should be reviewed yearly 
# By Audrey Bernard 22.10.24

using SmallModel

module AdjustCAC_Steel_2024

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
  MEInput::String = "MEInput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/Economic Driver)
  POCX::VariableArray{6} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)

  # Scratch Variables
  Temp::VariableArray{2} = zeros(Float64,length(Poll),length(Year)) # [ECC,Poll,Area,Year] Scratch Variable For Input Reductions
end

function IndPolicy(db)
  data = IControl(; db)
  (; Area,EC,ECC,Enduses,FuelEPs,Poll) = data
  (; Input,MEInput) = data
  (; MEPOCX,POCX,Temp) = data

  #
  # Adjust Combustion Emissions
  #
  polls = Select(Poll,["BC","COX","NOX","PMT","PM10","PM25","SOX","VOC"])
  years = collect(Yr(2023):Yr(2035))
  ec = Select(EC,"IronSteel")
  area = Select(Area,"ON")

  Temp[polls,years] .= [
    #/(Poll,Year)                   2023     2024     2025     2026     2027      2028     2029     2030     2031     2032     2033     2034     2035  
    #=Black Carbon=#              0.0000   0.0000   0.1750   0.1750   0.1750    0.3500   0.7000   0.7000   0.7000   0.7000   0.7000   0.7000   0.7000
    #=Carbon Monoxide=#           0.0000   0.0000   -0.0240  -0.0240  -0.0240   0.0530   0.1060   0.1060   0.1060   0.1060   0.1060   0.1060   0.1060
    #=Nitrogen Oxides=#           0.0000   0.0000   0.0500   0.0500   0.0500    0.1260   0.2520   0.2520   0.2520   0.2520   0.2520   0.2520   0.2520
    #=Total Particulate Matter=#  0.0000   0.0000   0.0290   0.0290   0.0290    0.0460   0.0920   0.0920   0.0920   0.0920   0.0920   0.0920   0.0920
    #=Particulate Matter 10=#     0.0000   0.0000   0.0270   0.0270   0.0270    0.0440   0.0880   0.0880   0.0880   0.0880   0.0880   0.0880   0.0880
    #=Particulate Matter 2.5=#    0.0000   0.0000   0.0320   0.0320   0.0320    0.0520   0.1040   0.1040   0.1040   0.1040   0.1040   0.1040   0.1040
    #=Sulphur Oxides=#            0.0000   0.0000   0.1190   0.1190   0.1190    0.2570   0.5140   0.5140   0.5140   0.5140   0.5140   0.5140   0.5140
    #=Volatile Org Comp=#         0.0000   0.0000   0.0850   0.0850   0.0850    0.1890   0.3780   0.3780   0.3780   0.3780   0.3780   0.3780   0.3780
    ]

  for enduse in Enduses, poll in polls, fuelep in FuelEPs
    years = collect(Yr(2023):Yr(2035))
    for year in years
      POCX[enduse,fuelep,ec,poll,area,year] = POCX[enduse,fuelep,ec,poll,area,year]*
                                              (1-Temp[poll,year])
    end
    years = collect(Yr(2036):Final)
    for year in years
      POCX[enduse,fuelep,ec,poll,area,year] = POCX[enduse,fuelep,ec,poll,area,year]*
                                              (1-Temp[poll,Yr(2035)])
    end
  end
  WriteDisk(db,"$Input/POCX",POCX)

  #
  # Adjust Process Emissions
  #
  polls = Select(Poll,["COX","NOX","PMT","PM10","PM25","SOX","VOC"])
  years = collect(Yr(2023):Yr(2035))
  ecc = Select(ECC,"IronSteel")
  area = Select(Area,"ON")

  Temp[polls,years] .= [
    #/(Poll,Year)                   2023     2024     2025     2026     2027      2028     2029     2030     2031     2032     2033     2034     2035  
    #=Carbon Monoxide=#           0.0000   0.0000   -0.0240  -0.0240  -0.0240   0.0530   0.1060   0.1060   0.1060   0.1060   0.1060   0.1060   0.1060
    #=Nitrogen Oxides=#           0.0000   0.0000   0.0500   0.0500   0.0500    0.1260   0.2520   0.2520   0.2520   0.2520   0.2520   0.2520   0.2520
    #=Total Particulate Matter=#  0.0000   0.0000   0.0290   0.0290   0.0290    0.0460   0.0920   0.0920   0.0920   0.0920   0.0920   0.0920   0.0920
    #=Particulate Matter 10=#     0.0000   0.0000   0.0270   0.0270   0.0270    0.0440   0.0880   0.0880   0.0880   0.0880   0.0880   0.0880   0.0880
    #=Particulate Matter 2.5=#    0.0000   0.0000   0.0320   0.0320   0.0320    0.0520   0.1040   0.1040   0.1040   0.1040   0.1040   0.1040   0.1040
    #=Sulphur Oxides=#            0.0000   0.0000   0.1190   0.1190   0.1190    0.2570   0.5140   0.5140   0.5140   0.5140   0.5140   0.5140   0.5140
    #=Volatile Org Comp=#         0.0000   0.0000   0.0850   0.0850   0.0850    0.1890   0.3780   0.3780   0.3780   0.3780   0.3780   0.3780   0.3780
    ]

  for poll in polls
    years = collect(Yr(2023):Yr(2035))
    for year in years
      MEPOCX[ecc,poll,area,year] = MEPOCX[ecc,poll,area,year]*(1-Temp[poll,year])
    end
    years = collect(Yr(2036):Final)
    for year in years
      MEPOCX[ecc,poll,area,year] = MEPOCX[ecc,poll,area,year]*(1-Temp[poll,Yr(2035)])
    end
  end
  WriteDisk(db,"MEInput/MEPOCX",MEPOCX)

end


function PolicyControl(db)
  @info "AdjustCAC_Steel_2024.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
