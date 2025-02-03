#
# Waste_diversion.jl
#
# Diversion values from the "Policies" tab of the "rates_2021" excel,and the 2021 Waste 
# Sector Policies word document. This version was last updated in Jan 2022.
# Diversion targets are provincial averages based on bulk waste quantities or 
# organic waste diversion targets
# Diversion rate values are a linear relationship between last historical year's diversion 
# value and a provinces announced diversion target.
#
########################
#  MODEL VARIABLE            VDATA VARIABLE
#  ProportionDivertedWaste = vDiversionRate
########################
#

using SmallModel

module Waste_diversion

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct MControl
  db::String

  CalDB::String = "MCalDB"
  Input::String = "MInput"
  Outpt::String = "MOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  Waste::SetArray = ReadDisk(db,"E2020DB/WasteKey")
  WasteDS::SetArray = ReadDisk(db,"E2020DB/WasteDS")
  Wastes::Vector{Int} = collect(Select(Waste))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ProportionDivertedWaste::VariableArray{3} = ReadDisk(db,"MInput/ProportionDivertedWaste") # [Waste,Area,Year] Proportion of Diverted Waste <PDvW> (Tonnes/Tonnes)
  DiversionRate::VariableArray{3} = zeros(Float64,length(Waste),length(Area),length(Year)) # [Waste,Area,Year] proportion of diverted waste (tonnes/tonnes)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,Waste) = data
  (; DiversionRate,ProportionDivertedWaste) = data 
  
  BC = Select(Area,"BC")
  AB = Select(Area,"AB")
  SK = Select(Area,"SK")
  MB = Select(Area,"MB")
  ON = Select(Area,"ON")
  QC = Select(Area,"QC")
  NB = Select(Area,"NB") 
  NS = Select(Area,"NS")
  NL = Select(Area,"NL")
  
  years = collect(Yr(2021):Yr(2030))
  
  #
  # assign standard diversion rates to all non-wood waste
  #  
  AshDry = Select(Waste,"AshDry")
  #                                 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030
  DiversionRate[AshDry,BC,years] = [0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40] 
  DiversionRate[AshDry,AB,years] = [0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18]
  DiversionRate[AshDry,SK,years] = [0.21 0.23 0.25 0.26 0.28 0.29 0.31 0.32 0.34 0.35]
  DiversionRate[AshDry,MB,years] = [0.21 0.21 0.21 0.21 0.21 0.21 0.21 0.21 0.21 0.21]
  DiversionRate[AshDry,ON,years] = [0.28 0.29 0.31 0.33 0.34 0.37 0.40 0.44 0.47 0.50]
  DiversionRate[AshDry,QC,years] = [0.31 0.38 0.44 0.44 0.44 0.44 0.44 0.44 0.44 0.44]
  DiversionRate[AshDry,NB,years] = [0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24]
  DiversionRate[AshDry,NS,years] = [0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45]
  DiversionRate[AshDry,NL,years] = [0.23 0.30 0.37 0.43 0.50 0.50 0.50 0.50 0.50 0.50]  

  waste1 = Select(Waste,!=("WoodWastePulpPaper"))
  waste2 = Select(Waste,!=("WoodWasteSolidWood"))
  wastes = intersect(waste1,waste2)
  
  areas = Select(Area,["BC","AB","SK","MB","ON","QC","NB","NS","NL"])
  for waste in wastes, area in areas, year in years
    ProportionDivertedWaste[waste,area,year] = DiversionRate[AshDry,area,year]
  end

  #
  # Assign Organic diversion rates
  #
  
  #
  # Food Dry
  #   
  FoodDry = Select(Waste,"FoodDry")
  #                                  2021 2022 2023 2024 2025 2026 2027 2028 2029 2030
  DiversionRate[FoodDry,BC,years] = [0.64 0.68 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[FoodDry,AB,years] = [0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18]
  DiversionRate[FoodDry,SK,years] = [0.22 0.24 0.26 0.27 0.29 0.31 0.33 0.34 0.36 0.38]
  DiversionRate[FoodDry,MB,years] = [0.43 0.55 0.67 0.79 0.79 0.79 0.79 0.79 0.79 0.79]
  DiversionRate[FoodDry,ON,years] = [0.37 0.42 0.48 0.54 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[FoodDry,QC,years] = [0.40 0.43 0.47 0.50 0.53 0.57 0.60 0.63 0.67 0.70]
  DiversionRate[FoodDry,NB,years] = [0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24]
  DiversionRate[FoodDry,NS,years] = [0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45]
  DiversionRate[FoodDry,NL,years] = [0.23 0.30 0.37 0.43 0.50 0.50 0.50 0.50 0.50 0.50]

  #
  # Food Wet
  #  
  FoodWet = Select(Waste,"FoodWet")
  #                                  2021 2022 2023 2024 2025 2026 2027 2028 2029 2030    
  DiversionRate[FoodWet,BC,years] = [0.64 0.68 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[FoodWet,AB,years] = [0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18]
  DiversionRate[FoodWet,SK,years] = [0.22 0.24 0.26 0.27 0.29 0.31 0.33 0.34 0.36 0.38]
  DiversionRate[FoodWet,MB,years] = [0.43 0.55 0.67 0.79 0.79 0.79 0.79 0.79 0.79 0.79]
  DiversionRate[FoodWet,ON,years] = [0.37 0.42 0.48 0.54 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[FoodWet,QC,years] = [0.40 0.43 0.47 0.50 0.53 0.57 0.60 0.63 0.67 0.70]
  DiversionRate[FoodWet,NB,years] = [0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24]
  DiversionRate[FoodWet,NS,years] = [0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45]
  DiversionRate[FoodWet,NL,years] = [0.23 0.30 0.37 0.43 0.50 0.50 0.50 0.50 0.50 0.50]

  #
  # Yard And Garden Dry
  #  
  waste = Select(Waste,"YardAndGardenDry")
  DiversionRate[waste,BC,years] = [0.64 0.68 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[waste,AB,years] = [0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18]
  DiversionRate[waste,SK,years] = [0.22 0.24 0.26 0.27 0.29 0.31 0.33 0.34 0.36 0.38]
  DiversionRate[waste,MB,years] = [0.43 0.55 0.67 0.79 0.79 0.79 0.79 0.79 0.79 0.79]
  DiversionRate[waste,ON,years] = [0.37 0.42 0.48 0.54 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[waste,QC,years] = [0.40 0.43 0.47 0.50 0.53 0.57 0.60 0.63 0.67 0.70]
  DiversionRate[waste,NB,years] = [0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24]
  DiversionRate[waste,NS,years] = [0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45]
  DiversionRate[waste,NL,years] = [0.23 0.30 0.37 0.43 0.50 0.50 0.50 0.50 0.50 0.50]

  #
  # Yard And Garden Wet
  # 
  waste = Select(Waste,"YardAndGardenWet")
  DiversionRate[waste,BC,years] = [0.64 0.68 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[waste,AB,years] = [0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18 0.18]
  DiversionRate[waste,SK,years] = [0.22 0.24 0.26 0.27 0.29 0.31 0.33 0.34 0.36 0.38]
  DiversionRate[waste,MB,years] = [0.43 0.55 0.67 0.79 0.79 0.79 0.79 0.79 0.79 0.79]
  DiversionRate[waste,ON,years] = [0.37 0.42 0.48 0.54 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[waste,QC,years] = [0.40 0.43 0.47 0.50 0.53 0.57 0.60 0.63 0.67 0.70]
  DiversionRate[waste,NB,years] = [0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24 0.24]
  DiversionRate[waste,NS,years] = [0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45 0.45]
  DiversionRate[waste,NL,years] = [0.23 0.30 0.37 0.43 0.50 0.50 0.50 0.50 0.50 0.50]

  wastes = Select(Waste,["FoodDry","FoodWet","YardAndGardenDry","YardAndGardenWet"])
  areas = Select(Area,["BC","AB","SK","MB","ON","QC","NB","NS","NL"])
  for waste in wastes, area in areas, year in years
    ProportionDivertedWaste[waste,area,year] = DiversionRate[waste,area,year]      
  end

  #
  # Assume post-2030 diversion is constant
  #  
  waste1 = Select(Waste,!=("WoodWastePulpPaper"))
  waste2 = Select(Waste,!=("WoodWasteSolidWood"))
  wastes = intersect(waste1,waste2)     
  areas = Select(Area,["BC","AB","SK","MB","ON","QC","NB","NS","NL"])
  years = collect(Yr(2031):Final)
  for waste in wastes, area in areas, year in years
    ProportionDivertedWaste[waste,area,year] = ProportionDivertedWaste[waste,area,Yr(2030)]
  end

  WriteDisk(db,"MInput/ProportionDivertedWaste",ProportionDivertedWaste)
end

function PolicyControl(db)
  @info "Waste_diversion.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
