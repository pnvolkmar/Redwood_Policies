#
# Trans_MS_Bus_Train.jl (from ZEV_Prov.jl)
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

module Trans_MS_Bus_Train

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
  BusTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Bus Market Share Total (Driver/Driver)
  EVBusShare::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Bus Market Share for Policy Vehicles (Driver/Driver)
  MSFTarget::VariableArray{3} = zeros(Float64,length(Tech),length(Area),length(Year)) # [Tech,Area,Year] Target Market Share for Policy Vehicles (Driver/Driver)
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB) = data
  (; Area,EC,Enduse,Enduses) = data 
  (; Tech) = data
  (; BusTotal,EVBusShare,MSFTarget,xMMSF) = data

  Passenger = Select(EC,"Passenger")
  enduse = Select(Enduse,"Carriage")

  #
  # Bus Electric - Data is share of Electric compared to Diesel - Ian 09/15/21
  #  
  areas = Select(Area,["BC","ON","QC"])
  BC = Select(Area,"BC")
  ON = Select(Area,"ON")
  QC = Select(Area,"QC")
  years = collect(Yr(2016):Yr(2050))

  #                        2016  2017  2018  2019  2020  2021  2022  2023  2024  2025  2026  2027  2028  2029  2030  2031  2032  2033  2034  2035  2036  2037  2038  2039  2040  2041  2042  2043  2044  2045  2046  2047  2048  2049  2050
  EVBusShare[BC,years] = [0.000 0.000 0.000 0.000 0.100 0.200 0.300 0.400 0.500 0.600 0.700 0.800 0.900 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999 0.999]
  EVBusShare[ON,years] = [0.000 0.000 0.000 0.000 0.050 0.050 0.100 0.150 0.200 0.250 0.300 0.350 0.400 0.450 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500]
  EVBusShare[QC,years] = [0.000 0.000 0.000 0.000 0.050 0.050 0.100 0.150 0.200 0.250 0.300 0.350 0.400 0.450 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500 0.500]

  techs = Select(Tech,["BusDiesel","BusElectric"])
  BusDiesel = Select(Tech,"BusDiesel")
  BusElectric = Select(Tech,"BusElectric")

  for area in areas, year in years
    BusTotal[area,year] = sum(xMMSF[enduse,tech,Passenger,area,year] for enduse in Enduses,
      tech in techs)
  end

  for area in areas, year in years
  
    MSFTarget[BusElectric,area,year] = max(BusTotal[area,year]*
      EVBusShare[area,year],xMMSF[enduse,BusElectric,Passenger,area,year])

    MSFTarget[BusDiesel,area,year] = min(BusTotal[area,year]*
      (1.0-EVBusShare[area,year]),xMMSF[enduse,BusDiesel,Passenger,area,year])
  end

  years = collect(Future:Yr(2050))
  for area in areas, year in years, tech in techs, enduse in Enduses
    xMMSF[enduse,tech,Passenger,area,year] = MSFTarget[tech,area,year]
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Trans_MS_Bus_Train - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
