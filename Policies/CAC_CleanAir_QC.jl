#
# CAC_CleanAir_QC.jl
#
# This policy files enacts reductions for the Quebec Clear Air 
# regulations - Ian 04/12/2012
#
# xRM values for Iron and Steel were not being written to the dbas
# This jl has been updated to correct that - Matt 07/30/2013
#
# Changed to Future year pointer for first forecast year, and also
# changed the way the rest of the forecast reduction multipliers were
# calculated to apply only the reduction from this policy file in the 
# first forecast year to future years, not any other additional reduction.
# - Hilary 15.05.16
#

using SmallModel

module CAC_CleanAir_QC

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [FuelEP,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Year)) # [EC,Poll,Year] Scratch Variable For Input Reductions
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; Area,EC,ECs,FuelEP,FuelEPs) = data 
  (; Poll,Polls,Years) = data
  (; Reduce,xRM) = data

  # 
  # "Please find in attached file the Quebec Clean Air Regulations for 
  # different sectors and gases. As usual the numbers in the file are 
  # expressed as coefficient multiplier applying to 2010 actual coefficients."
  # 04/11/2012 E-mail from Lifang
  #
  # Data is from "Quebec_CleanAirRegs_forJeff.xlsx"
  #
  for year in Years, poll in Polls, ec in ECs
    Reduce[ec,poll,year] = 1
  end

  QC = Select(Area,"QC")
  Lumber = Select(EC,"Lumber")
  Aluminum = Select(EC,"Aluminum")
  IronSteel = Select(EC,"IronSteel")
  IronOreMining = Select(EC,"IronOreMining")

  # 
  # PM Reductions
  # 
  pmt = Select(Poll,"PMT")
  pm10 = Select(Poll,"PM10")
  pmt25 = Select(Poll,"PM25")
  bc_poll = Select(Poll,"BC")

  Reduce[Lumber,       pmt,Future] = 0.8323
  Reduce[Aluminum,     pmt,Future] = 0.8795
  Reduce[IronSteel,    pmt,Future] = 0.8596
  Reduce[IronOreMining,pmt,Future] = 0.8692

  Reduce[Lumber,       pm10,Future] = 0.7922
  Reduce[Aluminum,     pm10,Future] = 0.8539
  Reduce[IronSteel,    pm10,Future] = 0.9524
  Reduce[IronOreMining,pm10,Future] = 0.9173
  
  Reduce[Lumber,       pmt25,Future] = 0.7863
  Reduce[Aluminum,     pmt25,Future] = 0.8557
  Reduce[IronSteel,    pmt25,Future] = 0.9396
  Reduce[IronOreMining,pmt25,Future] = 0.9377
  
  Reduce[Lumber,       bc_poll,Future] = 0.7863
  Reduce[Aluminum,     bc_poll,Future] = 0.8557
  Reduce[IronSteel,    bc_poll,Future] = 0.9396
  Reduce[IronOreMining,bc_poll,Future] = 0.9377

  polls = Select(Poll,["PMT","PM10","PM25","BC"])
  ecs = Select(EC,["Lumber","Aluminum","IronSteel","IronOreMining"])

  # 
  # xRM equals 1 if there are no exogenous reductions. Multiply existing value for 
  # each year in case sector has existing reductions via other policy.
  # 
  # I've changed the below calculations because re-applying the entire reduction from
  # the first forecast year seems redundant to me; this file should only apply the 
  # additional reduction due to the above policy to the future years. - Hilary 15.05.15
  # 
  # xRM(F,EC,P,A,Y) = xRM(F,EC,P,A,Y)*Reduce(EC,P,Y)
  # 
  # Select Year(2014-Final)
  # xRM(F,EC,P,A,Y) = xRM(F,EC,P,A,Y)*xRM(F,EC,P,A,2013)
  #  
  years = collect(Future:Final)
  for ec in ECs, poll in Polls, year in years
    xRM[FuelEPs,ec,poll,QC,year] = xRM[FuelEPs,ec,poll,QC,year] * 
      Reduce[ec,poll,Future]
  end

  # 
  # VOC Reductions
  # 
  VOC = Select(Poll, "VOC")
  Petroleum = Select(EC, "Petroleum")
  Reduce[Petroleum,VOC,Future] = 0.9476
  xRM[FuelEPs,Petroleum,VOC,QC,Future:Final] = 
    xRM[FuelEPs,Petroleum,VOC,QC,Future:Final] * Reduce[Petroleum,VOC,Future]

  # 
  # SOX Reductions - Only Apply to Heavy Fuel Oil per spreadsheet
  # 
  SOX = Select(Poll, "SOX")
  HFO = Select(FuelEP, "HFO")

  Lumber = Select(EC, "Lumber")
  PulpPaperMills = Select(EC, "PulpPaperMills")
  Petrochemicals = Select(EC, "Petrochemicals")
  OtherChemicals = Select(EC, "OtherChemicals")
  Petroleum = Select(EC, "Petroleum")
  Aluminum = Select(EC, "Aluminum")
  OtherNonferrous = Select(EC, "OtherNonferrous")
  TransportEquipment = Select(EC, "TransportEquipment")
  IronOreMining = Select(EC, "IronOreMining")
  OtherMetalMining = Select(EC, "OtherMetalMining")
  NonMetalMining = Select(EC, "NonMetalMining")

  Reduce[Lumber,            SOX,Future] = 0.9463
  Reduce[PulpPaperMills,    SOX,Future] = 0.8704
  Reduce[Petrochemicals,    SOX,Future] = 0.9841
  Reduce[OtherChemicals,    SOX,Future] = 0.9901
  Reduce[Petroleum,         SOX,Future] = 0.9306
  Reduce[Aluminum,          SOX,Future] = 0.9854
  Reduce[OtherNonferrous,   SOX,Future] = 0.9852
  Reduce[TransportEquipment,SOX,Future] = 0.4834
  Reduce[IronOreMining,     SOX,Future] = 0.9610
  Reduce[OtherMetalMining,  SOX,Future] = 0.2206
  Reduce[NonMetalMining,    SOX,Future] = 0.9581

  ecs = Select(EC,["Lumber","PulpPaperMills","Petrochemicals","OtherChemicals","Petroleum","Aluminum","OtherNonferrous","TransportEquipment","IronOreMining","OtherMetalMining","NonMetalMining"])
  years = collect(Future:Final)
  for ec in ECs, year in years
    xRM[HFO,ec,SOX,QC,year] = xRM[HFO,ec,SOX,QC,year] * Reduce[ec,SOX,Future]
  end

  WriteDisk(db,"$Input/xRM",xRM)
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
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [FuelEP,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Year)) # [EC,Poll,Year] Scratch Variable For Input Reductions
end

function ComPolicy(db)
  data = CControl(; db)
  (; Input) = data
  (; Area,EC,ECs,FuelEP) = data 
  (; Poll,Polls,Years) = data
  (; Reduce,xRM) = data
  
  # 
  # SOX Reductions - Only Apply to Heavy Fuel Oil per spreadsheet
  #   
  for year in Years, poll in Polls, ec in ECs
    Reduce[ec,poll,year] = 1
  end
  QC = Select(Area,"QC")
  SOX = Select(Poll,"SOX")
  HFO = Select(FuelEP,"HFO")

  Wholesale = Select(EC,"Wholesale")
  Retail = Select(EC,"Retail")
  Warehouse = Select(EC,"Warehouse")
  Information = Select(EC,"Information")
  Offices = Select(EC,"Offices")
  Education = Select(EC,"Education")
  Health = Select(EC,"Health")

  Reduce[Wholesale,  SOX,Future] = 0.7728
  Reduce[Retail,     SOX,Future] = 0.7728
  Reduce[Warehouse,  SOX,Future] = 0.7727
  Reduce[Information,SOX,Future] = 0.7728
  Reduce[Offices,    SOX,Future] = 0.7728
  Reduce[Education,  SOX,Future] = 0.7728
  Reduce[Health,     SOX,Future] = 0.7728
  
  ecs = Select(EC,["Wholesale","Retail","Warehouse","Information","Offices","Education","Health"])
  years = collect(Future:Final)
  for ec in ECs, year in years
    xRM[HFO,ec,SOX,QC,year] = xRM[HFO,ec,SOX,QC,year] * Reduce[ec,SOX,Future] 
  end

  WriteDisk(db,"$Input/xRM",xRM)
end

Base.@kwdef struct TControl
  db::String

  CalDB::String = "TCalDB"
  Input::String = "TInput"
  Outpt::String = "TOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [Tech,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(Tech),length(Poll),length(Year)) # [Tech,Poll,Year] Scratch Variable For Input Reductions
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; Area,EC,Poll,Polls) = data 
  (; Tech,Techs,Years) = data
  (; Reduce,xRM) = data
  
  for year in Years, poll in Polls, tech in Techs
    Reduce[tech,poll,year] = 1
  end
  
  QC = Select(Area,"QC")
  SOX = Select(Poll,"SOX")
  Freight = Select(EC,"Freight")
  MarineHeavy = Select(Tech,"MarineHeavy")
  Reduce[MarineHeavy,SOX,Future] = 0.8960

  #
  # xRM equals 1 if there are no reductions so multiply existing value for
  # each year in case sector has existing reductions via other policy
  #
  years = collect(Future:Final)
  for year in years
    xRM[MarineHeavy,Freight,SOX,QC,year] = xRM[MarineHeavy,Freight,SOX,QC,year]*
      Reduce[MarineHeavy,SOX,Future]
  end

  WriteDisk(db,"$Input/xRM",xRM)
end

Base.@kwdef struct EControl
  db::String

  CalDB::String = "ECalDB"
  Input::String = "EInput"
  Outpt::String = "EOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Plant::SetArray = ReadDisk(db,"E2020DB/PlantKey")
  PlantDS::SetArray = ReadDisk(db,"E2020DB/PlantDS")
  Plants::Vector{Int} = collect(Select(Plant))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  xEURM::VariableArray{5} = ReadDisk(db,"EGInput/xEURM") # [FuelEP,Plant,Poll,Area,Year] Exogenous Reduction Multiplier by Area (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{2} = zeros(Float64,length(Poll),length(Year)) # [Poll,Year] Scratch Variable For Input Reductions
end

function ElecPolicy(db)
  data = EControl(; db)
  (; Area,FuelEP,FuelEPs) = data
  (; Plants,Poll,Polls,Years) = data
  (; Reduce,xEURM) = data
  
  for year in Years, poll in Polls
    Reduce[poll,year] = 1
  end
  QC = Select(Area,"QC")
  NOX = Select(Poll,"NOX")
  Reduce[NOX,Future] = 0.8958
  years = collect(Future:Final)
  for year in years, plant in Plants, fuelep in FuelEPs
    xEURM[fuelep,plant,NOX,QC,year] = xEURM[fuelep,plant,NOX,QC,year] * 
      Reduce[NOX,Future]
  end
  
  SOX = Select(Poll,"SOX")
  Reduce[SOX,Future] = 0.8510
  HFO = Select(FuelEP,"HFO")
  years = collect(Future:Final)
  for year in years, plant in Plants
    xEURM[HFO,plant,SOX,QC,year] = xEURM[HFO,plant,SOX,QC,year]*
      Reduce[SOX,Future]
  end
  
  WriteDisk(db,"EGInput/xEURM",xEURM)
end

function PolicyControl(db)
  @info "CAC_CleanAir_QC.jl - PolicyControl"
  IndPolicy(db)
  ComPolicy(db)
  TransPolicy(db)
  ElecPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
