%% run_SA2_Share.m - SA2: constant nonlinear-load share all day (Case 2 loading)
% 50 MVA ONAN transformer, 24 degC, corrected thermal model, warm start.
%
% Before running:
%   - Integrated_Transformer_SA2_Harmonic_fixed.slx is in this folder, with the
%     correction Gains THETA_O_R^(1-1/n) (Top_Oil) and THETA_H_R^(1-1/m) (Hot_Spot)
%   - Case2_inputs.m is in this folder
%
% alpha = share of the transformer current drawn by six-pulse rectifiers, all day.
% The model's fixed Gain blocks read HLF and Irms_I1 from the workspace.
% 0 % must reproduce Case 2 (105.3 / 82.3 degC, 2.73 h).

Case2_inputs                                   % 50 MVA parameters (does clear/clc)
model      = 'Integrated_Transformer_SA2_Harmonic_fixed';
alpha_list = [0 0.15 0.30 0.50];
load_system(model);

%% Rectifier spectrum (FFT of SA2_Rectifier_Spectrum.slx, 2 Nov 2026)
if isfile('rect_spectrum.mat')
    load('rect_spectrum.mat', 'rho', 'hh');
    disp('Spectrum loaded from rect_spectrum.mat');
else
    hh  = 1:25;
    rho = zeros(1, 25);  rho(1) = 1;
    rho([5 7 11 13 17 19 23 25]) = [19.541 13.282 7.7871 6.1518 4.0291 3.266 2.1463 1.7349] / 100;
    disp('Spectrum: measured values from 2 Nov 2026 (rounded)');
end

%% Runs
nS  = numel(alpha_list);
res = struct('alpha',[],'THD',[],'F_HL',[],'HLF',[],'Irms_I1',[], ...
             'peakHS',[],'peakTO',[],'aging_h',[],'endTO',[],'endHS',[],'nRuns',[]);
outs = cell(nS, 1);
TO0 = 24;  H0 = 24;                             % first run starts cold
for i = 1:nS
    [HLF, Irms_I1, F_HL, THD] = harmonic_factors(alpha_list(i), rho, hh, PEC_R);
    fprintf('\nShare %2.0f %%: THD %.1f %%, F_HL %.2f, HLF %.3f, Irms/I1 %.4f\n', ...
            100*alpha_list(i), 100*THD, F_HL, HLF, Irms_I1);
    [out, r] = run_warm(model, TO0, H0);
    TO0 = r.endTO;  H0 = r.endHS;               % next share starts warm
    res(i) = struct('alpha', alpha_list(i), 'THD', THD, 'F_HL', F_HL, 'HLF', HLF, ...
                    'Irms_I1', Irms_I1, 'peakHS', r.peakHS, 'peakTO', r.peakTO, ...
                    'aging_h', r.aging_h, 'endTO', r.endTO, 'endHS', r.endHS, 'nRuns', r.nRuns);
    outs{i} = out;
end
HLF = 1;  Irms_I1 = 1;                          % back to no harmonics

%% Results
SA2s = struct2table(res);
SA2s.alpha_pct = 100*SA2s.alpha;  SA2s.THD_pct = 100*SA2s.THD;
disp(' ');
disp('SA2 - constant nonlinear share, Case 2 loading, 24 degC, warm start:');
disp(SA2s(:, {'alpha_pct','THD_pct','F_HL','HLF','peakHS','peakTO','aging_h','nRuns'}));
fprintf('Check at 0 %%: %.1f / %.1f degC, %.2f h  (Case 2: 105.3 / 82.3 degC, 2.73 h)\n', ...
        SA2s.peakHS(1), SA2s.peakTO(1), SA2s.aging_h(1));
fprintf('Aging vs Case 2: %s\n', sprintf('%+.0f %%  ', 100*(SA2s.aging_h/SA2s.aging_h(1) - 1)));

if min(SA2s.peakHS) < 110 && max(SA2s.peakHS) > 110
    a110 = interp1(SA2s.peakHS, SA2s.alpha_pct, 110);
    fprintf('Peak hot spot reaches 110 degC at a nonlinear share of about %.0f %%\n', a110);
else
    a110 = NaN;
    fprintf('Peak hot spot does not cross 110 degC in this range\n');
end

save('SA2_share_results.mat', 'SA2s', 'outs', 'alpha_list', 'rho', 'hh', 'a110');
fprintf('Saved SA2_share_results.mat\n');

%% ------------------------------------------------------------------------
function [out, r] = run_warm(model, TO0, H0)
% Repeat the day until it starts where it ends (periodic steady state).
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
% Harmonic factors at the transformer (IEEE C57.110), rectifier harmonics add
% arithmetically (worst case).
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
