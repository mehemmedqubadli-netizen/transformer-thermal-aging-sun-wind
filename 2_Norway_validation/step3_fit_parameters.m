%% STEP 3 - Fit dTheta_TO,R and tau_TO to the measured top oil
% Needs norway_data.mat from Step 1 (same folder). Base MATLAB only (fminsearch).
%
% Fixed:  R = 7.5 (published losses), n = 0.8 (IEEE C57.91, ONAN)
% Fitted: dTO_R (rated top-oil rise) and tau_h (top-oil time constant)
%
% Calibration = Jan-Jun 2024, validation = Jul-Dec 2024 (data the fit never saw).
% A full-year fit is also done, as the "best possible" reference.

clear; clc; close all;
load('norway_data.mat');   % t, K, Ta, TO, seg, ...

R = 7.5;  n = 0.8;
cal = t <  datetime(2024,7,1);   % calibration period
val = t >= datetime(2024,7,1);   % validation period

sim  = @(p) topoil_model(K, Ta, TO, seg, R, n, p(1), p(2));
rmse = @(e) sqrt(mean(e.^2));

%% 1. Standard parameters (Step 2), for reference
p_std  = [55 3];
e_std  = sim(p_std) - TO;

%% 2. Fit on Jan-Jun
% Parameters are fitted as log values so they stay positive.
opt   = optimset('Display','off','TolX',1e-6,'TolFun',1e-6);
q_cal = fminsearch(@(q) costfun(q, cal, K, Ta, TO, seg, R, n), log(p_std), opt);
p_cal = exp(q_cal);
e_cal = sim(p_cal) - TO;

%% 3. Fit on the full year
q_all = fminsearch(@(q) costfun(q, true(size(t)), K, Ta, TO, seg, R, n), log(p_std), opt);
p_all = exp(q_all);
e_all = sim(p_all) - TO;

%% 4. Results table
Case     = {'Standard (55 K, 3 h)'; 'Fitted on Jan-Jun'; 'Fitted on full year'};
dTO_R_K  = [p_std(1); p_cal(1); p_all(1)];
tau_h    = [p_std(2); p_cal(2); p_all(2)];
RMSE_cal = [rmse(e_std(cal)); rmse(e_cal(cal)); rmse(e_all(cal))];
RMSE_val = [rmse(e_std(val)); rmse(e_cal(val)); rmse(e_all(val))];
RMSE_yr  = [rmse(e_std);      rmse(e_cal);      rmse(e_all)];
bias_yr  = [mean(e_std);      mean(e_cal);      mean(e_all)];
res = table(dTO_R_K, tau_h, RMSE_cal, RMSE_val, RMSE_yr, bias_yr, 'RowNames', Case);
disp(res);

fprintf('Validation (Jul-Dec, not used for fitting): RMSE = %.2f K, MAE = %.2f K, max |err| = %.2f K\n', ...
        rmse(e_cal(val)), mean(abs(e_cal(val))), max(abs(e_cal(val))));

% Monthly bias after fitting: if a summer offset remains, the IEEE model
% misses something seasonal (most likely solar radiation on the tank).
mo = month(t);
fprintf('\nMonthly mean error, model fitted on Jan-Jun [K]:\n');
for m = 1:12
    fprintf('  %s: %+5.2f\n', datestr(datetime(2024,m,1),'mmm'), mean(e_cal(mo==m)));
end

%% 5. Plots
TO_cal = sim(p_cal);

figure('Name','Step 3 - Fitted model','Position',[100 100 1000 650]);
ax(1) = subplot(2,1,1);
plot(t, TO, t, TO_cal); grid on; hold on;
xline(datetime(2024,7,1), 'k--', 'calibration | validation');
ylabel('\theta_{TO} [°C]');
legend('Measured', sprintf('Fitted model (%.0f K, %.1f h)', p_cal(1), p_cal(2)), 'Location','best');
title(sprintf('Top oil 2024 - validation RMSE (Jul-Dec) = %.2f K', rmse(e_cal(val))));

ax(2) = subplot(2,1,2);
plot(t, e_std, t, e_cal); grid on; yline(0,'k');
xline(datetime(2024,7,1), 'k--');
ylabel('Error [K]'); legend('Standard parameters','Fitted on Jan-Jun','Location','best');
title('Simulated - measured');
linkaxes(ax,'x');

figure('Name','Step 3 - One week');
wk = t >= datetime(2024,7,1) & t < datetime(2024,7,8);
plot(t(wk), TO(wk), 'LineWidth', 1.5); hold on;
plot(t(wk), TO(wk) + e_std(wk), t(wk), TO_cal(wk), t(wk), Ta(wk), '--'); grid on;
ylabel('[°C]');
legend('Measured top oil','Standard (55 K, 3 h)','Fitted','Ambient','Location','best');
title('One week in July (validation period)');

%% 6. Save
save('step3_results.mat','p_std','p_cal','p_all','e_std','e_cal','e_all','res','R','n');
fprintf('\nSaved step3_results.mat\n');

%% ------------------------------------------------------------------------
function J = costfun(q, idx, K, Ta, TO, seg, R, n)
% RMSE on the selected samples, parameters given as log values.
    p   = exp(q);
    e   = topoil_model(K, Ta, TO, seg, R, n, p(1), p(2)) - TO;
    J   = sqrt(mean(e(idx).^2));
end

function TO_sim = topoil_model(K, Ta, TO, seg, R, n, dTO_R, tau_h)
% Exact discrete solution of the IEEE C57.91 top-oil equation, dt = 1 h.
% Restarts from the measured top-oil rise after each data gap.
    a  = exp(-1/tau_h);
    U  = dTO_R * ((K.^2*R + 1)/(R + 1)).^n;
    x  = zeros(size(K));
    for k = 1:numel(K)
        if k == 1 || seg(k) ~= seg(k-1)
            x(k) = TO(k) - Ta(k);
        else
            x(k) = U(k-1) + (x(k-1) - U(k-1)) * a;
        end
    end
    TO_sim = Ta + x;
end
