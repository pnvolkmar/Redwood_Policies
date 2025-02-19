#
# Com_MS_Incentive_Opt1.jl 
#

using SmallModel

module Com_MS_Incentive_Opt1

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct CControl
  db::String

  Input::String = "CInput"
  CalDB::String = "CCalDB"

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB) = data
  (; Area,EC,ECs,Enduse,Nation,Tech,Year) = data
  (; ANMap,xMMSF) = data

  # 
  # Select areas (territories excluded)
  #
  areas = Select(Area,(from = "ON", to = "PE"))
  enduses = Select(Enduse,["Heat","AC"]) 
  tech = Select(Tech,"HeatPump")

  # Apply incentive adjustments
  xMMSF[enduses,tech,ECs,areas,Yr(2025)] .+= 0.0005

  years = collect(Yr(2026):Yr(2027))
  for year in years
    xMMSF[enduses,tech,ECs,areas,year] .+= 0.0007
  end

  years = collect(Yr(2028):Yr(2029))
  for year in years
    xMMSF[enduses,tech,ECs,areas,year] .+= 0.0007
  end

  years = collect(Yr(2030):Final)
  for year in years
    xMMSF[enduses,tech,ECs,areas,year] .+= 0.0007
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Com_MS_Incentive_Opt1.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
