%% run_Validation.m - Norway top-oil validation, all steps in order
% Data: Baerug et al. (2025), Zenodo 10.5281/zenodo.17223516
% (40 MVA ONAN, 132 kV, hourly 2024). Only the top-oil model is validated.
%
% step1  load and check the measured data          -> norway_data.mat
% step2  IEEE model with standard parameters       -> step2_results.mat
% step3  fit dTheta_TO,R and tau (Jan-Jun / Jul-Dec)-> step3_results.mat
% step5  fit form A (Aslam) vs form B (IEEE)       -> step5_results.mat
% step4  inputs for Simulink, run Validation_TopOil.slx, check equation
%
% Written as plain lines (no loop), because the step scripts use "clear".

cd(fileparts(mfilename('fullpath')));

step1_load_norway_data;
step2_run_topoil_model;
step3_fit_parameters;
step5_fit_formA_vs_formB;
step4_prepare_inputs;

out = sim('Validation_TopOil');    % uses K_in, Ta_in, StopTime_s from step4
step4c_check_equation;             % expected: form B vs Simulink RMSE ~0.013 K,
                                   %           Simulink vs measurement RMSE ~1.70 K
