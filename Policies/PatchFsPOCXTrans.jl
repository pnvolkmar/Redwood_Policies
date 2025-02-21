#
# PatchFsPOCXTrans.jl - Patch for Transportation FsPOCX - Jeff Amloin 2/14/25
#
using SmallModel

module PatchFsPOCXTrans

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  FuelFs::SetArray = ReadDisk(db,"E2020DB/FuelFsKey")
  FuelFsDS::SetArray = ReadDisk(db,"E2020DB/FuelFsDS")
  FuelFss::Vector{Int} = collect(Select(FuelFs))
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))
  vArea::SetArray = ReadDisk(db,"E2020DB/vAreaKey")
  vAreaDS::SetArray = ReadDisk(db,"E2020DB/vAreaDS")
  vAreas::Vector{Int} = collect(Select(vArea))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  FsPOCS::VariableArray{6} = ReadDisk(db,"$Input/FsPOCS") # [Fuel,Tech,EC,Poll,Area,Year] Feedstock Pollution Standards (Tonnes/TBtu)
  FsPOCX::VariableArray{6} = ReadDisk(db,"$Input/FsPOCX") # [Fuel,Tech,EC,Poll,Area,Year] Feedstock Pollution Coefficient (Tonnes/TBtu)

end

function Emissions(db)
  data = TControl(; db)
  (;Input) = data
  (;Area,ECs,Enduses,Fuel) = data
  (;Nation,Poll,Polls,Techs,Years) = data
  (;ANMap,FsPOCS,FsPOCX) = data
  
  #
  # @info "Patch for Transportation FsPOCX" 
  #  
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1)
  poll = Select(Poll,"CO2")
  fuel = Select(Fuel,"Lubricants")
  for year in Years, area in areas, ec in ECs, tech in Techs
    FsPOCX[fuel,tech,ec,poll,area,year] = 60878
  end
  WriteDisk(db,"$Input/FsPOCX",FsPOCX)
  
  @. FsPOCS = 1e12   
  WriteDisk(db,"$Input/FsPOCS",FsPOCS)

end

function PolicyControl(db)
  @info "PatchFsPOCXTrans.jl - PolicyControl"
  Emissions(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
