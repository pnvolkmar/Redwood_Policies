#
# Trans_MS_Biofuels_CA.jl -
#

using SmallModel

module Trans_MS_Biofuels_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
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
  Fuels::Vector{Int} = collect(Select(Fuel))
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
  DmFrac::VariableArray{6} = ReadDisk(db,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Split (Btu/Btu)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)

  # Scratch Variables
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,ECs) = data
  (; Fuel) = data
  (; Techs) = data
  (; DmFracMax,DmFracMin) = data

  CA = Select(Area,"CA")

  #
  # Trend DmFracMin and DmFracMax Ethanol and Biodiesel to be 30% by 2030 and to 100% by 2045.
  # Per Jeff 09/29/23 R.Levesque.
  #
  Ethanol = Select(Fuel,"Ethanol")
  for ec in ECs, tech in Techs, fuel in Ethanol
    DmFracMin[1,fuel,tech,ec,CA,Yr(2030)] = 0.30 *0.25
    DmFracMax[1,fuel,tech,ec,CA,Yr(2030)] = 0.30 *0.25
    DmFracMin[1,fuel,tech,ec,CA,Yr(2050)] = 1.00 *0.40
    DmFracMax[1,fuel,tech,ec,CA,Yr(2050)] = 1.00 *0.40
  end

  years = collect(Future:Yr(2029))
  for year in years, ec in ECs, tech in Techs, fuel in Ethanol
    DmFracMin[1,fuel,tech,ec,CA,year] = DmFracMin[1,fuel,tech,ec,CA,year-1]+
      (DmFracMin[1,fuel,tech,ec,CA,Yr(2030)]-
      DmFracMin[1,fuel,tech,ec,CA,Last])/(2030-HisTime)
    DmFracMax[1,fuel,tech,ec,CA,year] = DmFracMax[1,fuel,tech,ec,CA,year-1]+
      (DmFracMax[1,fuel,tech,ec,CA,Yr(2030)]-
      DmFracMax[1,fuel,tech,ec,CA,Last])/(2030-HisTime)
  end

  years = collect(Yr(2031):Yr(2049))
  for year in years, ec in ECs, tech in Techs, fuel in Ethanol
    DmFracMin[1,fuel,tech,ec,CA,year] = DmFracMin[1,fuel,tech,ec,CA,year-1]+
      (DmFracMin[1,fuel,tech,ec,CA,Yr(2050)]-
      DmFracMin[1,fuel,tech,ec,CA,Yr(2030)])/(2050-2030)
    DmFracMax[1,fuel,tech,ec,CA,year] = DmFracMax[1,fuel,tech,ec,CA,year-1]+
      (DmFracMax[1,fuel,tech,ec,CA,Yr(2050)]-
      DmFracMax[1,fuel,tech,ec,CA,Yr(2030)])/(2050-2030)
  end

  Biodiesel = Select(Fuel,"Biodiesel")
  for ec in ECs, tech in Techs, fuel in Biodiesel
    DmFracMin[1,fuel,tech,ec,CA,Yr(2030)] = 0.50 *0.25
    DmFracMax[1,fuel,tech,ec,CA,Yr(2030)] = 0.50 *0.25
    DmFracMin[1,fuel,tech,ec,CA,Yr(2050)] = 1.00 *0.40
    DmFracMax[1,fuel,tech,ec,CA,Yr(2050)] = 1.00 *0.40
  end

  years = collect(Future:Yr(2029))
  for year in years, ec in ECs, tech in Techs, fuel in Biodiesel
    DmFracMin[1,fuel,tech,ec,CA,year] = DmFracMin[1,fuel,tech,ec,CA,year-1]+
      (DmFracMin[1,fuel,tech,ec,CA,Yr(2030)]-
      DmFracMin[1,fuel,tech,ec,CA,Last])/(2030-HisTime)
    DmFracMax[1,fuel,tech,ec,CA,year] = DmFracMax[1,fuel,tech,ec,CA,year-1]+
      (DmFracMax[1,fuel,tech,ec,CA,Yr(2030)]-
      DmFracMax[1,fuel,tech,ec,CA,Last])/(2030-HisTime)
  end

  years = collect(Yr(2031):Yr(2049))
  for year in years, ec in ECs, tech in Techs, fuel in Biodiesel
    DmFracMin[1,fuel,tech,ec,CA,year] = DmFracMin[1,fuel,tech,ec,CA,year-1]+
      (DmFracMin[1,fuel,tech,ec,CA,Yr(2050)]-
      DmFracMin[1,fuel,tech,ec,CA,Yr(2030)])/(2050-2030)
    DmFracMax[1,fuel,tech,ec,CA,year] = DmFracMax[1,fuel,tech,ec,CA,year-1]+
      (DmFracMax[1,fuel,tech,ec,CA,Yr(2050)]-
      DmFracMax[1,fuel,tech,ec,CA,Yr(2030)])/(2050-2030)
  end

  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
end

function PolicyControl(db)
  @info "Trans_MS_Biofuels_CA.jl - PolicyControl"
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
