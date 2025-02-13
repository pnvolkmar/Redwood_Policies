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

Com_PeakSavings.jl, Ind_AB_PP.jl, Ind_EcoPerformQC.jl, Ind_EnM.jl, Ind_Fungible_Coefficients.jl, Ind_H2_DemandsAP.jl, Ind_LCEF_Leader.jl, Ind_LCEF_Pro.jl, Ind_MS_OCNL.jl, Ind_NG.jl, Ind_NLOC_Eff.jl, Ind_NLOC_Pro.jl
Call CreateSinglePolicy_Inputs Com_PeakSavings           jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_AB_PP                 jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_EcoPerformQC          jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_EnM                   jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_Fungible_Coefficients jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_H2_DemandsAP          jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_LCEF_Leader           jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_LCEF_Pro              jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_MS_OCNL               jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_NG                    jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_NLOC_Eff              jl Policies StartBase Base Base OGRef Base
Call CreateSinglePolicy_Inputs Ind_NLOC_Pro              jl Policies StartBase Base Base OGRef Base
