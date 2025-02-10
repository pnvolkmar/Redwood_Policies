#
# RenewableLiquidsMaximum_CA.jl
#

using SmallModel

module RenewableLiquidsMaximum_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Last,Future,Final,Yr
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
  DmFracMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/DmFracMSM0") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Non-Price Factor (Btu/Btu)
  xDmFracLast::VariableArray{5} = ReadDisk(db,"$Input/xDmFrac",Last) # [Enduse,Fuel,Tech,EC,Area,Last] Energy Demands Fuel/Tech Split (Fraction)

  # Scratch Variables
  # BiodieselMax  'Biodiesel Technology Maximum Fraction of Demand (Btu/Btu)'
  # BiojetMax     'Biojet Technology Maximum Fraction of Demand (Btu/Btu)'
  # EthanolMax    'Ethanol Technology Maximum Fraction of Demand (Btu/Btu)'
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel,Tech) = data
  (; Years) = data
  (; DmFracMax,DmFracMSM0,xDmFracLast) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Oil")

  BiodieselMax = 1.00
  EthanolMax = 1.00

  #
  #########################
  #
  fuels = Select(Fuel,"Biodiesel")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiodieselMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
       DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = DmFracMax[eu,fuel,tech,ec,area,year-1]+
        (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
          DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  #########################
  #
  fuels = Select(Fuel,"Ethanol")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = EthanolMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$CalDB/DmFracMSM0",DmFracMSM0)
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
  DmFracMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/DmFracMSM0") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Non-Price Factor (Btu/Btu)
  xDmFracLast::VariableArray{5} = ReadDisk(db,"$Input/xDmFrac",Last) # [Enduse,Fuel,Tech,EC,Area,Last] Energy Demands Fuel/Tech Split (Fraction)

  # Scratch Variables
  # BiodieselMax  'Biodiesel Technology Maximum Fraction of Demand (Btu/Btu)'
  # BiojetMax     'Biojet Technology Maximum Fraction of Demand (Btu/Btu)'
  # EthanolMax    'Ethanol Technology Maximum Fraction of Demand (Btu/Btu)'
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel,Tech) = data
  (; Years) = data
  (; DmFracMax,DmFracMSM0,xDmFracLast) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Oil")

  BiodieselMax = 1.00
  EthanolMax = 1.00

  #
  #########################
  #
  fuels = Select(Fuel,"Biodiesel")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiodieselMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  #########################
  #
  fuels = Select(Fuel,"Ethanol")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = EthanolMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$CalDB/DmFracMSM0",DmFracMSM0)
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
  DmFracMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/DmFracMSM0") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Non-Price Factor (Btu/Btu)
  xDmFracLast::VariableArray{5} = ReadDisk(db,"$Input/xDmFrac",Last) # [Enduse,Fuel,Tech,EC,Area,Last] Energy Demands Fuel/Tech Split (Fraction)

  # Scratch Variables
  # BiodieselMax  'Biodiesel Technology Maximum Fraction of Demand (Btu/Btu)'
  # BiojetMax     'Biojet Technology Maximum Fraction of Demand (Btu/Btu)'
  # EthanolMax    'Ethanol Technology Maximum Fraction of Demand (Btu/Btu)'
end

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduses) = data
  (; Fuel,Tech) = data
  (; Years) = data
  (; DmFracMax,DmFracMSM0,xDmFracLast) = data
  (;) = data

  areas = Select(Area,"CA")
  techs = Select(Tech,"Oil")

  areas = Select(Area,"CA")
  techs = Select(Tech,"Oil")

  BiodieselMax = 1.00
  EthanolMax = 1.00

  #
  #########################
  #
  fuels = Select(Fuel,"Biodiesel")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiodieselMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  #########################
  #
  fuels = Select(Fuel,"Ethanol")
  for area in areas, ec in ECs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = EthanolMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2030)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2020)])/(2030-2020)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$CalDB/DmFracMSM0",DmFracMSM0)
end

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
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/DmFracMSM0") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Non-Price Factor (Btu/Btu)
  xDmFracLast::VariableArray{5} = ReadDisk(db,"$Input/xDmFrac",Last) # [Enduse,Fuel,Tech,EC,Area,Last] Energy Demands Fuel/Tech Split (Fraction)

  # Scratch Variables
  # BiodieselMax  'Biodiesel Technology Maximum Fraction of Demand (Btu/Btu)'
  # BiojetMax     'Biojet Technology Maximum Fraction of Demand (Btu/Btu)'
  # EthanolMax    'Ethanol Technology Maximum Fraction of Demand (Btu/Btu)'
end

function TransPolicy(db)
  data = TControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,Enduses) = data
  (; Fuel,Tech) = data
  (; Years) = data
  (; DmFracMax,DmFracMSM0,xDmFracLast) = data
  (;) = data

  areas = Select(Area,"CA")
  BiodieselMax = 1.00
  EthanolMax = 1.00

  #
  #########################
  #
  fuels = Select(Fuel,"Biodiesel")
  ecs = Select(EC,"Passenger")
  techs = Select(Tech,["LDVDiesel","LDTDiesel","BusDiesel","TrainDiesel"])
  for area in areas, ec in ecs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiodieselMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2035)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2028)])/(2035-2028)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end

  fuels = Select(Fuel,"Biodiesel")
  ecs = Select(EC,"Freight")
  techs = Select(Tech,["TrainDiesel","HDV2B3Diesel","HDV45Diesel","HDV67Diesel",
                       "HDV8Diesel","MarineLight","MarineHeavy"])
  for area in areas, ec in ecs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiodieselMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2035)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2028)])/(2035-2028)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end

  #
  #########################
  #
  fuels = Select(Fuel,"Ethanol")
  ecs = Select(EC,"Passenger")
  techs = Select(Tech,["LDVHybrid","LDTHybrid","LDVGasoline","LDTGasoline","Motorcycle","BusGasoline"])
  for area in areas, ec in ecs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = EthanolMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2035)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2028)])/(2035-2028)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end

  fuels = Select(Fuel,"Ethanol")
  ecs = Select(EC,"Freight")
  techs = Select(Tech,["HDV2B3Gasoline","HDV45Gasoline","HDV67Gasoline","HDV8Gasoline"])
  for area in areas, ec in ecs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = EthanolMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2035)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2028)])/(2035-2028)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end

  #
  #########################
  #
  fuels = Select(Fuel,"Biojet")
  ecs = Select(EC,["AirPassenger","AirFreight"])
  techs = Select(Tech,"PlaneJetFuel")
  BiojetMax = 0.90
  for area in areas, ec in ecs, tech in techs, fuel in fuels, eu in Enduses
    DmFracMax[eu,fuel,tech,ec,area,Yr(2020)] = 
      xDmFracLast[eu,fuel,tech,ec,area]*1.02
    DmFracMax[eu,fuel,tech,ec,area,Yr(2035)] = BiojetMax
    years = collect(Yr(2021):Yr(2028))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]*1.02
    end
    
    years = collect(Yr(2029):Yr(2035))
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]+
          (DmFracMax[eu,fuel,tech,ec,area,Yr(2035)]-
            DmFracMax[eu,fuel,tech,ec,area,Yr(2028)])/(2035-2028)
    end
    
    years = collect(Yr(2036):Final)
    for year in years
      DmFracMax[eu,fuel,tech,ec,area,year] = 
        DmFracMax[eu,fuel,tech,ec,area,year-1]
    end
    
    for year in Years
      DmFracMSM0[eu,fuel,tech,ec,area,year] = 0.0
    end
    
  end
  
  #
  WriteDisk(db,"$Input/DmFracMax",DmFracMax)
  WriteDisk(db,"$CalDB/DmFracMSM0",DmFracMSM0)
end

function PolicyControl(db)
    @info "RenewableLiquidsMaximum_CA.jl - PolicyControl"
  ResPolicy(db)
  ComPolicy(db)
  IndPolicy(db)
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
