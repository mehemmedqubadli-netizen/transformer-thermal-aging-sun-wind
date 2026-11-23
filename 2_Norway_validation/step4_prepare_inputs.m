%% STEP 4a - Prepare the Norway inputs and 40 MVA parameters for Simulink
% Needs norway_data.mat (Step 1) and step3_results.mat (Step 3).
% Run this BEFORE the Simulink validation model.
%
% Creates in the workspace:
%   K_in, Ta_in  - timeseries of measured load factor and ambient, time in SECONDS
%                  (the Simulink model runs in seconds: it uses Tt_O*60)
%   B, n, THETA_O_R, Tt_O, Theta_TO_0, T_amb, HLF, Irms_I1 - same names as SA2_inputs.m
%   StopTime_s   - simulation stop time [s]

clear; clc;
load('norway_data.mat');               % t, K, Ta, TO, seg
load('step5_results.mat', 'pB');  p_cal = pB;   % fitted [dTO_R  tau_h] from Jan-Jun

%% 1. Longest continuous stretch of data (no gaps)
segs   = unique(seg);
lens   = arrayfun(@(s) sum(seg == s), segs);
[~, i] = max(lens);
idx    = (seg == segs(i));

tv  = t(idx);   Kv = K(idx);   Tav = Ta(idx);   TOv = TO(idx);
tmin = minutes(tv - tv(1));            % time from start [min]
tsec = seconds(tv - tv(1));            % time from start [s] (Simulink time)

fprintf('Validation period: %s to %s  (%d hours, %.0f days)\n', ...
        string(tv(1)), string(tv(end)), numel(tv), days(tv(end) - tv(1)));

%% 2. Inputs for Simulink (From Workspace blocks)
K_in  = timeseries(Kv,  tsec);   K_in.Name  = 'K';
Ta_in = timeseries(Tav, tsec);   Ta_in.Name = 'Theta_A';
StopTime_s = tsec(end);

%% 3. 40 MVA parameters (same variable names as SA2_inputs.m)
B          = 7.5;              % load / no-load loss ratio (Madshaven et al. 2024)
n          = 0.8;              % oil exponent
THETA_O_R  = p_cal(1);         % fitted rated top-oil rise [K]
Tt_O       = p_cal(2) * 60;    % fitted top-oil time constant [min] (model multiplies by 60)
Theta_TO_0 = TOv(1);           % start from the measured top oil [degC]
T_amb      = Tav(1);           % only used if the model still needs a constant
HLF        = 1;                % no harmonics
Irms_I1    = 1;

fprintf('Parameters: B = %.1f, n = %.1f, THETA_O_R = %.1f K, Tt_O = %.0f min (%.1f h)\n', ...
        B, n, THETA_O_R, Tt_O, Tt_O/60);
fprintf('Stop time: %.0f s  -> type StopTime_s in the Stop Time box\n', StopTime_s);

%% 4. Reference: the Step 3 script on the same stretch, same start value
a      = exp(-1 / p_cal(2));
U      = THETA_O_R * ((Kv.^2 * B + 1) / (B + 1)).^n;
x      = zeros(size(Kv));
x(1)   = TOv(1) - Tav(1);
for k = 2:numel(Kv)
    x(k) = U(k-1) + (x(k-1) - U(k-1)) * a;
end
TO_script = Tav + x;

save('step4_inputs.mat', 'tv','tmin','tsec','Kv','Tav','TOv','TO_script', ...
     'K_in','Ta_in','StopTime_s','B','n','THETA_O_R','Tt_O','Theta_TO_0','T_amb','HLF','Irms_I1');
fprintf('Saved step4_inputs.mat. Now run the Simulink validation model.\n');
