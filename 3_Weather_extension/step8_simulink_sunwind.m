%% step8_simulink_sunwind.m
% Simulink version of the extended top-oil model (IEEE C57.91 Annex G form B
% + sun + wind) and the hot-spot gradient, for the 50 MVA Azerikimya unit.
%
% What this script does:
%   1. Builds the Simulink model TopOil_SunWind_50MVA.slx from code
%      (two subsystems: TopOil_SunWind and HotSpot_gradient, plus ageing).
%   2. Check 1 - Case 2 at constant 24 degC, no sun, no wind:
%      should give peak HS 105.3 degC, peak TO 82.4 degC, ageing 2.74 h/day.
%   3. Runs a full year of Sumgait 2024 weather for 4 cases
%      (IEEE, + sun, + sun + wind, + sun + half wind).
%   4. Check 2 - compares Simulink with an RK4 script of the same equations
%      (difference should be ~0.00 K) and prints the step7 numbers to compare.
%   5. Plots the hottest week (2-9 Aug) from the Simulink results.
%
% Needs: sumgait_2024.csv (Open-Meteo hourly, UTC) in the same folder.
% Equations:
%   dTO/dt = dTOR/tauTO * [ U + cA*G/P_R - (1 + kw*W) * ((TO - Ta)/dTOR)^(1/n) ]
%   U      = (K^2*R + 1)/(R + 1)
%   ddH/dt = dHR/tauW  * [ K^2 - (dH/dHR)^(1/m) ]
%   HS     = TO + dH
%   F_AA   = exp(15000/383 - 15000/(HS + 273))
%
% Simulink time is in SECONDS. Fixed step 60 s, solver ode4 (= RK4, 1 min).

clear; clc; close all;

%% 1. Settings and parameters -------------------------------------------
mdl         = 'TopOil_SunWind_50MVA';
csvFile     = 'sumgait_2024.csv';
utcOffset_h = 4;                 % Azerbaijan local time = UTC + 4
% Simulink installed and licensed? (false in Octave)
useSimulink = exist('OCTAVE_VERSION', 'builtin') == 0 && ...
              ~isempty(ver('simulink')) && license('test', 'Simulink');
if ~useSimulink
    warning('Simulink not found: check with  ver simulink  and  license(''test'',''Simulink'')');
end

% 50 MVA unit (same values as Case2_inputs.m - change here if yours differ)
P_NL  = 26.92e3;                 % no-load loss [W]
P_LL  = 135.9e3;                 % load loss at rated current [W]
P_R   = P_NL + P_LL;             % total loss at rated load [W]
R     = 5.05;                    % loss ratio P_LL/P_NL
dTOR  = 49;                      % rated top-oil rise [K]
dHR   = 18;                      % rated hot-spot gradient [K]
tauTO = 180*60;                  % top-oil time constant [s]
tauW  = 6*60;                    % winding time constant [s]
n     = 0.8;                     % top-oil exponent
m     = 0.8;                     % winding exponent
dt    = 60;                      % step [s]

% Case 2 daily load profile (pu), by local hour
K_night = 0.687;                 % 00-06
K_mid   = 0.833;                 % 06-12 and 18-24
K_peak  = 1.161;                 % 12-18

% Weather parameters (Norway fit, c*A scaled to 50 MVA)
cA_fit = 22.5;                   % effective sunlit area x absorptivity [m^2]
kw_fit = 0.050;                  % wind cooling factor [1/(m/s)]

% Start values for the model variables (changed before each run)
cA = 0; kw = 0; TO0 = 60; dH0 = 10;

%% 2. Build the Simulink model ------------------------------------------
if useSimulink
    build_model(mdl);
    fprintf('Simulink model %s.slx built and saved.\n\n', mdl);
else
    fprintf('Simulink not available - running the script (RK4) part only.\n\n');
end

%% 3. Check 1: Case 2 at constant 24 degC (no sun, no wind) ---------------
nDays  = 10;                                  % run 10 days, use the last one
t_h    = (0:24*nDays)' * 3600;                % hourly breakpoints [s]
lh     = mod((0:24*nDays)', 24);              % local hour (starts at 00:00)
K_h    = case2K(lh, K_night, K_mid, K_peak);
Ta_h   = 24*ones(size(t_h));
G_h    = zeros(size(t_h));
W_h    = zeros(size(t_h));
Tstop  = t_h(end);

cA = 0; kw = 0;
[TO0, dH0] = start_values(K_h(1), Ta_h(1), G_h(1), W_h(1), cA, kw, R, dTOR, dHR, P_R, n, m);
p = pack(R, dTOR, dHR, tauTO, tauW, n, m, P_R, cA, kw);
[tR, TOr, dHr] = rk4_ref(t_h, K_h, Ta_h, G_h, W_h, p, TO0, dH0, dt, Tstop);
HSr = TOr + dHr;
last = tR >= (nDays-1)*86400;
fprintf('Check 1 (24 degC, Case 2), script : peak HS %.1f, peak TO %.1f, ageing %.2f h  (target 105.3 / 82.4 / 2.74)\n', ...
    max(HSr(last)), max(TOr(last)), ageing_h(tR(last), HSr(last)));

if useSimulink
    K_ws = [t_h K_h]; Ta_ws = [t_h Ta_h]; G_ws = [t_h G_h]; W_ws = [t_h W_h];
    [tS, TOs, HSs] = run_sim(mdl, Tstop);
    lastS = tS >= (nDays-1)*86400;
    fprintf('Check 1 (24 degC, Case 2), Simulink: peak HS %.1f, peak TO %.1f, ageing %.2f h\n', ...
        max(HSs(lastS)), max(TOs(lastS)), ageing_h(tS(lastS), HSs(lastS)));
    fprintf('   max |Simulink - script| over 10 days: TO %.4f K, HS %.4f K\n\n', ...
        max(abs(TOs - TOr)), max(abs(HSs - HSr)));
end

%% 4. Read Sumgait weather ------------------------------------------------
[Ta_h, G_h, W_h] = read_openmeteo(csvFile);
Nh    = numel(Ta_h);
t_h   = (0:Nh-1)' * 3600;                     % t = 0 at 2024-01-01 00:00 UTC
lh    = mod((0:Nh-1)' + utcOffset_h, 24);     % local hour
K_h   = case2K(lh, K_night, K_mid, K_peak);
Tstop = t_h(end);
t0_local = datenum(2024,1,1) + utcOffset_h/24; % local date/time at t = 0
fprintf('Weather: %d hours, mean Ta %.1f degC, mean G %.0f W/m2, mean wind %.1f m/s\n\n', ...
    Nh, mean(Ta_h), mean(G_h), mean(W_h));

if useSimulink
    K_ws = [t_h K_h]; Ta_ws = [t_h Ta_h]; G_ws = [t_h G_h]; W_ws = [t_h W_h];
end

%% 5. Full-year runs ------------------------------------------------------
cases = { 'IEEE (no sun, no wind)', 0,      0;
          '+ sun',                  cA_fit, 0;
          '+ sun + wind',           cA_fit, kw_fit;
          '+ sun + half wind',      cA_fit, kw_fit/2 };
nc  = size(cases, 1);
res = zeros(nc, 7);       % ageing, LoL, HSmax, TOmax, h>110, days>110, max diff
HS_all = cell(nc, 1); tPlot = [];

for i = 1:nc
    cA = cases{i,2}; kw = cases{i,3};
    [TO0, dH0] = start_values(K_h(1), Ta_h(1), G_h(1), W_h(1), cA, kw, R, dTOR, dHR, P_R, n, m);
    p = pack(R, dTOR, dHR, tauTO, tauW, n, m, P_R, cA, kw);
    [tR, TOr, dHr] = rk4_ref(t_h, K_h, Ta_h, G_h, W_h, p, TO0, dH0, dt, Tstop);
    HSr = TOr + dHr;

    if useSimulink
        [tS, TOs, HSs] = run_sim(mdl, Tstop);
        dmax = max(abs(HSs - HSr));
        t = tS; TO = TOs; HS = HSs;         % report the Simulink results
    else
        dmax = NaN;
        t = tR; TO = TOr; HS = HSr;
    end

    A      = ageing_h(t, HS);
    hot    = HS(1:end-1) > 110;
    hours  = sum(hot) * dt/3600;
    dayNo  = floor(t0_local + t(1:end-1)/86400);
    days   = numel(unique(dayNo(hot)));
    res(i,:) = [A, A/180000*100, max(HS), max(TO), hours, days, dmax];
    HS_all{i} = HS; tPlot = t;
    fprintf('%-24s done.\n', cases{i,1});
end

%% 6. Results table -------------------------------------------------------
fprintf('\n%-24s %9s %9s %8s %8s %9s %9s %14s\n', 'Model', 'Ageing h', 'LoL %/yr', ...
    'HSmax', 'TOmax', 'h HS>110', 'days>110', 'max|Sim-scr| K');
for i = 1:nc
    fprintf('%-24s %9.0f %9.2f %8.1f %8.1f %9.0f %9d %14.4f\n', cases{i,1}, ...
        res(i,1), res(i,2), res(i,3), res(i,4), res(i,5), res(i,6), res(i,7));
end
fprintf('\nstep7 (script) for comparison:\n');
fprintf('IEEE 759 h, HS 116.1, 93 h / 55 days;  + sun 1015 h;  + sun + wind 390 h, HS 109.8, 0 days;  + sun + half wind 594 h, 15 days\n');
fprintf('Change vs IEEE: + sun %+.0f %%,  + sun + wind %+.0f %%,  + sun + half wind %+.0f %%\n', ...
    100*(res(2,1)/res(1,1)-1), 100*(res(3,1)/res(1,1)-1), 100*(res(4,1)/res(1,1)-1));

%% 7. Plot: hottest week from Simulink -----------------------------------
tl  = t0_local + tPlot/86400;                     % local date number
idx = tl >= datenum(2024,8,2) & tl <= datenum(2024,8,9);
figure('Name', 'Simulink - hottest week');
hold on; grid on; box on;
cols = [0 0.447 0.741; 0.85 0.325 0.098; 0.929 0.694 0.125; 0.466 0.674 0.188];
for i = 1:nc
    plot(tl(idx), HS_all{i}(idx), 'Color', cols(i,:), 'LineWidth', 1.2);
end
plot(tl(idx), 110*ones(sum(idx),1), 'k--', 'LineWidth', 1);
datetick('x', 'dd mmm'); xlim([datenum(2024,8,2) datenum(2024,8,9)]);
ylabel('Hot spot [\circC]');
title('Hot spot in the hottest week (Simulink), 50 MVA, Sumgait 2024');
legend([cases(:,1); {'110 \circC'}], 'Location', 'south');

save('step8_results.mat', 'cases', 'res', 'tPlot', 'HS_all', 't0_local');
fprintf('\nSaved step8_results.mat\n');

%% ======================== Local functions ===============================

function K = case2K(h, Kn, Km, Kp)
% Case 2 load (pu) for local hour h
K = Km * ones(size(h));
K(h < 6) = Kn;
K(h >= 12 & h < 18) = Kp;
end

function [TO0, dH0] = start_values(K, Ta, G, W, cA, kw, R, dTOR, dHR, P_R, n, m)
% Steady state for the first hour's inputs (avoids a cold start)
U   = (K^2*R + 1)/(R + 1) + cA*G/P_R;
TO0 = Ta + dTOR * (U/(1 + kw*W))^n;
dH0 = dHR * (K^2)^m;
end

function p = pack(R, dTOR, dHR, tauTO, tauW, n, m, P_R, cA, kw)
p = struct('R',R,'dTOR',dTOR,'dHR',dHR,'tauTO',tauTO,'tauW',tauW, ...
           'n',n,'m',m,'P_R',P_R,'cA',cA,'kw',kw);
end

function A = ageing_h(t, HS)
% Equivalent ageing [h] over the time span (IEEE C57.91, 110 degC reference)
F = exp(15000/383 - 15000./(HS + 273));
A = trapz(t, F) / 3600;
end

function [t, TO, dH] = rk4_ref(t_h, K_h, Ta_h, G_h, W_h, p, TO0, dH0, dt, Tstop)
% Same equations as the Simulink model, classic RK4, step dt.
% K is held per hour (like From Workspace with interpolation off);
% Ta, G, W are interpolated linearly (like From Workspace with interpolation on).
N   = round(Tstop/dt);
th  = (0:2*N)' * dt/2;                         % grid at t, t+dt/2, t+dt
Ta2 = interp1(t_h, Ta_h, th);
G2  = interp1(t_h, G_h,  th);
W2  = interp1(t_h, W_h,  th);
Kn  = numel(K_h);
TO  = zeros(N+1,1); dH = zeros(N+1,1);
TO(1) = TO0; dH(1) = dH0;
for k = 1:N
    t0 = (k-1)*dt;
    i0 = 2*k-1; i1 = 2*k; i2 = 2*k+1;
    Ka = K_h(min(floor(t0/3600) + 1, Kn));
    Kc = K_h(min(floor((t0+dt)/3600) + 1, Kn));
    x = TO(k); y = dH(k);
    [a1, b1] = deriv(x,            y,            Ka, Ta2(i0), G2(i0), W2(i0), p);
    [a2, b2] = deriv(x + dt/2*a1,  y + dt/2*b1,  Ka, Ta2(i1), G2(i1), W2(i1), p);
    [a3, b3] = deriv(x + dt/2*a2,  y + dt/2*b2,  Ka, Ta2(i1), G2(i1), W2(i1), p);
    [a4, b4] = deriv(x + dt*a3,    y + dt*b3,    Kc, Ta2(i2), G2(i2), W2(i2), p);
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
% Reads an Open-Meteo hourly CSV; finds the columns by name.
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
if any(isnan([Ta; G; W])), error('Missing values in %s', fname); end
end

function [t, TO, HS] = run_sim(mdl, Tstop)
out = sim(mdl, 'StopTime', num2str(Tstop), 'ReturnWorkspaceOutputs', 'on');
s1  = out.get('TO_sim'); s2 = out.get('HS_sim');
t   = s1.time(:); TO = s1.signals.values(:); HS = s2.signals.values(:);
end

function build_model(mdl)
% Builds TopOil_SunWind_50MVA.slx. All parameters are names of variables
% in the base workspace (R, dTOR, tauTO, n, cA, kw, P_R, dHR, tauW, m, TO0, dH0).
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist([mdl '.slx'], 'file'), delete([mdl '.slx']); end
new_system(mdl); open_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'dt', ...
          'StopTime', 'Tstop');

IN = 'simulink/Sources/In1';            OUT = 'simulink/Sinks/Out1';
GN = 'simulink/Math Operations/Gain';    BI  = 'simulink/Math Operations/Bias';
SM = 'simulink/Math Operations/Sum';     PR  = 'simulink/Math Operations/Product';
MF = 'simulink/Math Operations/Math Function';
CO = 'simulink/Sources/Constant';        SA  = 'simulink/Discontinuities/Saturation';
IT = 'simulink/Continuous/Integrator';   FW  = 'simulink/Sources/From Workspace';
TW = 'simulink/Sinks/To Workspace';      SC  = 'simulink/Sinks/Scope';

% ---- Subsystem 1: TopOil_SunWind --------------------------------------
s = [mdl '/TopOil_SunWind'];
add_block('built-in/Subsystem', s, 'Position', [250 40 400 200]);
ab(s, IN, 'K',  [20  40  50  54], 'Port', '1');
ab(s, IN, 'Ta', [20 200  50 214], 'Port', '2');
ab(s, IN, 'G',  [20 120  50 134], 'Port', '3');
ab(s, IN, 'W',  [20 290  50 304], 'Port', '4');
ab(s, MF, 'K_squared',   [ 90  35 130  60], 'Operator', 'square');
ab(s, GN, 'times_R',     [160  35 200  60], 'Gain', 'R');
ab(s, BI, 'plus_1',      [230  35 270  60], 'Bias', '1');
ab(s, GN, 'U',           [300  35 350  60], 'Gain', '1/(R+1)');
ab(s, GN, 'sun_cA_PR',   [300 115 350 140], 'Gain', 'cA/P_R');
ab(s, GN, 'times_kw',    [ 90 285 130 310], 'Gain', 'kw');
ab(s, BI, 'wind_factor', [160 285 200 310], 'Bias', '1');
ab(s, SM, 'dTO_minus',   [150 190 170 230], 'Inputs', '+-');
ab(s, GN, 'over_dTOR',   [200 195 240 225], 'Gain', '1/dTOR');
ab(s, SA, 'no_negative', [270 195 310 225], 'UpperLimit', 'inf', 'LowerLimit', '0');
ab(s, CO, 'one_over_n',  [270 240 310 260], 'Value', '1/n');
ab(s, MF, 'power_1n',    [340 195 380 245], 'Operator', 'pow');
ab(s, PR, 'cooling',     [420 200 450 300]);
ab(s, SM, 'balance',     [480  30 510 160], 'Inputs', '++-');
ab(s, GN, 'dTOR_tauTO',  [540  80 600 110], 'Gain', 'dTOR/tauTO');
ab(s, IT, 'TO_integ',    [630  80 670 110], 'InitialCondition', 'TO0');
ab(s, OUT, 'TO',         [720  88 750 102], 'Port', '1');
al(s, 'K/1', 'K_squared/1');       al(s, 'K_squared/1', 'times_R/1');
al(s, 'times_R/1', 'plus_1/1');    al(s, 'plus_1/1', 'U/1');
al(s, 'U/1', 'balance/1');
al(s, 'G/1', 'sun_cA_PR/1');       al(s, 'sun_cA_PR/1', 'balance/2');
al(s, 'W/1', 'times_kw/1');        al(s, 'times_kw/1', 'wind_factor/1');
al(s, 'TO_integ/1', 'dTO_minus/1'); al(s, 'Ta/1', 'dTO_minus/2');
al(s, 'dTO_minus/1', 'over_dTOR/1'); al(s, 'over_dTOR/1', 'no_negative/1');
al(s, 'no_negative/1', 'power_1n/1'); al(s, 'one_over_n/1', 'power_1n/2');
al(s, 'power_1n/1', 'cooling/1');  al(s, 'wind_factor/1', 'cooling/2');
al(s, 'cooling/1', 'balance/3');   al(s, 'balance/1', 'dTOR_tauTO/1');
al(s, 'dTOR_tauTO/1', 'TO_integ/1'); al(s, 'TO_integ/1', 'TO/1');

% ---- Subsystem 2: HotSpot_gradient ------------------------------------
h = [mdl '/HotSpot_gradient'];
add_block('built-in/Subsystem', h, 'Position', [250 260 400 320]);
ab(h, IN, 'K', [20 40 50 54], 'Port', '1');
ab(h, MF, 'K_squared',  [ 90  35 130  60], 'Operator', 'square');
ab(h, SM, 'balance',    [170  30 200  90], 'Inputs', '+-');
ab(h, GN, 'dHR_tauW',   [230  45 290  75], 'Gain', 'dHR/tauW');
ab(h, IT, 'dH_integ',   [320  45 360  75], 'InitialCondition', 'dH0');
ab(h, OUT, 'dH',        [420  53 450  67], 'Port', '1');
ab(h, GN, 'over_dHR',   [320 120 360 150], 'Gain', '1/dHR');
ab(h, SA, 'no_negative',[260 120 300 150], 'UpperLimit', 'inf', 'LowerLimit', '0');
ab(h, CO, 'one_over_m', [260 170 300 190], 'Value', '1/m');
ab(h, MF, 'power_1m',   [190 120 230 170], 'Operator', 'pow');
al(h, 'K/1', 'K_squared/1');      al(h, 'K_squared/1', 'balance/1');
al(h, 'balance/1', 'dHR_tauW/1'); al(h, 'dHR_tauW/1', 'dH_integ/1');
al(h, 'dH_integ/1', 'dH/1');      al(h, 'dH_integ/1', 'over_dHR/1');
al(h, 'over_dHR/1', 'no_negative/1'); al(h, 'no_negative/1', 'power_1m/1');
al(h, 'one_over_m/1', 'power_1m/2');  al(h, 'power_1m/1', 'balance/2');

% ---- Top level: inputs, hot spot, ageing, outputs ---------------------
ab(mdl, FW, 'K_ws',  [ 40  40 120  70], 'VariableName', 'K_ws',  'Interpolate', 'off', ...
   'OutputAfterFinalValue', 'Holding final value');
ab(mdl, FW, 'Ta_ws', [ 40 100 120 130], 'VariableName', 'Ta_ws', 'Interpolate', 'on', ...
   'OutputAfterFinalValue', 'Holding final value');
ab(mdl, FW, 'G_ws',  [ 40 160 120 190], 'VariableName', 'G_ws',  'Interpolate', 'on', ...
   'OutputAfterFinalValue', 'Holding final value');
ab(mdl, FW, 'W_ws',  [ 40 220 120 250], 'VariableName', 'W_ws',  'Interpolate', 'on', ...
   'OutputAfterFinalValue', 'Holding final value');
ab(mdl, SM, 'HS_sum',      [470 150 500 230], 'Inputs', '++');
ab(mdl, BI, 'plus_273',    [540 300 580 330], 'Bias', '273');
ab(mdl, MF, 'reciprocal',  [610 300 650 330], 'Operator', 'reciprocal');
ab(mdl, GN, 'minus_15000', [680 300 730 330], 'Gain', '-15000');
ab(mdl, BI, 'plus_15000_383', [760 300 810 330], 'Bias', '15000/383');
ab(mdl, MF, 'F_AA',        [840 300 880 330], 'Operator', 'exp');
ab(mdl, IT, 'ageing_integ',[910 300 950 330], 'InitialCondition', '0');
ab(mdl, GN, 's_to_h',      [980 300 1020 330], 'Gain', '1/3600');
ab(mdl, TW, 'TO_sim',  [560  60 640  90], 'VariableName', 'TO_sim',  'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
ab(mdl, TW, 'HS_sim',  [560 180 640 210], 'VariableName', 'HS_sim',  'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
ab(mdl, TW, 'AGE_sim', [1050 300 1130 330], 'VariableName', 'AGE_sim', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
ab(mdl, SC, 'Scope_TO_HS', [700 120 740 220], 'NumInputPorts', '2');

al(mdl, 'K_ws/1',  'TopOil_SunWind/1');   al(mdl, 'K_ws/1', 'HotSpot_gradient/1');
al(mdl, 'Ta_ws/1', 'TopOil_SunWind/2');
al(mdl, 'G_ws/1',  'TopOil_SunWind/3');
al(mdl, 'W_ws/1',  'TopOil_SunWind/4');
al(mdl, 'TopOil_SunWind/1',   'HS_sum/1');
al(mdl, 'HotSpot_gradient/1', 'HS_sum/2');
al(mdl, 'TopOil_SunWind/1', 'TO_sim/1');  al(mdl, 'TopOil_SunWind/1', 'Scope_TO_HS/1');
al(mdl, 'HS_sum/1', 'HS_sim/1');          al(mdl, 'HS_sum/1', 'Scope_TO_HS/2');
al(mdl, 'HS_sum/1', 'plus_273/1');
al(mdl, 'plus_273/1', 'reciprocal/1');    al(mdl, 'reciprocal/1', 'minus_15000/1');
al(mdl, 'minus_15000/1', 'plus_15000_383/1'); al(mdl, 'plus_15000_383/1', 'F_AA/1');
al(mdl, 'F_AA/1', 'ageing_integ/1');      al(mdl, 'ageing_integ/1', 's_to_h/1');
al(mdl, 's_to_h/1', 'AGE_sim/1');

try   % tidy the layout (R2018b and newer)
    Simulink.BlockDiagram.arrangeSystem(s);
    Simulink.BlockDiagram.arrangeSystem(h);
    Simulink.BlockDiagram.arrangeSystem(mdl);
catch
end
save_system(mdl);
end

function ab(sys, lib, name, pos, varargin)
add_block(lib, [sys '/' name], 'Position', pos, varargin{:});
end

function al(sys, src, dst)
add_line(sys, src, dst, 'autorouting', 'on');
end
