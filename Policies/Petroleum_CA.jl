#
# Petroleum_CA.jl - California Petroleum Refinery Policies
#

using SmallModel

module Petroleum_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  CalDB::String = "SCalDB"
  Input::String = "SInput"
  Outpt::String = "SOutput"
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

  RPPSw::VariableArray{2} = ReadDisk(db,"SpInput/RPPSw") # [Area,Year] Refined Petroleum Products (RPP) Switch
  xSqPolCCNet::VariableArray{4} = ReadDisk(db,"MEInput/xSqPolCCNet") # [ECC,Poll,Area,Year] Sequestering Net Emissions (Tonnes/Yr)

  # Scratch Variables
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Area,ECC,Poll) = data
  (; xSqPolCCNet,RPPSw) = data

  #
  # CCS on majority of petroleum refining operations by 2030
  #  
  CA = Select(Area,"CA")
  Petroleum = Select(ECC,"Petroleum")
  CO2 = Select(Poll,"CO2")
  years = collect(Yr(2030):Final)
  for year in years
    # xSqPolCCNet[Petroleum,CO2,CA,year] = -9000000
    xSqPolCCNet[Petroleum,CO2,CA,year] = -18000000
  end

  years = collect(Yr(2023):Yr(2029))
  for year in years
    xSqPolCCNet[Petroleum,CO2,CA,year] = 
      xSqPolCCNet[Petroleum,CO2,CA,year-1]+
        (xSqPolCCNet[Petroleum,CO2,CA,Yr(2030)]-
          xSqPolCCNet[Petroleum,CO2,CA,Yr(2025)])/(2030-2025)
  end

  WriteDisk(db,"MEInput/xSqPolCCNet",xSqPolCCNet)

  #
  ########################
  #
  # Production reduced in line with petroleum demand
  #
  years = collect(Yr(2023):Final)
  for year in years
    RPPSw[CA,year] = 2
  end

  WriteDisk(db,"SpInput/RPPSw",RPPSw)
end

function PolicyControl(db)
  @info "Petroleum_CA.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
