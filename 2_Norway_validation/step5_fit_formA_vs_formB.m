%% STEP 5 - Refit the top-oil model: old form (A) vs corrected form (B)
% Needs norway_data.mat from Step 1 (same folder). Base MATLAB only.
%
% Both forms have the ambient INSIDE the differential equation (like Simulink):
%   (A) Swift/Aslam:   dTO/dt = 1/tau * [ dTO_R^(1/n)*U - (TO-TA)^(1/n) ]
%   (B) IEEE Annex G:  dTO/dt = dTO_R/tau * [ U - ((TO-TA)/dTO_R)^(1/n) ]
%   with U = (K^2*B + 1)/(B + 1)
% Same steady state, different speed. Each form gets its own fitted dTO_R and tau.
%
% Calibration = Jan-Jun, validation = Jul-Dec. Restart from measurement after gaps.
% Runtime: a few minutes (each cost evaluation simulates the whole year).

clear; clc; close all;
load('norway_data.mat');   % t, K, Ta, TO, seg

B = 7.5;  n = 0.8;
U = (K.^2*B + 1)/(B + 1);
cal = t <  datetime(2024,7,1);
val = t >= datetime(2024,7,1);
rmse = @(e) sqrt(mean(e.^2,'omitnan'));
spow = @(x) sign(x).*abs(x).^(1/n);

% Right-hand sides, p = [dTO_R [K], tau [h]], time in hours
fA = @(x,u,ta,p) (p(1)^(1/n)*u - spow(x-ta)) / p(2);
fB = @(x,u,ta,p) p(1)*(u - spow((x-ta)/p(1))) / p(2);

opt = optimset('Display','iter','TolX',1e-4,'TolFun',1e-4,'MaxFunEvals',300);

%% 1. Fit both forms on Jan-Jun
fprintf('--- Fitting form A on Jan-Jun ---\n');
qA = fminsearch(@(q) cost(q, fA, cal, U, Ta, TO, seg), log([64.4 24.1]), opt);
pA = exp(qA);
fprintf('--- Fitting form B on Jan-Jun ---\n');
qB = fminsearch(@(q) cost(q, fB, cal, U, Ta, TO, seg), log([64.4 10]), opt);
pB = exp(qB);

eA = run_model(fA, pA, U, Ta, TO, seg) - TO;
eB = run_model(fB, pB, U, Ta, TO, seg) - TO;

%% 2. Results table
Form     = {'A (Swift/Aslam, old)'; 'B (IEEE Annex G, fixed)'};
dTO_R_K  = [pA(1); pB(1)];
tau_h    = [pA(2); pB(2)];
RMSE_cal = [rmse(eA(cal)); rmse(eB(cal))];
RMSE_val = [rmse(eA(val)); rmse(eB(val))];
RMSE_yr  = [rmse(eA);      rmse(eB)];
bias_yr  = [mean(eA,'omitnan'); mean(eB,'omitnan')];
res = table(dTO_R_K, tau_h, RMSE_cal, RMSE_val, RMSE_yr, bias_yr, 'RowNames', Form);
fprintf('\n'); disp(res);

% Effective (real-world) time constant of form A at the mean rise
dTh = mean(TO - Ta, 'omitnan');
fprintf('Mean top-oil rise in the data: %.1f K\n', dTh);
fprintf('Form A tau = %.1f h behaves like tau_eff = %.1f h\n', pA(2), n*dTh^(1-1/n)*pA(2));
fprintf('Form B tau = %.1f h behaves like tau_eff = %.1f h\n', pB(2), n*(dTh/pB(1))^(1-1/n)*pB(2));

%% 3. Same 342-day stretch as Step 4 (to compare with the 1.72 K from Simulink)
segs = unique(seg);  lens = arrayfun(@(s) sum(seg==s), segs);
[~,i] = max(lens);   L = (seg == segs(i));
fprintf('\nLongest stretch (%s to %s):\n', string(t(find(L,1))), string(t(find(L,1,'last'))));
fprintf('  Form A: RMSE = %.2f K, bias = %+.2f K\n', rmse(eA(L)), mean(eA(L),'omitnan'));
fprintf('  Form B: RMSE = %.2f K, bias = %+.2f K\n', rmse(eB(L)), mean(eB(L),'omitnan'));

%% 4. Monthly bias
mo = month(t);
fprintf('\nMonthly mean error [K]     A       B\n');
for m = 1:12
    fprintf('  %s              %+5.2f   %+5.2f\n', datestr(datetime(2024,m,1),'mmm'), ...
        mean(eA(mo==m),'omitnan'), mean(eB(mo==m),'omitnan'));
end

%% 5. Plots
figure('Name','Step 5 - Form A vs Form B','Position',[100 100 1000 650]);
ax(1) = subplot(2,1,1);
plot(t, TO, t, TO+eA, t, TO+eB); grid on;
xline(datetime(2024,7,1),'k--','calibration | validation');
ylabel('\theta_{TO} [°C]'); legend('Measured','Form A','Form B','Location','best');
title(sprintf('Validation RMSE (Jul-Dec): A = %.2f K, B = %.2f K', RMSE_val(1), RMSE_val(2)));
ax(2) = subplot(2,1,2);
plot(t, eA, t, eB); grid on; yline(0,'k');
ylabel('Error [K]'); legend('Form A','Form B','Location','best');
linkaxes(ax,'x');

figure('Name','Step 5 - One week in July');
wk = t >= datetime(2024,7,1) & t < datetime(2024,7,8);
plot(t(wk), TO(wk), 'LineWidth',1.5); hold on;
plot(t(wk), TO(wk)+eA(wk), t(wk), TO(wk)+eB(wk), t(wk), Ta(wk), '--'); grid on;
ylabel('[°C]'); legend('Measured','Form A','Form B','Ambient','Location','best');

save('step5_results.mat','pA','pB','eA','eB','res','B','n');
fprintf('\nSaved step5_results.mat\n');

%% ------------------------------------------------------------------------
function J = cost(q, f, idx, U, Ta, TO, seg)
    e = run_model(f, exp(q), U, Ta, TO, seg) - TO;
    J = sqrt(mean(e(idx).^2,'omitnan'));
end

function TOs = run_model(f, p, U, Ta, TO, seg)
% RK4, 5-min substeps, inputs held over each hour (like Simulink with
% interpolation off). Restarts from the measured top oil after each gap.
    h = 1/12;  ns = 12;
    TOs = zeros(size(U));
    for k = 1:numel(U)
        if k == 1 || seg(k) ~= seg(k-1)
            x = TO(k);
            if isnan(x), x = Ta(k) + 15; end
        else
            u = U(k-1); ta = Ta(k-1);
            for s = 1:ns
                k1 = f(x,          u, ta, p);
                k2 = f(x + h/2*k1, u, ta, p);
                k3 = f(x + h/2*k2, u, ta, p);
                k4 = f(x + h*k3,   u, ta, p);
                x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
            end
        end
        TOs(k) = x;
    end
end
