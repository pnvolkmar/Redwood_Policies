#
# Com_MS_LCEFC.jl - MS based on 'Com_MS_HeatPump_BC.txp'
# 
# This policy simulates the 2023 intake of the Low Carbon Economy Challenge Fund 
# Fuel switching from natural gas to heat pump in Ontario and BC.
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
# 
# Last updated by Yang Li on 2024-09-25
#

using SmallModel

module Com_MS_LCEFC

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

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
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  xMMSF::VariableArray{5} = ReadDisk(db,"$CalDB/xMMSF") # [Enduse,Tech,EC,Area,Year] Market Share Fraction ($/$)

  # Scratch Variables
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(Area),length(Year)) # [Enduse,Tech,Area,Year] Total Demand (TBtu/Yr)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost ($/TBtu)
end

function ComPolicy(db::String)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduse,Tech) = data
  (; DInvExo,DmdFrac,DmdRef,DmdTotal,PolicyCost,xInflation,xMMSF) = data

  #
  # Substitution of heatpump for natural gas in Ontario
  #  
  area = Select(Area,"ON")  
  
  #
  # Specify values for desired fuel shares (xMMSF)
  #  
  years = collect(Yr(2024):Yr(2027)) 
  enduse = Select(Enduse,"Heat")
  HeatPump = Select(Tech,"HeatPump")
  Gas = Select(Tech,"Gas")
  for ec in ECs, year in years
    xMMSF[enduse,HeatPump,ec,area,year] = xMMSF[enduse,HeatPump,ec,area,year]+0.005
    xMMSF[enduse,Gas,ec,area,year] = max(xMMSF[enduse,Gas,ec,area,year]-0.005,0.0)
  end
  
  #
  # Specify values for desired fuel shares (xMMSF)
  #  
  years = collect(Yr(2028):Yr(2050)) 
  for ec in ECs, year in years
    xMMSF[enduse,HeatPump,ec,area,year] = xMMSF[enduse,HeatPump,ec,area,year]+0.001
    xMMSF[enduse,Gas,ec,area,year] = max(xMMSF[enduse,Gas,ec,area,year]-0.001,0.0)
  end
  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)
  
  #
  # Program Costs are $121.43 million (CN$) spent equally between 2024 and 2027
  #
  years = collect(Yr(2024):Yr(2027))
  for year in years   
    PolicyCost[year] = 30.36
  end

  #
  # Split out PolicyCost using reference Dmd values
  #  
  for year in years
    DmdTotal[enduse,HeatPump,area,year] = sum(DmdRef[enduse,HeatPump,ec,area,year] for ec in ECs)
    for ec in ECs
      @finite_math DmdFrac[enduse,HeatPump,ec,area,year] = DmdRef[enduse,HeatPump,ec,area,year]/
                                                           DmdTotal[enduse,HeatPump,area,year]
      DInvExo[enduse,HeatPump,ec,area,year] = DInvExo[enduse,HeatPump,ec,area,year]+PolicyCost[year]/
                                              xInflation[area,Yr(2023)]*DmdFrac[enduse,HeatPump,ec,area,year]
    end
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)

  #
  # Substitution of heatpump for natural gas in BC
  #  
  area = Select(Area,"BC")  
  
  #
  # Specify values for desired fuel shares (xMMSF)
  #  
  years = collect(Yr(2024):Yr(2027)) 
  enduse = Select(Enduse,"Heat")
  HeatPump = Select(Tech,"HeatPump")
  Gas = Select(Tech,"Gas")
  for ec in ECs, year in years
    xMMSF[enduse,HeatPump,ec,area,year] = xMMSF[enduse,HeatPump,ec,area,year]+0.012
    xMMSF[enduse,Gas,ec,area,year] = max(xMMSF[enduse,Gas,ec,area,year]-0.012,0.0)
  end

  #
  # Specify values for desired fuel shares (xMMSF)
  #  
  years = collect(Yr(2028):Yr(2050)) 
  for ec in ECs, year in years
    xMMSF[enduse,HeatPump,ec,area,year] = xMMSF[enduse,HeatPump,ec,area,year]+0.002
    xMMSF[enduse,Gas,ec,area,year] = max(xMMSF[enduse,Gas,ec,area,year]-0.002,0.0)
  end
  WriteDisk(DB,"$CalDB/xMMSF",xMMSF)

  #
  # Program Costs are $121.43 million (CN$) spent equally between 2024 and 2027
  #
  years = collect(Yr(2024):Yr(2027))
  for year in years   
    PolicyCost[year] = 33.09
  end

  #
  # Split out PolicyCost using reference Dmd values
  #  
  for year in years
    DmdTotal[enduse,HeatPump,area,year] = sum(DmdRef[enduse,HeatPump,ec,area,year] for ec in ECs)
    for ec in ECs
      @finite_math DmdFrac[enduse,HeatPump,ec,area,year] = DmdRef[enduse,HeatPump,ec,area,year]/
                                                           DmdTotal[enduse,HeatPump,area,year]
      DInvExo[enduse,HeatPump,ec,area,year] = DInvExo[enduse,HeatPump,ec,area,year]+PolicyCost[year]/
                                              xInflation[area,Yr(2023)]*DmdFrac[enduse,HeatPump,ec,area,year]
    end
  end
  WriteDisk(db,"$Input/DInvExo",DInvExo)
end

function PolicyControl(db)
  @info "Com_MS_LCEFC - PolicyControl"
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
