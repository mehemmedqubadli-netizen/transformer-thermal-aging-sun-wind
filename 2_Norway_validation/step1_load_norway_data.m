%% STEP 1 - Load and inspect the measured data (Baerug 2025, 40 MVA ONAN, 2024, hourly)
% Put Barug2025_sensordata.csv in the same folder as this script, then run.
% Output: plots for a visual check + norway_data.mat (used in Step 2).
%
% NOTE: the current is measured on the 132 kV (HV) side, while the voltage
% column is from the LV side. So the load factor is K = I / I_rated(HV),
% not V*I.

clear; clc; close all;

%% 1. Read the file
file = 'Barug2025_sensordata.csv';
opts = detectImportOptions(file, 'VariableNamingRule', 'preserve');
T    = readtable(file, opts);

disp('Columns found in the file:');
disp(T.Properties.VariableNames');

%% 2. Pull out the signals (column names exactly as in the CSV)
t = T.Timestamp;
if ~isdatetime(t)
    t = datetime(t, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');  % adjust if the format differs
end

I    = T.("Current [A]");          % load current, HV side [A]
V    = T.("Voltage [kV]");         % voltage, LV side [kV] (not used for K)
Ta   = T.("Ambient [degC]");       % ambient temperature [degC]
TO   = T.("Top oil [degC]");       % measured top-oil temperature [degC]
HSHV = T.("Hot-spot HV [degC]");   % measured hot-spot, HV winding [degC]
HSLV = T.("Hot-spot LV [degC]");   % measured hot-spot, LV winding [degC]

I_rated = 40e6 / (sqrt(3) * 132e3);   % rated HV current = 175 A
K       = I / I_rated;                % load factor [pu]
rise    = TO - Ta;                    % top-oil rise over ambient [K]

%% 3. Data quality checks
fprintf('\nPeriod: %s  to  %s\n', string(t(1)), string(t(end)));
fprintf('Number of samples: %d\n', numel(t));

nanCount = sum(isnan([I V Ta TO HSHV HSLV]));
fprintf('Missing values (I, V, Ta, TO, HS_HV, HS_LV): %s\n', mat2str(nanCount));

dt     = diff(t);
gapIdx = find(dt > hours(1));
fprintf('Gaps longer than 1 h: %d\n', numel(gapIdx));
for k = 1:numel(gapIdx)
    fprintf('  gap from %s to %s  (%.1f days)\n', ...
        string(t(gapIdx(k))), string(t(gapIdx(k)+1)), days(dt(gapIdx(k))));
end

% Segment number: changes after every gap. Step 2 restarts the
% simulation at the start of each segment instead of bridging the gap.
seg = [1; 1 + cumsum(dt > hours(1))];

%% 4. Summary table
summary = table( ...
    [min(I); mean(I); max(I)], ...
    [min(K); mean(K); max(K)], ...
    [min(Ta); mean(Ta); max(Ta)], ...
    [min(TO); mean(TO); max(TO)], ...
    [min(HSHV); mean(HSHV,'omitnan'); max(HSHV)], ...
    [min(HSLV); mean(HSLV,'omitnan'); max(HSLV)], ...
    'VariableNames', {'I_A','K_pu','Ta_C','TO_C','HSHV_C','HSLV_C'}, ...
    'RowNames', {'min','mean','max'});
disp(summary);

fprintf('Rated HV current: %.0f A\n', I_rated);
fprintf('K_max = %.2f pu\n', max(K));

%% 5. Plots
figure('Name','Measured data - 40 MVA ONAN, 2024','Position',[100 100 1000 800]);

ax(1) = subplot(4,1,1);
plot(t, K); grid on;
ylabel('K [pu]'); title('Load factor');

ax(2) = subplot(4,1,2);
plot(t, Ta); grid on;
ylabel('\theta_A [°C]'); title('Ambient temperature');

ax(3) = subplot(4,1,3);
plot(t, TO, t, HSHV, t, HSLV); grid on;
ylabel('[°C]'); title('Measured temperatures');
legend('Top oil','Hot-spot HV','Hot-spot LV','Location','best');

ax(4) = subplot(4,1,4);
plot(t, rise); grid on;
ylabel('\Delta\theta_{TO} [K]'); title('Top-oil rise over ambient');

linkaxes(ax, 'x');   % zoom on one plot, all follow

% One-week zoom to see the daily cycle and the time lag of the oil
figure('Name','One week in summer');
wk = t >= datetime(2024,7,1) & t < datetime(2024,7,8);
yyaxis left;  plot(t(wk), K(wk)); ylabel('K [pu]');
yyaxis right; plot(t(wk), TO(wk), t(wk), Ta(wk), '--'); ylabel('[°C]');
legend('Load','Top oil','Ambient'); grid on;
title('Daily cycle: top oil lags behind the load');

%% 6. Save for Step 2
save('norway_data.mat', 't','I','V','K','I_rated','Ta','TO','HSHV','HSLV','seg');
fprintf('\nSaved norway_data.mat\n');
