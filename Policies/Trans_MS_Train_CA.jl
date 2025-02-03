#
# Trans_MS_Train_CA.jl - 100% of passenger and other locomotive 
# sales are ZEV by 2030. 100% of line haul locomotive sales are ZEV 
# by 2035. Line haul and passenger rail rely primarily on hydrogen 
# fuel cell technology, and others primarily utilize electricity
#

using SmallModel

module Trans_MS_Train_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB
# import ...SmallModel: .E2020Years

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
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  MSFPVBase::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Sum of Personal Vehicle Market Shares in Base
end

function TransPolicy(db)
  data = TControl(; db)
  (; Area,EC) = data 
  (; Tech) = data
  (; MSFPVBase,xMMSF) = data
  
  CA = Select(Area,"CA")
  ecs = Select(EC,["Passenger","Freight"])

  # 
  #  Assume 80/20 split between H2 and Electric - Ian
  # 
  #  Passenger
  #   
  techs = Select(Tech,(from="TrainDiesel",to="TrainFuelCell"))
  years = collect(Yr(2030):Final)
  TrainFuelCell = Select(Tech,"TrainFuelCell")
  TrainElectric = Select(Tech,"TrainElectric")
  for year in years, ec in ecs
    MSFPVBase[CA,year] = sum(xMMSF[1,tech,ec,CA,year] for tech in techs)
    xMMSF[1,TrainFuelCell,ec,CA,year] = MSFPVBase[CA,year] * 0.8
    xMMSF[1,TrainElectric,ec,CA,year] = MSFPVBase[CA,year] * 0.2
  end
  
  TrainDiesel = Select(Tech,"TrainDiesel")
  for year in years, ec in ecs
    xMMSF[1,TrainDiesel,ec,CA,year] = 0.0
  end
  
  #
  # Interpolate from 2021
  #  
  years = collect(Yr(2022):Yr(2029))
  for tech in techs, year in years, ec in ecs
    xMMSF[1,tech,ec,CA,year] = xMMSF[1,tech,ec,CA,year-1]+
      (xMMSF[1,tech,ec,CA,Yr(2030)]-xMMSF[1,tech,ec,CA,Yr(2021)])/
        (2030-2021)
  end

  #
  # Assume 80/20 split between H2 and Electric - Ian
  #
  # Freight
  #  
  Freight = Select(EC,"Freight")
  
  #
  # Interpolate from 2021
  # 
  years = collect(Yr(2022):Yr(2034))
  for tech in techs, year in years, ec in ecs
    xMMSF[1,tech,ec,CA,year] = xMMSF[1,tech,ec,CA,year-1]+
      (xMMSF[1,tech,ec,CA,Yr(2035)]-xMMSF[1,tech,ec,CA,Yr(2021)])/
        (2035-2021)
  end  
  
end

function PolicyControl(db)
  @info "Trans_MS_Train_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
