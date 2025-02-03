#
# DAC_Exogenous_CA.jl - Direct Air Carbon Test Policy with Exogenous levels of DAC in California
#
# The ENERGY 2020 model and all associated software are
# the property of Systematic Solutions, Inc. and cannot
# be modified or distributed to others without expressed,
# written permission of Systematic Solutions, Inc.
# � 2016 Systematic Solutions, Inc.  All rights reserved.
#

using SmallModel

module DAC_Exogenous_CA

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct SControl
  db::String

  CalDB::String = "SCalDB"
  Input::String = "SInput"
  Outpt::String = "SOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  DACTech::SetArray = ReadDisk(db,"$Input/DACTechKey")
  DACTechDS::SetArray = ReadDisk(db,"$Input/DACTechDS")
  DACTechs::Vector{Int} = collect(Select(DACTech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DACMSM0::VariableArray{3} = ReadDisk(db,"SpInput/DACMSM0") # [DACTech,Area,Year] DAC Market Share Non-Price Factor (Tonnes/Tonnes)
  DACSw::VariableArray{2} = ReadDisk(db,"SpInput/DACSw") # [Area,Year] Switch to Determine DAC Target
  xDACDem::VariableArray{2} = ReadDisk(db,"SpInput/xDACDem") # [Area,Year] Exogenous Demand for DAC (Tonnes/Yr)

  # Scratch Variables
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Area,DACTech) = data
  (; Years) = data
  (; DACMSM0,DACSw,xDACDem) = data

  CA = Select(Area,"CA")
  years = collect(Yr(2030):Final)
  for year in years
    DACSw[CA,year] = 0
  end
  
  WriteDisk(db,"SpInput/DACSw",DACSw)

  xDACDem[CA,Yr(2030)] = 6.8*1e6
  xDACDem[CA,Yr(2035)] = 35.1*1e6
  years = collect(Yr(2045):Final)
  for year in years
    xDACDem[CA,year] = 80.0*1e6
  end
  
  years = collect(Yr(2031):Yr(2034))
  for year in years
    xDACDem[CA,year] = xDACDem[CA,year-1]+(xDACDem[CA,Yr(2035)]-
      xDACDem[CA,Yr(2030)])/(2035-2030)
  end
  
  years = collect(Yr(2036):Yr(2044))
  for year in years
    xDACDem[CA,year] = xDACDem[CA,year-1]+(xDACDem[CA,Yr(2045)]-
      xDACDem[CA,Yr(2035)])/(2045-2035)
  end

  WriteDisk(db,"SpInput/xDACDem",xDACDem)

  #
  ########################
  #
  # DAC Market Share Non-Price Factor (mmBtu/mmBtu)
  # Placeholder data needs to be replaced - Jeff Amlin 10/22/19
  #
  # Hydrogen only in California
  #
  dactechs = Select(DACTech,["LiquidNG","SolidNG"])
  for year in Years, dactech in dactechs
    DACMSM0[dactech,CA,year] = -10.0
  end

  dactechs = Select(DACTech,["LiquidH2","SolidH2"])
  for year in Years, dactech in dactechs
    DACMSM0[dactech,CA,year] =   0.0
  end

  WriteDisk(db,"SpInput/DACMSM0",DACMSM0)
end

function PolicyControl(db)
  @info ("DAC_Exogenous_CA.jl - PolicyControl")
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end 

end
