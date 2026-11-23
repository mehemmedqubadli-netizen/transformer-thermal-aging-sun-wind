%% run_SA2_TimeVarying.m - SA2: Load D as a six-pulse rectifier (time-varying harmonics)
% 50 MVA ONAN transformer, Case 2 loading, 24 degC, corrected thermal model, warm start.
%
% Before running:
%   - Integrated_Transformer_SA2_TimeVarying_fixed.slx is in this folder, with the
%     correction Gains THETA_O_R^(1-1/n) (Top_Oil) and THETA_H_R^(1-1/m) (Hot_Spot)
%   - Case2_inputs.m is in this folder
%
% How the model works (built 2 Nov 2026):
%   the model measures Load D's current and divides it by the total current
%   -> alpha(t) = share of the transformer current drawn by the rectifier.
%   Two lookup tables turn alpha(t) into HLF(t) and Irms/I1(t), using the
%   rectifier spectrum measured with SA2_Rectifier_Spectrum.slx (FFT).
%
% This script:
%   Run A - check: lookup tables set to "no harmonics" -> must reproduce Case 2
%   Run B - the real time-varying harmonic case
%   Each run: cold start, then warm runs until start = end (periodic steady state).

Case2_inputs                                   % 50 MVA parameters (does clear/clc)
model = 'Integrated_Transformer_SA2_TimeVarying_fixed';
load_system(model);

%% 1. Rectifier spectrum (six-pulse diode rectifier, FFT of SA2_Rectifier_Spectrum.slx)
% Harmonic currents relative to the rectifier's own fundamental.
% If rect_spectrum.mat (saved by the FFT script) is in this folder, it is used;
% otherwise the measured values below (rounded) are used.
if isfile('rect_spectrum.mat')
    load('rect_spectrum.mat', 'rho', 'hh');
    disp('Spectrum loaded from rect_spectrum.mat');
else
    hh  = 1:25;
    rho = zeros(1, 25);  rho(1) = 1;
    rho([5 7 11 13 17 19 23 25]) = [19.541 13.282 7.7871 6.1518 4.0291 3.266 2.1463 1.7349] / 100;
    disp('Spectrum: measured values from 2 Nov 2026 (rounded)');
end
fprintf('Rectifier alone: THD = %.1f %%, F_HL = %.2f\n', ...
        100*sqrt(sum(rho(2:end).^2)), sum(rho.^2 .* hh.^2) / sum(rho.^2));

%% 2. Lookup tables alpha -> HLF and Irms/I1 (IEEE C57.110)
alpha_bp = 0:0.01:1;
HLF_tab  = zeros(size(alpha_bp));
Irms_tab = zeros(size(alpha_bp));
for k = 1:numel(alpha_bp)
    [HLF_tab(k), Irms_tab(k)] = harmonic_factors(alpha_bp(k), rho, hh, PEC_R);
end
fprintf('HLF at alpha = 15%%: %.3f,  at 50%%: %.3f\n', HLF_tab(16), HLF_tab(51));
HLF_real  = HLF_tab;   Irms_real = Irms_tab;   % keep the real tables
HLF = 1;  Irms_I1 = 1;                          % in case any fixed Gain still uses them

%% 3. Run A - check (no harmonics): must give Case 2 = 105.3 / 82.3 degC, 2.73 h
HLF_tab  = ones(size(alpha_bp));
Irms_tab = ones(size(alpha_bp));
[outA, rA] = run_warm(model, 24, 24);
fprintf('\nRun A (no harmonics): %.1f / %.1f degC, %.2f h   (Case 2: 105.3 / 82.3 degC, 2.73 h)\n', ...
        rA.peakHS, rA.peakTO, rA.aging_h);

%% 4. Run B - Load D as rectifier (time-varying harmonics)
HLF_tab  = HLF_real;
Irms_tab = Irms_real;
[outB, rB] = run_warm(model, rA.endTO, rA.endHS);   % start from the Case 2 end values
a = getv(outB, 'alpha_t');
fprintf('Run B (time-varying): %.1f / %.1f degC, %.2f h,  peak alpha = %.1f %%\n', ...
        rB.peakHS, rB.peakTO, rB.aging_h, 100*max(a));

%% 5. Summary
fprintf('\n%-30s %8s %8s %10s %14s\n', 'Run', 'Peak HS', 'Peak TO', 'Aging (h)', 'End TO / HS');
fprintf('%-30s %8.1f %8.1f %10.2f %7.2f / %.2f\n', 'Case 2 (no harmonics)', ...
        rA.peakHS, rA.peakTO, rA.aging_h, rA.endTO, rA.endHS);
fprintf('%-30s %8.1f %8.1f %10.2f %7.2f / %.2f\n', 'Load D rectifier (time-var.)', ...
        rB.peakHS, rB.peakTO, rB.aging_h, rB.endTO, rB.endHS);
fprintf('Aging increase due to harmonics: %+.0f %%\n', 100*(rB.aging_h/rA.aging_h - 1));

save('SA2_TV_results.mat', 'outA', 'outB', 'rA', 'rB', 'rho', 'hh', ...
     'alpha_bp', 'HLF_real', 'Irms_real');
fprintf('Saved SA2_TV_results.mat\n');

%% ------------------------------------------------------------------------
function [out, r] = run_warm(model, TO0, H0)
% Cold/warm start loop: repeat the day until it starts where it ends.
    tol = 0.05;  maxRuns = 5;
    assignin('base', 'Theta_TO_0', TO0);
    assignin('base', 'Theta_H_0',  H0);
    for k = 1:maxRuns
        out = sim(model);
        to = getv(out, 'Theta_TO_varying');
        h  = getv(out, 'Theta_H_varying');
        fprintf('   run %d: start %.2f/%.2f -> end %.2f/%.2f\n', k, TO0, H0, to(end), h(end));
        if k > 1 && abs(to(end) - TO0) < tol && abs(h(end) - H0) < tol
            break
        end
        TO0 = to(end);  H0 = h(end);
        assignin('base', 'Theta_TO_0', TO0);
        assignin('base', 'Theta_H_0',  H0);
    end
    ag = getv(out, 'Aging_hours_varying');
    r = struct('peakHS', max(h), 'peakTO', max(to), 'aging_h', ag(end), ...
               'endTO', to(end), 'endHS', h(end), 'nRuns', k);
end

function [HLF, Irms_I1, F_HL, THD] = harmonic_factors(alpha, rho, hh, PEC_R)
% Harmonic factors at the transformer (IEEE C57.110).
% alpha = share of the transformer fundamental current drawn by rectifiers.
% Assumption: harmonic currents of all rectifiers add arithmetically (worst case).
    I       = [1, alpha * rho(2:end)];
    F_HL    = sum(I.^2 .* hh.^2) / sum(I.^2);
    Irms_I1 = sqrt(sum(I.^2));
    THD     = sqrt(sum(I(2:end).^2));
    HLF     = (1 + F_HL*PEC_R) / (1 + PEC_R);
end

function v = getv(out, name)
% Values of a logged signal (Timeseries or Structure With Time)
    s = out.(name);
    if isa(s, 'timeseries')
        v = squeeze(s.Data);
    else
        v = squeeze(s.signals.values);
    end
end
