%% step12_ambient_vs_harmonics_datasheet.m
% Burcu (21 Nov): (1) which dominates the transformer temperature - ambient
% (SA1) or harmonics (SA2)? (2) make a datasheet from the results.
%
% Model: copy of Integrated_Transformer_SA2_Harmonic_fixed.slx (your SA2 model,
% electrical part included) with two parameters made adjustable:
%   - Top_Oil_Thermal_Model/Constant1:  24            -> Ta_const   (ambient)
%   - top-level Gain (K path):  1/I_rated*Irms_I1     -> 1/I_rated*Irms_I1*K_scale
%     (K_scale = 1 is Case 2; K_scale scales the whole daily load profile)
% The original SA2 model is not changed.
%
% Method: every (share, load) combination is run at 24 degC to its periodic
% daily state. Other ambients follow EXACTLY by shifting all temperatures by
% (Ta - 24) - the equations contain only temperature differences (shown in
% SA1: slope 1.00 K/degC, R^2 = 1.0000). A spot check with full Simulink runs
% at other ambients is printed at the end.
%
% Put in 1_Case_studies (needs Integrated_Transformer_SA2_Harmonic_fixed.slx,
% Case2_inputs.m, optional rect_spectrum.mat).

clear; clc; close all;
run('Case2_inputs.m');                          % has its own "clear" -> must run first

src   = 'Integrated_Transformer_SA2_Harmonic_fixed';
mdl   = 'Integrated_Transformer_SA2_datasheet';
alpha_grid = 0:0.025:0.50;                      % nonlinear share for the dominance map
alpha_ds   = [0 0.15 0.30];                     % shares in the datasheet
s_grid     = 0.70:0.05:1.30;                    % load scale (1 = Case 2) for the datasheet
Ta_grid    = 0:1:45;                            % ambient range
K_peak     = 1.161;                             % Case 2 peak-period load [pu]

%% 1. Rectifier spectrum (same as run_SA2_Share.m) -------------------------
if isfile('rect_spectrum.mat')
    load('rect_spectrum.mat', 'rho', 'hh');
else
    hh  = 1:25;  rho = zeros(1, 25);  rho(1) = 1;
    rho([5 7 11 13 17 19 23 25]) = [19.541 13.282 7.7871 6.1518 4.0291 3.266 2.1463 1.7349] / 100;
end

%% 2. Adjustable copy of the SA2 model -------------------------------------
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist([mdl '.slx'], 'file'), delete([mdl '.slx']); end
copyfile([src '.slx'], [mdl '.slx']);
load_system(mdl);
set_param([mdl '/Top_Oil_Thermal_Model/Constant1'], 'Value', 'Ta_const');
set_param([mdl '/Gain'], 'Gain', '1/I_rated*Irms_I1*K_scale');
save_system(mdl);
fprintf('Made %s.slx (ambient = Ta_const, K x K_scale). Original unchanged.\n\n', mdl);

%% 3. Runs at 24 degC --------------------------------------------------------
Ta_const = 24;
runs = {};                                       % each: alpha, s, t, TO, HS, HLF, Irms, THD
combos = [alpha_grid' ones(numel(alpha_grid),1)];
for a = alpha_ds
    combos = [combos; a*ones(numel(s_grid),1) s_grid']; %#ok<AGROW>
end
combos = unique(round(combos, 6), 'rows');
TO0 = 64.42;  H0 = 77.90;  tic;
for i = 1:size(combos, 1)
    [HLF, Irms_I1, F_HL, THD] = harmonic_factors(combos(i,1), rho, hh, PEC_R);
    K_scale = combos(i,2);
    [t, TO, HS, TO0, H0, nr] = run_periodic(mdl, TO0, H0);
    runs(end+1, :) = {combos(i,1), K_scale, t, TO, HS, HLF, Irms_I1, THD, F_HL}; %#ok<AGROW>
    fprintf('share %4.1f %%, load x%.2f: HS %6.1f, TO %5.1f, ageing %6.2f h  (%d runs, %.0f s)\n', ...
        100*combos(i,1), K_scale, max(HS), max(TO), ageing_h(t, HS), nr, toc);
end
HLF = 1; Irms_I1 = 1; K_scale = 1; Ta_const = 24;           % back to Case 2
find_run = @(a, s) find(abs([runs{:,1}] - a) < 1e-6 & abs([runs{:,2}] - s) < 1e-6, 1);

%% 4. Dominance: ambient vs harmonics (Case 2 load) ------------------------
nA = numel(alpha_grid);  nT = numel(Ta_grid);
P24 = zeros(nA,1); TO24 = zeros(nA,1); Ag24 = zeros(nA,1); THDv = zeros(nA,1); HLFv = zeros(nA,1);
HSgrid = zeros(nT, nA);  AGgrid = zeros(nT, nA);
for j = 1:nA
    r = runs(find_run(alpha_grid(j), 1), :);
    P24(j) = max(r{5});  TO24(j) = max(r{4});  Ag24(j) = ageing_h(r{3}, r{5});
    THDv(j) = r{8};  HLFv(j) = r{6};
    for k = 1:nT
        HSgrid(k,j) = P24(j) + (Ta_grid(k) - 24);
        AGgrid(k,j) = ageing_h(r{3}, r{5} + (Ta_grid(k) - 24));
    end
end
% equivalent ambient rise of each share: (a) same peak HS, (b) same daily ageing
dT_peak = P24 - P24(1);
AG0 = AGgrid(:,1);
dT_age = interp1(log(AG0), Ta_grid', log(Ag24), 'linear', 'extrap') - 24;

fprintf('\n=== Which dominates? (Case 2 load, 24 degC) ===\n');
fprintf('%7s %7s %7s %9s %9s %10s %16s %16s\n', 'share %', 'THD %', 'HLF', 'HS max', 'TO max', 'ageing h', 'same peak as +K', 'same ageing as +K');
for j = 1:2:nA
    fprintf('%7.1f %7.1f %7.3f %9.1f %9.1f %10.2f %16.1f %16.1f\n', 100*alpha_grid(j), 100*THDv(j), ...
        HLFv(j), P24(j), TO24(j), Ag24(j), dT_peak(j), dT_age(j));
end
a110_24 = interp1(P24, alpha_grid, 110);
fprintf('At 24 degC, peak HS reaches 110 degC at a share of %.1f %% (SA2: ~24 %%)\n', 100*a110_24);

%% 5. Datasheet ------------------------------------------------------------
% (a) maximum nonlinear share at each ambient (Case 2 load, HS <= 110 degC)
amax = nan(nT, 1);
for k = 1:nT
    target = 110 - (Ta_grid(k) - 24);                 % needed peak at 24 degC
    if P24(1) > target,       amax(k) = 0;            % not even without harmonics
    elseif P24(end) <= target, amax(k) = Inf;         % above the swept range
    else,                     amax(k) = interp1(P24, alpha_grid, target);
    end
end
% (b) maximum load factor at each ambient for shares 0/15/30 % (HS <= 110 degC)
smax = nan(nT, numel(alpha_ds));  AGds = nan(nT, numel(alpha_ds));
for q = 1:numel(alpha_ds)
    Ps = arrayfun(@(s) max(runs{find_run(alpha_ds(q), s), 5}), s_grid);
    for k = 1:nT
        target = 110 - (Ta_grid(k) - 24);
        if Ps(1) > target || Ps(end) < target, continue; end
        smax(k,q) = interp1(Ps, s_grid, target);
    end
    r = runs(find_run(alpha_ds(q), 1), :);
    for k = 1:nT, AGds(k,q) = ageing_h(r{3}, r{5} + (Ta_grid(k) - 24)); end
end

rowsDS = 1:5:nT;                                       % 0, 5, 10, ... 45 degC
fprintf('\n=== DATASHEET - 50 MVA, 110/10.5 kV, ONAN, Case 2 daily load shape ===\n');
fprintf('Limit: peak hot spot 110 degC. "Peak load" = load in 12-18 h (Case 2 = %.3f pu).\n', K_peak);
fprintf('%8s | %15s | %26s | %26s\n', 'Ambient', 'max nonlinear', 'max peak load [pu] at share', 'daily ageing [h] at share');
fprintf('%8s | %15s | %8s %8s %8s | %8s %8s %8s\n', '[degC]', 'share (Case 2)', '0 %', '15 %', '30 %', '0 %', '15 %', '30 %');
for k = rowsDS
    if isinf(amax(k)), sa = '> 50 %'; elseif amax(k) == 0, sa = 'none'; else, sa = sprintf('%.0f %%', 100*amax(k)); end
    fprintf('%8.0f | %15s | %8.2f %8.2f %8.2f | %8.2f %8.2f %8.2f\n', Ta_grid(k), sa, ...
        K_peak*smax(k,:), AGds(k,:));
end

DS = table(Ta_grid(rowsDS)', 100*amax(rowsDS), K_peak*smax(rowsDS,1), K_peak*smax(rowsDS,2), ...
    K_peak*smax(rowsDS,3), AGds(rowsDS,1), AGds(rowsDS,2), AGds(rowsDS,3), ...
    'VariableNames', {'Ambient_degC', 'Max_share_pct_Case2', 'MaxPeakLoad_pu_0pct', ...
    'MaxPeakLoad_pu_15pct', 'MaxPeakLoad_pu_30pct', 'Ageing_h_0pct', 'Ageing_h_15pct', 'Ageing_h_30pct'});
HF = table(100*alpha_grid', 100*THDv, HLFv, P24, TO24, Ag24, dT_peak, dT_age, ...
    'VariableNames', {'Share_pct', 'THD_pct', 'HLF', 'HS_max_24C', 'TO_max_24C', 'Ageing_h_24C', ...
    'Equiv_ambient_rise_peak_K', 'Equiv_ambient_rise_ageing_K'});
gNames = [{'Ambient_degC'}, arrayfun(@(a) ['share_' strrep(sprintf('%.1f', 100*a), '.', 'p') '_pct'], ...
    alpha_grid, 'UniformOutput', false)];
G1 = array2table([Ta_grid' HSgrid], 'VariableNames', gNames);
G2 = array2table([Ta_grid' AGgrid], 'VariableNames', gNames);
fx = 'Datasheet_50MVA.xlsx';
if isfile(fx), delete(fx); end
writetable(DS, fx, 'Sheet', 'Datasheet');
writetable(HF, fx, 'Sheet', 'Ambient_vs_harmonics');
writetable(G1, fx, 'Sheet', 'PeakHS_grid');
writetable(G2, fx, 'Sheet', 'Ageing_grid_h_per_day');
save('step12_results.mat', 'alpha_grid', 'Ta_grid', 'HSgrid', 'AGgrid', 'P24', 'Ag24', 'dT_peak', ...
    'dT_age', 'amax', 'smax', 'AGds', 's_grid', 'alpha_ds', 'THDv', 'HLFv');
fprintf('\nSaved %s and step12_results.mat\n', fx);

%% 6. Spot check: full Simulink runs at other ambients -----------------------
fprintf('\n=== Spot check: full run at another ambient vs shifted 24 degC result ===\n');
chk = [35 0.30; 10 0.15; 40 0];
for c = 1:size(chk, 1)
    [HLF, Irms_I1] = harmonic_factors(chk(c,2), rho, hh, PEC_R);  K_scale = 1;
    Ta_const = chk(c,1);
    r = runs(find_run(chk(c,2), 1), :);
    Theta_TO_0 = r{4}(end) + (Ta_const - 24);  Theta_H_0 = r{5}(end) + (Ta_const - 24);
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    [t, ~, HS] = get_TO_HS(out);
    fprintf('Ta %2d degC, share %2.0f %%: full run HS %.2f / ageing %.3f h;  shifted HS %.2f / ageing %.3f h\n', ...
        chk(c,1), 100*chk(c,2), max(HS), ageing_h(t, HS), max(r{5}) + Ta_const - 24, ...
        ageing_h(r{3}, r{5} + Ta_const - 24));
end
HLF = 1; Irms_I1 = 1; K_scale = 1; Ta_const = 24;

%% 7. Figures --------------------------------------------------------------
cols = [0 0.447 0.741; 0.85 0.325 0.098; 0.929 0.694 0.125];

figure('Name', 'Dominance map', 'Position', [60 80 680 460]);
[AA, TT] = meshgrid(100*alpha_grid, Ta_grid);
contourf(TT, AA, HSgrid, 80:5:140, 'LineColor', [0.6 0.6 0.6]); hold on;
cb = colorbar; cb.Label.String = 'Peak hot spot [\circC]';
contour(TT, AA, HSgrid, [110 110], 'k-', 'LineWidth', 2.5);
plot(24, 0, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 12);
text(25, 2.5, 'Case 2', 'FontSize', 10);
xlabel('Ambient temperature [\circC]'); ylabel('Nonlinear (rectifier) share [%]');
title('Peak hot spot vs ambient and harmonic share (Case 2 load), black = 110 \circC');

figure('Name', 'Equivalent ambient', 'Position', [760 80 600 420]);
plot(100*alpha_grid, dT_peak, '-', 'Color', cols(1,:), 'LineWidth', 1.8); hold on; grid on; box on;
plot(100*alpha_grid, dT_age,  '--', 'Color', cols(2,:), 'LineWidth', 1.5);
xlabel('Nonlinear (rectifier) share [%]'); ylabel('Equivalent ambient rise [K]');
legend({'same peak hot spot', 'same daily ageing'}, 'Location', 'northwest');
title('Harmonics expressed as extra ambient temperature');

figure('Name', 'Datasheet - max load', 'Position', [60 560 600 420]);
hold on; grid on; box on;
for q = 1:numel(alpha_ds)
    plot(Ta_grid, K_peak*smax(:,q), '-', 'Color', cols(q,:), 'LineWidth', 1.8);
end
yline(1.0, 'k:', 'Rated load', 'LabelHorizontalAlignment', 'left');
xlabel('Ambient temperature [\circC]'); ylabel('Max load in 12-18 h [pu]');
legend(arrayfun(@(a) sprintf('%.0f %% nonlinear', 100*a), alpha_ds, 'UniformOutput', false), ...
       'Location', 'northeast');
title('Loading guide: max peak load for HS \leq 110 \circC (Case 2 load shape)');

%% ======================== Local functions ===============================
function [t, TO, HS, TOe, He, k] = run_periodic(mdl, TO0, H0)
% Repeat the day until it ends where it starts (periodic steady state)
for k = 1:6
    assignin('base', 'Theta_TO_0', TO0);  assignin('base', 'Theta_H_0', H0);
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    [t, TO, HS] = get_TO_HS(out);
    d = max(abs([TO(end) - TO0, HS(end) - H0]));
    TO0 = TO(end);  H0 = HS(end);
    if d < 0.01, break; end
end
TOe = TO0;  He = H0;
end

function [t, TO, HS] = get_TO_HS(out)
[t, TO] = sig(out, 'Theta_TO_varying');
[tH, H] = sig(out, 'Theta_H_varying');
HS = interp1(tH, H, t);
end

function [t, v] = sig(out, name)
s = out.get(name);
if isa(s, 'timeseries'), t = s.Time(:); v = squeeze(s.Data);
else,                    t = s.time(:); v = squeeze(s.signals.values); end
v = v(:);
end

function A = ageing_h(t, HS)
A = trapz(t, exp(15000/383 - 15000./(HS + 273))) / 3600;
end

function [HLF, Irms_I1, F_HL, THD] = harmonic_factors(alpha, rho, hh, PEC_R)
% IEEE C57.110, rectifier harmonics add arithmetically (as run_SA2_Share.m)
I       = [1, alpha * rho(2:end)];
F_HL    = sum(I.^2 .* hh.^2) / sum(I.^2);
Irms_I1 = sqrt(sum(I.^2));
THD     = sqrt(sum(I(2:end).^2));
HLF     = (1 + F_HL*PEC_R) / (1 + PEC_R);
end
