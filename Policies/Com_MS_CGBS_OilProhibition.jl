#
# Com_MS_CGBS_OilProhibition.jl - based on 'EL_Bldg_HPs.txp' - Policy Targets for FuelShares - Jeff Amlin 5/10/16
#
# This policy simulates the prohibition of fossil fuel heating as part of the Buildings Sector Strategy.
# The prohibition is implemented into software code by setting to zero the Marginal Market Share Fraction MMSF of the
# Space heater technolgies "Coal", "Gas", "LPG", and "Oil" . Only provinces are affects; territories are exempt.
# Last updated by Kevin Palmer-Wilson on 2023-03-22
#

using SmallModel

module Com_MS_CGBS_OilProhibition

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
  (; Area,EC,Enduse,Nation,Tech,Year) = data
  (; ANMap,xMMSF) = data

  #
  # Set up policy area and time selections
  #
  CN = Select(Nation,"CN")
  areas = Select(Area,["AB","BC","MB","ON","QC","SK","NS","NL","NB","PE"])
  enduses = Select(Enduse,["Heat","HW"])
  years = collect(Yr(2028):Final)

  #
  # Assign emitting fuel shares to heat pumps
  #
  ecs = Select(EC,(from = "Wholesale",to = "OtherCommercial"))
  oil = Select(Tech,"Oil")
  heatpump = Select(Tech,"HeatPump")
  techs = Select(Tech,["HeatPump","Oil"])

  for year in years, area in areas, ec in ecs, enduse in enduses
    xMMSF[enduse,heatpump,ec,area,year] = sum(xMMSF[enduse,techs,ec,area,year])
  end

  #
  # Assign 0 market share to all emitting Techs
  #
  for year in years, area in areas, ec in ecs, enduse in enduses
    xMMSF[enduse,oil,ec,area,year] = 0.0
  end

  WriteDisk(db,"$CalDB/xMMSF",xMMSF)
end

function PolicyControl(db)
  @info "Com_MS_CGBS_OilProhibition.jl - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
