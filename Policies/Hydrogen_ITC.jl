#
# Hydrogen_ITC_PTs.jl - Designed to model the clean hydrogen investment tax credit
# by acting as a subidy on hydrogen production. 
#
# Capital costs are decreased by appropriate amounts based on the
# carbon intensity standards set out in the clean hydrogen investment
# tax Hydrogen_Tax_Credit_Cap.
# Analysis is based on the Excel workbook Carbon Intensity Hydrogen.xlsx
# the approach in the policy file is to use a multiplier to decrease capital costs
# by the appropriate amount.
#
# The txp separates Newfoundland out from the rest of the provinces in order to capture the Green Technology Investment Tax credit that NL
# introduced. To capture the full impact of both ITCs on hydrogen in NL, the txp applies the combined discounted costs from two ITCs
#
# This version of the txp includes the Green Technology Tax Credit applied in Newfoundland. This is why all of the
# rates applied to different tech are different in NL.
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

  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  years = collect(Yr(2024):Yr(2031))
  areas = Select(Area,["ON","QC","BC","AB","MB","SK","NB","NS","PE","YT","NT","NU"])  

  #
  # The full rate is applied to wind technology until 2031.
  # Calculations are based on Pembina LCA of hydrogen from wind.
  #  
  OnshoreWind = Select(H2Tech,"OnshoreWind")
  CapMult[OnshoreWind] = 0.60
  #
  for year in years, area in areas
    H2CCN[OnshoreWind,area,year] = CapMult[OnshoreWind] * H2CCN[OnshoreWind,area,year]
  end

  areas = Select(Area,["ON","QC","BC","AB","MB","SK","NB","NS","PE","YT","NT","NU"])  

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt, half the previous ITC rate is applied to equipment that would come online in 2034
  # half the previous ITC rate is applied to equipment that would come online in 2034. 
  # ITC has a phase-out clause
  #
  OnshoreWind = Select(H2Tech,"OnshoreWind")
  CapMult[OnshoreWind] = 0.8

  for area in areas
    H2CCN[OnshoreWind,area,Yr(2032)] = CapMult[OnshoreWind] * H2CCN[OnshoreWind,area,Yr(2032)]
  end

  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  years = collect(Yr(2024):Yr(2031))
  NL = Select(Area,"NL")
  #
  # The full rate is applied to wind technology until 2031. Calculations are based on Pembina LCA of hydrogen from wind.
  #
  CapMult[OnshoreWind] = 0.40

  #
  ########################
  #
  for year in years
    H2CCN[OnshoreWind,NL,year] = CapMult[OnshoreWind] * H2CCN[OnshoreWind,NL,year]
  end
  #
  ########################
  #
  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt, half the previous ITC rate is applied to equipment that would come online in 2034
  # ITC has a phase-out clause
  #
  CapMult[OnshoreWind] = 0.60
  #
  ########################
  #
  NL = Select(Area,"NL")
  H2CCN[OnshoreWind,NL,Yr(2032)] = H2CCN[OnshoreWind,NL,Yr(2032)]*CapMult[OnshoreWind] 

  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end

  years = collect(Yr(2024):Yr(2031))
  areas = Select(Area,["ON","QC","BC","AB","MB","SK","NB","NS","PE","YT","NT","NU"])

  #
  # Second rate applies to solar and to interruptible. Based on Pembina values as well.
  #
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.75
  end
  for year in years, area in areas, h2tech in h2techs
    H2CCN[h2tech,area,year] = H2CCN[h2tech,area,year]*CapMult[h2tech] 
  end

  CN = Select(Nation,"CN")
  areas = Select(ANMap[Areas,CN],==(1))
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  areas = Select(Area,["ON","QC","BC","AB","MB","SK","NB","NS","PE","YT","NT","NU"])

  #
  # Due to the construction delay of 2 years associated with hydrogen
  # projects, see H2.txt, half the previous ITC rate is applied to
  # equipment that would come online in 2034. ITC has a phase-out clause.
  #  
  
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.875
  end
  for area in areas, h2tech in h2techs
    H2CCN[h2tech,area,Yr(2032)] = H2CCN[h2tech,area,Yr(2032)]*CapMult[h2tech]
  end 
  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  years = collect(Yr(2024):Yr(2031))
  areas = Select(Area,"NL")

  #
  # Second rate applies to solar and to interruptible. Based on Pembina values as well.
  #  
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.55
  end
  
  for year in years, area in areas, h2tech in h2techs
    H2CCN[h2tech,area,year] = CapMult[h2tech] * H2CCN[h2tech,area,year]
  end
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end

  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  areas = Select(Area,"NL")
  h2techs = Select(H2Tech,["SolarPV","Interruptible"])
  for h2tech in h2techs
    CapMult[h2tech] = 0.675
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
  years = collect(Yr(2024):Yr(2031))
  h2techs = Select(H2Tech,"ATRNGCCS")
  for h2tech in h2techs
    CapMult[h2tech] = 0.75
  end
  for year in years, area in areas, h2tech in h2techs
    H2CCN[h2tech,area,year] = CapMult[h2tech] * H2CCN[h2tech,area,year]
  end
  
  areas = Select(Area,["BC","MB","QC"])
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  ATRNGCCS = Select(H2Tech,"ATRNGCCS")
  CapMult[ATRNGCCS] = 0.875
  for area in areas
    H2CCN[ATRNGCCS,area,Yr(2032)] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,Yr(2032)]
  end

  #
  #
  #
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  areas = Select(Area,["BC","SK","AB","MB","NB","NS","PE"])
  years = collect(Yr(2024):Yr(2031))
  #
  # NGSMR with CCS qualifies for the second rate assuming best case scenario
  # in the preceding provinces.
  #
  NGCCS = Select(H2Tech,"NGCCS")
  CapMult[NGCCS] = 0.75
  for year in years, area in areas
    H2CCN[NGCCS,area,year] = CapMult[NGCCS] * H2CCN[NGCCS,area,year]
  end

  #
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  # NGSMR with CCS qualifies for the second rate assuming best case scenario
  # in the preceding provinces.
  #  
  years = collect(Yr(2024):Yr(2031))
  areas = Select(Area,"NL")
  NGCCS = Select(H2Tech,"NGCCS")
  CapMult[NGCCS] = 0.55
  
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
  CapMult[NGCCS] = 0.675
  
  H2CCN[NGCCS,NL,Yr(2032)] = CapMult[NGCCS] * H2CCN[NGCCS,NL,Yr(2032)]

  #
  ######################
  #
  areas = Select(Area,["MB","QC"])
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  areas = Select(Area,["MB","QC"])
  years = collect(Yr(2024):Yr(2031))
  Grid = Select(H2Tech,"Grid")

  CapMult[Grid] = 0.75
  #
  # MB and QC grids qualify for the ITC at the second rate.
  #  
  for year in years, area in areas
    H2CCN[Grid,area,year] = CapMult[Grid]*H2CCN[Grid,area,year]
  end
  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  #
  # Due to the construction delay of 2 years associated with hydrogen projects, see H2.txt,
  # half the previous ITC rate is applied to equipment that would come online in 2034.
  #  
  Grid = Select(H2Tech,"Grid")
  CapMult[Grid] = 0.875
  for area in areas
    H2CCN[Grid,area,Yr(2032)] = CapMult[Grid] * H2CCN[Grid,area,Yr(2032)]
  end


  areas = Select(Area,["AB","SK","ON","NB","NS","PE"])
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end

  years = collect(Yr(2024):Yr(2031))
  #
  # autothermal in the preceding provinces count towards the third rate
  #
  ATRNGCCS = Select(H2Tech,"ATRNGCCS")
  CapMult[ATRNGCCS] = 0.85

  for year in years, area in areas
    H2CCN[ATRNGCCS,area,year] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,year]
  end

  #

  areas = Select(Area,["AB","SK","ON","NB","NL","NS","PE"])
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  #
  # credit is available at a reduced rate in 2032 due to the phase out
  #
  CapMult[ATRNGCCS] = 0.925
  for area in areas
    H2CCN[ATRNGCCS,area,Yr(2032)] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,Yr(2032)]
  end

  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  #
  # Autothermal in the preceding provinces count towards the third rate
  # 
  
  areas = Select(Area,"NL")
  CapMult[ATRNGCCS] = 0.65
  years = collect(Yr(2024):Yr(2031))
  for year in years, area in areas
    H2CCN[ATRNGCCS,area,year] = CapMult[ATRNGCCS] * H2CCN[ATRNGCCS,area,year]
  end
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  
  #
  # credit is available at a reduced rate in 2032 due to the phase out
  #  
  CapMult[ATRNGCCS] = 0.725
  for area in areas
    H2CCN[ATRNGCCS,area,Yr(2032)] = CapMult[ATRNGCCS]*H2CCN[ATRNGCCS,area,Yr(2032)] 
  end
  
  for h2tech in H2Techs
    CapMult[h2tech] = 1.0
  end
  #
  # the third rate applies to NGSMR CCS in Ontario and Quebec
  #  
  
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
  
  areas = Select(Area,["BC","NT"])
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
  areas = Select(Area,"NL")
  for h2tech in H2Techs
    CapMult[h2tech] = 1
  end
  years = collect(Yr(2024):Yr(2031))
  #
  # Use BC Grid value where appropriate from BC study. Apply the values to NL and NT as well.
  #
  Grid = Select(H2Tech,"Grid")
  CapMult[Grid] = 0.65

  for year in years, area in areas
    H2CCN[Grid,area,year] = CapMult[Grid] * H2CCN[Grid,area,year]
  end

  for h2tech in H2Techs
    CapMult[h2tech] = 1
  end
  areas = Select(Area,"NL")
  Grid = Select(H2Tech,"Grid")
  CapMult[Grid] = 0.725

  for area in areas
    H2CCN[Grid,area,Yr(2032)] = CapMult[Grid] * H2CCN[Grid,area,Yr(2032)]
  end

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
