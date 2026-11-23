%% STEP 2 - Run the IEEE C57.91 top-oil model on the measured data and compare
% Needs norway_data.mat from Step 1 (same folder).
% Optional: Barug2025_calculated.csv (SINTEF's own model) for comparison.
%
% Model (IEEE C57.91, Clause 7):
%   dTheta_TO,U = dTheta_TO,R * ((K^2*R + 1)/(R + 1))^n     (ultimate rise)
%   tau_TO * d(dTheta_TO)/dt = dTheta_TO,U - dTheta_TO       (first-order lag)
%   Theta_TO = Theta_A + dTheta_TO
% Solved exactly for each 1 h step (K and Theta_A held constant over the hour).

clear; clc; close all;
load('norway_data.mat');   % t, K, Ta, TO, seg, ...

%% 1. Parameters of the 40 MVA transformer
R      = 120/16;   % load loss / no-load loss = 7.5  (Madshaven et al. 2024)
n      = 0.8;      % oil exponent, IEEE C57.91 for ONAN
dTO_R  = 55;       % rated top-oil rise [K]   -> ASSUMED, fitted in Step 3
tau_h  = 3;        % top-oil time constant [h] -> ASSUMED, fitted in Step 3

%% 2. Simulate
TO_sim = topoil_model(K, Ta, TO, seg, R, n, dTO_R, tau_h);

%% 3. Error statistics
err  = TO_sim - TO;
RMSE = sqrt(mean(err.^2));
MAE  = mean(abs(err));
bias = mean(err);
emax = max(abs(err));

fprintf('IEEE top-oil model, standard parameters (dTO_R = %g K, tau = %g h, n = %g, R = %.1f)\n', ...
        dTO_R, tau_h, n, R);
fprintf('  RMSE = %.2f K | MAE = %.2f K | bias = %+.2f K | max |err| = %.2f K\n', ...
        RMSE, MAE, bias, emax);

% Monthly bias: shows whether the error depends on the season
mo = month(t);
fprintf('\nMonthly mean error (simulated - measured) [K]:\n');
for m = 1:12
    fprintf('  %s: %+5.2f\n', datestr(datetime(2024,m,1),'mmm'), mean(err(mo==m)));
end

%% 4. Optional: SINTEF's own calculated top oil, for comparison
if isfile('Barug2025_calculated.csv')
    C  = readtable('Barug2025_calculated.csv', 'VariableNamingRule','preserve');
    tc = C.Timestamp; if ~isdatetime(tc), tc = datetime(tc); end
    [~, ia, ib] = intersect(t, tc);
    eS = C.("Top oil (calculated) [degC]")(ib) - TO(ia);
    fprintf('\nSINTEF calculated top oil: RMSE = %.2f K | MAE = %.2f K\n', ...
            sqrt(mean(eS.^2,'omitnan')), mean(abs(eS),'omitnan'));
end

%% 5. Plots
figure('Name','Step 2 - Model vs measurement','Position',[100 100 1000 650]);
ax(1) = subplot(2,1,1);
plot(t, TO, t, TO_sim); grid on;
ylabel('\theta_{TO} [°C]');
legend('Measured','IEEE model (standard parameters)','Location','best');
title(sprintf('Top-oil temperature, 2024  (RMSE = %.2f K)', RMSE));

ax(2) = subplot(2,1,2);
plot(t, err); grid on; yline(0,'k');
ylabel('Error [K]'); title('Simulated - measured');
linkaxes(ax,'x');

figure('Name','Step 2 - One week');
wk = t >= datetime(2024,7,1) & t < datetime(2024,7,8);
plot(t(wk), TO(wk), t(wk), TO_sim(wk), t(wk), Ta(wk), '--'); grid on;
ylabel('[°C]'); legend('Measured top oil','Model','Ambient','Location','best');
title('One week in July');

%% 6. Save
save('step2_results.mat','TO_sim','err','RMSE','MAE','bias','R','n','dTO_R','tau_h');
fprintf('\nSaved step2_results.mat\n');

%% ------------------------------------------------------------------------
function TO_sim = topoil_model(K, Ta, TO, seg, R, n, dTO_R, tau_h)
% Exact discrete solution of the IEEE C57.91 top-oil equation, dt = 1 h.
% At the start of each data segment (after a gap) the model starts from
% the measured top-oil rise, so the gaps don't affect the result.
    dt = 1;                                   % [h]
    a  = exp(-dt/tau_h);
    U  = dTO_R * ((K.^2*R + 1)/(R + 1)).^n;   % ultimate rise [K]
    x  = zeros(size(K));                      % top-oil rise [K]
    for k = 1:numel(K)
        if k == 1 || seg(k) ~= seg(k-1)
            x(k) = TO(k) - Ta(k);             % start from measurement
        else
            x(k) = U(k-1) + (x(k-1) - U(k-1)) * a;
        end
    end
    TO_sim = Ta + x;
end
