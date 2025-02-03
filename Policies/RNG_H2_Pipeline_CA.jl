#
# RNG_H2_Pipeline_CA.jl - In 2030s RNG blended in pipeline
# Renewable Hydrogen blended in natural gas pipeline at 7% energy
# (~20% by volume), ramping up between 2030 and 2040. In 2030s,
# dedicated hydrogen pipelines constructed to serve certain industrial clusters
#

using SmallModel

module RNG_H2_Pipeline_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct RControl
  db::String

  CalDB::String = "RCalDB"
  Input::String = "RInput"
  Outpt::String = "ROutput"
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
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)

  # Scratch Variables
end

function ResPolicy(db)
  data = RControl(; db)
  (; Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMax,DmFracMin) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Gas")
  RNG = Select(Fuel,"RNG")
  NaturalGas = Select(Fuel,"NaturalGas")
  Hydrogen = Select(Fuel,"Hydrogen")

  years = collect(Yr(2030):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.90)
  end

  years = collect(Yr(2040):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,Hydrogen,tech,ec,area,year] = 
      max(DmFracMin[enduse,Hydrogen,tech,ec,area,year],0.07)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.83)
  end

  #
  # Interpolate from 2030
  #  
  years = collect(Yr(2031):Yr(2039))
  for year in years,area in areas,ec in ECs,tech in techs,fuel in Hydrogen,enduse in Enduses
    DmFracMin[enduse,fuel,tech,ec,area,year] = DmFracMin[enduse,fuel,tech,ec,area,year-1]+
      (DmFracMin[enduse,fuel,tech,ec,area,Yr(2040)]-
        DmFracMin[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  for year in years,area in areas,ec in ECs,tech in techs,fuel in NaturalGas,enduse in Enduses
    DmFracMax[enduse,fuel,tech,ec,area,year] = DmFracMax[enduse,fuel,tech,ec,area,year-1]+
      (DmFracMax[enduse,fuel,tech,ec,area,Yr(2040)]-
        DmFracMax[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  WriteDisk(db,"$Input/DmFracMax",DmFracMax);
  WriteDisk(db,"$Input/DmFracMin",DmFracMin);
end

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
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
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)

  # Scratch Variables
end

function ComPolicy(db)
  data = CControl(; db)

  (; Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMax,DmFracMin) = data
  (;) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Gas")
  RNG = Select(Fuel,"RNG")
  NaturalGas = Select(Fuel,"NaturalGas")
  Hydrogen = Select(Fuel,"Hydrogen")

  years = collect(Yr(2030):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.90)
  end

  years = collect(Yr(2040):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,Hydrogen,tech,ec,area,year] = 
      max(DmFracMin[enduse,Hydrogen,tech,ec,area,year],0.07)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.83)
  end

  #
  # Interpolate from 2030
  #
  years = collect(Yr(2031):Yr(2039))
  for year in years,area in areas,ec in ECs,tech in techs,fuel in Hydrogen,enduse in Enduses
    DmFracMin[enduse,fuel,tech,ec,area,year] = 
      DmFracMin[enduse,fuel,tech,ec,area,year-1]+
        (DmFracMin[enduse,fuel,tech,ec,area,Yr(2040)]-
          DmFracMin[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  for year in years,area in areas,ec in ECs,tech in techs,fuel in NaturalGas,enduse in Enduses
    DmFracMax[enduse,fuel,tech,ec,area,year] = 
      DmFracMax[enduse,fuel,tech,ec,area,year-1]+
        (DmFracMax[enduse,fuel,tech,ec,area,Yr(2040)]-
          DmFracMax[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  WriteDisk(db,"$Input/DmFracMax",DmFracMax);
  WriteDisk(db,"$Input/DmFracMin",DmFracMin);
end

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
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
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  FsFracMax::VariableArray{5} = ReadDisk(db,"$Input/FsFracMax") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  FsFracMin::VariableArray{5} = ReadDisk(db,"$Input/FsFracMin") # [Fuel,Tech,EC,Area,Year] Feedstock Fuel/Tech Fraction Minimum (Btu/Btu)

  # Scratch Variables
end

function IndPolicy(db)
  data = IControl(; db)

  (; Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel) = data
  (; Tech) = data
  (; DmFracMax,DmFracMin,FsFracMin,FsFracMax) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Gas")
  RNG = Select(Fuel,"RNG")
  NaturalGas = Select(Fuel,"NaturalGas")
  Hydrogen = Select(Fuel,"Hydrogen")

  years = collect(Yr(2030):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,RNG,tech,ec,area,year] = 
      max(DmFracMin[enduse,RNG,tech,ec,area,year],0.10)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.90)
  end

  #
  # Add extra H2 to Industrial to simulate clusters
  # 
  years = collect(Yr(2040):Final)
  for year in years,area in areas,ec in ECs,tech in techs,enduse in Enduses
    DmFracMin[enduse,Hydrogen,tech,ec,area,year] = 
      max(DmFracMin[enduse,Hydrogen,tech,ec,area,year],0.07+0.20)
    DmFracMax[enduse,NaturalGas,tech,ec,area,year] = 
      min(DmFracMax[enduse,NaturalGas,tech,ec,area,year],0.63)
  end

  #
  # Interpolate from 2030
  #  
  years = collect(Yr(2031):Yr(2039))
  for year in years,area in areas,ec in ECs,tech in techs,fuel in Hydrogen,enduse in Enduses
    DmFracMin[enduse,fuel,tech,ec,area,year] = 
      DmFracMin[enduse,fuel,tech,ec,area,year-1]+
        (DmFracMin[enduse,fuel,tech,ec,area,Yr(2040)]-
          DmFracMin[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  for year in years,area in areas,ec in ECs,tech in techs,fuel in NaturalGas,enduse in Enduses
    DmFracMax[enduse,fuel,tech,ec,area,year] = 
      DmFracMax[enduse,fuel,tech,ec,area,year-1]+
        (DmFracMax[enduse,fuel,tech,ec,area,Yr(2040)]-
          DmFracMax[enduse,fuel,tech,ec,area,Yr(2030)])/(2040-2030)
  end

  fuels = Select(Fuel,["RNG","Hydrogen"])
  years = collect(Yr(2030):Final)
  for year in years,area in areas,ec in ECs,tech in techs,fuel in fuels
    FsFracMin[fuel,tech,ec,area,year] = DmFracMin[1,fuel,tech,ec,area,year]
  end

  for year in years,area in areas,ec in ECs,tech in techs,fuel in NaturalGas
    FsFracMax[fuel,tech,ec,area,year] = DmFracMax[1,fuel,tech,ec,area,year]
  end

  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$Input/DmFracMin",DmFracMin)
  WriteDisk(db,"$Input/FsFracMax",FsFracMax)
  WriteDisk(db,"$Input/FsFracMin",FsFracMin)
end

function PolicyControl(db)
  @info "RNG_H2_Pipeline_CA.jl - PolicyControl"
  ResPolicy(db)
  ComPolicy(db)
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
