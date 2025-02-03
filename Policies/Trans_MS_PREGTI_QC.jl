#
# Trans_MS_PREGTI_QC.jl (from QCPREGTI.jl)
#
# This file models Quebec's PREGTI program by increasing train and 
# marine marketshare at the expense of heavy trucks to meet emissions
# goal of 226 kt in 2030 (M. Charbonneau, 2017/06/16).
# Revised structure Jeff Amlin 07/20/21
#

using SmallModel

module Trans_MS_PREGTI_QC

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
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data    
  (; Area,EC,Enduses) = data 
  (; Tech) = data
  (; xMMSF) = data
  (;) = data

  QC = Select(Area,"QC");
  Freight = Select(EC,"Freight");
  years = collect(Future:Final)
  
  #
  # Improve train and marine market shares starting in the first year of the forecast
  #
  techs = Select(Tech,["TrainDiesel","MarineLight","MarineHeavy"])
  for enduse in Enduses, tech in techs, year in years
    xMMSF[enduse,tech,Freight,QC,year] = xMMSF[enduse,tech,Freight,QC,year]+(0.04/3.0)
  end

  #    
  # Remove market shares from HDV8
  #  
  HDV8Diesel = Select(Tech,"HDV8Diesel");
  for enduse in Enduses, year in years
    xMMSF[enduse,HDV8Diesel,Freight,QC,year] = 
      max(xMMSF[enduse,HDV8Diesel,Freight,QC,year]-0.04,0.00)
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF);    
end

function PolicyControl(db)
  @info "Trans_MS_PREGTI_QC.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
