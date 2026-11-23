%% half_year_bias.m - RMSE and mean bias per half-year (Table 4.4)
% Put this file in the Norway validation folder (next to norway_data.mat
% and step5_results.mat), then type:  half_year_bias
% Uses the fitted Form B parameters (pB) - no Simulink needed.

clear; clc;
load('norway_data.mat');               % t, K, Ta, TO, seg
load('step5_results.mat', 'pB');       % pB = [dTO_R (K)  tau (h)]

B = 7.5;  n = 0.8;
dR = pB(1);  tau = pB(2);              % 64.77 K, 8.01 h
fprintf('Parameters: dTO_R = %.2f K, tau = %.2f h\n\n', dR, tau);

% Form B (IEEE) top-oil equation, RK4 with 5-min substeps, inputs held per hour,
% restart from the measurement after each data gap (same as step 5)
U    = (K.^2 * B + 1) / (B + 1);
spow = @(x) sign(x) .* abs(x).^(1/n);
f    = @(x, u, ta) dR / tau * (u - spow((x - ta) / dR));     % degC per hour
h    = 5/60;  ns = 12;

TOm = nan(size(TO));
for k = 1:numel(TO)
    if k == 1 || seg(k) ~= seg(k-1)
        TOm(k) = TO(k);                % start of a segment = measurement
    else
        x = TOm(k-1);  u = U(k-1);  ta = Ta(k-1);
        for s = 1:ns
            k1 = f(x, u, ta);            k2 = f(x + h/2*k1, u, ta);
            k3 = f(x + h/2*k2, u, ta);   k4 = f(x + h*k3,   u, ta);
            x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
        end
        TOm(k) = x;
    end
end

e     = TOm - TO;                       % model - measurement
first = [true; seg(2:end) ~= seg(1:end-1)];
ok    = ~first & ~isnan(e);             % skip restart points (error = 0 there)
mo    = month(t);

P = {'January-June (calibration)', ok & mo <= 6;
     'July-December (validation)', ok & mo >= 7;
     'Whole year',                 ok};
fprintf('%-30s %10s %14s\n', 'Period', 'RMSE (K)', 'Mean bias (K)');
for i = 1:size(P,1)
    ei = e(P{i,2});
    fprintf('%-30s %10.2f %+14.2f\n', P{i,1}, sqrt(mean(ei.^2)), mean(ei));
end
fprintf('\nCheck: RMSE should be about 1.81 / 1.55 / 1.68 K, whole-year bias about -0.40 K.\n');
