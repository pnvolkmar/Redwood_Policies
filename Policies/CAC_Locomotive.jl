#
# CAC_Locomotive.jl 
# This txp simulates the impact of the following Transport Canada policy 
# to control criteria air contaminant emissions from locomotives:
# Locomotive Emissions Regulations, under the Railway Safety Act 
#
# Details available in this file: 
#  \\ncr.int.ec.gc.ca\shares\e\ECOMOD\CACs\Policy Files\2019\Locomotive Emission Regulations\CAC_locomotive Reg 2019.08.15.xlsx
#
# Last edited by Audrey Bernard 20/09/03
#

using SmallModel

module CAC_Locomotive

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct TControl
  db::String

  Input::String = "TInput"
  
  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Year)) # [EC,Poll,Year] Scratch Variable For Input Reductions
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Areas,EC,Enduses,Years,Year) = data
  (; FuelEP) = data
  (; Poll,Tech) = data
  (; POCX,Reduce) = data

  @. Reduce = 1.0

  ecs = Select(EC,["Passenger","Freight"])
  years = collect(Last:Yr(2050)) # Need to read in Last to Reduce
  tech = Select(Tech,"TrainDiesel")
  
  ec = Select(EC,"Passenger")
  NOX = Select(Poll,"NOX")
  tmp = zeros(Float64,length(Years)) # Create temp variable with dim years
  tmp[Yr(2018):Yr(2050)] = [
  #  2018   2019   2020   2021   2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050
  1.00000 0.9867 0.9734 0.9601 0.9468 0.9335 0.9202 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070 0.9070
  ]
  Reduce[ec,NOX,years] = tmp[years]
  
  PM = Select(Poll,"PM10")
  tmp = zeros(Float64,length(Years)) # Reset temp variable with dim years
  tmp[Yr(2018):Yr(2050)] = [
  #  2018   2019   2020   2021   2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048    2049   2050
  1.00000 0.9867 0.9772 0.9658 0.9544 0.9430 0.9316 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200 0.9200  0.9200 0.9200
  ]
  Reduce[ec,PM,years] = tmp[years]
  
  CO = Select(Poll,"COX")
  tmp = zeros(Float64,length(Years)) # Reset temp variable with dim years
  tmp[Yr(2018):Yr(2050)] = [
  #  2018   2019   2020   2021   2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050 
  1.00000 0.9867 0.9538 0.9307 0.9076 0.8845 0.8614 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380 0.8380
  ]
  Reduce[ec,CO,years] = tmp[years]
  
  VOC = Select(Poll,"VOC")
  tmp = zeros(Float64,length(Years)) # Reset temp variable with dim years
  tmp[Yr(2018):Yr(2050)] = [
  #  2018   2019   2020   2021   2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040   2041   2042   2043   2044   2045   2046   2047   2048   2049   2050
  1.00000 0.9867 0.9164 0.8746 0.8328 0.7910 0.7492 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072 0.7072
  ]    
  Reduce[ec,VOC,years] = tmp[years]
  Reduce[ec,VOC,Yr(2023):Yr(2025)] = tmp[Yr(2022):Yr(2024)] # TODO Promula This appears to be misread into Promula

  polls = Select(Poll,["NOX","PM10","COX","VOC"])
  Diesel = Select(FuelEP,"Diesel")
  years = collect(Future:Final) # Only modifying Future to Final on database variable

  for year in years, area in Areas, poll in polls, ec in ecs, eu in Enduses
    POCX[eu,Diesel,tech,ec,poll,area,year] = min(POCX[eu,Diesel,tech,ec,poll,area,Last]*
      Reduce[ec,poll,year],POCX[eu,Diesel,tech,ec,poll,area,year])
      # TODO Promula, the code wants a ratio here but the Last values aren't read in 
      # resulting in a divide by 1
      # Reduce[ec,poll,year]/Reduce[ec,poll,Last],POCX[eu,Diesel,tech,ec,poll,area,year])
  end

  polls = Select(Poll,["NOX","PM10"])
  years = collect(Future:Yr(2025)) # TODO Promula These are shifted over in the read

  for year in years, area in Areas, poll in polls, ec in ecs, eu in Enduses
    POCX[eu,Diesel,tech,ec,poll,area,year] = min(POCX[eu,Diesel,tech,ec,poll,area,Last]*
      # Reduce[ec,poll,year],POCX[eu,Diesel,tech,ec,poll,area,year])
      Reduce[ec,poll,year]/Reduce[ec,poll,Last],POCX[eu,Diesel,tech,ec,poll,area,year])
  end

  WriteDisk(db,"$Input/POCX",POCX) 
  # ec = Select(EC,"Passenger")
  # poll = Select(Poll,"VOC")
  # year = Select(Year,"2023")
  # # print("Reduce(2023): ")
  # # print(Reduce[ec,poll,year])
  # ec = Select(EC,"Passenger")
  # poll = Select(Poll,"VOC")
  # year = Last
  # print("\nReduce(Last): ")
  # print(Reduce[ec,poll,year])
end

function PolicyControl(db)
  @info "CAC_Locomotive.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
