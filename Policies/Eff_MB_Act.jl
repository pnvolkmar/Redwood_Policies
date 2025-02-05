#
# Eff_MB_Act.jl
#
# This jl simulates the impact of implementing the Efficiency Manitoba Act in the commercial and residential sectors. 
# Details about the underlying assumptions for this policy are available in the following file:
# \\ncr.int.ec.gc.ca\shares\e\ECOMOD\Documentation\Policy - Buildings Policies.docx.
#
# Last updated by Yang Li on 2024-06-13
#

using SmallModel

module Eff_MB_Act

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
  DCCLimit::VariableArray{5} = ReadDisk(db,"$Input/DCCLimit") # [Enduse,Tech,EC,Area,Year] Device Capital Cost Limit Multiplier ($/$)
  DEE::VariableArray{5} = ReadDisk(db,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency ($/Btu)
  DEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Base Year Device Efficiency ($/Btu)
  DEM::VariableArray{4} = ReadDisk(db,"$Input/DEM") # [Enduse,Tech,EC,Area] Maximum Device Efficiency ($/mmBtu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Device Efficiency Max. Mult. ($/Btu/$/Btu)
  DEStd::VariableArray{5} = ReadDisk(db,"$Input/DEStd") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard ($/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard Policy ($/Btu)
  PEE::VariableArray{5} = ReadDisk(db,"$Outpt/PEE") # Process Efficiency ($/Btu) [Enduse,Tech,EC,Area]
  PEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # Process Efficiency ($/Btu) [Enduse,Tech,EC,Area]
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM")       # [Enduse,EC,Area] Process Efficiency ($/Btu)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM")     # [Enduse,Tech,EC,Area,Year] Maximum Process Efficiency ($/mmBtu)
  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)
  
  # Scratch Variables
  Change::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Change in Policy Variable
end

function ResPolicy(db)
  data = RControl(; db)
  (; CalDB,Input) = data
  (; Area,ECs,Enduse,Enduses) = data  
  (; Nation,Tech) = data
  (; ANMap,Change,DCCLimit,DEEBase,DEM,DEMM,DEStd,DEStdP)= data
  (; PEEBase,PEM,PEMM,PEStdP,PEStd) = data
  
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1.0);
  
  MB = Select(Area,"MB")
  ecs = ECs
  years = collect(Yr(2023):Final)
  
  #
  # Default Value (for all Techs)
  #  
  @. Change = 0.0;

  #
  # Example - Different value for electric
  #  
  Electric = Select(Tech,"Electric");
  for year in years
    Change[Electric,year] = 0.0193 + Change[Electric,year-1]
  end
  
  Gas = Select(Tech,"Gas");
  for year in years
    Change[Gas,year] = 0.005 + Change[Gas,year-1]
  end
  
  techs = Select(Tech,["Electric","Gas"])
  for year in years, enduse in Enduses, tech in techs, ec in ecs
    DEStdP[enduse,tech,ec,MB,year] = max(DEStdP[enduse,tech,ec,MB,year],
      DEStd[enduse,tech,ec,MB,year],DEEBase[enduse,tech,ec,MB,year])*(1+Change[tech,year])
  end
  
  #
  # Making sure efficiencies are not greater that 98.9%
  #  
  enduses = Select(Enduse,!=("AC"));
  for year in years, enduse in enduses, tech in techs, ec in ecs
    DEStdP[enduse,tech,ec,MB,year] = min(DEStdP[enduse,tech,ec,MB,year],0.989)
  end
  
  for year in years, enduse in Enduses, tech in techs, ec in ecs
    @finite_math DEMM[enduse,tech,ec,MB,year] = max(DEStdP[enduse,tech,ec,MB,year]/
      (DEM[enduse,tech,ec,MB] *0.98),DEMM[enduse,tech,ec,MB,year])
      
    DCCLimit[enduse,tech,ec,MB,year] = 3.0;
  end
  
  for year in years, enduse in Enduses, tech in techs, ec in ecs   
    PEStdP[enduse,tech,ec,MB,year] = max(PEStdP[enduse,tech,ec,MB,year],
      PEStd[enduse,tech,ec,MB,year],PEEBase[enduse,tech,ec,MB,year])*
        (1+Change[tech,year])
    
    @finite_math PEMM[enduse,tech,ec,MB,year] = max(PEStdP[enduse,tech,ec,MB,year]/
      (PEM[enduse,ec,MB] *0.98),PEMM[enduse,tech,ec,MB,year])
  end
  
  WriteDisk(db,"$Input/DEStdP",DEStdP);
  WriteDisk(db,"$CalDB/DEMM",DEMM);
  WriteDisk(db,"$Input/DCCLimit",DCCLimit);
  WriteDisk(db,"$Input/PEStdP",PEStdP);
  WriteDisk(db,"$CalDB/PEMM",PEMM);
end

Base.@kwdef struct CControl
  db::String

  CalDB::String = "CCalDB"
  Input::String = "CInput"
  Outpt::String = "COutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB")#  Base Case Name

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
  DCCLimit::VariableArray{5} = ReadDisk(db,"$Input/DCCLimit") # [Enduse,Tech,EC,Area,Year] Device Capital Cost Limit Multiplier ($/$)
  DEE::VariableArray{5} = ReadDisk(db,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Device Efficiency ($/Btu)
  DEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/DEE") # [Enduse,Tech,EC,Area,Year] Base Year Device Efficiency ($/Btu)
  DEM::VariableArray{4} = ReadDisk(db,"$Input/DEM") # [Enduse,Tech,EC,Area] Maximum Device Efficiency ($/mmBtu)
  DEMM::VariableArray{5} = ReadDisk(db,"$CalDB/DEMM") # [Enduse,Tech,EC,Area,Year] Device Efficiency Max. Mult. ($/Btu/$/Btu)
  DEStd::VariableArray{5} = ReadDisk(db,"$Input/DEStd") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard ($/Btu)
  DEStdP::VariableArray{5} = ReadDisk(db,"$Input/DEStdP") # [Enduse,Tech,EC,Area,Year] Device Efficiency Standard Policy ($/Btu)
  PEE::VariableArray{5} = ReadDisk(db,"$Outpt/PEE") # Process Efficiency ($/Btu) [Enduse,Tech,EC,Area]
  PEEBase::VariableArray{5} = ReadDisk(BCNameDB,"$Outpt/PEE") # Process Efficiency ($/Btu) [Enduse,Tech,EC,Area]
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM")       # [Enduse,EC,Area] Process Efficiency ($/Btu)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM")     # [Enduse,Tech,EC,Area,Year] Maximum Process Efficiency ($/mmBtu)
  PEStd::VariableArray{5} = ReadDisk(db,"$Input/PEStd") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard ($/Btu)
  PEStdP::VariableArray{5} = ReadDisk(db,"$Input/PEStdP") # [Enduse,Tech,EC,Area,Year] Process Efficiency Standard Policy ($/Btu)

  # Scratch Variables
  Change::VariableArray{2} = zeros(Float64,length(Tech),length(Year)) # [Tech,Year] Change in Policy Variable
end

function ComPolicy(db)
  data = CControl(; db)
  (; CalDB,Input) = data
  (; Area,EC,Enduse,Enduses) = data  
  (; Nation,Tech) = data
  (; ANMap,Change,DCCLimit,DEEBase,DEM,DEMM,DEStd,DEStdP)= data
  (; PEEBase,PEM,PEMM,PEStdP,PEStd) = data
  
  CN = Select(Nation,"CN");
  areas = findall(ANMap[:,CN] .== 1.0);
  
  MB = Select(Area,"MB")
  ecs = Select(EC,(from = "Wholesale", to = "OtherCommercial"))
  years = collect(Yr(2023):Final)
  
  #
  # Default Value (for all Techs)
  #  
  @. Change = 0.0;

  #
  # Example - Different value for electric
  #  
  Electric = Select(Tech,"Electric");
  for year in years
    Change[Electric,year] = 0.0193 + Change[Electric,year-1]
  end
  
  Gas = Select(Tech,"Gas");
  for year in years
    Change[Gas,year] = 0.005 + Change[Gas,year-1]
  end
  
  techs = Select(Tech,["Electric","Gas"]);
  for year in years, enduse in Enduses, tech in techs, ec in ecs
    DEStdP[enduse,tech,ec,MB,year] = max(DEStdP[enduse,tech,ec,MB,year],
      DEStd[enduse,tech,ec,MB,year],DEEBase[enduse,tech,ec,MB,year])*(1+Change[tech,year])
  end
  
  #
  # Making sure efficiencies are not greater that 98.9%
  #  
  enduses = Select(Enduse,!=("AC"));
  for year in years, enduse in enduses, tech in techs, ec in ecs
    DEStdP[enduse,tech,ec,MB,year] = min(DEStdP[enduse,tech,ec,MB,year],0.989)
  end
  
  for year in years, enduse in Enduses, tech in techs, ec in ecs  
    @finite_math DEMM[enduse,tech,ec,MB,year] = max(DEStdP[enduse,tech,ec,MB,year]/
      (DEM[enduse,tech,ec,MB] *0.98),DEMM[enduse,tech,ec,MB,year])
      
    DCCLimit[enduse,tech,ec,MB,year] = 3.0;
  end
  
  for year in years, enduse in Enduses, tech in techs, ec in ecs     
   PEStdP[enduse,tech,ec,MB,year] = max(PEStdP[enduse,tech,ec,MB,year],
     PEStd[enduse,tech,ec,MB,year],PEEBase[enduse,tech,ec,MB,year])*(1+Change[tech,year]);
   
   @finite_math PEMM[enduse,tech,ec,MB,year] = max(PEStdP[enduse,tech,ec,MB,year]/
     (PEM[enduse,ec,MB] *0.98),PEMM[enduse,tech,ec,MB,year])
 end
  
  WriteDisk(db,"$Input/DEStdP",DEStdP);
  WriteDisk(db,"$CalDB/DEMM",DEMM);
  WriteDisk(db,"$Input/DCCLimit",DCCLimit);
  WriteDisk(db,"$Input/PEStdP",PEStdP);
  WriteDisk(db,"$CalDB/PEMM",PEMM);
end

function PolicyControl(db)
  @info "Eff_MB_Act.jl - PolicyControl"
  ResPolicy(db)
  ComPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
