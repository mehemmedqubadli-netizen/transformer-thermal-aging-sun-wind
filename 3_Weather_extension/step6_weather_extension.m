%% STEP 6 - IEEE top-oil model extended with sun and wind (Norway validation)
% Needs in the same folder:
%   Barug2025_sensordata.csv   (Baerug et al. 2025, 40 MVA ONAN, hourly 2024)
%   oslo_2024.csv              (Open-Meteo historical weather, 59.86 N 10.81 E, UTC)
%
% Model (IEEE C57.91 Annex G, form B) with two weather terms:
%   dTO/dt = (dTO_R/tau) * [ U + cA*G/P_R - (1 + kw*W) * ((TO - Ta)/dTO_R)^(1/n) ]
%   U = (K^2*R + 1)/(R + 1)
%   G  = global horizontal solar irradiance [W/m2]  -> extra heat input c*A*G
%   W  = wind speed at 10 m [m/s]                    -> stronger radiator cooling
%   cA = effective sunlit area x absorptivity [m2]   (fitted)
%   kw = wind cooling factor [1/(m/s)]               (fitted)
%
% Four models are fitted on Jan-Jun and tested on Jul-Dec:
%   1 IEEE (base)   2 + sun   3 + wind   4 + sun + wind
% Same numerics as step 5: RK4, 5-min substeps, inputs held per hour,
% restart from the measurement after each data gap.

clear; clc; close all;

%% 1. Constants (Norway unit)
R   = 7.5;            % load / no-load loss ratio (120 kW / 16 kW)
n   = 0.8;            % oil exponent
P_R = 136e3;          % rated total losses [W] = 120 kW + 16 kW
I_R = 40e6/(sqrt(3)*132e3);   % rated HV current = 175 A

%% 2. Read the measured data
fid = fopen('Barug2025_sensordata.csv');
hdr = fgetl(fid);
C   = textscan(fid, '%s %f %f %f %f %*[^\n]', 'Delimiter', ',', 'Whitespace', '');
fclose(fid);
t   = datenum(C{1}, 'yyyy-mm-dd HH:MM:SS');   % Norwegian local time (CET/CEST)
K   = C{3} / I_R;     % load factor [pu]
Ta  = C{4};           % ambient [degC]
TO  = C{5};           % measured top oil [degC]

%% 3. Read the weather data and convert UTC -> Norwegian local time
fid = fopen('oslo_2024.csv');
for k = 1:4, fgetl(fid); end                  % skip the 4 header lines
Wd  = textscan(fid, '%s %f %f %f %f %f %f', 'Delimiter', ',', 'Whitespace', '');
fclose(fid);
tw  = datenum(strrep(Wd{1},'T',' '), 'yyyy-mm-dd HH:MM');     % UTC
% Summer time 2024: 31 Mar 01:00 UTC to 27 Oct 01:00 UTC -> UTC+2, otherwise UTC+1
dst = tw >= datenum(2024,3,31,1,0,0) & tw < datenum(2024,10,27,1,0,0);
tw  = tw + (1 + dst)/24;
[tw, iu] = unique(tw);                        % remove the doubled hour in October
G_all = Wd{3}(iu);                            % shortwave radiation [W/m2]
W_all = Wd{6}(iu);                            % wind speed 10 m [m/s]
% Value for each measured hour (nearest weather hour)
G = interp1(tw, G_all, t, 'nearest', 'extrap');
W = interp1(tw, W_all, t, 'nearest', 'extrap');

% Check: the weather file must cover the measured hours
fprintf('Data: %d hours, mean G = %.0f W/m2, mean wind = %.2f m/s\n', numel(t), mean(G), mean(W));

%% 4. Data gaps -> restart points
restart = [true; diff(t)*24 > 1.5];

%% 5. Calibration / validation split
mo  = str2num(datestr(t, 'mm'));  %#ok<ST2NM>
cal = mo <= 6;   val = ~cal;

%% 6. Fit the four models
names = {'IEEE (base)', '+ sun', '+ wind', '+ sun + wind'};
useS  = [0 1 0 1];
useW  = [0 0 1 1];
x0all = [64.8 8.0 20 0.05];       % start values: dTO_R [K], tau [h], cA [m2], kw [1/(m/s)]
P     = zeros(4,4);  E = zeros(numel(t),4);
opt   = optimset('Display','off','TolX',1e-4,'TolFun',1e-5,'MaxIter',600,'MaxFunEvals',1200);

for c = 1:4
    free = logical([1 1 useS(c) useW(c)]);
    q0   = x0all(free);  q0(1:2) = log(q0(1:2));          % dTO_R and tau fitted as logs (stay positive)
    cost = @(q) rmse_on(q, free, cal, K, Ta, G, W, TO, restart, R, n, P_R);
    q    = fminsearch(cost, q0, opt);
    p    = unpack(q, free);
    P(c,:) = p;
    E(:,c) = topoil_weather(p, K, Ta, G, W, TO, restart, R, n, P_R) - TO;
    fprintf('%-14s fitted.\n', names{c});
end

%% 7. Results table
rm = @(e) sqrt(mean(e.^2));
fprintf('\n%-14s %8s %7s %8s %8s %9s %9s %9s %8s\n', 'Model','dTO_R K','tau h','cA m2','kw', ...
        'RMSE cal','RMSE val','RMSE yr','max|e|val');
for c = 1:4
    e = E(:,c);
    fprintf('%-14s %8.1f %7.1f %8.1f %8.3f %9.2f %9.2f %9.2f %8.2f\n', names{c}, P(c,:), ...
            rm(e(cal)), rm(e(val)), rm(e), max(abs(e(val))));
end

fprintf('\nMonthly mean error [K] (simulated - measured):\n');
fprintf('%-14s', 'Month');  fprintf('%6d', 1:12);  fprintf('\n');
for c = [1 4]
    fprintf('%-14s', names{c});
    for m = 1:12, fprintf('%6.2f', mean(E(mo==m,c))); end
    fprintf('\n');
end

%% 8. Plots
figure('Name','Monthly mean error','Position',[100 100 800 400]);
Mb = zeros(12,4);
for c = 1:4, for m = 1:12, Mb(m,c) = mean(E(mo==m,c)); end, end
bar(Mb(:,[1 4])); grid on;
set(gca,'XTickLabel',{'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'});
ylabel('Mean error [K]'); legend('IEEE','IEEE + sun + wind','Location','best');
title('Monthly mean top-oil error, Norway 2024');

figure('Name','One week in July','Position',[100 550 900 400]);
wk = t >= datenum(2024,7,1) & t < datenum(2024,7,8);
plot(t(wk), TO(wk), 'k', 'LineWidth', 1.5); hold on;
plot(t(wk), TO(wk) + E(wk,1), t(wk), TO(wk) + E(wk,4)); grid on;
datetick('x','dd mmm','keeplimits');
ylabel('\theta_{TO} [°C]'); legend('Measured','IEEE','IEEE + sun + wind','Location','best');
title('Top oil, first week of July (validation period)');

%% 9. Save
save('step6_results.mat', 'P', 'E', 'names', 'cal', 'val', 'G', 'W', 'R', 'n', 'P_R');
fprintf('\nSaved step6_results.mat\n');

%% ------------------------------------------------------------------------
function p = unpack(q, free)
% Builds the full parameter vector [dTO_R tau cA kw] from the fitted ones.
p = [0 0 0 0];
p(free) = q;
p(1:2)  = exp(p(1:2));
end

function J = rmse_on(q, free, idx, K, Ta, G, W, TO, restart, R, n, P_R)
p  = unpack(q, free);
th = topoil_weather(p, K, Ta, G, W, TO, restart, R, n, P_R);
J  = sqrt(mean((th(idx) - TO(idx)).^2));
end

function th = topoil_weather(p, K, Ta, G, W, TO, restart, R, n, P_R)
% IEEE Annex G (form B) top-oil model with sun and wind terms.
% Inputs held constant over each hour; RK4 with 12 substeps of 5 min.
dR = p(1); tau = p(2); cA = p(3); kw = p(4);
N  = numel(K);  th = zeros(N,1);  x = TO(1);
h  = 5/60;  ns = 12;  a = dR/tau;  e = 1/n;
for i = 1:N
    if restart(i), x = TO(i); end
    th(i) = x;
    if i == N, break; end
    U  = (K(i)^2*R + 1)/(R + 1) + cA*G(i)/P_R;   % heating: losses + sun
    cw = 1 + kw*W(i);                            % cooling factor from wind
    A  = Ta(i);
    for s = 1:ns
        k1 = a*(U - cw*sign(x-A)*abs((x-A)/dR)^e);
        y  = x + h/2*k1;  k2 = a*(U - cw*sign(y-A)*abs((y-A)/dR)^e);
        y  = x + h/2*k2;  k3 = a*(U - cw*sign(y-A)*abs((y-A)/dR)^e);
        y  = x + h*k3;    k4 = a*(U - cw*sign(y-A)*abs((y-A)/dR)^e);
        x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
end
end
