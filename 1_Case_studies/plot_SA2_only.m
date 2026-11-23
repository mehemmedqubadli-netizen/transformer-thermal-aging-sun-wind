%% plot_SA2_only.m - plots only the SA2 (harmonics) results
% Put this file in the same folder as SA2_share_results.mat and
% SA2_TV_results.mat, then type:  plot_SA2_only
% It does NOT run Simulink; it only reads the saved results.

clear; close all; clc;

%% 1. Constant nonlinear share (0 / 15 / 30 / 50 %)
S = load('SA2_share_results.mat');      % SA2s, outs, alpha_list, ...
if isfield(S, 'SA2s'), disp(S.SA2s); end

nRun = numel(S.alpha_list);
leg  = compose('%d %% nonlinear', round(100*S.alpha_list));
col  = lines(nRun);

figure('Name', 'SA2 - hot spot');      hold on; grid on
for i = 1:nRun
    [t, y] = getsig(pick(S.outs, i), 'Theta_H_varying');
    plot(t, y, 'LineWidth', 1.4, 'Color', col(i,:));
end
yline(110, '--k', '110 °C');
xlabel('Time of day (h)'); ylabel('Hot-spot temperature (°C)');
legend([leg, {'110 °C'}], 'Location', 'northwest'); xlim([0 24]); xticks(0:3:24);
title('SA2: hot-spot temperature for different nonlinear shares');

figure('Name', 'SA2 - top oil');       hold on; grid on
for i = 1:nRun
    [t, y] = getsig(pick(S.outs, i), 'Theta_TO_varying');
    plot(t, y, 'LineWidth', 1.4, 'Color', col(i,:));
end
xlabel('Time of day (h)'); ylabel('Top-oil temperature (°C)');
legend(leg, 'Location', 'northwest'); xlim([0 24]); xticks(0:3:24);
title('SA2: top-oil temperature for different nonlinear shares');

ageing = zeros(1, nRun);
for i = 1:nRun
    [~, a] = getsig(pick(S.outs, i), 'Aging_hours_varying');
    ageing(i) = a(end);
end
figure('Name', 'SA2 - daily ageing');
bar(100*S.alpha_list, ageing); grid on
text(100*S.alpha_list, ageing, compose('%.2f h', ageing), ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
xlabel('Nonlinear load share (%)'); ylabel('Daily ageing (h)');
title('SA2: daily ageing against nonlinear share');

%% 2. Time-varying case (Load D = rectifier, 12:00-18:00)
T  = load('SA2_TV_results.mat');
fn = fieldnames(T);
fprintf('\nVariables in SA2_TV_results.mat: %s\n', strjoin(fn, ', '));
runs = {};                               % collect every saved simulation output
for k = 1:numel(fn)
    v = T.(fn{k});
    if isa(v, 'Simulink.SimulationOutput')
        runs{end+1} = v;  %#ok<AGROW>
    elseif iscell(v)
        for j = 1:numel(v)
            if isa(v{j}, 'Simulink.SimulationOutput'), runs{end+1} = v{j}; end %#ok<AGROW>
        end
    end
end
if isempty(runs)
    disp('No simulation output found in SA2_TV_results.mat - send me the variable list above.');
else
    figure('Name', 'SA2 - time-varying'); hold on; grid on
    [t, y] = getsig(pick(S.outs, 1), 'Theta_H_varying');      % 0 % = Case 2
    plot(t, y, 'k', 'LineWidth', 1.4);
    [t, y] = getsig(runs{end}, 'Theta_H_varying');            % rectifier run
    plot(t, y, 'r', 'LineWidth', 1.4);
    xline([12 18], ':', {'Load D on', 'Load D off'});
    xlabel('Time of day (h)'); ylabel('Hot-spot temperature (°C)');
    legend('No harmonics (Case 2)', 'Load D as rectifier', 'Location', 'northwest');
    xlim([0 24]); xticks(0:3:24);
    title('SA2: time-varying harmonics (Load D rectifier, 12:00-18:00)');
end

%% ---------------- helper functions ----------------
function o = pick(outs, i)
% one run from a cell array or a struct array
    if iscell(outs), o = outs{i}; else, o = outs(i); end
end

function [t, y] = getsig(o, name)
% time (h) and values of a logged signal, whatever the save format
    s = o.(name);
    if isa(s, 'timeseries')
        t = s.Time;  y = squeeze(s.Data);
    elseif isstruct(s) && isfield(s, 'signals')
        t = s.time;  y = squeeze(s.signals.values);
    else
        t = s(:,1);  y = s(:,2);
    end
    if max(t) > 100, t = t / 3600; end   % seconds -> hours
end
