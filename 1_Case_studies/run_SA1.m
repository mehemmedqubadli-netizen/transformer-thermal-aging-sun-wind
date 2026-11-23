%% run_SA1.m - Sensitivity analysis 1: ambient temperature (Case 2 loading)
% 50 MVA ONAN transformer, corrected thermal model, warm (periodic) start.
%
% Before running:
%   - Integrated_Transformer_SA1_fixed.slx is a copy of Case2_fixed
%   - the ambient Constant block inside Top_Oil_Thermal_Model says T_amb (not 24)
%   - this script, Case2_inputs.m and the model are in the same folder
%
% What it does, for each ambient temperature:
%   1. cold run (start at ambient)
%   2. warm runs: start the day where the previous run ended, until
%      start = end (periodic steady state), max 5 runs
%   3. stores peak hot spot, peak top oil, daily aging, end values
% Output: table on screen + SA1_results.mat

Case2_inputs                                  % 50 MVA parameters (also does clear/clc)

model   = 'Integrated_Transformer_SA1_fixed';
T_list  = [10 24 30 35 40];                   % ambient temperatures [degC]
tol     = 0.05;                               % start = end within 0.05 degC
maxRuns = 5;

load_system(model);
nT  = numel(T_list);
res = struct('T_amb',[],'peakHS',[],'peakTO',[],'aging_h',[], ...
             'endTO',[],'endHS',[],'nRuns',[]);
outs = cell(nT,1);

for i = 1:nT
    T_amb      = T_list(i);
    Theta_TO_0 = T_amb;                       % cold start
    Theta_H_0  = T_amb;

    for r = 1:maxRuns
        out = sim(model);
        to  = getv(out, 'Theta_TO_varying');
        h   = getv(out, 'Theta_H_varying');
        dTO = abs(to(end) - Theta_TO_0);
        dH  = abs(h(end)  - Theta_H_0);
        fprintf('T_amb = %2d degC, run %d: start %.2f/%.2f -> end %.2f/%.2f\n', ...
                T_amb, r, Theta_TO_0, Theta_H_0, to(end), h(end));
        if r > 1 && dTO < tol && dH < tol
            break                             % converged
        end
        Theta_TO_0 = to(end);                 % warm start for next run
        Theta_H_0  = h(end);
    end

    ag = getv(out, 'Aging_hours_varying');
    res(i).T_amb   = T_amb;
    res(i).peakHS  = max(h);
    res(i).peakTO  = max(to);
    res(i).aging_h = ag(end);
    res(i).endTO   = to(end);
    res(i).endHS   = h(end);
    res(i).nRuns   = r;
    outs{i} = out;
end

%% Results table
SA1 = struct2table(res);
disp(' ');
disp('SA1 - ambient temperature, Case 2 loading, warm start:');
disp(SA1(:, {'T_amb','peakHS','peakTO','aging_h','endTO','endHS','nRuns'}));

% Check: 24 degC must reproduce Case 2 (105.3 / 82.3 degC, 2.73 h)
k = find(T_list == 24);
if ~isempty(k)
    fprintf('Check at 24 degC: %.1f / %.1f degC, %.2f h  (Case 2: 105.3 / 82.3 degC, 2.73 h)\n', ...
            SA1.peakHS(k), SA1.peakTO(k), SA1.aging_h(k));
end

% Crossover: ambient at which the peak hot spot reaches 110 degC
if min(SA1.peakHS) < 110 && max(SA1.peakHS) > 110
    T110 = interp1(SA1.peakHS, SA1.T_amb, 110);
    fprintf('Peak hot spot reaches 110 degC at an ambient of about %.1f degC\n', T110);
else
    T110 = NaN;
    fprintf('Peak hot spot does not cross 110 degC in this temperature range\n');
end

save('SA1_results.mat', 'SA1', 'T110', 'outs', 'T_list');
fprintf('Saved SA1_results.mat\n');

%% ------------------------------------------------------------------------
function v = getv(out, name)
% Get the values of a logged signal (Timeseries or Structure With Time)
    s = out.(name);
    if isa(s, 'timeseries')
        v = squeeze(s.Data);
    else
        v = squeeze(s.signals.values);
    end
end
