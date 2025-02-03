#
# CAC_OffRoad.jl - simulates the 'OffRoad Engine Tire4 Policy' for
# diesel vehicles and 'OffRoad Small Spark-Ignition Policy' for
# gasoline vehicles. Ian 03/27/2012
# Note that the tables contain historical data; these values are only in the temp Reduce variable
# and the overwrite of model variables should start in the first forecast year using the 2018-2035
# pointer. - Hilary 15.04.14
#
# Changed 2015 to 2018 - Andy 18.10.02
#

using SmallModel

module CAC_OffRoad

import ...SmallModel: ReadDisk,WriteDisk,Select,HisTime,ITime,MaxTime,First,Last,Future,DB,Final,Yr
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
  ECDS::SetArray = ReadDisk(db,"$Input/ECDS")
  ECs::Vector{Int} = collect(Select(EC))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
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
  xRM::VariableArray{5} = ReadDisk(db,"$Input/xRM") # [FuelEP,EC,Poll,Area,Year] Exogenous Average Pollution Coefficient Reduction Multiplier (Tonnes/Tonnes)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Year)) # [EC,Poll,Year] Scratch Variable For Input Reductions
end

function IndPolicy(db)
  data = IControl(; db)
  (; Input) = data
  (; EC,FuelEP) = data
  (; Nation,Poll) = data
  (; ANMap,Reduce,xRM) = data

  #
  # Read in reductions to marginal coefficient calculated by EnvCa for Off-Road Diesel
  # engines for various economic sectors.
  #
  # Data is from 'RevisedPolicy_offroad_DieselGasoline_05OCT2016.xlsx' via Lifang
  #
  # Don't change PollSw for now. Ian - 03/27/12
  #
  @. Reduce = 1.0

  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)

  ec1 = Select(EC,(from="IronOreMining",to="FrontierOilMining"))
  ec2 = Select(EC,["OilSandsMining","ConventionalGasProduction","UnconventionalGasProduction"])
  ec3 = Select(EC,(from="CoalMining",to="OnFarmFuelUse"))
  ecs = union(ec1,ec2,ec3)

  years = collect(Yr(2021):Yr(2035))

  PMT = Select(Poll,"PMT")
  #! format: off
  Reduce[ecs, PMT, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter Total
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Iron Ore Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Other Metal Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Non-Metal Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Light Oil Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Heavy Oil Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Frontier Oil Mining
    0.6349  0.6058  0.5777  0.5507  0.5247  0.5172  0.5096  0.5017  0.4935  0.5010  0.5123  0.5277  0.5186  0.5099  0.5016 # Oil Sands Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Conv. Gas Production
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # UnConv Gas Production
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Coal Mining
    0.6375  0.6021  0.5665  0.5310  0.4953  0.4737  0.4521  0.4305  0.4089  0.3867  0.3815  0.3765  0.3728  0.3694  0.3662 # Construction
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Forestry
    0.6375  0.6021  0.5665  0.5310  0.4953  0.4737  0.4521  0.4305  0.4089  0.3867  0.3815  0.3765  0.3728  0.3694  0.3662 # On Farm Fuel Use
  ]
  #! format: on

  PM10 = Select(Poll,"PM10")
  #! format: off
  Reduce[ecs, PM10, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter 10
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Iron Ore Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Other Metal Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Non-Metal Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Light Oil Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Heavy Oil Mining
    0.6095  0.5762  0.5429  0.5094  0.4759  0.4530  0.4302  0.4075  0.3850  0.3576  0.3475  0.3361  0.3332  0.3305  0.3281 # Frontier Oil Mining
    0.6349  0.6058  0.5777  0.5507  0.5247  0.5172  0.5096  0.5017  0.4935  0.5010  0.5123  0.5277  0.5186  0.5099  0.5016 # Oil Sands Mining
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Conv. Gas Production
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # UnConv Gas Production
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Coal Mining
    0.6375  0.6021  0.5665  0.5310  0.4953  0.4737  0.4521  0.4305  0.4089  0.3867  0.3815  0.3765  0.3728  0.3694  0.3662 # Construction
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Forestry
    0.6375  0.6021  0.5665  0.5310  0.4953  0.4737  0.4521  0.4305  0.4089  0.3867  0.3815  0.3765  0.3728  0.3694  0.3662 # On Farm Fuel Use
  ]
  #! format: on

  PM25 = Select(Poll,"PM25")
  #! format: off
  Reduce[ecs, PM25, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter 2.5
    0.6174  0.5847  0.5520  0.5193  0.4864  0.4640  0.4416  0.4194  0.3973  0.3705  0.3606  0.3494  0.3466  0.3440  0.3415 # Iron Ore Mining
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3704  0.3605  0.3493  0.3465  0.3438  0.3414 # Other Metal Mining
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3703  0.3605  0.3493  0.3465  0.3438  0.3414 # Non-Metal Mining
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # Light Oil Mining
    0.6168  0.5841  0.5513  0.5185  0.4856  0.4631  0.4408  0.4185  0.3964  0.3695  0.3596  0.3484  0.3456  0.3429  0.3405 # Heavy Oil Mining
    0.6196  0.5871  0.5546  0.5220  0.4894  0.4671  0.4449  0.4228  0.4008  0.3741  0.3643  0.3532  0.3504  0.3478  0.3453 # Frontier Oil Mining
    0.6096  0.5784  0.5484  0.5195  0.4917  0.4838  0.4756  0.4671  0.4584  0.4663  0.4785  0.4950  0.4852  0.4759  0.4671 # Oil Sands Mining
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # Conv. Gas Production
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # UnConv Gas Production
    0.6172  0.5846  0.5519  0.5191  0.4862  0.4638  0.4414  0.4192  0.3971  0.3702  0.3604  0.3492  0.3464  0.3437  0.3413 # Coal Mining
    0.6403  0.6052  0.5700  0.5346  0.4993  0.4778  0.4564  0.4350  0.4135  0.3915  0.3864  0.3814  0.3778  0.3743  0.3712 # Construction
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3704  0.3605  0.3493  0.3465  0.3438  0.3414 # Forestry
    0.6403  0.6052  0.5700  0.5346  0.4993  0.4778  0.4564  0.4350  0.4135  0.3915  0.3864  0.3814  0.3778  0.3743  0.3712 # On Farm Fuel Use
  ]
  #! format: on

  BC = Select(Poll,"BC")
  #! format: off
  Reduce[ecs, BC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Black Carbon
    0.6174  0.5847  0.5520  0.5193  0.4864  0.4640  0.4416  0.4194  0.3973  0.3705  0.3606  0.3494  0.3466  0.3440  0.3415 # Iron Ore Mining
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3704  0.3605  0.3493  0.3465  0.3438  0.3414 # Other Metal Mining
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3703  0.3605  0.3493  0.3465  0.3438  0.3414 # Non-Metal Mining
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # Light Oil Mining
    0.6168  0.5841  0.5513  0.5185  0.4856  0.4631  0.4408  0.4185  0.3964  0.3695  0.3596  0.3484  0.3456  0.3429  0.3405 # Heavy Oil Mining
    0.6196  0.5871  0.5546  0.5220  0.4894  0.4671  0.4449  0.4228  0.4008  0.3741  0.3643  0.3532  0.3504  0.3478  0.3453 # Frontier Oil Mining
    0.6096  0.5784  0.5484  0.5195  0.4917  0.4838  0.4756  0.4671  0.4584  0.4663  0.4785  0.4950  0.4852  0.4759  0.4671 # Oil Sands Mining
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # Conv. Gas Production
    0.6179  0.5854  0.5527  0.5200  0.4872  0.4648  0.4425  0.4203  0.3982  0.3714  0.3616  0.3504  0.3476  0.3450  0.3426 # UnConv Gas Production
    0.6172  0.5846  0.5519  0.5191  0.4862  0.4638  0.4414  0.4192  0.3971  0.3702  0.3604  0.3492  0.3464  0.3437  0.3413 # Coal Mining
    0.6403  0.6052  0.5700  0.5346  0.4993  0.4778  0.4564  0.4350  0.4135  0.3915  0.3864  0.3814  0.3778  0.3743  0.3712 # Construction
    0.6173  0.5846  0.5519  0.5192  0.4863  0.4639  0.4415  0.4193  0.3972  0.3704  0.3605  0.3493  0.3465  0.3438  0.3414 # Forestry
    0.6403  0.6052  0.5700  0.5346  0.4993  0.4778  0.4564  0.4350  0.4135  0.3915  0.3864  0.3814  0.3778  0.3743  0.3712 # On Farm Fuel Use
  ]
  #! format: on

  NOX = Select(Poll,"NOX")
  #! format: off
  Reduce[ecs, NOX, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Nitrogen Oxides
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Iron Ore Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Other Metal Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Non-Metal Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Light Oil Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Heavy Oil Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Frontier Oil Mining
    0.9394  0.8859  0.8338  0.7830  0.7338  0.7254  0.7183  0.7128  0.7094  0.7737  0.8092  0.8598  0.8143  0.7703  0.7277 # Oil Sands Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Conv. Gas Production
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # UnConv Gas Production
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Coal Mining
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Construction
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Forestry
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # On Farm Fuel Use
  ]
  #! format: on

  VOC = Select(Poll,"VOC")
  #! format: off
  Reduce[ecs, VOC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Volatile Org Comp.
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Iron Ore Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Other Metal Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Non-Metal Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Light Oil Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Heavy Oil Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Frontier Oil Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Oil Sands Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Conv. Gas Production
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # UnConv Gas Production
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Coal Mining
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Construction
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Forestry
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # On Farm Fuel Use
  ]
  #! format: on

  polls = Select(Poll,["PMT","PM10","PM25","BC","NOX","VOC"])
  Diesel = Select(FuelEP,"Diesel")

  #
  # xRM equals 1 if there are no reductions so multiply existing value for
  # each year in case sector has existing reductions via other policy.
  #
  years = collect(Future:Yr(2035))
  for year in years, area in areas, poll in polls, ec in ecs
    xRM[Diesel,ec,poll,area,year] = xRM[Diesel,ec,poll,area,year]*
      Reduce[ec,poll,year]/Reduce[ec,poll,Last]
  end

  years = collect(Yr(2035):Final)
  for year in years, area in areas, poll in polls, ec in ecs
    xRM[Diesel,ec,poll,area,year] = xRM[Diesel,ec,poll,area,Yr(2035)]
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
  Enduse::SetArray = ReadDisk(db,"$Input/EnduseKey")
  EnduseDS::SetArray = ReadDisk(db,"$Input/EnduseDS")
  Enduses::Vector{Int} = collect(Select(Enduse))
  FuelEP::SetArray = ReadDisk(db,"E2020DB/FuelEPKey")
  FuelEPDS::SetArray = ReadDisk(db,"E2020DB/FuelEPDS")
  FuelEPs::Vector{Int} = collect(Select(FuelEP))
  Nation::SetArray = ReadDisk(db,"E2020DB/NationKey")
  NationDS::SetArray = ReadDisk(db,"E2020DB/NationDS")
  Nations::Vector{Int} = collect(Select(Nation))
  Poll::SetArray = ReadDisk(db,"E2020DB/PollKey")
  PollDS::SetArray = ReadDisk(db,"E2020DB/PollDS")
  Polls::Vector{Int} = collect(Select(Poll))
  Tech::SetArray = ReadDisk(db,"$Input/TechKey")
  TechDS::SetArray = ReadDisk(db,"$Input/TechDS")
  Techs::Vector{Int} = collect(Select(Tech))
  Year::SetArray = ReadDisk(db,"E2020DB/YearKey")
  YearDS::SetArray = ReadDisk(db,"E2020DB/YearDS")
  Years::Vector{Int} = collect(Select(Year))

  ANMap::VariableArray{2} = ReadDisk(db,"E2020DB/ANMap") # [Area,Nation] Map between Area and Nation
  POCX::VariableArray{7} = ReadDisk(db,"$Input/POCX") # [Enduse,FuelEP,Tech,EC,Poll,Area,Year] Marginal Pollution Coefficients (Tonnes/TBtu)

  # Scratch Variables
  Reduce::VariableArray{3} = zeros(Float64,length(EC),length(Poll),length(Year)) # [EC,Poll,Year] Scratch Variable For Input Reductions
end

function TransPolicy(db)
  data = TControl(; db)
  (; Input) = data
  (; EC,Enduses) = data
  (; FuelEP,Nation) = data
  (; Poll,Techs) = data
  (; Year) = data
  (; ANMap,POCX,Reduce) = data

  @. Reduce = 1.0

  #
  # Transportation portion of the OffRoad Diesel regulation from above.
  # 
  CN = Select(Nation,"CN")
  areas = findall(ANMap[:,CN] .== 1)
  ecs = Select(EC,["ResidentialOffRoad","CommercialOffRoad"])
  years = Select(Year,(from="2021",to="2035"))

  PMT = Select(Poll,"PMT")
  #! format: off
  Reduce[ecs, PMT, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter Tot
    0.6237  0.5898  0.5558  0.5217  0.4876  0.4654  0.4432  0.4211  0.3991  0.3741  0.3661  0.3573  0.3542  0.3512  0.3484 # Residential Off Road
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Commercial Off Road
  ]
  #! format: on

  PM10 = Select(Poll,"PM10")
  #! format: off
  Reduce[ecs, PM10, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter 10
    0.6237  0.5898  0.5558  0.5217  0.4876  0.4654  0.4432  0.4211  0.3991  0.3741  0.3661  0.3573  0.3542  0.3512  0.3484 # Residential Off Road
    0.6142  0.5813  0.5484  0.5153  0.4822  0.4596  0.4371  0.4146  0.3924  0.3653  0.3554  0.3441  0.3413  0.3386  0.3361 # Commercial Off Road
  ]
  #! format: on

  PM25 = Select(Poll,"PM25")
  #! format: off
  Reduce[ecs, PM25, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Particulate Matter 2.5
    0.6069  0.5715  0.5359  0.5003  0.4646  0.4414  0.4183  0.3952  0.3722  0.3461  0.3377  0.3286  0.3253  0.3221  0.3193 # Residential Off Road
    0.6062  0.5726  0.5390  0.5052  0.4714  0.4483  0.4253  0.4024  0.3797  0.3521  0.3419  0.3304  0.3275  0.3248  0.3223 # Commercial Off Road
  ]
  #! format: on

  BC = Select(Poll,"BC")
  #! format: off
  Reduce[ecs, BC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Black Carbon
    0.6069  0.5715  0.5359  0.5003  0.4646  0.4414  0.4183  0.3952  0.3722  0.3461  0.3377  0.3286  0.3253  0.3221  0.3193 # Residential Off Road
    0.6062  0.5726  0.5390  0.5052  0.4714  0.4483  0.4253  0.4024  0.3797  0.3521  0.3419  0.3304  0.3275  0.3248  0.3223 # Commercial Off Road
  ]
  #! format: on

  NOX = Select(Poll,"NOX")
  #! format: off
  Reduce[ecs, NOX, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Nitrogen Oxides
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Residential Off Road
    0.6753  0.6592  0.6428  0.6262  0.6093  0.5846  0.5598  0.5346  0.5090  0.4707  0.4523  0.4319  0.4306  0.4297  0.4293 # Commercial Off Road
  ]
  #! format: on

  VOC = Select(Poll,"VOC")
  #! format: off
  Reduce[ecs, VOC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035 # /Volatile Org Comp.
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Residential Off Road
    0.8613  0.8458  0.8303  0.8147  0.7992  0.7895  0.7798  0.7700  0.7603  0.7505  0.7505  0.7505  0.7505  0.7505  0.7505 # Commercial Off Road
  ]
  #! format: on

  polls = Select(Poll,["PMT","PM10","PM25","BC","NOX","VOC"])
  Diesel = Select(FuelEP,"Diesel")

  #
  # Apply reduction to 2010 coefficient
  #
  years = collect(Future:Yr(2035))
  for year in years, area in areas, poll in polls, ec in ecs, tech in Techs, eu in Enduses
    POCX[eu,Diesel,tech,ec,poll,area,year] = min(POCX[eu,Diesel,tech,ec,poll,area,year]*
      Reduce[ec,poll,year]/Reduce[ec,poll,Last],POCX[eu,Diesel,tech,ec,poll,area,year])
  end

  years = collect(Yr(2035):Final)
  for year in years, area in areas, poll in polls, ec in ecs, tech in Techs, eu in Enduses
    POCX[eu,Diesel,tech,ec,poll,area,year] = POCX[eu,Diesel,tech,ec,poll,area,Yr(2035)]
  end

  #
  # Read in data for spark ignition reductions as sent by Lifang in 'RevisedPolicy_offroad_DieselGasoline_05OCT2016.xlsx'
  #  
  @. Reduce = 1.0

  years = collect(Yr(2021):Yr(2040))

  PMT = Select(Poll,"PMT")
  #! format: off
  Reduce[ecs, PMT, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Particulate Matter Tot
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Residential Off Road
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Commercial Off Road
  ]
  #! format: on

  PM10 = Select(Poll,"PM10")
  #! format: off
  Reduce[ecs, PM10, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Particulate Matter 10
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Residential Off Road
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Commercial Off Road
  ]
  #! format: on

  PM10 = Select(Poll,"PM10")
  #! format: off
  Reduce[ecs, PM10, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Particulate Matter 10
    0.9354  0.9302  0.9256  0.9216  0.9188  0.9168  0.9151  0.9138  0.9129  0.9123  0.9120  0.9118  0.9117  0.9117  0.9119  0.9121  0.9124  0.9127  0.9131  0.9135 # Residential Off Road
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Commercial Off Road
  ]
  #! format: on

  PM25 = Select(Poll,"PM25")
  #! format: off
  Reduce[ecs, PM25, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Particulate Matter 2.5
    0.9354  0.9302  0.9256  0.9216  0.9188  0.9168  0.9151  0.9138  0.9129  0.9123  0.9120  0.9118  0.9117  0.9117  0.9119  0.9121  0.9124  0.9127  0.9131  0.9135 # Residential Off Road
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Commercial Off Road
  ]
  #! format: on

  BC = Select(Poll,"BC")
  #! format: off
  Reduce[ecs, BC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Black Carbon
    0.9354  0.9302  0.9256  0.9216  0.9188  0.9168  0.9151  0.9138  0.9129  0.9123  0.9120  0.9118  0.9117  0.9117  0.9119  0.9121  0.9124  0.9127  0.9131  0.9135 # Residential Off Road
    0.9334  0.9281  0.9234  0.9193  0.9163  0.9143  0.9126  0.9112  0.9103  0.9096  0.9093  0.9091  0.9090  0.9090  0.9092  0.9094  0.9097  0.9100  0.9104  0.9108 # Commercial Off Road
  ]
  #! format: on

  NOX = Select(Poll,"NOX")
  #! format: off
  Reduce[ecs, NOX, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Nitrogen Oxides
    0.8291  0.8174  0.8064  0.7962  0.7869  0.7782  0.7700  0.7622  0.7549  0.7483  0.7440  0.7409  0.7383  0.7361  0.7342  0.7325  0.7311  0.7297  0.7286  0.7275 # Residential Off Road
    0.8291  0.8174  0.8064  0.7962  0.7869  0.7782  0.7700  0.7622  0.7549  0.7483  0.7440  0.7409  0.7383  0.7361  0.7342  0.7325  0.7311  0.7297  0.7286  0.7275 # Commercial Off Road
  ]
  #! format: on

  VOC = Select(Poll,"VOC")
  #! format: off
  Reduce[ecs, VOC, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Volatile Org Comp.
    0.7851  0.7694  0.7556  0.7435  0.7340  0.7263  0.7199  0.7145  0.7101  0.7065  0.7037  0.7015  0.6998  0.6985  0.6976  0.6969  0.6965  0.6962  0.6961  0.6961 # Residential Off Road
    0.7851  0.7694  0.7556  0.7435  0.7340  0.7263  0.7199  0.7145  0.7101  0.7065  0.7037  0.7015  0.6998  0.6985  0.6976  0.6969  0.6965  0.6962  0.6961  0.6961 # Commercial Off Road
  ]
  #! format: on

  COX = Select(Poll,"COX")
  #! format: off
  Reduce[ecs, COX, years] .= [
    # 2021    2022    2023    2024    2025    2026    2027    2028    2029    2030    2031    2032    2033    2034    2035    2036    2037    2038    2039    2040 # /Carbon Monoxide
    0.9577  0.9559  0.9544  0.9530  0.9519  0.9508  0.9499  0.9490  0.9482  0.9475  0.9470  0.9467  0.9464  0.9462  0.9461  0.9459  0.9458  0.9457  0.9456  0.9456 # Residential Off Road
    0.9577  0.9559  0.9544  0.9530  0.9519  0.9508  0.9499  0.9490  0.9482  0.9475  0.9470  0.9467  0.9464  0.9462  0.9461  0.9459  0.9458  0.9457  0.9456  0.9456 # Commercial Off Road
  ]
  #! format: on


  polls = Select(Poll,["PMT","PM10","PM25","BC","NOX","VOC","COX"])
  Gasoline = Select(FuelEP,"Gasoline")

  #
  # Apply reduction to 2010 coefficient
  # 
  years = collect(Future:Yr(2040))
  for year in years, area in areas, poll in polls, ec in ecs, tech in Techs, eu in Enduses
    POCX[eu,Gasoline,tech,ec,poll,area,year] = 
      min(POCX[eu,Gasoline,tech,ec,poll,area,year]*Reduce[ec,poll,year]/
        Reduce[ec,poll,Last],POCX[eu,Gasoline,tech,ec,poll,area,year])
  end

  years = collect(Yr(2040):Final)
  for year in years, area in areas, poll in polls, ec in ecs, tech in Techs, eu in Enduses
    POCX[eu,Diesel,tech,ec,poll,area,year] = POCX[eu,Diesel,tech,ec,poll,area,Yr(2040)]
  end

  WriteDisk(db,"$Input/POCX",POCX)
end

function PolicyControl(db)
  @info "CAC_OffRoad.jl - PolicyControl"
  IndPolicy(db)
  TransPolicy(db)
end

if abspath(PROGRAM_FILE) == @__FILE__
  PolicyControl(DB)
end

end
