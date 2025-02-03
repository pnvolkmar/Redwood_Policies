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
      1.00    1.00    0.9456  0.9178  0.9178  0.9192  0.9192  0.9143  0.9143  0.9143  0.9143  0.9143  0.9143  0.9143  0.9143  0.9134  0.9126  0.9117 # Oil Sands Upgraders
      1.00    1.00    0.6950  0.5505  0.5669  0.5827  0.5991  0.5797  0.5942  0.6069  0.6204  0.6315  0.6420  0.6525  0.6627  0.6726  0.6816  0.6906 # Petrochemicals
      1.00    1.00    0.8843  0.8223  0.8223  0.8223  0.8223  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126  0.8126 # Petroleum Products
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
      1.00    1.00    0.8844  0.8239  0.8239  0.8180  0.8180  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136  0.8136 #  Petroleum Products
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
      1.00    1.00    0.4271  0.1157  0.1156  0.1156  0.1156  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677  0.0677 # Petroleum Products
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
      1.00    1.00    0.9130  0.8838  0.8881  0.8989  0.9052  0.9002  0.9036  0.9067  0.9099  0.9125  0.9150  0.9175  0.9199  0.9223  0.9244  0.9265 #  Petrochemicals
      1.00    1.00    0.8779  0.8185  0.8185  0.8241  0.8272  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191  0.8191 #  Petroleum Products
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
      1.00    1.00    0.8028  0.7290  0.7290  0.7290  0.7290  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152  0.7152 # Petroleum Products
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
    1.00    1.00    0.9028  0.8481  0.8479  0.8479  0.8479  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387  0.8387 #  Petroleum Products
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
