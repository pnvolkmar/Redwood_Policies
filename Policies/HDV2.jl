#
# HDV2.jl
#
# Note that this file contains a fixed table but only reads
# in Future-Final data into the model, so historical data will
# be ignored in future updates. - Hilary 15.04.15
#
# This file extends HDV (2014-2018) by improving DEEs in years
# 2019 and 2020 for HDV6+ classes,and all classes from 2021 to 2027
# HDV2 overwrites HDV, so it can be run on top of REF16.bat
#
# Updated to reflect CG2 analysis, ~6 MT of reductions in 2030
# Matt Lewis August 27 2018
#
# Reverted to CG1 values to decrease reductions in 2030
# Need to verify results targetting ~6 MT of reductions in 2030
# Matt Lewis July 16, 2019
#
# For 2021_Update,incorporating growth in DEE in vdata, thus need to adjust
# Temps values in this jl. % Growth is rebased to 2021, with no change in
# 2021 due to the HDV2 regs.
# Matt Lewis June 30, 2023
#

using SmallModel

module HDV2

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  Input::String = "TInput"
  Outpt::String = "TOutput"
  
  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  Years::Vector{Int} = collect(Select(Year))
  
  DEE::VariableArray{5} = ReadDisk(db,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency (Mile/mmBtu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standards Policy (Btu/Btu)
  # Scratch
  Temps::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # Temps(Enduse,Tech,EC,Area,Year)  TYPE=REAL(8,2)
 end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,EC,Enduse,Tech,Years) = data
  (; DEE,DEStdP,Temps) = data

  areas = Select(Area,(from = "ON",to = "NU"))
  techs = Select(Tech,(from = "HDV2B3Gasoline",to = "HDV8FuelCell"))
  ecs = Select(EC,(from = "Passenger",to = "CommercialOffRoad"))
  enduse = Select(Enduse,["Carriage"])
  
  years = collect(Future:Final)
  for year in years, tech in techs, ec in ecs, area in areas
    DEStdP[enduse,tech,ec,area,year] = DEE[enduse,tech,ec,area,Last]
  end

  area  = Select(Area,["ON"])
  ec  = Select(EC,["Freight"])
  techs = Select(Tech,["HDV2B3Gasoline","HDV2B3Diesel","HDV45Gasoline","HDV45Diesel","HDV67Gasoline","HDV67Diesel","HDV8Gasoline","HDV8Diesel"])
  years = collect(Yr(2014):Yr(2027))

  #! format: off
  Temps[enduse,techs,ec,area,years] = [
    #2014   2015   2016   2017   2018   2019   2020   2021   2022   2023   2024   2025   2026   2027
    1.015  1.015  1.046  1.062  1.108  1.108  1.108  1.000  1.014  1.027  1.048  1.062  1.075  1.089 # HDV2B3Gasoline
    1.026  1.04   1.066  1.105  1.158  1.158  1.158  1.000  1.014  1.027  1.048  1.062  1.075  1.089 # HDV2B3Diesel
    1.007  1.007  1.05   1.057  1.079  1.079  1.079  1.000  1.000  1.000  1.033  1.033  1.033  1.053 # HDV45Gasoline
    1.037  1.044  1.058  1.097  1.125  1.125  1.125  1.000  1.000  1.000  1.046  1.046  1.046  1.059 # HDV45Diesel
    1.001  1.001  1.054  1.054  1.054  1.054  1.054  1.000  1.000  1.000  1.034  1.034  1.034  1.054 # HDV67Gasoline
    1.056  1.056  1.056  1.094  1.094  1.094  1.094  1.000  1.000  1.000  1.040  1.040  1.040  1.059 # HDV67Diesel
    1.002  1.002  1.054  1.055  1.055  1.055  1.055  1.000  1.000  1.000  1.046  1.046  1.046  1.066 # HDV8Gasoline
    1.083  1.083  1.083  1.115  1.115  1.117  1.117  1.000  1.000  1.000  1.032  1.032  1.032  1.065 # HDV8Diesel
  ]
  #! format: on

  years = collect(Yr(2014):Yr(2027))
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] = Temps[enduse,tech,ec,area,year] .* 
      DEStdP[enduse,tech,ec,area,year] 
  end

  #
  # Use gasoline growth rates for propane and natural gas trucks
  #  
  techs = Select(Tech,["HDV2B3Propane","HDV2B3NaturalGas"])
  gasoline = Select(Tech,["HDV2B3Gasoline"])
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] = Temps[enduse,gasoline,ec,area,year] .* 
      DEStdP[enduse,tech,ec,area,year]
  end
  
  techs = Select(Tech,["HDV45Propane","HDV45NaturalGas"])
  gasoline = Select(Tech,["HDV45Gasoline"])
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] = Temps[enduse,gasoline,ec,area,year] .* 
      DEStdP[enduse,tech,ec,area,year]
  end

  techs = Select(Tech,["HDV67Propane","HDV67NaturalGas"])
  gasoline = Select(Tech,["HDV67Gasoline"])
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] = Temps[enduse,gasoline,ec,area,year] .* 
      DEStdP[enduse,tech,ec,area,year]
  end

  techs = Select(Tech,["HDV8Propane","HDV8NaturalGas"])
  gasoline = Select(Tech,["HDV8Gasoline"])
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] = Temps[enduse,gasoline,ec,area,year] .* 
      DEStdP[enduse,tech,ec,area,year]
  end

  techs = Select(Tech,(from = "HDV2B3Gasoline",to = "HDV8FuelCell"))
  years = collect(Yr(2028):Final)
  for year in years, tech in techs
    DEStdP[enduse,tech,ec,area,year] .= DEStdP[enduse,tech,ec,area,Yr(2027)] 
  end

  areas = Select(Area,(from = "QC",to = "NU"))
  ON = Select(Area,"ON")
  for year in Years, tech in techs
    DEStdP[enduse,tech,ec,areas,year] .= DEStdP[enduse,tech,ec,ON,year]
  end
  
  WriteDisk(db,"$Input/DEStdP",DEStdP)
end

function PolicyControl(db)
  @info "HDV2.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
