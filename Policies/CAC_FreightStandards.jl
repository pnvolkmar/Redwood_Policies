#
# CAC_FreightStandards.jl
#

using SmallModel

module CAC_FreightStandards

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  Input::String = "TInput"
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

  FTMap::VariableArray{3} = ReadDisk(db,"$Input/FTMap") # [Fuel,EC,Tech]   # Map between Fuel and Tech (Map)
  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)
  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [Tech,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{1} = zeros(Float64,length(Year)) # [Year] xRM reduction input variable
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Areas,EC) = data
  (; Fuel,FuelEP) = data
  (; Enduses) = data
  (; Tech) = data
  (; Poll) = data
  (; FTMap,POCX,Reduce,xRM) = data
  
  ec = Select(EC,"Freight")
  fuelEPs = Select(FuelEP,["Gasoline","Diesel"])
  techs = Select(Tech,["HDV2B3Diesel","HDV2B3Gasoline"])
  poll = Select(Poll,"CO2")
  years = collect(Future:Final)
  
  #
  # *
  # * Adjustment for COX E.C. to be equal to 2019. 
  # *
  #
  
  for enduse in Enduses, fuelEP in fuelEPs, tech in techs, area in Areas, year in years
    POCX[enduse,fuelEP,tech,ec,poll,area,year] = POCX[enduse,fuelEP,tech,ec,poll,area,Yr(2019)]
  end
  
  WriteDisk(DB,"$Input/POCX",POCX)

  # *
  # * Tier 3 Sulfur Content in Gasoline
  # * The Tier 3 fuel standards require that federal Gasoline contains no more than 10 ppm of sulfur (down from 30 ppm) on an annual average basis by January 1, 2017.
  # * http://www.dieselnet.com/standards/us/ld_t3.php
  # *
  # * Implement reduction to all devices on road since it applies to fuel
  # * Reductions from e-mail from Matt Lewis 01/05/16 - Ian
  # *
  
  @. Reduce = 1.0    
  Reduce[Yr(2021)] = 0.470
  
  years = collect(Yr(2022):Final)
  for year in years
    Reduce[year] = Reduce[Yr(2021)]
  end

  fuels = Select(Fuel,["Gasoline","Ethanol"])
  poll = Select(Poll,"SOX")
  years = collect(Future:Final)    

  #
  # FTMap in the original file is just selecting using the first Fuel 
  # (Gasoline) since it isn't in a Do loop. Code below replicates this
  # - Ian 06/03/24
  #  
  Gasoline = Select(Fuel,"Gasoline")
  techs = findall(FTMap[Gasoline,ec,:] .== 1)
  
  for tech in techs
    if FTMap[Gasoline,ec,tech] == 1
      for area in Areas, year in years
        xRM[tech,ec,poll,area,year] = min(xRM[tech,ec,poll,area,year],Reduce[year])
      end
      
    end
    
  end
  
  WriteDisk(db,"$Input/xRM",xRM) 
end

function PolicyControl(db)
  @info "CAC_FreightStandards.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
