#
# CAC_VOC_PetroleumSectors.jl - This jl models the VOC emission reductions for PRG-VOC Regulations
# Coefficient Multipliers Updated by Howard (Taeyeong) Park - 23.09.14
#     Updated multipliers are calculated in "230911_CAC_VOC_PetroleumSectors Analysis.xlsx
#

using SmallModel

module CAC_VOC_PetroleumSectors

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
  FuPOCX::VariableArray{4} = ReadDisk(db,"MEInput/FuPOCX") # [ECC,Poll,Area,Year] Other Fugitive Emissions Coefficient (Tonnes/Driver)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(ECC),length(Poll),length(Year)) # [ECC,Poll,Year] Scratch Variable For Input Reductions
end

function MacroPolicy(db)
  data = MControl(; db)
  (; Area,ECC) = data
  (; Poll) = data
  (; FuPOCX) = data
  (; Reduce) = data

  #
  # Read in reductions to marginal coefficient calculated by Environment Canada 
  # for downstream petroleum sectors for VOC emissions.
  #
  # Data is from VOC_PetroleumSectors_Coeff_calculations.xlsx
  #
  @. Reduce=1

  #
  ################
  #Alberta
  ################
  #
  areas = Select(Area,"AB")
  eccs = Select(ECC,["OilSandsUpgraders","Petrochemicals","Petroleum"])
  years = collect(Yr(2020):Yr(2037))
  VOC = Select(Poll,"VOC")
  #! format: off
  Reduce[eccs, VOC, years] .= [
    # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
      1.00    1.00    0.9521  0.9240  0.9232  0.9223  0.9244  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198  0.9198
      1.00    1.00    0.7605  0.6266  0.6250  0.6438  0.6625  0.6478  0.6787  0.7110  0.7346  0.7545  0.7606  0.7668  0.7729  0.7784  0.7840  0.7893
      1.00    1.00    0.8910  0.8325  0.8325  0.8325  0.8325  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234  0.8234
          ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  #
  ################
  #British Columbia
  ################
  #
  areas = Select(Area,"BC")
  eccs = Select(ECC,"Petroleum")
  years = collect(Yr(2020):Yr(2037))
  #! format: off
  Reduce[eccs, VOC, years] = [
    # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
      1.00    1.00    0.8985  0.8455  0.8455  0.8403  0.8403  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364  0.8364
    ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  #
  ################
  #New Brunswick
  ################
  #
  areas = Select(Area,"NB")
  eccs = Select(ECC,"Petroleum")
  years = collect(Yr(2020):Yr(2037))
  #! format: off
  Reduce[eccs, VOC, years] = [
    # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
      1.00    1.00    0.6554  0.4681  0.4680  0.4680  0.4680  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392  0.4392
    ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  #
  ################
  #Newfoundland
  ################
  #
  # NOTE: Newfoundland Petro. Prod. facilities are converted to biofuel units.
  #    Updated by Howard (Taeyeong) Park - 22.10.04
  #
  # areas = Select(Area,"NL")
  # eccs = Select(ECC,"Petroleum")
  # years = collect(Yr(2020):Yr(2037))
  #! format: off
  # Reduce[eccs, VOC, years] = [
  #   # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
  #     1.00    1.00    0.5340  0.3287  0.3287  0.3287  0.3287  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865  0.2865 # Petroleum Products
  #   ]
  #! format: on

  # #
  # # Apply reductions to coefficient
  # #
  # years = collect(Future:Yr(2037))
  # for year in years, area in areas, poll in VOC, ecc in eccs
  #   FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  # end

  # years = collect(Yr(2038):Final)
  # for year in years, area in areas, poll in VOC, ecc in eccs
  #   FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  # end

  #
  ################
  #Ontario
  ################
  #
  areas = Select(Area,"ON")
  eccs = Select(ECC,["Petrochemicals","Petroleum"])
  years = collect(Yr(2020):Yr(2037))
  #! format: off
  Reduce[eccs, VOC, years] .= [
    # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
      1.00    1.00    0.9357  0.9104  0.9112  0.9204  0.9267  0.9227  0.9184  0.9105  0.9024  0.8935  0.8953  0.8967  0.8974  0.8985  0.8994  0.9003
      1.00    1.00    0.7932  0.6925  0.6925  0.7020  0.7072  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935  0.6935
    ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  #
  ################
  #Quebec
  ################
  #
  areas = Select(Area,"QC")
  eccs = Select(ECC,"Petroleum")
  years = collect(Yr(2020):Yr(2037))
  #! format: off
  Reduce[eccs, VOC, years] = [
    # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
      1.00    1.00    0.6122  0.4671  0.4671  0.4671  0.4671  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400  0.4400
    ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  #
  ################
  #Quebec
  ################
  #
  areas = Select(Area,"SK")
  eccs = Select(ECC,["OilSandsUpgraders","Petroleum"])
  years = collect(Yr(2020):Yr(2037))
  #! format: off
  Reduce[eccs, VOC, years] = [
  # 2020    2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037 # Volatile Org Comp.
    1.00    1.00    0.9413  0.9113  0.9113  0.9128  0.9128  0.9076  0.9076  0.9076  0.9076  0.9076  0.9076  0.9076  0.9076  0.9066  0.9057  0.9047 #  Oil Sands Upgraders
    1.00    11.00   0.8184  0.7163  0.7159  0.7159  0.7159  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987  0.6987
  ]
  #! format: on

  #
  # Apply reductions to coefficient
  #
  years = collect(Future:Yr(2037))
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,year]*Reduce[ecc,poll,year]
  end

  years = collect(Yr(2038):Final)
  for year in years, area in areas, poll in VOC, ecc in eccs
    FuPOCX[ecc,poll,area,year] = FuPOCX[ecc,poll,area,Yr(2037)]
  end

  WriteDisk(db,"MEInput/FuPOCX",FuPOCX)
end

function PolicyControl(db)
  @info "CAC_VOC_PetroleumSectors.jl - PolicyControl"
  MacroPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
