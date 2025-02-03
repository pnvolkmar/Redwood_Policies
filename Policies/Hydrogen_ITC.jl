#
# Hydrogen_ITC_PTs.jl - Designed to model the clean hydrogen investment tax credit
# by acting as a subidy on hydrogen production. 
#
# Capital costs are decreased by appropriate amounts based
# on the carbon intensity standards set out in the
# clean hydrogen investment tax Hydrogen_Tax_Credit_Cap
# Analysis is based on the Excel workbook Carbon Intensity Hydrogen.xlsx
# the approach in the jl is to use a multiplier to decrease capital costs
# by the appropriate amount
#

using SmallModel

module Hydrogen_ITC

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  H2Tech::SetArray = ReadDisk(db,"$Input/H2TechKey")
  H2TechDS::SetArray = ReadDisk(db,"$Input/H2TechDS")
  H2Techs::Vector{Int} = collect(Select(H2Tech))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  H2CCN::VariableArray{3} = ReadDisk(db,"SpInput/H2CCN") # [H2Tech,Area,Year] Hydrogen Production Capital Cost (Real $/mmBtu)

  # Scratch Variables
  CapMult::VariableArray{1} = zeros(Float64,length(H2Tech))
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Area,Areas,H2Tech,H2Techs) = data
  (; Nation,Years) = data
  (; ANMap,CapMult,H2CCN) = data

  #
  # The full rate is applied to wind technology until 2031.
  # Calculations are based on Pembina LCA of hydrogen from wind.
  #  
  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  OnshoreWind = Select(H2Tech,"OnshoreWind")
  CapMult[OnshoreWind] = 0.60
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[OnshoreWind,area,year] = CapMult[OnshoreWind] * H2CCN[OnshoreWind,area,year]
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen
  # projects, see H2.txt, half the previous ITC rate is applied to
  # equipment that would come online in 2034. ITC has a phase-out clause.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[OnshoreWind] = 0.80
  for area in areas
    H2CCN[OnshoreWind,area,Yr(2032)] = CapMult[OnshoreWind] * 
      H2CCN[OnshoreWind,area,Yr(2032)]
  end 
  
  #
  # Second rate applies to solar and to interruptible.
  # Based on Pembina values as well.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.75
  end
  
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas, h2tech in h2techs
    H2CCN[h2tech,area,year] = CapMult[h2tech] * H2CCN[h2tech,area,year]
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.875
  end
  
  for area in areas, h2tech in h2techs
    H2CCN[h2tech,area,Yr(2032)] = CapMult[h2tech] * H2CCN[h2tech,area,Yr(2032)]
  end

  #
  # Second rate applies ATRNGCCS in Quebec, BC, and Manitoba.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["BC","MB","QC"])
  ATRNGCCS = Select(H2Tech,"ATRNGCCS")
  CapMult[ATRNGCCS] = 0.75
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[ATRNGCCS,area,year] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,year]
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[ATRNGCCS] = 0.875
  years = Select(Years,Yr(2032))
  for year in years, area in areas
    H2CCN[ATRNGCCS,area,year] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,year]
  end

  #
  # NGSMR with CCS qualifies for the second rate assuming best case scenario
  # in the preceding provinces.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["BC","SK","AB","MB","NB","NS","NL","PE"])
  NGCCS = Select(H2Tech,"NGCCS")
  CapMult[NGCCS] = 0.75
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[NGCCS,area,year] = CapMult[NGCCS] * H2CCN[NGCCS,area,year]
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[NGCCS] = 0.875
  for area in areas
    H2CCN[NGCCS,area,Yr(2032)] = CapMult[NGCCS] * H2CCN[NGCCS,area,Yr(2032)]
  end

  #
  # MB and QC grids qualify for the ITC at the second rate.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["MB","QC"])
  Grid = Select(H2Tech,"Grid")
  CapMult[Grid] = 0.75
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[Grid,area,year] = CapMult[Grid] * H2CCN[Grid,area,year]
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[Grid] = 0.875
  for area in areas
    H2CCN[Grid,area,Yr(2032)] = CapMult[Grid] * H2CCN[Grid,area,Yr(2032)]
  end

  #
  # Autothermal in the preceding provinces count towards the third rate
  # 
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["AB","SK","ON","NB","NL","NS","PE"])
  CapMult[ATRNGCCS] = 0.85
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[ATRNGCCS,area,year] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,year]
  end
  
  #
  # credit is available at a reduced rate in 2032 due to the phase out
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["AB","SK","ON","NB","NL","NS","PE"])
  CapMult[ATRNGCCS] = 0.925
  for area in areas
    H2CCN[ATRNGCCS,area,Yr(2032)] = CapMult[ATRNGCCS] * 
      H2CCN[ATRNGCCS,area,Yr(2032)]
  end
  
  #
  # the third rate applies to NGSMR CCS in Ontario and Quebec
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["ON","QC"])
  CapMult[NGCCS] = 0.85
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[NGCCS,area,year] = CapMult[NGCCS] * H2CCN[NGCCS,area,year]
  end
  
  #
  #
  #
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[NGCCS] = 0.925
  for area in areas
    H2CCN[NGCCS,area,Yr(2032)] = CapMult[NGCCS] * H2CCN[NGCCS,area,Yr(2032)]
  end

  #
  # Use BC Grid value where appropriate from BC study. Apply the values to NL and NT as well.
  #  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  areas = Select(Area,["BC","NL","NT"])
  CapMult[Grid] = 0.85
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[Grid,area,year] = CapMult[Grid] * H2CCN[Grid,area,year]
  end

  #
  #
  #
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  CapMult[Grid] = 0.925
  for area in areas
    H2CCN[Grid,area,Yr(2032)] = CapMult[Grid] * H2CCN[Grid,area,Yr(2032)]
  end
  
  #
  WriteDisk(db,"SpInput/H2CCN",H2CCN)
end

function PolicyControl(db)
  @info "Hydrogen_ITC.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
