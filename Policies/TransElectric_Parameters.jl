#
# TransElectric_Parameters.jl - Assign parameters for electric vehicles
#

using SmallModel

module TransElectric_Parameters

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
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

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
  Fuels::Vector{Int} = collect(Select(Fuel))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  xDmFracBefore::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)

  # Scratch Variables
  xDmFracSum::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] 
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  GasPoolFrac::VariableArray{6} = zeros(Float64,length(Enduse),length(Fuel),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Fuel,Tech,EC,Area,Year] Variable for calculating total gasoline and ethanol
  GasPoolFracTotal::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Variable for calculating total gasoline and ethanol
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Areas,EC,Enduse) = data 
  (; Fuel) = data
  (; Poll,Tech) = data
  (; DmFracMax,DmFracMin,GasPoolFrac) = data
  (; GasPoolFracTotal,POCX,xDmFrac,xDmFracSum) = data
  
  enduse = Select(Enduse,["Carriage"])
  techs = Select(Tech,["LDVHybrid","LDTHybrid"])
  fuels = Select(Fuel,["Gasoline","Ethanol"])
  ec = Select(EC,["Passenger"])
  years = collect(Future:Final)

  xDmFracSum[enduse,techs,ec,Areas,years] = 
    sum(xDmFrac[enduse,fuel,techs,ec,Areas,years] for fuel in fuels)
  
  GasPoolFracTotal[enduse,techs,ec,Areas,years].=xDmFracSum[enduse,techs,ec,Areas,years]
  for fuel in fuels
    GasPoolFrac[enduse,fuel,techs,ec,Areas,years].=
      xDmFrac[enduse,fuel,techs,ec,Areas,years]./
        GasPoolFracTotal[enduse,techs,ec,Areas,years] 
  end
  
  fuel = Select(Fuel,["Electric"])
  DmFracMin[enduse,fuel,techs,ec,Areas,years].=0.65
  xDmFrac[enduse,fuel,techs,ec,Areas,years].=0.65

  fuels = Select(Fuel,["Gasoline","Ethanol"])
  xDmFrac[enduse,fuels,techs,ec,Areas,years] .= 
    GasPoolFrac[enduse,fuels,techs,ec,Areas,years]*0.35
  DmFracMax[enduse,fuels,techs,ec,Areas,years] .= 
    GasPoolFrac[enduse,fuels,techs,ec,Areas,years]*0.35

  WriteDisk(db,"$Input/xDmFrac",xDmFrac)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)

  fuelep = Select(Fuel,["Gasoline"])
  
  CACs = Select(Poll,["PMT","PM10","PM25","SOX","NOX","VOC","COX","NH3","Hg","BC"])
  techToUse = Select(Tech,["LDVGasoline"])
  techToAssign = Select(Tech,["LDVHybrid"])
  POCX[enduse,fuelep,techToAssign,ec,CACs,Areas,years] = 
    POCX[enduse,fuelep,techToUse,ec,CACs,Areas,years]
  techToAssign = Select(Tech,["LDTHybrid"])
  techToUse = Select(Tech,["LDTGasoline"])
  POCX[enduse,fuelep,techToAssign,ec,CACs,Areas,years] = 
    POCX[enduse,fuelep,techToUse,ec,CACs,Areas,years]
end

function PolicyControl(db)
  @info "TransElectric_Parameters.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
