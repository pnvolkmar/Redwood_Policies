#
# Ind_Fungible_Coefficients.jl - Fungible Demands Market Share Calibration 
#

using SmallModel

module Ind_Fungible_Coefficients

import ...SmallModel: ReadDisk,WriteDisk,Select
import ...SmallModel: HisTime,ITime,MaxTime,First,Future,Final,Yr
import ...SmallModel: @finite_math,finite_inverse,finite_divide,finite_power,finite_exp,finite_log,HasValues
import ...SmallModel: DB

const VariableArray{N} = Array{Float64,N} where {N}
const SetArray = Vector{String}

Base.@kwdef struct IControl
  db::String

  CalDB::String = "ICalDB"
  Input::String = "IInput"
  Outpt::String = "IOutput"
  BCNameDB::String = ReadDisk(db,"E2020DB/BCNameDB") #  Base Case Name
  RefNameDB::String = ReadDisk(db,"E2020DB/RefNameDB") #  Reference Case Name

  Area::SetArray = ReadDisk(db,"E2020DB/AreaKey")
  AreaDS::SetArray = ReadDisk(db,"E2020DB/AreaDS")
  Areas::Vector{Int} = collect(Select(Area))
  EC::SetArray = ReadDisk(db,"$Input/ECKey")
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  Fuel::SetArray = ReadDisk(db,"E2020DB/FuelKey")
  FuelDS::SetArray = ReadDisk(db,"E2020DB/FuelDS")
  Fuels::Vector{Int} = collect(Select(Fuel))
  # Prior::SetArray = ReadDisk(db,"E2020DB/PriorKey")
  # PriorDS::SetArray = ReadDisk(db,"E2020DB/PriorDS")
  # Priors::Vector{Int} = collect(Select(Prior))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  DmFrac::VariableArray{6} = ReadDisk(db,"$Outpt/DmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Split (Btu/Btu)
  DmFracMarginal::VariableArray{6} = ReadDisk(db,"$Outpt/DmFracMarginal") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Marginal Market Share (Btu/Btu)
  DmFracMax::VariableArray{6} = ReadDisk(db,"$Input/DmFracMax") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Maximum (Btu/Btu)
  DmFracMin::VariableArray{6} = ReadDisk(db,"$Input/DmFracMin") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Minimum (Btu/Btu) 
  DmFracMSF::VariableArray{6} = ReadDisk(db,"$Outpt/DmFracMSF") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Market Share (Btu/Btu)
  DmFracMSM0::VariableArray{6} = ReadDisk(db,"$CalDB/DmFracMSM0") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Fraction Non-Price Factor (Btu/Btu)
  # DmFracPrior::VariableArray{6} = ReadDisk(db,"$Outpt/DmFracPrior") # [Enduse,Fuel,Tech,EC,Area,Prior] Demand Fuel/Tech Fraction Split (Btu/Btu)
  DmFracTime::VariableArray{6} = ReadDisk(db,"$Input/DmFracTime") # [Enduse,Fuel,Tech,EC,Area,Year] Demand Fuel/Tech Adjustment Time (Years)
  DmFracVF::VariableArray{5} = ReadDisk(db,"$Input/DmFracVF") # [Enduse,Fuel,Tech,EC,Area] Demand Fuel/Tech Fraction Variance Factor (Btu/Btu)
  DPL::VariableArray{5} = ReadDisk(db,"$Outpt/DPL") # [Enduse,Tech,EC,Area,Year] Physical Life of Equipment (Years) 
  ECFP0Ref::VariableArray{4} = ReadDisk(RefNameDB,"$Outpt/ECFP",First) # [Enduse,Tech,EC,Area,First] Fuel Price ($/mmBtu)
  ECFPFuelRef::VariableArray{4} = ReadDisk(RefNameDB,"$Outpt/ECFPFuel") # [Fuel,EC,Area,Year] Fuel Price ($/mmBtu)
  xDmFrac::VariableArray{6} = ReadDisk(db,"$Input/xDmFrac") # [Enduse,Fuel,Tech,EC,Area,Year] Energy Demands Fuel/Tech Split (Btu/Btu)

  # Scratch Variables
  # DmFracCount   'Counter for Demand Fuel/Tech Fraction Market Shares'
  DmFracMAW::VariableArray{5} = zeros(Float64,length(Enduse),length(Fuel),length(Tech),length(EC),length(Area)) # [Enduse,Fuel,Tech,EC,Area] Allocation Weights for Demand Fuel/Tech Fraction (DLess)
  DmFracTMAW::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Total of Allocation Weights for Demand Fuel/Tech Fraction (DLess)
  DmFracMU::VariableArray{5} = zeros(Float64,length(Enduse),length(Fuel),length(Tech),length(EC),length(Area)) # [Enduse,Fuel,Tech,EC,Area] Initial Estimate of Fuel/Tech Fraction Non-Price Factor
  DmFracTotal::VariableArray{4} = zeros(Float64,length(Enduse),length(Tech),length(EC),length(Area)) # [Enduse,Tech,EC,Area] Total of Demand Fuel/Tech Fractions (Btu/Btu)
end

function Fungible(data,techs,ecs,areas,years)
  (; Enduses,Fuels) = data
  (; DmFrac,DmFracMarginal,DmFracMax,DmFracMAW) = data
  (; DmFracMin,DmFracMSF) = data
  (; DmFracMSM0,DmFracTime,DmFracTMAW,DmFracTotal,DmFracVF) = data
  (; ECFP0Ref,ECFPFuelRef) = data

  for year in years
    @finite_math [DmFracMAW[eu,fuel,tech,ec,area] = 
      exp(DmFracMSM0[eu,fuel,tech,ec,area,year] + DmFracVF[eu,fuel,tech,ec,area] * 
        log(ECFPFuelRef[fuel,ec,area,year]/ECFP0Ref[eu,tech,ec,area]))
      for eu in Enduses, fuel in Fuels, tech in techs, ec in ecs, area in areas]

    DmFracTMAW[Enduses,techs,ecs,areas] = 
      sum(DmFracMAW[Enduses,fuel,techs,ecs,areas] for fuel in Fuels)
    
    for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses
      @finite_math DmFracMSF[eu,fuel,tech,ec,area,year] = DmFracMAW[eu,fuel,tech,ec,area] / 
      	DmFracTMAW[eu,tech,ec,area]
    end
        
    # 
    # Apply Minimums and Maximums
    #   
    for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses    
      DmFracMarginal[eu,fuel,tech,ec,area,year] = DmFracMSF[eu,fuel,tech,ec,area,year]
    end
    
    for DmFracCount in 1:10
      for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses
        DmFracMarginal[eu,fuel,tech,ec,area,year] = 
          min(max(DmFracMarginal[eu,fuel,tech,ec,area,year], 
            DmFracMin[eu,fuel,tech,ec,area,year]), 6DmFracMax[eu,fuel,tech,ec,area,year])
      end
                
      DmFracTotal[Enduses,techs,ecs,areas] = 
        sum(DmFracMarginal[Enduses,fuel,techs,ecs,areas,year] for fuel in Fuels) 
        
      for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses
        @finite_math DmFracMarginal[eu,fuel,tech,ec,area,year] = 
          DmFracMarginal[eu,fuel,tech,ec,area,year] / DmFracTotal[eu,tech,ec,area]
      end
      
    end # while DmFracCount < 10

    # DmFracPrior is DmFrac using year-1
    for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses
      DmFrac[eu,fuel,tech,ec,area,year] = DmFrac[eu,fuel,tech,ec,area,year-1] +
        (DmFracMarginal[eu,fuel,tech,ec,area,year] - DmFrac[eu,fuel,tech,ec,area,year-1]) /
           DmFracTime[eu,fuel,tech,ec,area,year]
    end

    for area in areas, ec in ecs, tech in techs, eu in Enduses
      DmFracTotal[eu,tech,ec,area] = sum(DmFrac[eu,fuel,tech,ec,area,year] for fuel in Fuels)
    end
      
    for area in areas, ec in ecs, tech in techs, fuel in Fuels, eu in Enduses
      DmFrac[eu,fuel,tech,ec,area,year] = DmFrac[eu,fuel,tech,ec,area,year] / 
      	DmFracTotal[eu,tech,ec,area]
    end
    
  end
  
end # Fungible

function FungibleCalib(data,eu,fuels,t,ec,a,year)
  (; DmFracMAW,DmFracMSM0,DmFracMU,DmFracVF,ECFP0Ref) = data
  (; ECFPFuelRef,xDmFrac) = data
 
  for f in fuels
    @finite_math DmFracMAW[eu,f,t,ec,a] =
      exp(DmFracVF[eu,f,t,ec,a]*log(ECFPFuelRef[f,ec,a,year]/ECFP0Ref[eu,t,ec,a]))

    @finite_math DmFracMU[eu,f,t,ec,a] = 
      xDmFrac[eu,f,t,ec,a,year]/DmFracMAW[eu,f,t,ec,a]
  end
  
  @.  @finite_math DmFracMSM0[eu,fuels,t,ec,a,year] = 
    log(DmFracMU[eu,fuels,t,ec,a]/maximum(DmFracMU[eu,f,t,ec,a] for f in fuels))
  
  # if (Enduse[eu] == "Heat")
    #   @info " "
    #   EuKey = Enduse[eu]
    #   TechKey = Tech[t]
    #   EcKey = EC[ec]
    #   AreaKey = EC[ec]
    #   YearKey = Year[y]
    #   @info "$EuKey, $TechKey, $EcKey, $AreaKey, $YearKey"
    #   ZZZ = DmFracMSM0[eu,fuel,t,ec,a,y]
    #   @info "DmFracMSM0 = $ZZZ"
    #   ZZZ = ECFPFuelRef[fuel,ec,a,y]
    #   @info "ECFPFuelRef = $ZZZ"
    #   ZZZ = ECFP0Ref[eu,t,ec,a,y]
    #   @info "ECFP0Ref = $ZZZ"
    #   ZZZ = DmFracMAW[eu,fuel,t,ec,a]
    #   @info "DmFracMAW = $ZZZ"
    #   ZZZ = DmFracMU[eu,fuel,t,ec,a]
    #   @info "DmFracMU = $ZZZ"
    #   @info " "
    # end
  # end
end #FungibleCalib

function ControlFungibleCalib(data,techs,ecs,areas,years)
  (; Enduses,Fuels,Year) = data
  (; Enduses,Fuels,Year) = data
  (; DmFracMSM0,ECFPFuelRef,xDmFrac) = data

  for eu in Enduses, fuel in Fuels, tech in techs, ec in ecs, area in areas, year in years
    DmFracMSM0[eu,fuel,tech,ec,area,year] = -170.391
  end
    
  for year in years, area in areas, ec in ecs, tech in techs, eu in Enduses
    fuelsxDMFrac = Select(xDmFrac[eu,Fuels,tech,ec,area,year],>(0.0))
    fuelsECFPFuel = Select(ECFPFuelRef[Fuels,ec,area,year],>(0.0))
    fuels = intersect(fuelsxDMFrac,fuelsECFPFuel)
    if HasValues(fuels)
      FungibleCalib(data,eu,fuels,tech,ec,area,year)
    else
      DmFracMSM0[eu,fuels,tech,ec,area,year] = DmFracMSM0[eu,fuels,tech,ec,area,year-1]
    end
    
  end

end # ControlFungibleCalib

function ControlFlow(data)
  (; Area,EC,Enduses,Fuels,Tech) = data
  (; DmFracMSM0) = data

  #
  # To save execution time, just do the sectors needed. - Jeff Amlin 09/06/21
  #     
  area = Select(Area,"AB")
  ecs = Select(EC,["Petrochemicals","Petroleum","OilSandsUpgraders"])
  tech = Select(Tech,"Gas")
  years = collect(Yr(2024):Yr(2030))
  ControlFungibleCalib(data,tech,ecs,area,years)

  years = collect(Yr(2031):Yr(2050))
  for eu in Enduses, fuel in Fuels, ec in ecs, year in years
    DmFracMSM0[eu,fuel,tech,ec,area,year] = DmFracMSM0[eu,fuel,tech,ec,area,Yr(2030)]
  end
   
  #
  # Check results
  #  
  years = collect(Yr(2024):Yr(2050))
  ControlFungibleCalib(data,tech,ecs,area,years)

end # ControlFlow

function IndPolicy(db)
  data = IControl(; db)
  (; CalDB,Outpt) = data
  (; DmFrac,DmFracMarginal) = data 
  (; DmFracMSF,DmFracMSM0) = data
  
  ControlFlow(data)

  WriteDisk(db,"$CalDB/DmFracMSM0",DmFracMSM0)
  WriteDisk(db,"$Outpt/DmFrac",DmFrac)
  WriteDisk(db,"$Outpt/DmFracMarginal",DmFracMarginal)
  WriteDisk(db,"$Outpt/DmFracMSF",DmFracMSF)
end

function PolicyControl(db)
  @info "Ind_Fungible_Coefficients.jl - PolicyControl"
  IndPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
