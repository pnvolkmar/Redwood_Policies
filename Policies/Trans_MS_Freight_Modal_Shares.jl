#
# Trans_MS_Freight_Modal_Shares.jl (from ZEV_Prov.jl)
#
# Targets for ZEV market shares in Transportation by Matt Lewis, July 7 2020
# Includes BC ZEV mandate and Federal Subsidy
# CleanGrowth BC plans sets a target of 94% of buses electric by 2030
# Use BASE market shares and allocate from 2018 to 2030 linearly
# Adjust other transit in provinces to directionally match transit study
# Revised structure Jeff Amlin 07/20/21
#
# Updated BC targets to 100% by 2029
# Brock Batey Oct 18 2023
#

using SmallModel

module Trans_MS_Freight_Modal_Shares

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

  AMSF::VariableArray{5} = ReadDisk(db,"$Outpt/AMSF") # [Enduse,Tech,EC,Area,Year] Average Market Share
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  MSFTarget::VariableArray{2} = zeros(Float64,length(Tech),length(Area)) # [Tech,Area] Target Market Share for Policy Vehicles (Driver/Driver)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC,Enduse,Tech,Techs) = data 
  (; AMSF,MSFTarget,xMMSF) = data

  areas = Select(Area,["AB","MB","QC","NS","PE","NL","YT","NU"])
  ec = Select(EC,"Freight")
  enduse = Select(Enduse,"Carriage")

  #
  # Target 2010 AMSF value
  #  
  year = Yr(2010)
  for tech in Techs, area in areas
    MSFTarget[tech,area] = AMSF[enduse,tech,ec,area,year]
  end

  tech = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = max(MSFTarget[tech,area]-0.1,0.0)
  end
  tech = Select(Tech,"HDV8Diesel")
  TrainDiesel = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = MSFTarget[tech,area]+(AMSF[enduse,TrainDiesel,ec,area,year]-
                           MSFTarget[TrainDiesel,area])
  end

  years = collect(Future:Yr(2050))
  for tech in Techs, area in areas, year in years
    xMMSF[enduse,tech,ec,area,year] = MSFTarget[tech,area]
  end

  #
  # Target 2016 AMSF value
  #  
  areas = Select(Area,["BC","SK","ON"])
  year = Yr(2016)
  for tech in Techs, area in areas
    MSFTarget[tech,area] = AMSF[enduse,tech,ec,area,year]
  end

  tech = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = max(MSFTarget[tech,area]-0.1,0.0)
  end
  tech = Select(Tech,"HDV8Diesel")
  TrainDiesel = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = MSFTarget[tech,area]+(AMSF[enduse,TrainDiesel,ec,area,year]-
                           MSFTarget[TrainDiesel,area])
  end

  years = collect(Future:Yr(2050))
  for tech in Techs, area in areas, year in years
    xMMSF[enduse,tech,ec,area,year] = MSFTarget[tech,area]
  end

  #
  # Target 2015 AMSF value
  #  
  areas = Select(Area,"NB")
  year = Yr(2015)
  for tech in Techs, area in areas
    MSFTarget[tech,area] = AMSF[enduse,tech,ec,area,year]
  end

  tech = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = max(MSFTarget[tech,area]-0.1,0.0)
  end
  tech = Select(Tech,"HDV8Diesel")
  TrainDiesel = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = MSFTarget[tech,area]+(AMSF[enduse,TrainDiesel,ec,area,year]-
                           MSFTarget[TrainDiesel,area])
  end

  years = collect(Future:Yr(2050))
  for tech in Techs, area in areas, year in years
    xMMSF[enduse,tech,ec,area,year] = MSFTarget[tech,area]
  end

  #
  # Target 2018 AMSF value
  #  
  areas = Select(Area,"NT")
  year = Yr(2018)
  for tech in Techs, area in areas
    MSFTarget[tech,area] = AMSF[enduse,tech,ec,area,year]
  end

  tech = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = max(MSFTarget[tech,area]-0.1,0.0)
  end
  tech = Select(Tech,"HDV8Diesel")
  TrainDiesel = Select(Tech,"TrainDiesel")
  for area in areas
    MSFTarget[tech,area] = MSFTarget[tech,area]+(AMSF[enduse,TrainDiesel,ec,area,year]-
                           MSFTarget[TrainDiesel,area])
  end

  years = collect(Future:Yr(2050))
  for tech in Techs, area in areas, year in years
    xMMSF[enduse,tech,ec,area,year] = MSFTarget[tech,area]
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Trans_MS_Freight_Modal_Shares - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
