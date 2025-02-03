#
# CAC_PassStandards.txt
#

using SmallModel

module CAC_PassStandards

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

  FTMap::VariableArray{3} = ReadDisk(db,"$Input/FTMap") # [Fuel,EC,Tech]   # Map between Fuel and Tech (Map)
  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution coefficient (Tonnes/TBtu)
  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [Tech,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{1} = zeros(Float64,length(Year)) # [Year] xRM reduction input variable
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Areas,EC,Enduses) = data
  (; Fuel,FuelEP,FuelEPs) = data
  (; Poll,Tech,Years) = data
  (; FTMap,POCX,Reduce,xRM) = data

  #
  # * Light Duty Vehicles for Model Year 2009 onward is NOx 0.07 Grams/Mile from Table 2
  # * http://www.dieselnet.com/standards/ca/
  # * 
  # * Light Duty US Standards
  # * Table 2 - Tier 2 Emission Standards, FTP 75 (Grams/Mile)
  # *                    CO  NOx  PM
  # * Light Duty (Bin 5) 4.2 0.07 0.01
  # * http://www.dieselnet.com/standards/us/ld_t2.php
  # *
  # * Light Duty Vehicles
  # *
  
  years = collect(Future:Final)
  Passenger = Select(EC,"Passenger")
  techs = Select(Tech,(from="LDVGasoline", to="LDTHybrid"))
  Gasoline = Select(FuelEP,"Gasoline")
  polls = Select(Poll,["BC","PM25","PM10","PMT","COX","NOX","VOC"])
  
  for year in years, area in Areas, poll in polls, eu in Enduses, tech in techs
    POCX[eu,Gasoline,tech,Passenger,poll,area,year] = 
      POCX[eu,Gasoline,tech,Passenger,poll,area,Yr(2019)]
  end
  
  # 
  # Tier 3 Sulfur Content in Gasoline
  # The Tier 3 fuel standards require that federal gasoline contains no more than 10 ppm of sulfur (down from 30 ppm) on an annual average basis by January 1, 2017.
  # http://www.dieselnet.com/standards/us/ld_t3.php
  # 
  # Implement reduction to all devices on road since it applies to fuel
  # Reductions from e-mail from Matt Lewis 01/05/16 - Ian
  # TODOLater: FTMap is zero for transportation, so nothing changes - Jeff Amlin 06/13/24 
  # 
  @. Reduce = 1.0  
  #
  years = collect(Yr(2022):Yr(2050))
  for year in years
    Reduce[year] = 0.470
  end 
  
  #
  years = collect(Future:Final)
  SOX = Select(Poll,"SOX")
  fuels = Select(Fuel,["Gasoline","Ethanol"]) 
  techs = findall(FTMap[Gasoline,Passenger,:] .== 1)
  for tech in techs
    if FTMap[Gasoline,Passenger,tech] == 1
      for area in Areas, year in Years
        xRM[tech,Passenger,SOX,area,year] = min(xRM[tech,Passenger,SOX,area,year],
          Reduce[year])
      end
      
    end
    
  end    
  
  WriteDisk(db,"$Input/xRM",xRM)
  
  #
  # Assume Electrics have zero emissions for selected set of CACs
  #
  techs = Select(Tech,["LDVElectric","LDTElectric"])
  polls = Select(Poll,["NOX","VOC","PM10","PM25","PMT","COX"])
  years = collect(Future:Final)
  for eu in Enduses, fuelep in FuelEPs, tech in techs, poll in polls, area in Areas, year in years 
    POCX[eu,fuelep,tech,Passenger,poll,area,year] = 0
  end
  
  WriteDisk(DB,"$Input/POCX",POCX)
end

function PolicyControl(db)
  @info "CAC_PassStandards.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
