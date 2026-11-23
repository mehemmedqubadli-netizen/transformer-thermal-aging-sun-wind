%% step9_extend_thesis_model.m
% Adds the sun + wind extension to the THESIS model
% (Integrated_Transformer_Case2_fixed.slx -> Integrated_Transformer_Case2_sunwind.slx).
% The original file is not changed.
%
% Changes inside Top_Oil_Thermal_Model (new blocks are coloured):
%   1. Ambient: Constant "24" (Constant1)  ->  From Workspace "Ambient_Ta" (Ta_ws)
%   2. Sun:     U = Load_loss_ratio  ->  U + cA*G/P_R   (new Sum "U_plus_sun",
%               From Workspace "Solar_G" (G_ws), Gain "Sun_cA_over_PR")
%   3. Wind:    Cooling_power  ->  Cooling_power * (1 + kw*W)  (new Product
%               "Cooling_times_wind", From Workspace "Wind_W" (W_ws), Gain, Bias)
% Electrical part, Hot_Spot_Thermal_Model and Aging model are NOT changed.
%
% Check A: Ta = 24 degC, G = 0, W = 0  ->  must equal the original model exactly.
% Check B: one real Sumgait day (5 Aug 2024, Case 2 load): thesis model vs the
%          step7/step8 equations (script), for IEEE and for + sun + wind.
%
% Put in ONE folder: this script, Integrated_Transformer_Case2_fixed.slx,
% Case2_inputs.m and sumgait_2024.csv.

clear; clc; close all;

%% 1. Settings ------------------------------------------------------------
% Case2_inputs.m contains its own "clear", so it must run FIRST
run('Case2_inputs.m');               % B, n, m, THETA_O_R, THETA_H_R, Tt_O, Tw_H, Theta_TO_0, Theta_H_0, ...

origMdl  = 'Integrated_Transformer_Case2_fixed';
newMdl   = 'Integrated_Transformer_Case2_sunwind';
csvFile  = 'sumgait_2024.csv';
utcOffset_h = 4;
dayB     = datenum(2024, 8, 5);      % hottest-week day for Check B
nWarm    = 7;                        % days of warm-up for the start values

TO0_case2 = Theta_TO_0;  H0_case2 = Theta_H_0;   % keep the Case 2 start values

% Weather extension parameters (own names, so nothing in Case2_inputs is overwritten)
cA_sun    = 0;          % set per run below; fitted value 22.5 m^2
kw_wind   = 0;          % set per run below; fitted value 0.050 1/(m/s)
P_R_total = 26.92e3 + 135.9e3;       % P_NL + P_LL [W]
cA_fit = 22.5;  kw_fit = 0.050;

% Case 2 load levels (pu) used by the script reference
K_night = 0.687; K_mid = 0.833; K_peak = 1.161;

%% 2. Make the extended copy of the thesis model --------------------------
if bdIsLoaded(newMdl), close_system(newMdl, 0); end
if exist([newMdl '.slx'], 'file'), delete([newMdl '.slx']); end
copyfile([origMdl '.slx'], [newMdl '.slx']);
load_system(newMdl);
s = [newMdl '/Top_Oil_Thermal_Model'];
newColor = 'cyan';

% (1) ambient: Constant1 (24) -> From Workspace Ta_ws
delete_line(s, 'Constant1/1', 'Theta_minus_ambient/2');
delete_block([s '/Constant1']);
add_block('simulink/Sources/From Workspace', [s '/Ambient_Ta'], 'Position', [5 80 95 110], ...
    'VariableName', 'Ta_ws', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value', ...
    'BackgroundColor', newColor);
add_line(s, 'Ambient_Ta/1', 'Theta_minus_ambient/2', 'autorouting', 'on');

% (2) sun: U -> U + cA*G/P_R, before the multiplication by THETA_O_R^(1/n)
delete_line(s, 'Load_loss_ratio/1', 'Heating_term/2');
add_block('simulink/Math Operations/Sum', [s '/U_plus_sun'], 'Position', [520 345 545 395], ...
    'Inputs', '++', 'BackgroundColor', newColor);
add_block('simulink/Sources/From Workspace', [s '/Solar_G'], 'Position', [255 625 345 655], ...
    'VariableName', 'G_ws', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value', ...
    'BackgroundColor', newColor);
add_block('simulink/Math Operations/Gain', [s '/Sun_cA_over_PR'], 'Position', [390 625 450 655], ...
    'Gain', 'cA_sun/P_R_total', 'BackgroundColor', newColor);
add_line(s, 'Load_loss_ratio/1', 'U_plus_sun/1', 'autorouting', 'on');
add_line(s, 'Solar_G/1', 'Sun_cA_over_PR/1', 'autorouting', 'on');
add_line(s, 'Sun_cA_over_PR/1', 'U_plus_sun/2', 'autorouting', 'on');
add_line(s, 'U_plus_sun/1', 'Heating_term/2', 'autorouting', 'on');

% (3) wind: cooling term x (1 + kw*W)
delete_line(s, 'Cooling_power/1', 'Heating_minus_cooling/1');
add_block('simulink/Math Operations/Product', [s '/Cooling_times_wind'], 'Position', [560 100 590 140], ...
    'Inputs', '**', 'BackgroundColor', newColor);
add_block('simulink/Sources/From Workspace', [s '/Wind_W'], 'Position', [255 690 345 720], ...
    'VariableName', 'W_ws', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value', ...
    'BackgroundColor', newColor);
add_block('simulink/Math Operations/Gain', [s '/Wind_kw'], 'Position', [390 690 430 720], ...
    'Gain', 'kw_wind', 'BackgroundColor', newColor);
add_block('simulink/Math Operations/Bias', [s '/One_plus'], 'Position', [465 690 505 720], ...
    'Bias', '1', 'BackgroundColor', newColor);
add_line(s, 'Wind_W/1', 'Wind_kw/1', 'autorouting', 'on');
add_line(s, 'Wind_kw/1', 'One_plus/1', 'autorouting', 'on');
add_line(s, 'Cooling_power/1', 'Cooling_times_wind/1', 'autorouting', 'on');
add_line(s, 'One_plus/1', 'Cooling_times_wind/2', 'autorouting', 'on');
add_line(s, 'Cooling_times_wind/1', 'Heating_minus_cooling/1', 'autorouting', 'on');

try   % short note inside the subsystem
    a = Simulink.Annotation(s, 'Weather extension (coloured blocks): ambient Ta(t); sun cA*G/P_R added to U; cooling x (1 + kw*W)');
    a.Position = [250 590 750 610];
catch
end
save_system(newMdl);
fprintf('Saved %s.slx (original model unchanged).\n\n', newMdl);

%% 3. Check A: no weather -> must equal the original model ---------------
Ta_ws = [0 24; 86400 24];  G_ws = [0 0; 86400 0];  W_ws = [0 0; 86400 0];
cA_sun = 0; kw_wind = 0;
Theta_TO_0 = TO0_case2; Theta_H_0 = H0_case2;

outO = sim(origMdl, 'ReturnWorkspaceOutputs', 'on');
outN = sim(newMdl,  'ReturnWorkspaceOutputs', 'on');
[tO, TOo, HSo] = get_TO_HS(outO);
[tN, TOn, HSn] = get_TO_HS(outN);
HSn_on_tO = interp1(tN, HSn, tO);  TOn_on_tO = interp1(tN, TOn, tO);
fprintf('Check A (24 degC, no sun, no wind):\n');
fprintf('   original : peak HS %.2f, peak TO %.2f, ageing %.2f h\n', max(HSo), max(TOo), ageing_h(tO, HSo));
fprintf('   extended : peak HS %.2f, peak TO %.2f, ageing %.2f h\n', max(HSn), max(TOn), ageing_h(tN, HSn));
fprintf('   max |difference|: TO %.4f K, HS %.4f K   (should be 0.0000)\n\n', ...
    max(abs(TOn_on_tO - TOo)), max(abs(HSn_on_tO - HSo)));

%% 4. Check B: 5 Aug 2024, real Sumgait weather ---------------------------
[Ta_y, G_y, W_y] = read_openmeteo(csvFile);
Nh   = numel(Ta_y);
tloc = datenum(2024,1,1) + ((0:Nh-1)' + utcOffset_h)/24;     % local time of each row
i0   = find(abs(tloc - (dayB - nWarm)) < 1e-6);               % start of warm-up
iB   = find(abs(tloc - dayB) < 1e-6);                         % 00:00 local on day B
if isempty(i0) || isempty(iB), error('Day not found in %s', csvFile); end

% script reference: warm-up + day B, same equations as step7/step8
rows = (i0 : iB+24)';
t_h  = (rows - i0) * 3600;
lh   = mod(round((tloc(rows) - floor(tloc(rows)))*24), 24);
K_h  = case2K(lh, K_night, K_mid, K_peak);
cases = {'IEEE (real ambient, no sun, no wind)', 0, 0;
         '+ sun + wind', cA_fit, kw_fit};
fprintf('Check B (5 Aug 2024, Case 2 load):\n');
fprintf('%-38s %-9s %8s %8s %9s\n', 'Model', 'source', 'HS max', 'TO max', 'ageing h');
HSplot = cell(2, 2); tplot = cell(2, 2);
for c = 1:2
    cA_sun = cases{c,2}; kw_wind = cases{c,3};
    p = struct('R',B,'dTOR',THETA_O_R,'dHR',THETA_H_R,'tauTO',Tt_O*60,'tauW',Tw_H*60, ...
               'n',n,'m',m,'P_R',P_R_total,'cA',cA_sun,'kw',kw_wind);
    [TOs0, dHs0] = start_values(K_h(1), Ta_y(rows(1)), G_y(rows(1)), W_y(rows(1)), p);
    [tR, TOr, dHr] = rk4_ref(t_h, K_h, Ta_y(rows), G_y(rows), W_y(rows), p, TOs0, dHs0, 60, t_h(end));
    HSr = TOr + dHr;
    dayIdx = tR >= nWarm*86400;
    tRd = tR(dayIdx) - nWarm*86400;  TOrd = TOr(dayIdx);  HSrd = HSr(dayIdx);

    % thesis model: start from the script state at 00:00 on day B
    Theta_TO_0 = TOrd(1);  Theta_H_0 = HSrd(1);
    tw = (0:24)' * 3600;
    Ta_ws = [tw Ta_y(iB:iB+24)];  G_ws = [tw G_y(iB:iB+24)];  W_ws = [tw W_y(iB:iB+24)];
    out = sim(newMdl, 'ReturnWorkspaceOutputs', 'on');
    [tS, TOs, HSs] = get_TO_HS(out);

    fprintf('%-38s %-9s %8.1f %8.1f %9.2f\n', cases{c,1}, 'Simulink', max(HSs), max(TOs), ageing_h(tS, HSs));
    fprintf('%-38s %-9s %8.1f %8.1f %9.2f\n', '',          'script',   max(HSrd), max(TOrd), ageing_h(tRd, HSrd));
    HSplot{c,1} = HSs; tplot{c,1} = tS;  HSplot{c,2} = HSrd; tplot{c,2} = tRd;
end
fprintf('\nSmall differences (a few tenths of a K) come from the electrical K(t) vs the\n');
fprintf('idealised 0.687/0.833/1.161 pu steps in the script.\n');

%% 5. Plot -----------------------------------------------------------------
figure('Name', 'Thesis model with weather - 5 Aug 2024'); hold on; grid on; box on;
col = [0 0.447 0.741; 0.929 0.694 0.125];
h = gobjects(1, 4);
for c = 1:2
    h(2*c-1) = plot(tplot{c,1}/3600, HSplot{c,1}, '-',  'Color', col(c,:), 'LineWidth', 1.5);
    h(2*c)   = plot(tplot{c,2}/3600, HSplot{c,2}, '--', 'Color', col(c,:), 'LineWidth', 1.0);
end
plot([0 24], [110 110], 'k:', 'LineWidth', 1);
xlim([0 24]); xticks(0:3:24);
xlabel('Local time [h]'); ylabel('Hot spot [\circC]');
title('Thesis Simulink model with Sumgait weather, 5 Aug 2024 (Case 2 load)');
legend(h, {'IEEE - Simulink', 'IEEE - script', '+ sun + wind - Simulink', '+ sun + wind - script'}, ...
       'Location', 'northwest');

open_system(s);   % show the extended subsystem

%% ======================== Local functions ===============================

function [t, TO, HS] = get_TO_HS(out)
a = out.get('Theta_TO_varying');  b = out.get('Theta_H_varying');
t = a.time(:);  TO = a.signals.values(:);
HS = interp1(b.time(:), b.signals.values(:), t);
end

function A = ageing_h(t, HS)
F = exp(15000/383 - 15000./(HS + 273));
A = trapz(t, F) / 3600;
end

function K = case2K(h, Kn, Km, Kp)
K = Km * ones(size(h));
K(h < 6) = Kn;
K(h >= 12 & h < 18) = Kp;
end

function [TO0, dH0] = start_values(K, Ta, G, W, p)
U   = (K^2*p.R + 1)/(p.R + 1) + p.cA*G/p.P_R;
TO0 = Ta + p.dTOR * (U/(1 + p.kw*W))^p.n;
dH0 = p.dHR * (K^2)^p.m;
end

function [t, TO, dH] = rk4_ref(t_h, K_h, Ta_h, G_h, W_h, p, TO0, dH0, dt, Tstop)
N   = round(Tstop/dt);
th  = (0:2*N)' * dt/2;
Ta2 = interp1(t_h, Ta_h, th);  G2 = interp1(t_h, G_h, th);  W2 = interp1(t_h, W_h, th);
Kn  = numel(K_h);
TO  = zeros(N+1,1); dH = zeros(N+1,1); TO(1) = TO0; dH(1) = dH0;
for k = 1:N
    t0 = (k-1)*dt; i0 = 2*k-1; i1 = 2*k; i2 = 2*k+1;
    Ka = K_h(min(floor(t0/3600) + 1, Kn));
    Kc = K_h(min(floor((t0+dt)/3600) + 1, Kn));
    x = TO(k); y = dH(k);
    [a1, b1] = deriv(x,           y,           Ka, Ta2(i0), G2(i0), W2(i0), p);
    [a2, b2] = deriv(x + dt/2*a1, y + dt/2*b1, Ka, Ta2(i1), G2(i1), W2(i1), p);
    [a3, b3] = deriv(x + dt/2*a2, y + dt/2*b2, Ka, Ta2(i1), G2(i1), W2(i1), p);
    [a4, b4] = deriv(x + dt*a3,   y + dt*b3,   Kc, Ta2(i2), G2(i2), W2(i2), p);
    TO(k+1) = x + dt/6*(a1 + 2*a2 + 2*a3 + a4);
    dH(k+1) = y + dt/6*(b1 + 2*b2 + 2*b3 + b4);
end
t = (0:N)' * dt;
end

function [dTO, ddH] = deriv(TO, dH, K, Ta, G, W, p)
U   = (K^2*p.R + 1)/(p.R + 1);
x   = max((TO - Ta)/p.dTOR, 0);
dTO = p.dTOR/p.tauTO * (U + p.cA*G/p.P_R - (1 + p.kw*W) * x^(1/p.n));
y   = max(dH/p.dHR, 0);
ddH = p.dHR/p.tauW * (K^2 - y^(1/p.m));
end

function [Ta, G, W] = read_openmeteo(fname)
txt   = fileread(fname);
lines = regexp(txt, '\r?\n', 'split');
hi    = find(strncmp(lines, 'time', 4), 1);
hdr   = strsplit(lines{hi}, ',');
col   = @(name) find(strncmp(hdr, name, length(name)), 1);
iT = col('temperature_2m'); iG = col('shortwave_radiation'); iW = col('wind_speed_10m');
body  = lines(hi+1:end);
body  = body(~cellfun(@isempty, strtrim(body)));
nc    = numel(hdr);
C     = textscan(strjoin(body, sprintf('\n')), ['%s' repmat(' %f', 1, nc-1)], ...
                 'Delimiter', ',', 'CollectOutput', true);
M  = C{2};
Ta = M(:, iT-1); G = M(:, iG-1); W = M(:, iW-1);
end
