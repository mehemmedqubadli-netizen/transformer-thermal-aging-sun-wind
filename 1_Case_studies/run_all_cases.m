%% run_all_cases.m - run every case study and produce all figures
% Order: Cases 1-3 -> SA1 (ambient) -> SA2 time-varying -> SA2 share -> figures.
% Every run repeats the 24-h day until it ends where it started
% (periodic steady state, see run_periodic.m). This takes several minutes.
%
% Written as plain lines (no loop), so a "clear" inside one of the
% scripts cannot break the sequence.

cd(fileparts(mfilename('fullpath')));

disp('=== 1/5  Cases 1-3 ===');                     run_Cases;
disp('=== 2/5  SA1 - ambient temperature ===');      run_SA1;
disp('=== 3/5  SA2 - rectifier load, time-varying ==='); run_SA2_TimeVarying;
disp('=== 4/5  SA2 - constant nonlinear share ===');  run_SA2_Share;
disp('=== 5/5  Figures ===');                        plot_all_figures;

disp('All case studies finished. Compare with Thesis_results_5Nov.xlsx.');
