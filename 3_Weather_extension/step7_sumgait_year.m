%% STEP 7 - 50 MVA Azerikimya transformer, one year of Sumgait weather (2024)
% IEEE model vs IEEE + sun + wind (parameters from step 6, Norway fit).
% Needs in the same folder:
%   sumgait_2024.csv   (Open-Meteo historical weather, 40.60 N 49.65 E, UTC)
%
% Load: Case 2 profile repeated every day of 2024.
% Top oil  (form B): dTO/dt = (dTO_R/tau_O)*[U + cA*G/P_R - (1+kw*W)*((TO-Ta)/dTO_R)^(1/n)]
% Hot spot (form B): dH/dt  = (dH_R/tau_W)*[K^2 - (dH/dH_R)^(1/m)],  HS = TO + dH
% Ageing: F_AA = exp(15000/383 - 15000/(HS + 273)), 110 degC reference.

clear; clc; close all;

%% 1. 50 MVA parameters (same as Case2_inputs.m)
P_NL  = 26.92e3;  P_LL = 135.9e3;     % no-load and load losses [W]
R     = P_LL/P_NL;                    % 5.05
P_R   = P_NL + P_LL;                  % rated total losses [W]
dTO_R = 49;   dH_R = 18;              % rated rises [K]
tau_O = 180/60;  tau_W = 6/60;        % time constants [h]
n = 0.8;  m = 0.8;

%% 2. Case 2 daily load profile [pu]
% Levels recovered from the Case 2 results (peak HS 105.3, TO 82.3, ageing 2.73 h at 24 degC).
% Replace with the exact values from Table 3.3 if they differ.
K_night = 0.687;     % 00-06  (Load A)
K_day   = 0.833;     % 06-12 and 18-24 (Loads A+B)
K_peak  = 1.161;     % 12-18  (Loads A+B+C+D)

%% 3. Weather parameters (from step 6, Norway fit) and cases
kw     = 0.0504;                % wind cooling factor [1/(m/s)]
cA_40  = 20.07;                 % fitted on the 40 MVA unit [m2]
cA     = cA_40*(50/40)^0.5;     % scaled to 50 MVA by surface area ~ S^0.5 -> 22.4 m2
cases  = {'IEEE (no sun, no wind)', '+ sun', '+ wind', '+ sun + wind', '+ sun + half wind'};
cAc    = [0   cA  0   cA  cA  ];
kwc    = [0   0   kw  kw  kw/2];

%% 4. Read weather, convert to local time (Azerbaijan UTC+4), interpolate to 1 min
fid = fopen('sumgait_2024.csv');
for k = 1:4, fgetl(fid); end
Wd  = textscan(fid, '%s %f %f %f %f %f %f', 'Delimiter', ',', 'Whitespace', '');
fclose(fid);
tw  = datenum(strrep(Wd{1},'T',' '), 'yyyy-mm-dd HH:MM') + 4/24;
dt  = 1/60;                                     % time step [h]
t   = (datenum(2024,1,1):dt/24:datenum(2024,12,31,23,59,0))';
Ta  = interp1(tw, Wd{2}, t, 'linear', 'extrap');
G   = max(interp1(tw, Wd{3}, t, 'linear', 'extrap'), 0);
W   = max(interp1(tw, Wd{6}, t, 'linear', 'extrap'), 0);

hr  = mod(t - floor(t), 1)*24;                  % hour of day
K   = K_day*ones(size(t));
K(hr < 6) = K_night;
K(hr >= 12 & hr < 18) = K_peak;

%% 5. Check: constant 24 degC must reproduce Case 2
day = 1:1440;  x = [64.4 13.5];
for r = 1:8
    [TOc, Hc, x] = thermal50(K(day), 24*ones(1440,1), zeros(1440,1), zeros(1440,1), x, ...
                             0, 0, R, P_R, dTO_R, dH_R, tau_O, tau_W, n, m, dt);
end
fprintf('Check at 24 degC: peak HS %.1f (Case 2: 105.3), peak TO %.1f (82.3), ageing %.2f h (2.73)\n\n', ...
        max(Hc), max(TOc), sum(faa(Hc))*dt);

%% 6. Run the year for each case
mo  = str2num(datestr(t, 'mm'));  %#ok<ST2NM>
dno = floor(t);  [~, ~, dIdx] = unique(dno);
res = zeros(numel(cases), 6);  AgeM = zeros(12, numel(cases));  HSall = zeros(numel(t), numel(cases));
for c = 1:numel(cases)
    x = [50 13];                                             % warm-up: 1 Jan three times
    for r = 1:3
        [~, ~, x] = thermal50(K(day), Ta(day), G(day), W(day), x, cAc(c), kwc(c), ...
                              R, P_R, dTO_R, dH_R, tau_O, tau_W, n, m, dt);
    end
    [TOy, Hy] = thermal50(K, Ta, G, W, x, cAc(c), kwc(c), R, P_R, dTO_R, dH_R, tau_O, tau_W, n, m, dt);
    F      = faa(Hy);
    dayMax = accumarray(dIdx, Hy, [], @max);
    res(c,:) = [sum(F)*dt, sum(F)*dt/180000*100, max(Hy), max(TOy), sum(Hy > 110)*dt, sum(dayMax > 110)];
    for k = 1:12, AgeM(k,c) = sum(F(mo == k))*dt; end
    HSall(:,c) = Hy;
    fprintf('%s done.\n', cases{c});
end

%% 7. Results
fprintf('\n%-24s %10s %9s %8s %8s %10s %9s\n', 'Model', 'Ageing h', 'LoL %/yr', 'HSmax', 'TOmax', 'h HS>110', 'days>110');
for c = 1:numel(cases)
    fprintf('%-24s %10.0f %9.2f %8.1f %8.1f %10.0f %9d\n', cases{c}, res(c,1:5), res(c,6));
end
fprintf('\nChange in annual ageing vs IEEE: ');
fprintf('%s %+.0f %%;  ', cases{2}, 100*(res(2,1)/res(1,1)-1));
fprintf('%s %+.0f %%;  ', cases{4}, 100*(res(4,1)/res(1,1)-1));
fprintf('%s %+.0f %%\n', cases{5}, 100*(res(5,1)/res(1,1)-1));

%% 8. Plots
figure('Name','Monthly ageing','Position',[100 100 800 400]);
bar(AgeM(:,[1 2 4])); grid on;
set(gca,'XTickLabel',{'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'});
ylabel('Ageing [h per month]'); legend(cases([1 2 4]), 'Location','northwest');
title('50 MVA unit, Case 2 load every day, Sumgait 2024');

figure('Name','Hottest week','Position',[100 550 900 400]);
[~, imax] = max(HSall(:,1));
wk = t >= floor(t(imax)) - 3 & t < floor(t(imax)) + 4;
plot(t(wk), HSall(wk,1), t(wk), HSall(wk,2), t(wk), HSall(wk,4)); hold on;
plot(t(wk), 110*ones(sum(wk),1), 'k--'); grid on;
datetick('x','dd mmm','keeplimits');
ylabel('Hot spot [°C]'); legend([cases([1 2 4]) {'110 °C'}], 'Location','best');
title('Hot spot in the hottest week');

%% 9. Save
save('step7_results.mat', 'res', 'AgeM', 'cases', 'cA', 'kw', 'K_night', 'K_day', 'K_peak');
fprintf('\nSaved step7_results.mat\n');

%% ------------------------------------------------------------------------
function F = faa(H)
F = exp(15000/383 - 15000./(H + 273));
end

function [TO, HS, xe] = thermal50(K, Ta, G, W, x0, cA, kw, R, P_R, dTO_R, dH_R, tau_O, tau_W, n, m, dt)
% Top oil and hot spot, IEEE Annex G (form B), with sun and wind in the top-oil equation.
% RK4, one step per minute for top oil, six substeps for the hot-spot gradient (tau_W = 6 min).
N  = numel(K);  TO = zeros(N,1);  HS = zeros(N,1);
x  = x0(1);  y = x0(2);
aO = dTO_R/tau_O;  aH = dH_R/tau_W;  eO = 1/n;  eH = 1/m;  hs = dt/6;
for i = 1:N
    U  = (K(i)^2*R + 1)/(R + 1) + cA*G(i)/P_R;
    cw = 1 + kw*W(i);  A = Ta(i);  K2 = K(i)^2;
    k1 = aO*(U - cw*sign(x-A)*abs((x-A)/dTO_R)^eO);
    z  = x + dt/2*k1;  k2 = aO*(U - cw*sign(z-A)*abs((z-A)/dTO_R)^eO);
    z  = x + dt/2*k2;  k3 = aO*(U - cw*sign(z-A)*abs((z-A)/dTO_R)^eO);
    z  = x + dt*k3;    k4 = aO*(U - cw*sign(z-A)*abs((z-A)/dTO_R)^eO);
    x  = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);
    for s = 1:6
        j1 = aH*(K2 - sign(y)*abs(y/dH_R)^eH);
        z  = y + hs/2*j1;  j2 = aH*(K2 - sign(z)*abs(z/dH_R)^eH);
        z  = y + hs/2*j2;  j3 = aH*(K2 - sign(z)*abs(z/dH_R)^eH);
        z  = y + hs*j3;    j4 = aH*(K2 - sign(z)*abs(z/dH_R)^eH);
        y  = y + hs/6*(j1 + 2*j2 + 2*j3 + j4);
    end
    TO(i) = x;  HS(i) = x + y;
end
xe = [x y];
end
