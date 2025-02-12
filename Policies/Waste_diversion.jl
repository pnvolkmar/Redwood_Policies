#
# Waste_diversion.jl
# Diversion values from the "Policy Summary" tab of the "Waste Diversion Notes" excel, and the List of Ref24 Policies SharePoint list. This version was last updated in Aug. 2024. 
# Diversion targets are provincial averages based on bulk waste quantities or organic waste diversion targets
# Diversion rate values are a linear relationship between last historical year's diversion value and a provinces announced diversion target.
#
########################
#  MODEL VARIABLE    VDATA VARIABLE
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
  YT = Select(Area,"YT")
  
  years = collect(Yr(2023):Yr(2050))
  
  #
  # assign standard diversion rates to all non-wood waste
  #  
  AshDry = Select(Waste,"AshDry")
  #                                 2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050
  DiversionRate[AshDry,ON,years] = [0.28 0.31 0.34 0.38 0.41 0.44 0.47 0.50 0.52 0.53 0.55 0.56 0.58 0.59 0.61 0.62 0.64 0.65 0.67 0.68 0.70 0.71 0.73 0.74 0.76 0.77 0.79 0.80]
  DiversionRate[AshDry,NL,years] = [0.24 0.37 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50]
  DiversionRate[AshDry,YT,years] = [0.29 0.34 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40]

  waste1 = Select(Waste,!=("WoodWastePulpPaper"))
  waste2 = Select(Waste,!=("WoodWasteSolidWood"))
  wastes = intersect(waste1,waste2)
  
  areas = Select(Area,["ON","NL","YT"])
  for year in years, area in areas, waste in wastes
  ProportionDivertedWaste[waste,area,year] = DiversionRate[AshDry,area,year]
  end

  #
  # Assign Organic diversion rates
  #
  areas = Select(Area,["BC","ON","QC","NL","MB","YT"])
  years = collect(Yr(2023):Yr(2050))  
  #
  # Food Dry
  # 
  FoodDry = Select(Waste,"FoodDry")
  #                                  2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050
  DiversionRate[FoodDry,BC,years] = [0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[FoodDry,ON,years] = [0.37 0.48 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[FoodDry,QC,years] = [0.36 0.41 0.46 0.51 0.55 0.60 0.65 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70]
  DiversionRate[FoodDry,NL,years] = [0.24 0.37 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50]
  DiversionRate[FoodDry,MB,years] = [0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64]
  DiversionRate[FoodDry,YT,years] = [0.29 0.34 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40]

  #
  # Food Wet
  #  
  FoodWet = Select(Waste,"FoodWet")
  #                                  2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050
  DiversionRate[FoodWet,BC,years] = [0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[FoodWet,ON,years] = [0.37 0.48 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[FoodWet,QC,years] = [0.36 0.41 0.46 0.51 0.55 0.60 0.65 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70]
  DiversionRate[FoodWet,NL,years] = [0.24 0.37 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50]
  DiversionRate[FoodWet,MB,years] = [0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64]
  DiversionRate[FoodWet,YT,years] = [0.29 0.34 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40]

  #
  # Yard And Garden Dry
  #  
  YardGardenDry = Select(Waste,"YardAndGardenDry")
  #                                        2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050
  DiversionRate[YardGardenDry,BC,years] = [0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[YardGardenDry,ON,years] = [0.37 0.48 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[YardGardenDry,QC,years] = [0.36 0.41 0.46 0.51 0.55 0.60 0.65 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70]
  DiversionRate[YardGardenDry,NL,years] = [0.24 0.27 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50]
  DiversionRate[YardGardenDry,MB,years] = [0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64]
  DiversionRate[YardGardenDry,YT,years] = [0.29 0.34 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40]

  #
  # Yard And Garden Wet
  # 
  YardGardenWet = Select(Waste,"YardAndGardenWet")
  #                                        2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040 2041 2042 2043 2044 2045 2046 2047 2048 2049 2050
  DiversionRate[YardGardenWet,BC,years] = [0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76 0.76]
  DiversionRate[YardGardenWet,ON,years] = [0.37 0.48 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60 0.60]
  DiversionRate[YardGardenWet,QC,years] = [0.36 0.41 0.46 0.51 0.55 0.60 0.65 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70 0.70]
  DiversionRate[YardGardenWet,NL,years] = [0.24 0.27 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50]
  DiversionRate[YardGardenWet,MB,years] = [0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64 0.64]
  DiversionRate[YardGardenWet,YT,years] = [0.29 0.34 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40 0.40]

  wastes = Select(Waste,["FoodDry","FoodWet","YardAndGardenDry","YardAndGardenWet"])
  areas = Select(Area,["BC","ON","QC","NL","MB","YT"])
  for waste in wastes, area in areas, year in years
    ProportionDivertedWaste[waste,area,year] = DiversionRate[waste,area,year]  
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
