%% step10_SA1_continuous.m
% SA1 (Burcu, 21 Nov): ambient temperature as a CONTINUOUS variable.
% Thesis Simulink model (Integrated_Transformer_Case2_sunwind, sun and wind
% switched OFF = identical to the original Case 2 model, Check A), Case 2 load,
% constant ambient swept from Ta_min to Ta_max.
%
% Start values: the daily cycle is first made periodic at 24 degC (end of day =
% start of day). Because the top-oil and hot-spot equations only contain
% (Theta_TO - Ta) and (Theta_H - Theta_TO), the periodic start for any other
% ambient is the 24 degC one shifted by (Ta - 24). One run per ambient.
%
% Output: table (Command Window + SA1_sweep.xlsx), crossover ambients,
% two figures for the thesis. Put in 3_Weather_extension (same as step9).

clear; clc; close all;
run('Case2_inputs.m');                 % has its own "clear" -> must run first

mdl    = 'Integrated_Transformer_Case2_sunwind';
Ta_vec = (0:1:45)';                    % sweep [degC] - use 0:2:45 if runs are slow
cA_sun = 0; kw_wind = 0; P_R_total = 26.92e3 + 135.9e3;   % weather OFF
G_ws = [0 0; 86400 0];  W_ws = [0 0; 86400 0];
load_system(mdl);

%% 1. Periodic start values at 24 degC ------------------------------------
Ta_ws = [0 24; 86400 24];
TO0 = 64.4; H0 = 77.9;                 % first guess (end of Case 2 day)
for it = 1:5
    Theta_TO_0 = TO0; Theta_H_0 = H0;
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    [t, TO, HS] = get_TO_HS(out);
    dEnd = max(abs([TO(end) - TO0, HS(end) - H0]));
    fprintf('Periodic start, iteration %d: start %.2f / %.2f, end %.2f / %.2f (diff %.3f K)\n', ...
        it, TO0, H0, TO(end), HS(end), dEnd);
    TO0 = TO(end); H0 = HS(end);
    if dEnd < 0.01, break; end
end
TO0_24 = TO0; H0_24 = H0;
fprintf('24 degC periodic day: peak HS %.1f, peak TO %.1f, ageing %.2f h  (thesis Case 2: 105.3 / 82.3 / 2.73)\n\n', ...
    max(HS), max(TO), ageing_h(t, HS));

%% 2. Sweep ---------------------------------------------------------------
nT  = numel(Ta_vec);
R   = zeros(nT, 6);                    % Ta, HSmax, TOmax, HSmin, ageing h/day, LoL %/day
tic;
for i = 1:nT
    Ta = Ta_vec(i);
    Ta_ws = [0 Ta; 86400 Ta];
    Theta_TO_0 = TO0_24 + (Ta - 24);
    Theta_H_0  = H0_24  + (Ta - 24);
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    [t, TO, HS] = get_TO_HS(out);
    A = ageing_h(t, HS);
    R(i,:) = [Ta, max(HS), max(TO), min(HS), A, A/180000*100];
    fprintf('Ta = %4.1f degC: HS max %6.1f, TO max %5.1f, ageing %7.2f h/day   (%d/%d, %.0f s)\n', ...
        Ta, R(i,2), R(i,3), R(i,5), i, nT, toc);
end

%% 3. Key numbers ---------------------------------------------------------
Ta_110 = crossing(Ta_vec, R(:,2), 110);      % peak HS = 110 degC
Ta_24h = crossing(Ta_vec, R(:,5), 24);       % ageing = 24 h/day (F_EQA = 1)
p      = polyfit(Ta_vec, R(:,2), 1);         % slope of peak HS vs Ta
pa     = polyfit(Ta_vec, log(R(:,5)), 1);    % ageing grows exponentially
fprintf('\nPeak HS rises %.2f K per 1 degC ambient (linear, R^2 = %.4f)\n', p(1), ...
    1 - sum((R(:,2) - polyval(p, Ta_vec)).^2)/sum((R(:,2) - mean(R(:,2))).^2));
fprintf('Daily ageing doubles every %.1f degC of ambient\n', log(2)/pa(1));
fprintf('Peak HS reaches 110 degC at Ta = %.1f degC\n', Ta_110);
fprintf('Daily ageing reaches 24 h (normal rate, F_EQA = 1) at Ta = %.1f degC\n', Ta_24h);

T = array2table(R, 'VariableNames', {'Ambient_degC', 'HS_max_degC', 'TO_max_degC', ...
    'HS_min_degC', 'Ageing_h_per_day', 'LoL_percent_per_day'});
writetable(T, 'SA1_sweep.xlsx', 'Sheet', 'SA1_continuous');
save('SA1_sweep.mat', 'R', 'Ta_vec', 'Ta_110', 'Ta_24h', 'TO0_24', 'H0_24');
fprintf('Saved SA1_sweep.xlsx and SA1_sweep.mat\n');

%% 4. Figures (thesis) ----------------------------------------------------
c1 = [0 0.447 0.741]; c2 = [0.85 0.325 0.098];

figure('Name', 'SA1 - peak temperatures', 'Position', [100 100 640 420]);
hold on; grid on; box on;
plot(Ta_vec, R(:,2), '-', 'Color', c1, 'LineWidth', 1.8);
plot(Ta_vec, R(:,3), '-', 'Color', c2, 'LineWidth', 1.8);
yline(110, 'k--', '110 \circC limit', 'LabelHorizontalAlignment', 'left');
plot(Ta_110, 110, 'ko', 'MarkerFaceColor', 'k');
text(Ta_110, 106, sprintf('  %.1f \\circC', Ta_110), 'FontSize', 10);
xline(24, ':', 'Case 2 (24 \circC)', 'LabelVerticalAlignment', 'bottom');
xlabel('Ambient temperature [\circC]'); ylabel('Peak temperature [\circC]');
legend({'Hot spot', 'Top oil'}, 'Location', 'northwest');
title('SA1: peak temperatures vs ambient (Case 2 load)');

figure('Name', 'SA1 - daily ageing', 'Position', [760 100 640 420]);
semilogy(Ta_vec, R(:,5), '-', 'Color', c1, 'LineWidth', 1.8); hold on; grid on; box on;
yline(24, 'k--', 'Normal ageing (24 h/day)', 'LabelHorizontalAlignment', 'left');
plot(Ta_24h, 24, 'ko', 'MarkerFaceColor', 'k');
text(Ta_24h, 16, sprintf('  %.1f \\circC', Ta_24h), 'FontSize', 10);
xline(24, ':', 'Case 2 (24 \circC)', 'LabelVerticalAlignment', 'bottom');
xlabel('Ambient temperature [\circC]'); ylabel('Equivalent ageing [h/day]');
title('SA1: daily insulation ageing vs ambient (Case 2 load)');

%% ======================== Local functions ===============================
function [t, TO, HS] = get_TO_HS(out)
a = out.get('Theta_TO_varying');  b = out.get('Theta_H_varying');
t = a.time(:);  TO = a.signals.values(:);
HS = interp1(b.time(:), b.signals.values(:), t);
end

function A = ageing_h(t, HS)
A = trapz(t, exp(15000/383 - 15000./(HS + 273))) / 3600;
end

function x0 = crossing(x, y, level)
% first x where y crosses level (linear interpolation); NaN if never
k = find(y(1:end-1) < level & y(2:end) >= level, 1);
if isempty(k), x0 = NaN; return; end
x0 = x(k) + (level - y(k)) * (x(k+1) - x(k)) / (y(k+1) - y(k));
end
