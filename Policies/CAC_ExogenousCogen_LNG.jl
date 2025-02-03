#
# CAC_ExogenousCogen_LNG.jl
# This file calculates the CAC coefficients for the
# industrial sector including the enduse (POCX), cogeneration (CgPOCX),
# non-combustion (FsPOCX), and process (MEPOCX).  JSA 1/11/10
#

using SmallModel

module CAC_ExogenousCogen_LNG

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Future,DB,Final
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log

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
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  ECCDS::SetArray = ReadDisk(db,"E2020DB/ECCDS")
  ECCs::Vector{Int} = collect(Select(ECC))
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Unit::SetArray = ReadDisk(db,"E2020DB/UnitKey")
  Units::Vector{Int} = collect(Select(Unit))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  UnArea::Array{String} = ReadDisk(db,"EGInput/UnArea") # [Unit] Area Pointer
  UnPlant::Array{String} = ReadDisk(db,"EGInput/UnPlant") # [Unit] Plant Type
  UnSector::Array{String} = ReadDisk(db,"EGInput/UnSector") # [Unit] Unit Type (Utility or Industry)

  CgDem::VariableArray{4} = ReadDisk(BCNameDB,"$Outpt/CgDem") # [FuelEP,EC,Area,Year] Cogeneration Demands (TBtu/Yr)
  CgPOCX::VariableArray{5} = ReadDisk(db,"$Input/CgPOCX") # [FuelEP,EC,Poll,Area,Year] Cogeneration Pollution Coeff. (Tonnes/TBtu)
  ECCMap::VariableArray{2} = ReadDisk(db,"$Input/ECCMap") # [EC,ECC] # EC TO ECC Map
  EuDem::VariableArray{5} = ReadDisk(db,"$Outpt/EuDem") # [Enduse,FuelEP,EC,Area,Year] Enduse Demands (TBtu/Yr)
  FsDem::VariableArray{4} = ReadDisk(db,"$Outpt/FsDem") # [Fuel,EC,Area,Year] Feedstock Demands (TBtu/Yr)
  FsPOCX::VariableArray{5} = ReadDisk(db,"$Input/FsPOCX") # [Fuel,EC,Poll,Area,Year] Feedstock Marginal Pollution Coefficients (Tonnes/TBtu)
  FsPol::VariableArray{5} = ReadDisk(db,"$Outpt/FsPol") # [Fuel,EC,Poll,Area,Year] Feedstock Pollution (Tonnes/Yr)
  FuPOCX::VariableArray{4} = ReadDisk(db,"MEInput/FuPOCX") # [ECC,Poll,Area,Year] Other Fugitive Emissions Coefficient (Tonnes/Driver)
  MEDriver::VariableArray{3} = ReadDisk(db,"MOutput/MEDriver") # [ECC,Area,Year] Driver for Process Emissions (Various Millions/Yr)
  MEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/Economic Driver)
  ORMEPOCX::VariableArray{4} = ReadDisk(db,"MEInput/ORMEPOCX") # [ECC,Poll,Area,Year] Non-Energy Off Road Pollution Coefficient (Tonnes/Economic Driver)
  POCX::VariableArray{6} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,EC,Poll,Area,Year] Pollution Coefficient (Tonnes/TBtu)
  Polute::VariableArray{6} = ReadDisk(db,"$CalDB/Polute") # [Enduse,FuelEP,EC,Poll,Area,Year] Pollution (Tonnes/Yr)
  UnCogen::VariableArray{1} = ReadDisk(db,"EGInput/UnCogen") # [Unit] Industrial Self-Generation Flag (1=Self-Generation)
  UnDmd::VariableArray{3} = ReadDisk(db,"EGOutput/UnDmd") # [Unit,FuelEP,Year] Energy Demands (TBtu)
  UnPOCX::VariableArray{4} = ReadDisk(db,"EGInput/UnPOCX") # [Unit,FuelEP,Poll,Year] Pollution Coefficient (Tonnes/TBtu)
  VnPOCX::VariableArray{4} = ReadDisk(db,"MEInput/VnPOCX") # [ECC,Poll,Area,Year] Fugitive Venting Emissions Coefficient (Tonnes/Driver)
  xCgDmd::VariableArray{4} = ReadDisk(db,"$Input/xCgDmd") # [Tech,EC,Area,Year] Exogenous Cogeneration (TBtu/Yr)
  xCgFPol::VariableArray{5} = ReadDisk(db,"SInput/xCgFPol") # [FuelEP,ECC,Poll,Area,Year] Cogeneration Related Pollution (Tonnes/Yr)
  xEnFPol::VariableArray{5} = ReadDisk(db,"SInput/xEnFPol") # [FuelEP,ECC,Poll,Area,Year] Actual Energy Related Pollution excluding Off Road (Tonnes/Yr)
  xFlPol::VariableArray{4} = ReadDisk(db,"SInput/xFlPol") # [ECC,Poll,Area,Year] Fugitive Flaring Emissions (Tonnes/Yr)
  xFuPol::VariableArray{4} = ReadDisk(db,"SInput/xFuPol") # [ECC,Poll,Area,Year] Fugitive Emissions (Tonnes/Yr)
  xMEPol::VariableArray{4} = ReadDisk(db,"SInput/xMEPol") # [ECC,Poll,Area,Year] Actual Process Pollution (Tonnes/Yr)
  xOREnFPol::VariableArray{5} = ReadDisk(db,"SInput/xOREnFPol") # [FuelEP,ECC,Poll,Area,Year] Off Road Actual Energy Related Pollution (Tonnes/Yr)
  xORMEPol::VariableArray{4} = ReadDisk(db,"SInput/xORMEPol") # [ECC,Poll,Area,Year] Actual Process Pollution (Tonnes/Yr)
  xUnPolSw::VariableArray{3} = ReadDisk(db,"EGInput/xUnPolSw") # [Unit,Poll,Year] Historical Pollution Switch (1=No Unit Data)
  xVnPol::VariableArray{4} = ReadDisk(db,"SInput/xVnPol") # [ECC,Poll,Area,Year] Fugitive Venting Emissions (Tonnes/Yr)

  # Scratch Variables
  CgDmdNPRI::VariableArray{3} = zeros(Float64,length(FuelEP),length(EC),length(Area)) # [FuelEP,EC,Area] Demands for NPRI Cogen units
  CgPolNPRI::VariableArray{4} = zeros(Float64,length(FuelEP),length(ECC),length(Poll),length(Area)) # [FuelEP,ECC,Poll,Area] Emissions for NPRI Cogen units
  EPOCX::VariableArray{4} = zeros(Float64,length(FuelEP),length(EC),length(Poll),length(Area)) # [FuelEP,EC,Poll,Area] Emission Coefficient (Tonnes/TBtu)
  MisPol::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Area)) # [EC,Poll,Area] Missing Pollution (Tonnes/Yr)
end

function GetUnitSets(data::IControl,unit)
  (; Area,Plant) = data
  (; UnArea,UnPlant,UnSector) = data

  plant = Select(Plant,UnPlant[unit])
  ec = Select(EC,UnSector[unit])
  area = Select(Area,UnArea[unit])

  return plant,ec,area
end

function CalcCoefficients(data::IControl,year,polls)
  (; Areas,ECs,ECCs,Enduse,FuelEPs,Nation) = data
  (; ANMap,CgDem,CgPOCX,ECCMap,EPOCX,Polls,xCgFPol) = data

  #
  # Select Canada areas
  #
  cn_areas = Select(ANMap[Areas,Select(Nation,"CN")],==(1))

  # 
  # For each ECC select the appropriate EC with ECCMap
  #  
  for ecc in ECCs
    ec = Select(ECCMap[ECs,ecc],filter(x -> x in ECCMap[ECs,ecc],[1.0]))
    if ec != []
      ec = ec[1]
      for area in cn_areas
        # if sum(CgDem[fuelep,ec,area,year] for fuelep in FuelEPs) > 0.0
        if sum(CgDem[fuelep,ec,area,1] for fuelep in FuelEPs) > 0.0
          eu = Select(Enduse,!=("OffRoad"))
          # @finite_math [EPOCX[fuelep,ec,poll,area] = xCgFPol[fuelep,ecc,poll,area,year] / CgDem[fuelep,ec,area,year] for fuelep in FuelEPs, poll in polls]
           [@finite_math EPOCX[fuelep,ec,poll,area] = xCgFPol[fuelep,ecc,poll,area,year] / CgDem[fuelep,ec,area,1] for fuelep in FuelEPs, poll in polls]
          for poll in Polls, fuelep in FuelEPs
            CgPOCX[fuelep,ec,poll,area,year] = EPOCX[fuelep,ec,poll,area]
          end
          
        end
        
      end
      
    end
    
  end

  return
end

function UnitCoefficients(data::IControl,ecc,polls,year)
  (; ECC,FuelEPs,Unit) = data
  (; UnSector) = data

  units = Select(UnSector,filter(x -> x in UnSector,[ECC[ecc]]))
  for unit in units
    plant,ec,area = GetUnitSets(data::IControl,unit)
    for poll in polls, fuelep in FuelEPs
      UnPOCX[unit,fuelep,poll,year] = CgPOCX[fuelep,ec,poll,area,year]
    end
    
  end
  
  return
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; ECC) = data
  (; Poll) = data
  (; CgPOCX,UnPOCX) = data

  # 
  # Calculate Coefficients for years which have data
  # 
  ecc = Select(ECC,"LNGProduction")
  polls = Select(Poll,["PMT","PM10","PM25","SOX","NOX","VOC","COX","NH3","Hg","BC"])
  years = collect(Future:Final)
  for year in years, poll in polls
    CalcCoefficients(data::IControl,year,poll)
    UnitCoefficients(data::IControl,ecc,poll,year)
  end

  WriteDisk(db,"$Input/CgPOCX",CgPOCX)
  WriteDisk(db,"EGInput/UnPOCX",UnPOCX)
end

function PolicyControl(db)
  @info "CAC_ExogenousCogen_LNG.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
