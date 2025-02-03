#
# H2_Supply.jl - Hydrogen Supply Policy
#

using SmallModel

module H2_Supply

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
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
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  #
  # Hydrogen Market Share Non-Price Factor (mmBtu/mmBtu)
  # Placeholder data needs to be replaced - Jeff Amlin 10/22/19
  #

  H2MSM0::VariableArray{3} = ReadDisk(db,"SpInput/H2MSM0") # [H2Tech,Area,Year] Hydrogen Market Share Non-Price Factor (mmBtu/mmBtu)
  H2PL::VariableArray{2} = ReadDisk(db,"SpInput/H2PL") # [H2Tech,Year] Hydrogen Production Physical Lifetime (Years)
end

function SupplyPolicy(db)
  data = SControl(; db)
  (; Area,Areas,H2Tech,H2Techs) = data
  (; Years) = data
  (; H2MSM0,H2PL) = data

  for year in Years, area in Areas, h2tech in H2Techs  
    H2MSM0[h2tech,area,year] = -170
  end

  #
  # Establish historical Hydrogen production (from Natural Gas)
  #  
  NG = Select(H2Tech,"NG")
  years = collect(1:Last)
  for year in years, area in Areas
    H2MSM0[NG,area,year] = 0.0
  end

  #
  # Options in the Forecast
  #  
  h2techs = Select(H2Tech,["Grid","OnshoreWind","SolarPV"])
  years = collect(Future:Final)
  for year in years, area in Areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = 0.0
  end

  #
  # Only Ontario has significant need for Interruptible power
  #  
  ON = Select(Area,"ON")
  Interruptible = Select(H2Tech,"Interruptible")
  years = collect(Future:Final)
  for year in years
    H2MSM0[Interruptible,ON,year] = -1.0
  end

  #
  # NG CCS units only expected in AB and SK
  #  
  areas = Select(Area,["AB","SK"])
  h2techs = Select(H2Tech,["Grid","OnshoreWind","SolarPV"])
  years = collect(Future:Final)
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = -10.0
  end
  
  NGCCS = Select(H2Tech,"NGCCS")
  for year in years, area in areas
    H2MSM0[NGCCS,area,year] = -5.0
  end
  
  ATRNGCCS = Select(H2Tech,"ATRNGCCS")
  for year in years, area in areas
    H2MSM0[ATRNGCCS,area,year] = 0.0
  end

  #
  # Biomass Gasification only in BC and QC
  #  
  areas = Select(Area,["BC","QC"])
  h2techs = Select(H2Tech,["Grid","OnshoreWind","SolarPV"])
  years = collect(Future:Final)
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = 0.0
  end
  
  h2techs = Select(H2Tech,["Biomass","BiomassCCS"])
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = -1.0
  end

  #
  # NU: Temp fix to remove H2 production in Ref22
  #  
  NU = Select(Area,"NU")
  for year in years, h2tech in H2Techs
    H2MSM0[h2tech,NU,year] = -170.0
  end

  #
  areas = Select(Area,["NS","NB","PE"])
  h2techs = Select(H2Tech,["ATRNGCCS","NGCCS"])
  years = collect(Future:Final)
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = -10.0
  end
  
  h2techs = Select(H2Tech,["Grid","SolarPV"])
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[h2tech,area,year] = -10.0
  end
  
  OnshoreWind = Select(H2Tech,"OnshoreWind")
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[OnshoreWind,area,year] = 0.0
  end
  
  #
  NL = Select(Area,"NL")
  h2techs = Select(H2Tech,["ATRNGCCS","NGCCS"])
  for year in years, h2tech in h2techs
    H2MSM0[h2tech,NL,year] = -170.0
  end

  h2techs = Select(H2Tech,["Grid","SolarPV"])
  for year in years, h2tech in h2techs
    H2MSM0[h2tech,NL,year] = -170.0
  end
  
  for year in years, area in areas, h2tech in h2techs
    H2MSM0[OnshoreWind,NL,year] = 0.0
  end
  
  #
  WriteDisk(db,"SpInput/H2MSM0",H2MSM0)

  #
  # Since all these are new facilities, remove all the
  # retirements by having a lifetime of 0 - Jeff Amlin 08/11/22
  #
  for year in Years, h2tech in H2Techs  
    H2PL[h2tech,year] = 0
  end
  
  WriteDisk(db,"SpInput/H2PL",H2PL)
end

function PolicyControl(db)
  @info "H2_Supply.jl - PolicyControl"
  SupplyPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
