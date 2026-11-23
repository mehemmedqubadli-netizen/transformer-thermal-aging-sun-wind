%% step11_sumgait_year_simulink.m
% FULL YEAR of Sumgait 2024 weather on the THESIS Simulink model
% (Integrated_Transformer_Case2_sunwind, electrical part included).
% The year is simulated as 366 one-day runs; each day starts where the
% previous day ended (Theta_TO_0, Theta_H_0 <- end of previous day).
% Case 2 load every day (same assumption as step7).
%
% Cases: IEEE (real ambient, no sun, no wind), + sun, + sun + wind,
%        + sun + half wind. About 0.6 s per day -> ~4 min per case.
%
% Put in 3_Weather_extension (needs Case2_inputs.m, sumgait_2024.csv and
% Integrated_Transformer_Case2_sunwind.slx from step9).

clear; clc; close all;
run('Case2_inputs.m');                 % has its own "clear" -> must run first

mdl         = 'Integrated_Transformer_Case2_sunwind';
csvFile     = 'sumgait_2024.csv';
utcOffset_h = 4;
P_R_total   = 26.92e3 + 135.9e3;
cA_fit = 22.5;  kw_fit = 0.050;
cases = { 'IEEE (no sun, no wind)', 0,      0;
          '+ sun',                  cA_fit, 0;
          '+ sun + wind',           cA_fit, kw_fit;
          '+ sun + half wind',      cA_fit, kw_fit/2 };
step7 = [759 1015 390 594];            % step7 script results for comparison
TO0_24 = 64.42;  H0_24 = 77.90;        % periodic start at 24 degC (step10)

%% 1. Weather on local time -------------------------------------------------
[Ta_u, G_u, W_u] = read_openmeteo(csvFile);          % hourly, UTC, from 2024-01-01 00:00
pad  = utcOffset_h;                                   % local 00:00-03:00 on 1 Jan not in file
Ta_l = [repmat(Ta_u(1), pad, 1); Ta_u];               % index 1 = 1 Jan 2024 00:00 local
G_l  = [repmat(G_u(1),  pad, 1); G_u];
W_l  = [repmat(W_u(1),  pad, 1); W_u];
nDays = floor((numel(Ta_l) - 1) / 24);                % 366 days (2024)
tw    = (0:24)' * 3600;
load_system(mdl);

%% 2. Year loop -------------------------------------------------------------
nc   = size(cases, 1);
tMin = (0:60:86400)';                                  % 1-min grid for storing
res  = zeros(nc, 6);                                  % ageing, LoL, HSmax, TOmax, h>110, days>110
dayAge = zeros(nDays, nc);  dayHSmax = zeros(nDays, nc);
HSyear = zeros(nDays*1440 + 1, nc);
tic;
for c = 1:nc
    cA_sun = cases{c,2};  kw_wind = cases{c,3};
    Theta_TO_0 = TO0_24 + (Ta_l(1) - 24);
    Theta_H_0  = H0_24  + (Ta_l(1) - 24);
    hot_h = 0;
    for d = 1:nDays
        r = (d-1)*24 + (1:25)';
        Ta_ws = [tw Ta_l(r)];  G_ws = [tw G_l(r)];  W_ws = [tw W_l(r)];
        out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
        [t, TO, HS] = get_TO_HS(out);
        dayAge(d,c)   = ageing_h(t, HS);
        dayHSmax(d,c) = max(HS);
        res(c,4) = max(res(c,4), max(TO));
        HSm = interp1(t, HS, tMin);
        hot_h = hot_h + sum(HSm(1:end-1) > 110) / 60;
        HSyear((d-1)*1440 + (1:1441), c) = HSm;
        Theta_TO_0 = TO(end);  Theta_H_0 = HS(end);    % next day starts here
        if mod(d, 61) == 0
            fprintf('  %-24s day %3d/%d  (%.0f s)\n', cases{c,1}, d, nDays, toc);
        end
    end
    A = sum(dayAge(:,c));
    res(c,[1 2 3 5 6]) = [A, A/180000*100, max(dayHSmax(:,c)), hot_h, sum(dayHSmax(:,c) > 110)];
    fprintf('%-24s done (%.0f s)\n', cases{c,1}, toc);
end

%% 3. Results -------------------------------------------------------------
fprintf('\nFULL YEAR, thesis Simulink model, Case 2 load every day, Sumgait 2024\n');
fprintf('%-24s %9s %9s %8s %8s %9s %9s %10s\n', 'Model', 'Ageing h', 'LoL %/yr', ...
    'HSmax', 'TOmax', 'h HS>110', 'days>110', 'step7 h');
for c = 1:nc
    fprintf('%-24s %9.0f %9.2f %8.1f %8.1f %9.0f %9d %10.0f\n', cases{c,1}, res(c,1), res(c,2), ...
        res(c,3), res(c,4), res(c,5), res(c,6), step7(c));
end
fprintf('Change vs IEEE: + sun %+.0f %%,  + sun + wind %+.0f %%,  + sun + half wind %+.0f %%\n', ...
    100*(res(2,1)/res(1,1)-1), 100*(res(3,1)/res(1,1)-1), 100*(res(4,1)/res(1,1)-1));

dn  = datenum(2024,1,1) + (0:nDays-1)';
mon = str2num(datestr(dn, 'mm')); %#ok<ST2NM>
monAge = zeros(12, nc);
for k = 1:12, monAge(k,:) = sum(dayAge(mon == k, :), 1); end
fprintf('\nMonthly ageing [h]:\n%-24s', 'Month');  fprintf('%7d', 1:12);  fprintf('\n');
for c = 1:nc, fprintf('%-24s', cases{c,1}); fprintf('%7.1f', monAge(:,c)); fprintf('\n'); end

T = array2table(res, 'VariableNames', {'Ageing_h_per_year', 'LoL_percent_per_year', ...
    'HS_max_degC', 'TO_max_degC', 'Hours_HS_above_110', 'Days_HS_above_110'}, ...
    'RowNames', cases(:,1));
writetable(T, 'Sumgait_year_Simulink.xlsx', 'Sheet', 'Annual', 'WriteRowNames', true);
M = array2table([(1:12)' monAge], 'VariableNames', [{'Month'}, matlab.lang.makeValidName(cases(:,1))']);
writetable(M, 'Sumgait_year_Simulink.xlsx', 'Sheet', 'Monthly_ageing_h');
save('step11_results.mat', 'cases', 'res', 'dayAge', 'dayHSmax', 'monAge', 'HSyear', 'nDays');
fprintf('\nSaved Sumgait_year_Simulink.xlsx and step11_results.mat\n');

%% 4. Figures (thesis) ----------------------------------------------------
cols = [0 0.447 0.741; 0.85 0.325 0.098; 0.929 0.694 0.125; 0.466 0.674 0.188];

figure('Name', 'Monthly ageing', 'Position', [80 80 720 420]);
b = bar(monAge(:, [1 2 3]), 'grouped');
for k = 1:3, b(k).FaceColor = cols(k,:); end
grid on; box on;
set(gca, 'XTickLabel', {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'});
ylabel('Ageing [h per month]');
legend(cases([1 2 3],1), 'Location', 'northwest');
title('50 MVA unit, Case 2 load every day, Sumgait 2024');

figure('Name', 'Hottest week', 'Position', [820 80 720 420]);
tYear = datenum(2024,1,1) + (0:nDays*1440)'/1440;
idx = tYear >= datenum(2024,8,2) & tYear <= datenum(2024,8,9);
hold on; grid on; box on;
for c = 1:nc, plot(tYear(idx), HSyear(idx,c), 'Color', cols(c,:), 'LineWidth', 1.2); end
plot(tYear(idx), 110*ones(sum(idx),1), 'k--');
datetick('x', 'dd mmm'); xlim([datenum(2024,8,2) datenum(2024,8,9)]);
ylabel('Hot spot [\circC]');
legend([cases(:,1); {'110 \circC'}], 'Location', 'south');
title('Hot spot in the hottest week, 50 MVA, Sumgait 2024');

%% ======================== Local functions ===============================
function [t, TO, HS] = get_TO_HS(out)
a = out.get('Theta_TO_varying');  b = out.get('Theta_H_varying');
t = a.time(:);  TO = a.signals.values(:);
HS = interp1(b.time(:), b.signals.values(:), t);
end

function A = ageing_h(t, HS)
A = trapz(t, exp(15000/383 - 15000./(HS + 273))) / 3600;
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
