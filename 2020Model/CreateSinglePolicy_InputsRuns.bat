rem
rem  CreateSinglePolicy_InputsRuns.bat
rem
rem  %1 - File Name
rem  %2 - File Extension
rem  %3 - "Calibration" or "Policies"
rem  %4 - Start Database
rem  %5 - Base Case
rem  %6 - Reference Case
rem  %7 - Oil and Gas Reference Case
rem  %8 - Scenario for zInitial in Access outputs

rem success

  rem  Call CreateSinglePolicy_Inputs Adjust_Freight_MVF    jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs Adjust_TR_Covid    jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_CCME_AcidRain  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_Locomotive     jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_MSAPR          jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_NL_AirControlReg jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_NS_AirQualityReg jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_OffRoad          jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_ON_SOX_Nickel_Smelting_Refining jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_ON_SOXPetroProd  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_PassStandards  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_ProvRecipReg  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_VOC_PetroleumSectors  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CAC_VOC_Products  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CCS_ITC  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs CFS_LiquidMarket_CN  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs Com_MS_HeatPump_BC  jl Policies StartBase Base Base OGRef Base
  rem  Call CreateSinglePolicy_Inputs DAC_Exogenous_CA  jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Eff_MB_Act                 jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs EIP_CCS_2                  jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Electric_Renew_NS          jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Electricity_Patch          jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs EndogenousElectricCapacity jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Electricity_ITCs           jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Device_Com_Elec  jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Device_Com_NG    jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Device_Res_Elec  jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Device_Res_NG    jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Process_Com_Elec jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Process_Com_NG   jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Process_Res_Elec jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Retro_Process_Res_NG   jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs RNG_H2_Pipeline_CA     jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs RNG_Standard_BC        jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs RNG_Standard_QC        jl Policies StartBase Base Base OGRef Base
  rem Call CreateSinglePolicy_Inputs Res_PeakSavings        jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Ind_PeakSavings           jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_MarineOffRoad_CA    jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_MS_Bus_Train        jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_MS_Conversions_CA   jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_MS_iMHZEV           jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_MS_HDV_CA           jl Policies StartBase Base Base OGRef Base
    rem Call CreateSinglePolicy_Inputs Trans_BiofuelEmissions_CA jl Policies StartBase Base Base OGRef Base

rem unknown
rem Group:  Ind_CleanBC_Cmnt.jl, Ind_PeakSavings.jl, Trans_BiofuelEmissions_CA.jl, Trans_MarineOffRoad_CA.jl, Trans_MS_Bus_Train.jl, Trans_MS_Conversions_CA.jl, Trans_MS_HDV_CA.jl, Trans_MS_iMHZEV.jl,    
    rem Call CreateSinglePolicy_Inputs Ind_CleanBC_Cmnt          jl Policies StartBase Base Base OGRef Base
    Call CreateSinglePolicy_Inputs Ind_H2_FeedstocksAP          jl Policies StartBase Base Base OGRef Base
rem rerun

rem failing     
   

pause
    

