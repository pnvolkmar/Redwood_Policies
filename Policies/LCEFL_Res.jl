#
# LCEFL_Res.jl - Low Carbon Economy Leadership Fund - Device Retrofits
# in residential buildings
#
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
#
# Last updated by Yang Li on 2024-08-12
#

using SmallModel

module LCEFL_Res

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: DB
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  DmdRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/Dmd") # [Enduse,Tech,EC,Area,Year] Demand (TBtu/Yr)
  DERRef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DER") # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DERReduction::VariableArray{5} = ReadDisk(db,"$Input/DERReduction") # [Enduse,Tech,EC,Area,Year] Fraction of Device Energy Removed after this Policy is added ((mmBtu/Yr)/(mmBtu/Yr))
  DERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/DERRRExo") # [Enduse,Tech,EC,Area,Year] Device Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  DInvExo::VariableArray{5} = ReadDisk(db,"$Input/DInvExo") # [Enduse,Tech,EC,Area,Year] Device Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  AnnualAdjustment::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Adjustment for energy savings rebound
  CCC::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DDD::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Total Demand (TBtu/Yr)
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2015 CN$M)
  FractionRemovedAnnually::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Fraction of Energy Requirements Removed (Btu/Btu)
 # KJBtu    'Kilo Joule per BTU'
  PolicyCost::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Policy Cost ($/TBtu)
  ReductionAdditional::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
  ReductionTotal::VariableArray{2} = zeros(Float64,length(Area),length(Year)) # [Area,Year] Demand Reduction from this Policy Cumulative over Years (TBtu/Yr)
end

function AllocateReduction(data::RControl,enduses,techs,ecs,areas,years)
  (; Outpt) = data
  (; db) = data
  (; DERRef) = data
  (; DERRRExo,DmdRef) = data
  (; DmdTotal,FractionRemovedAnnually) = data
  (; ReductionAdditional,ReductionTotal) = data

  KJBtu = 1.054615

  #
  # Total Demands
  #  
  for year in years, area in areas
    DmdTotal[area,year] = sum(DmdRef[enduse,tech,ec,area,year] 
                              for enduse in enduses, tech in techs, ec in ecs)
  end

  #
  # Accumulate ReductionAdditional and apply to reference case demands
  #  
  for area in areas, year in years
    ReductionAdditional[area,year] = max((ReductionAdditional[area,year] - 
    	ReductionTotal[area,year-1]),0.0)
    ReductionTotal[area,year] = ReductionAdditional[area,year] + 
    	ReductionTotal[area,year-1]
  end

  #
  # Fraction Removed each Year
  #  
  for area in areas, year in years
    @finite_math FractionRemovedAnnually[area,year] = ReductionAdditional[area,year] / 
    	DmdTotal[area,year]
  end
   
  #
  # Energy Requirements Removed due to Program
  #  
  for enduse in enduses, tech in techs, ec in ecs, area in areas, year in years
  DERRRExo[enduse,tech,ec,area,year] = DERRRExo[enduse,tech,ec,area,year] + 
    DERRef[enduse,tech,ec,area,year] * FractionRemovedAnnually[area,year]
  end

  WriteDisk(db,"$Outpt/DERRRExo",DERRRExo)
end

function ResPolicy(db::String)
  data = RControl(; db)
  (; Input) = data
  (; Area,ECs,Enduses) = data
  (; Nation,Tech) = data
  (; AnnualAdjustment) = data
  (; DInvExo,DmdFrac,DmdRef,DmdTotal) = data
  (; PolicyCost,ReductionAdditional,xInflation) = data

  KJBtu = 1.054615

  #
  # Select Policy Sets (Enduse,Tech,EC)
  #  
  CN = Select(Nation,"CN")
  techs = Select(Tech,["Electric","Gas","Coal","Oil","Biomass","Solar",
  	"LPG","Steam","Geothermal","HeatPump"])
  years = collect(Yr(2023):Yr(2040))
  areas = Select(Area,["AB","NB","NS"])

  #
  # Reductions in demand read in in TJ and converted to TBtu
  #
  
  ReductionAdditional[areas,years] .= [
  #   2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040
      1886 1886 1886 1886 1886 1886 1886 1457    0    0    0    0    0    0    0    0    0    0  #AB
      193  193  193  193  193  193  193  193  193  193  193  170  125  125  125  125  125  125  #NB
      203  203  203  203  203  203  203  203    0    0    0    0    0    0    0    0    0    0] #NS

  #
  # Apply an annual adjustment to reductions to compensate for 'rebound' from less retirements
  #
  #
  # Read in final line only to match bug in Promula code - Ian 05/21/24
  #
  
  AnnualAdjustment[years] = [
    #   2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039 2040
    #   1.63 1.75 1.88 1.99 2.10 2.20 2.31 1.96    0    0    0    0    0    0    0    0    0    0   
    #   0.96 1.03 1.09 1.18 1.25 1.31 1.38 1.43 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00
        1.31 1.38 1.44 1.51 1.57 1.63 1.68 1.75    0    0    0    0    0    0    0    0    0    0]


  #
  # Convert from TJ to TBtu
  #  
  for area in areas, year in years
    ReductionAdditional[area,year] = ReductionAdditional[area,year]/
      KJBtu/1000*AnnualAdjustment[year]
  end
  
  AllocateReduction(data,Enduses,techs,ECs,areas,years)

  #
  # Program costs have been commented out as 2022 becomes the last historical year (Yang Li 2024-08-12)
  # Program Costs $M 
  #  
  # PolicyCost.= 0
  # AB = Select(Area,"AB")
  # PolicyCost[AB,Yr(2022)] = 20 / xInflation[AB,Yr(2018)]
  
  # 
  # Split out PolicyCost using reference Dmd values. DInv only uses Device Heat.
  #  
  # for enduse in Enduses, tech in techs, ec in ECs
    # DmdFrac[enduse,tech,ec,AB,Yr(2022)] = DmdRef[enduse,tech,ec,AB,Yr(2022)]/
    #   DmdTotal[AB,Yr(2022)]
    # DInvExo[enduse,tech,ec,AB,Yr(2022)] = DInvExo[enduse,tech,ec,AB,Yr(2022)]+
    #  (PolicyCost[AB,Yr(2022)]*DmdFrac[enduse,tech,ec,AB,Yr(2022)])      
  # end
  
  # WriteDisk(db,"$Input/DInvExo",DInvExo)
end  #function ResPolicy

function PolicyControl(db)
  @info "LCEFL_Res.jl - PolicyControl"
  ResPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
