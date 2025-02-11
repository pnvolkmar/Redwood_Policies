#
# Interties.jl Should be used in the Reference Case. 
#
# Modified in the context of the electrification project 
# (should be kept for annual updates). JSLandry; Mar 22, 2020. 
#
# Added a MB-to-SK contract from 2028 onwards based on SK response 
# to the questionnaire. JSLandry; Jul 6, 2020. 
#

using SmallModel

module Interties

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct EControl
  db::String

  CalDB::String = "ECalDB"
  Input::String = "EInput"
  Outpt::String = "EOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Month::SetArray = ReadDisk(db,"E2020DB/MonthKey")
  MonthDS::SetArray = ReadDisk(db,"E2020DB/MonthDS")
  Months::Vector{Int} = collect(Select(Month))
  Node::SetArray = ReadDisk(db,"E2020DB/NodeKey")
  NodeDS::SetArray = ReadDisk(db,"E2020DB/NodeDS")
  NodeX::SetArray = ReadDisk(db,"E2020DB/NodeXKey")
  NodeXDS::SetArray = ReadDisk(db,"E2020DB/NodeXDS")
  NodeXs::Vector{Int} = collect(Select(NodeX))
  Nodes::Vector{Int} = collect(Select(Node))
  TimeP::SetArray = ReadDisk(db,"E2020DB/TimePKey")
  TimePs::Vector{Int} = collect(Select(TimeP))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  HDXLoad::VariableArray{5} = ReadDisk(db,"EGInput/HDXLoad") # [Node,NodeX,TimeP,Month,Year] Exogenous Loading on Transmission Lines (MW)
  LLMax::VariableArray{5} = ReadDisk(db,"EGInput/LLMax") # [Node,NodeX,TimeP,Month,Year] Maximum Loading on Transmission Lines (MW)
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Months,Node,NodeX) = data
  (; TimePs) = data
  (; HDXLoad,LLMax) = data

  # 
  # BC to AB
  # In NRCan_Elec_Transmission.txp. 
  # 
  # MB to SK
  # 
  # Note that Phases 1 (100 MW for 2020-2039) and 2 (190 MW for 2022-2039) are 
  # included in ElectricTransmission.txt, because contracts are announced. 
  # Phase 3 (starting at ~300 MW in 2027) is in NRCan_Elec_Transmission.txp. 
  # 
  # Modification by JSLandry on Sep 12, 2019:
  # We now assume that the contracts for Phases 1 and 2 are extended until 
  # the Final year (no need to modify LLMax,because the 250-MW increase already 
  # goes until Final in ElectricTransmission.txt). 
  #   
  node = Select(Node,"SK")
  nodex = Select(NodeX,"MB")
  years = collect(Yr(2040):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[node,nodex,timep,month,year] = HDXLoad[node,nodex,timep,month,year]+100+190
  end

  # TODO
  # This block is duplicate of block above to match Promula version. 
  # I don't know the original intention, but I doubt it's this. R.Levesque 2/6/25
  #
  years = collect(Yr(2040):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[node,nodex,timep,month,year] = HDXLoad[node,nodex,timep,month,year]+100+190
  end

  # 
  # QC to NB
  #
  # We extend the 2020-2040 contract until 2050. The 2020-2040 contract is 
  # included in ElectricTransmission.txt and corresponds to a value of 
  # 255.5 MW for HDXLoad. No change to LLMax,because existing infrastructure. 
  #   
  node = Select(Node,"NB")
  nodex = Select(NodeX,"QC")
  years = collect(Yr(2041):Final)
  for year in years, month in Months, timep in TimePs
    HDXLoad[node,nodex,timep,month,year] = HDXLoad[node,nodex,timep,month,year]+255.5
  end

  # 
  # QC to NS
  # In NRCan_Elec_Transmission.txp. 
  # 
  
  #
  # NL to NS
  # In NRCan_Elec_Transmission.txp. 
  # 

  WriteDisk(db,"EGInput/HDXLoad",HDXLoad)
end

function PolicyControl(db)
  @info "Interties.jl - PolicyControl"
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
