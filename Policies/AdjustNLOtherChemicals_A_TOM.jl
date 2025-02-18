#
# AdjustNLOtherChemicals_A_TOM.jl - adds specific amounts to emissions 
# from the Breya Renewable Fuels and OtherChemicals
#
# Modified AdjustFactors to reduce spike in Still Gas energy demands in Ref24A. (JSO October 2023)
#

using SmallModel

module AdjustNLOtherChemicals_A_TOM

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: ITime,HisTime,MaxTime,Zero,First,Last,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String
  
  CalDB::String = "ICalDB"
  Input::String = "IInput"
  MEInput::String = "MEInput"
  MInput::String = "MInput"
  Outpt::String = "IOutput"
 
  # Sets
  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECC::SetArray = ReadDisk(db,"E2020DB/ECCKey")
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey") 
  Enduses = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  Fuels::Vector{Int} = collect(Select(Fuel))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
 
  # Main Variables
  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  CERSM::VariableArray{4} = ReadDisk(db,"$CalDB/CERSM") # [Enduse,EC,Area,Year] Capital Energy Requirement (Btu/Btu)
  CUF::VariableArray{5} = ReadDisk(db,"$CalDB/CUF") # [Enduse,Tech,EC,Area,Year] Capacity Utilization Factor ($/Yr/$/Yr)
  DCTC::VariableArray{5} = ReadDisk(db,"$Outpt/DCTC") # [Enduse,Tech,EC,Area,Year] Device Cap. Trade Off Coefficient (DLESS)
  DFTC::VariableArray{5} = ReadDisk(db,"$Outpt/DFTC") # [Enduse,Tech,EC,Area,Year] Device Fuel Trade Off Coef. (DLESS)
  DSt::VariableArray{4} = ReadDisk(db,"$Outpt/DSt") # [Enduse,EC,Area,Year] Device Saturation (Btu/Btu)
  FsFrac::VariableArray{5} = ReadDisk(db,"$Outpt/FsFrac") # [Fuel,Tech,EC,Area,Year] Feedstock Demands Fuel/Tech Split (Fraction)
  FsPEE::VariableArray{4} = ReadDisk(db,"$CalDB/FsPEE") # [Tech,EC,Area,Year] Feedstock Process Efficiency ($/mmBtu)
  FsFracMax::VariableArray{5} = ReadDisk(db,"$Input/FsFracMax") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  FsFracMin::VariableArray{5} = ReadDisk(db,"$Input/FsFracMin") # [Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu)
  xFsFrac::VariableArray{5} = ReadDisk(db,"$Input/xFsFrac") # [Fuel,Tech,EC,Area,Year] Feedstock Demands Fuel/Tech Split (Fraction)
  MacroSwitch::SetArray = ReadDisk(db,"$MInput/MacroSwitch") # [Nation] String Indicator of Macroeconomic Forecast (TOM,Stokes,AEO,CER)
  MMSM0::VariableArray{5} = ReadDisk(db,"$CalDB/MMSM0") # [Enduse,Tech,EC,Area,Year] Non-price Factors. ($/$)
  PCCN::VariableArray{4} = ReadDisk(db,"$Outpt/PCCN") # [Enduse,Tech,EC,Area] Normalized Process Capital Cost ($/mmBtu)
  PCTC::VariableArray{5} = ReadDisk(db,"$Outpt/PCTC") # [Enduse,Tech,EC,Area,Year] Process Capital Trade Off Coefficient (DLESS)
  PEM::VariableArray{3} = ReadDisk(db,"$CalDB/PEM") # [Enduse,EC,Area] Maximum Process Efficiency ($/mmBtu)
  PEMM::VariableArray{5} = ReadDisk(db,"$CalDB/PEMM") # [Enduse,Tech,EC,Area,Year] Process Energy Effic. Max. Mult. ($/Btu/($/Btu))
  PEPM::VariableArray{5} = ReadDisk(db,"$Input/PEPM") # [Enduse,Tech,EC,Area,Year] Process Energy Price Mult. ($/$)
  PFTC::VariableArray{5} = ReadDisk(db,"$Outpt/PFTC") # [Enduse,Tech,EC,Area,Year] Process Fuel Trade Off Coefficient
  PFPN::VariableArray{4} = ReadDisk(db,"$Outpt/PFPN") # [Enduse,Tech,EC,Area] Process Normalized Fuel Price ($/mmBtu)
  StockAdjustment::VariableArray{5} = ReadDisk(db,"$Input/StockAdjustment") # [Enduse,Tech,EC,Area,Year] Exogenous Capital Stock Adjustment ($/$)
  
  # Emissions Variables
  FlPOCX::VariableArray{4} = ReadDisk(db,"$MEInput/FlPOCX") # [ECC,Poll,Area,Year] Fugitive Flaring Emissions Coefficient (Tonnes/Driver)
  FuPOCX::VariableArray{4} = ReadDisk(db,"$MEInput/FuPOCX") # [ECC,Poll,Area,Year] Other Fugitive Emissions Coefficient (Tonnes/Driver)
  MEPOCX::VariableArray{4} = ReadDisk(db,"$MEInput/MEPOCX") # [ECC,Poll,Area,Year] Non-Energy Pollution Coefficient (Tonnes/$B-output)
  VnPOCX::VariableArray{4} = ReadDisk(db,"$MEInput/VnPOCX") # [ECC,Poll,Area,Year] Fugitive Venting Emissions Coefficient (Tonnes/Driver)
end
 
function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Input,MEInput,Outpt) = data
  (; Area,EC,ECC,Enduse,Enduses,Fuels,Nation,Poll,Polls,Tech,Techs) = data
  (; ANMap,CERSM,CUF,DCTC,DFTC,DSt,FsFrac,FsPEE) = data
  (; MacroSwitch,MMSM0,PCCN,PCTC,PEM,PEMM,PEPM,PFTC,PFPN) = data
  (; StockAdjustment) = data
  (; FlPOCX,FuPOCX,MEPOCX,VnPOCX) = data
 
  CN = Select(Nation,"CN")
  
  # Only proceed if using TOM macro switch
  if MacroSwitch[CN] == "TOM"
    
    # Plant only has Electric and Gas demands
    years = collect(Yr(2023):Final)
    NL = Select(Area,"NL")
    QC = Select(Area,"QC")
    ec = Select(EC,"OtherChemicals")

    for year in years
    # Copy base variables from QC to NL
      for enduse in Enduses, tech in Techs
        CUF[enduse,tech,ec,NL,year] = CUF[enduse,tech,ec,QC,year]
        DCTC[enduse,tech,ec,NL,year] = DCTC[enduse,tech,ec,QC,year]
        DFTC[enduse,tech,ec,NL,year] = DFTC[enduse,tech,ec,QC,year]
        MMSM0[enduse,tech,ec,NL,year] = MMSM0[enduse,tech,ec,QC,year]
        PCTC[enduse,tech,ec,NL,year] = PCTC[enduse,tech,ec,QC,year]
        PEMM[enduse,tech,ec,NL,year] = PEMM[enduse,tech,ec,QC,year]
        PEPM[enduse,tech,ec,NL,year] = PEPM[enduse,tech,ec,QC,year]
        PFTC[enduse,tech,ec,NL,year] = PFTC[enduse,tech,ec,QC,year]
        StockAdjustment[enduse,tech,ec,NL,year] = 0.00
      end

      # Copy variables without tech dimension
      for enduse in Enduses
        CERSM[enduse,ec,NL,year] = CERSM[enduse,ec,QC,year]
        DSt[enduse,ec,NL,year] = DSt[enduse,ec,QC,year]
      end
    end

    # Copy variables without year dimension
    for enduse in Enduses, tech in Techs
      PCCN[enduse,tech,ec,NL] = PCCN[enduse,tech,ec,QC]
      PFPN[enduse,tech,ec,NL] = PFPN[enduse,tech,ec,QC]
    end

    # Copy PEM which has only enduse/ec/area dimensions
    for enduse in Enduses
      PEM[enduse,ec,NL] = PEM[enduse,ec,QC]
    end
    
    # Feedstock Demands
    for year in years, tech in Techs
      for fuel in Fuels
        FsFrac[fuel,tech,ec,NL,year] = FsFrac[fuel,tech,ec,QC,year]
      end
      FsPEE[tech,ec,NL,year] = FsPEE[tech,ec,QC,year]
    end
    
    # Get rid of historical 2022 electricity values for EUPC, 
    # PER, and DER by setting StockAdjustment=-1. 03/20/24 R.Levesque
    enduses = Select(Enduse, ["Heat", "OthSub"])
    elec = Select(Tech,"Electric")
    ec = Select(EC, "OtherChemicals")
    NL = Select(Area, "NL")
    year = Yr(2022)
    for enduse in enduses
      StockAdjustment[enduse,elec,ec,NL,year] = -1.0
    end
    
    # Match fuel shares from Ash. 03/18/24 R.Levesque
    years = collect(Yr(2023):Final)
    for enduse in enduses, year in years
      MMSM0[enduse,Techs,ec,NL,year] .= -170.0
      MMSM0[enduse,Select(Tech,"Electric"),ec,NL,year] = -10.0
      MMSM0[enduse,Select(Tech,"Gas"),ec,NL,year] = 0.0
    end
    
    # Adjust energy demands to match Ash
    # 03/18/24 R.Levesque
    for enduse in Enduses
      CERSM[enduse,ec,NL,Yr(2023)] *= 0.009
      CERSM[enduse,ec,NL,Yr(2024)] *= 0.052
      CERSM[enduse,ec,NL,Yr(2025)] *= 0.060
      CERSM[enduse,ec,NL,Yr(2026)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2027)] *= 0.063
      CERSM[enduse,ec,NL,Yr(2028)] *= 0.064
      CERSM[enduse,ec,NL,Yr(2029)] *= 0.066
      CERSM[enduse,ec,NL,Yr(2030)] *= 0.067
      CERSM[enduse,ec,NL,Yr(2031)] *= 0.068
      CERSM[enduse,ec,NL,Yr(2032)] *= 0.068
      CERSM[enduse,ec,NL,Yr(2033)] *= 0.067
      CERSM[enduse,ec,NL,Yr(2034)] *= 0.065
      CERSM[enduse,ec,NL,Yr(2035)] *= 0.063
      CERSM[enduse,ec,NL,Yr(2036)] *= 0.062
      CERSM[enduse,ec,NL,Yr(2037)] *= 0.063
      CERSM[enduse,ec,NL,Yr(2038)] *= 0.063
      CERSM[enduse,ec,NL,Yr(2039)] *= 0.062
      CERSM[enduse,ec,NL,Yr(2040)] *= 0.062
      CERSM[enduse,ec,NL,Yr(2041)] *= 0.062
      CERSM[enduse,ec,NL,Yr(2042)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2043)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2044)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2045)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2046)] *= 0.061
      CERSM[enduse,ec,NL,Yr(2047)] *= 0.060
      CERSM[enduse,ec,NL,Yr(2048)] *= 0.060
      CERSM[enduse,ec,NL,Yr(2049)] *= 0.059
      CERSM[enduse,ec,NL,Yr(2050)] *= 0.058
    end
    
    # Apply yearly FsPEE adjustments 
    for tech in Techs
      FsPEE[tech,ec,NL,Yr(2023)] *= 0.0135 * 0.99 * 12.4
      FsPEE[tech,ec,NL,Yr(2024)] *= 0.0240 * 0.99 * 7.8
      FsPEE[tech,ec,NL,Yr(2025)] *= 0.0296 * 0.999 * 8.2 
      FsPEE[tech,ec,NL,Yr(2026)] *= 0.0353 * 0.99 * 7.0
      FsPEE[tech,ec,NL,Yr(2027)] *= 0.0325 * 0.733 * 4.8
      FsPEE[tech,ec,NL,Yr(2028)] *= 0.0342 * 0.733 * 4.5
      FsPEE[tech,ec,NL,Yr(2029)] *= 0.0317 * 0.732 * 2.98
      FsPEE[tech,ec,NL,Yr(2030)] *= 0.0419 * 0.731 * 2.3
      FsPEE[tech,ec,NL,Yr(2031)] *= 0.0499 * 0.732 * 1.9
      FsPEE[tech,ec,NL,Yr(2032)] *= 0.0575 * 0.732 * 1.67
      FsPEE[tech,ec,NL,Yr(2033)] *= 0.0641 * 0.732 * 1.50
      FsPEE[tech,ec,NL,Yr(2034)] *= 0.0617 * 0.731 * 2.1
      FsPEE[tech,ec,NL,Yr(2035)] *= 0.0695 * 0.732 * 1.9
      FsPEE[tech,ec,NL,Yr(2036)] *= 0.0776 * 0.732 * 1.7
      FsPEE[tech,ec,NL,Yr(2037)] *= 0.0809 * 0.732 * 1.6
      FsPEE[tech,ec,NL,Yr(2038)] *= 0.0847 * 0.732 * 1.6
      FsPEE[tech,ec,NL,Yr(2039)] *= 0.0885 * 0.732 * 1.5
      FsPEE[tech,ec,NL,Yr(2040)] *= 0.1719 * 0.727 * 1.002
      FsPEE[tech,ec,NL,Yr(2041)] *= 0.1751 * 0.732 * 1.03
      FsPEE[tech,ec,NL,Yr(2042)] *= 0.1796 * 0.732 * 1.02
      FsPEE[tech,ec,NL,Yr(2043)] *= 0.1830 * 0.732 * 1.02
      FsPEE[tech,ec,NL,Yr(2044)] *= 0.1868 * 0.732 * 1.01
      FsPEE[tech,ec,NL,Yr(2045)] *= 0.1909 * 0.732 * 1.01
      FsPEE[tech,ec,NL,Yr(2046)] *= 0.1959 * 0.732 * 1.01
      FsPEE[tech,ec,NL,Yr(2047)] *= 0.2001 * 0.732 * 1.007
      FsPEE[tech,ec,NL,Yr(2048)] *= 0.2043 * 0.732 * 1.01
      FsPEE[tech,ec,NL,Yr(2049)] *= 0.2083 * 0.732 * 1.0
      FsPEE[tech,ec,NL,Yr(2050)] *= 0.2121 * 0.732 * 1.0
    end
    
    # Write updated variables
    WriteDisk(db,"$CalDB/CERSM",CERSM)
    WriteDisk(db,"$CalDB/CUF",CUF)
    WriteDisk(db,"$Outpt/DCTC",DCTC)
    WriteDisk(db,"$Outpt/DFTC",DFTC)
    WriteDisk(db,"$Outpt/DSt",DSt)
    WriteDisk(db,"$CalDB/MMSM0",MMSM0)
    WriteDisk(db,"$Input/StockAdjustment",StockAdjustment)
    
    WriteDisk(db,"$Outpt/PCCN",PCCN)
    WriteDisk(db,"$Outpt/PCTC",PCTC)
    WriteDisk(db,"$CalDB/PEM",PEM)
    WriteDisk(db,"$CalDB/PEMM",PEMM)
    WriteDisk(db,"$Input/PEPM",PEPM)
    WriteDisk(db,"$Outpt/PFPN",PFPN)
    WriteDisk(db,"$Outpt/PFTC",PFTC)

    WriteDisk(db,"$Outpt/FsFrac",FsFrac)
    WriteDisk(db,"$CalDB/FsPEE",FsPEE)
    
    
    # Copy emissions coefficients from QC to NL
    ecc = Select(ECC,"OtherChemicals")
    for  poll in Polls, year in years
      FlPOCX[ecc,poll,NL,year] = FlPOCX[ecc,poll,QC,year]
      FuPOCX[ecc,poll,NL,year] = FuPOCX[ecc,poll,QC,year]
      MEPOCX[ecc,poll,NL,year] = MEPOCX[ecc,poll,QC,year]
      VnPOCX[ecc,poll,NL,year] = VnPOCX[ecc,poll,QC,year]
    end
    
    WriteDisk(db,"$MEInput/FlPOCX",FlPOCX)
    WriteDisk(db,"$MEInput/FuPOCX",FuPOCX)
    WriteDisk(db,"$MEInput/MEPOCX",MEPOCX)
    WriteDisk(db,"$MEInput/VnPOCX",VnPOCX)
  end # MacroSwitch = TOM
end

function PolicyControl(db)
 @info "AdjustNLOtherChemicals_A_TOM.jl - PolicyControl"
 IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
 PolicyControl(DB)
end

end
