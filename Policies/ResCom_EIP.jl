#
# ResCom_EIP.jl  - NRCan RDD Projects. 
#
# Last updated by Yang Li on 2024-06-12
# More details about this policy are available in the following file: 
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx
#
#
#####################################
#####################################
#

using SmallModel

module ResCom_EIP

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
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
  PEERef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Base Year Process Efficiency ($/Btu)
  PEE::VariableArray{5} = ReadDisk(db,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Process Efficiency ($/Btu)
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM") # Maximum Process Efficiency ($/Btu) [Enduse,EC,Area]
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Process Efficiency Max. Mult. ($/Btu/$/Btu)
  PEMMRef::VariableArray{5} = ReadDisk(BCNameDB,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Base Year Process Efficiency Max. Mult. ($/Btu/$/Btu)
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  CCC::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  Change::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Change in Policy Variable
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  PEENew::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] New PEE
  PERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PEStd1::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost (M$/Yr)
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data   
  (; ECs) = data 
  (; Enduse,Enduses,Nation) = data
  (; Techs) = data
  (; ANMap,Change,DmdFrac,DmdRef,DmdTotal) = data
  (; PEENew,PEERef,PEM,PEMM,PEMMRef) = data
  (; PEStd,PEStdP,PEStd1,PInvExo,) = data
  (; PolicyCost,xInflation) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)

  #
  # Read Base Year Values for Process Efficiency (PEE)
  #
  # FText1=BCName::0+Slash::0+"ROutput.dba"
  # Open Outpt FText1
  # Read Disk(PEERef,PEMMRef,DmdRef)  
  # Open Outpt "ROutput.dba"
  #
  # Store Orignal PEStdP
  #
  @. PEStd1 = PEStdP

  #
  # New facilities are x% more efficient/year beginning in 2022
  #
  @. Change = 1.0

  years = collect(Yr(2023):Yr(2026))
  for year in years, ec in ECs
    Change[ec,year] = 1.066
  end

  for year in years, area in areas, ec in ECs, tech in Techs, eu in Enduses
    PEENew[eu,tech,ec,area,year] = PEERef[eu,tech,ec,area,Yr(2017)]*Change[ec,year]
  end

  for year in years, area in areas, ec in ECs, tech in Techs, eu in Enduses
    PEMM[eu,tech,ec,area,year] = max(PEMM[eu,tech,ec,area,year],
      PEMM[eu,tech,ec,area,Yr(2017)]*Change[ec,year],PEMMRef[eu,tech,ec,area,Yr(2017)]*
        Change[ec,year])
    PEStdP[eu,tech,ec,area,year] = min(PEM[eu,ec,area]*
      PEMM[eu,tech,ec,area,year]*.98,max(PEStd[eu,tech,ec,area,year],
        PEStdP[eu,tech,ec,area,year],PEERef[eu,tech,ec,area,year],
          PEENew[eu,tech,ec,area,year]))
  end

  #
  # Adjust PEMM to account for growth of PEE in forecast
  # 
  for year in years, area in areas, ec in ECs, tech in Techs, eu in Enduses
    @finite_math PEMM[eu,tech,ec,area,year] = PEMM[eu,tech,ec,area,year]/
      (PEERef[eu,tech,ec,area,year]/PEERef[eu,tech,ec,area,Yr(2017)])
  end

  WriteDisk(db,"$Input/PEStdP",PEStdP)
  WriteDisk(db,"$CalDB/PEMM",PEMM)

  #
  ########################
  #
  # Program Costs are $82 million (CN$) spent equally between 2022 and 2026
  # 
  for year in years
    PolicyCost[year] = 16.4
  end

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  # 
  Heat = Select(Enduse,"Heat")

  for year in years
    DmdTotal[year] = 
      sum(DmdRef[Heat,tech,ec,area,year] for area in areas, ec in ECs, tech in Techs)
  end

  for year in years, area in areas, ec in ECs, tech in Techs
    @finite_math DmdFrac[Heat,tech,ec,area,year] = 
      DmdRef[Heat,tech,ec,area,year]/DmdTotal[year]
  end

  for year in years, area in areas, ec in ECs, tech in Techs
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+PolicyCost[year]/
      xInflation[area,Yr(2018)]*DmdFrac[Heat,tech,ec,area,year]
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)

  #
  # CHECK new standard
  #
  # Select EC*
  # Select Tech*
  # Select Enduse*
  # Select Area*
  #
  # Select Year(2016-2030)
  #
  
  #
  # CHECK calculated PInvExo
  #
  # DDD = PInvExo
  # Write("New PInvExo Values")
  # Write("-----------------")
  # Do Year
  #     Write(Year,";",DDD:15:e)
  # End Do Year
  # Write("-----------------")
  #
  
  #
  # CHECK calculated percentage changes in PEStdP
  #
  # CCC = PEStdP
  # CCC = PEMM
  # CCC = PEMMRef
  # Write("New PEStdP Values")
  # Write("-----------------")
  # Do Year
  #     Write(Year,";",CCC:15:e)
  # End Do Year
  # Write("-----------------")
  #
end

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
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
  PEERef::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Base Year Process Efficiency ($/Btu)
  PEE::VariableArray{5} = ReadDisk(db,"$Outpt/PEE") # [Enduse,Tech,EC,Area,Year] Process Efficiency ($/Btu)
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM") # Maximum Process Efficiency ($/Btu) [Enduse,EC,Area]
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Process Efficiency Max. Mult. ($/Btu/$/Btu)
  PEMMRef::VariableArray{5} = ReadDisk(BCNameDB,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Base Year Process Efficiency Max. Mult. ($/Btu/$/Btu)
  PERRRExo::VariableArray{5} = ReadDisk(db,"$Outpt/PERRRExo") # [Enduse,Tech,EC,Area,Year] Process Energy Exogenous Retrofits ((mmBtu/Yr)/Yr)
  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)

  # Scratch Variables
  CCC::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  Change::VariableArray{2} = zeros(Float64,length(EC),length(Year)) # [EC,Year] Change in Policy Variable
  DDD::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Variable for Displaying Outputs
  DmdFrac::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Device Energy Requirement (mmBtu/Yr)
  DmdTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Demand (TBtu/Yr)
  PEENew::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] New PEE
  PERRRExoTotal::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Total Process Energy Removed (mmBtu/Yr)
  PEStd1::VariableArray{5} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area),length(Year)) # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)
  PolicyCost::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Policy Cost (M$/Yr)
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; EC) = data 
  (; Enduse,Enduses,Nation) = data
  (; Techs) = data
  (; ANMap,Change,DmdFrac,DmdRef,DmdTotal) = data
  (; PEENew,PEERef,PEM,PEMM,PEMMRef) = data
  (; PEStd,PEStdP,PEStd1,PInvExo) = data
  (; PolicyCost,xInflation) = data

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)

  #
  # Read Base Year Values for Process Efficiency (PEE)
  #
  # FText1=BCName::0+Slash::0+"ROutput.dba"
  # Open Outpt FText1
  # Read Disk(PEERef,PEMMRef,DmdRef)  
  # Open Outpt "ROutput.dba"
  #
  # Store Orignal PEStdP
  #
  @. PEStd1 = PEStdP

  #
  # New facilities are x% more efficient/year beginning in 2022
  #
  @. Change = 1.0

  years = collect(Yr(2023):Yr(2026))
  ecs = Select(EC,(from="Wholesale", to="OtherCommercial"))
  for year in years, ec in ecs
    Change[ec,year] = 1.02
  end

  for year in years, area in areas, ec in ecs, tech in Techs, eu in Enduses
    PEENew[eu,tech,ec,area,year] = PEERef[eu,tech,ec,area,Yr(2017)]*Change[ec,year]
  end

  for year in years, area in areas, ec in ecs, tech in Techs, eu in Enduses
    PEMM[eu,tech,ec,area,year] = max(PEMM[eu,tech,ec,area,year],
      PEMM[eu,tech,ec,area,Yr(2017)]*Change[ec,year],PEMMRef[eu,tech,ec,area,Yr(2017)]*
        Change[ec,year])
    PEStdP[eu,tech,ec,area,year] = min(PEM[eu,ec,area]*PEMM[eu,tech,ec,area,year]*
      .98,max(PEStd[eu,tech,ec,area,year],PEStdP[eu,tech,ec,area,year],
        PEERef[eu,tech,ec,area,year],PEENew[eu,tech,ec,area,year]))
  end

  #
  # Adjust PEMM to account for growth of PEE in forecast
  #  
  for year in years, area in areas, ec in ecs, tech in Techs, eu in Enduses
    @finite_math PEMM[eu,tech,ec,area,year] = PEMM[eu,tech,ec,area,year]/
      (PEERef[eu,tech,ec,area,year]/PEERef[eu,tech,ec,area,Yr(2017)])
  end

  WriteDisk(db,"$Input/PEStdP",PEStdP)
  WriteDisk(db,"$CalDB/PEMM",PEMM)

  #
  ########################
  #
  # Program Costs are $82 million (CN$) spent equally between 2022 and 2026
  # 
  for year in years
    PolicyCost[year] = 2.28
  end

  #
  # Split out PolicyCost using reference Dmd values. PInv only uses Process Heat.
  #  
  Heat = Select(Enduse,"Heat")

  for year in years
    DmdTotal[year] = 
      sum(DmdRef[Heat,tech,ec,area,year] for area in areas, ec in ecs, tech in Techs)
  end

  for year in years, area in areas, ec in ecs, tech in Techs
    DmdFrac[Heat,tech,ec,area,year] = DmdRef[Heat,tech,ec,area,year]/DmdTotal[year]
  end

  for year in years, area in areas, ec in ecs, tech in Techs
    PInvExo[Heat,tech,ec,area,year] = PInvExo[Heat,tech,ec,area,year]+PolicyCost[year]/
      xInflation[area,Yr(2018)]*DmdFrac[Heat,tech,ec,area,year]
  end

  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "ResCom_EIP.jl - PolicyControl"
  ResPolicy(db)
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
