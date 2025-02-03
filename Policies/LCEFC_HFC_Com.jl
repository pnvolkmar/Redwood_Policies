#
# LCEFC_HFC_Com.jl  - Policy that reduces HFC emissions from the retail sector in Ontario. 
# Last updated by Kevin Palmer-Wilson on 2023-06-09
# More details about this policy are available in the following file: 
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx
#

using SmallModel

module LCEFC_HFC_Com

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  MEDriverRef::VariableArray{3} = ReadDisk(BCNameDB,"MOutput/MEDriver") #[ECC,Area,Year]  Driver for Process Emissions (Various Millions/Yr)
  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Process Pollution Coefficient (Tonnes/$B-Output)
  PolConv::VariableArray{1} = ReadDisk(db,"SInput/PolConv") # [Poll] Pollution Conversion Factor (convert GHGs to eCO2)
  xMEPol::VariableArray{4} = ReadDisk(db,"SInput/xMEPol") # [ECC,Poll,Area,Year] Process Pollution (Tonnes/Yr)    

  # Scratch Variables
  ReductionInput::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Reductions Input
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
  MEDriverRef::VariableArray{3} = ReadDisk(BCNameDB,"MOutput/MEDriver") #[ECC,Area,Year]  Driver for Process Emissions (Various Millions/Yr)
  PInvExo::VariableArray{5} = ReadDisk(db,"$Input/PInvExo") # [Enduse,Tech,EC,Area,Year] Process Exogenous Investments (M$/Yr)
  xInflation::VariableArray{2} = ReadDisk(db,"MInput/xInflation") # [Area,Year] Inflation Index ($/$)
  
  # Scratch Variables
  Expenses::VariableArray{1} = zeros(Float64,length(Year)) # [Year] Program Expenses (2018 CN$M)
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,ECC) = data
  (; Poll) = data
  (; MEDriverRef,MEPOCX,PolConv) = data
  (; ReductionInput,xMEPol) = data

  #
  # Ontario retail HFC reduction program 
  # Reduction in HFC emissions from policy in CO2e equivalent
  #  
  years = collect(Yr(2022):Yr(2040))
  ON = Select(Area,"ON")
  Retail = Select(ECC,"Retail")
  HFC = Select(Poll,"HFC")
  
  #
  # 2041 commented out to match bug in Promula file - Ian 05/21/24
  #
  
  ReductionInput[years] = [ 
  # 2022   2023   2024   2025   2026   2027   2028   2029   2030   2031   2032   2033   2034   2035   2036   2037   2038   2039   2040  # 2041
    -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -243   -169    -97  #  -22
  ]

  #
  # Convert from kt CO2e to natural tonnes
  # 
  @. ReductionInput = ReductionInput * 1000 / PolConv[HFC]

  #
  # Compute coefficienct using exogneous emissions and driver
  #
  for year in years
    MEPOCX[Retail,HFC,ON,year]=(xMEPol[Retail,HFC,ON,year]+ReductionInput[year])/
      MEDriverRef[Retail,ON,year]
  end

  WriteDisk(db,"MEInput/MEPOCX",MEPOCX)
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area,EC,Enduse) = data
  (; Tech) = data
  (; Expenses,PInvExo,xInflation) = data
  (; ) = data

  #
  # Select Sets for Policy
  #
  ON = Select(Area,"ON")
  Retail = Select(EC,"Retail")
  Heat = Select(Enduse,"Heat")
  Electric = Select(Tech,"Electric")
  years = collect(Yr(2022):Yr(2022))

  Expenses[Yr(2022)] = 4.3

  #
  # Allocate Program Costs to each Enduse, Tech, EC, and Area
  #  
  PInvExo[Heat,Electric,Retail,ON,Yr(2022)] = 
    PInvExo[Heat,Electric,Retail,ON,Yr(2022)]+
      Expenses[Yr(2022)]/xInflation[ON,Yr(2018)]
  WriteDisk(db,"$Input/PInvExo",PInvExo)
end

function PolicyControl(db)
  @info "LCEFC_HFC_Com.jl - PolicyControl"
  MacroPolicy(db)
  # Program Costs
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end



