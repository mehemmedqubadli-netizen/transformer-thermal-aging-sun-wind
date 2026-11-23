%% STEP 4c - Which equation does the Simulink model contain? (exact verification)
% Run AFTER the Simulink model and step4_compare, in the same MATLAB session.
%
% Reading of Top_Oil_Thermal_Model from the block diagram:
%   dTO/dt = 1/tau * [ dTO_R^(1/n) * (K^2*B+1)/(B+1) - (TO - TA)^(1/n) ]      (A)
% IEEE C57.91 Annex G form has an extra factor dTO_R^(1-1/n):
%   dTO/dt = dTO_R/tau * [ (K^2*B+1)/(B+1) - ((TO - TA)/dTO_R)^(1/n) ]          (B)
% Both have the same steady state; they differ only in how fast they react.
% The one that matches Simulink to ~0 K is the one inside the model.

load('step4_inputs.mat', 'tv','tsec','Kv','Tav','TOv','B','n','THETA_O_R','Tt_O');

if exist('out', 'var') && isa(out, 'Simulink.SimulationOutput')
    ts = out.TO_simulink;
else
    ts = TO_simulink;
end
TO_sl = interp1(ts.Time, squeeze(ts.Data), tsec, 'linear');

tau = Tt_O * 60;                                   % [s], as in the model (Tt_O*60)
U   = (Kv.^2 * B + 1) / (B + 1);                   % loss ratio, held over each hour
spow = @(x) sign(x) .* abs(x).^(1/n);              % same as the +-|u|^y block

fA = @(TOx, Uk, Tak) (THETA_O_R^(1/n) * Uk - spow(TOx - Tak)) / tau;
fB = @(TOx, Uk, Tak) THETA_O_R * (Uk - spow((TOx - Tak) / THETA_O_R)) / tau;

TO_A = rk4_run(fA, U, Tav, TOv(1));
TO_B = rk4_run(fB, U, Tav, TOv(1));

dA = TO_A - TO_sl;   dB = TO_B - TO_sl;
fprintf('Form (A) without factor vs Simulink: max |diff| = %.3f K, RMSE = %.3f K\n', max(abs(dA)), sqrt(mean(dA.^2,'omitnan')));
fprintf('Form (B) with factor    vs Simulink: max |diff| = %.3f K, RMSE = %.3f K\n', max(abs(dB)), sqrt(mean(dB.^2,'omitnan')));

eA = TO_A - TOv;   eB = TO_B - TOv;
fprintf('\nVs measurement:  (A) RMSE = %.2f K  |  (B) RMSE = %.2f K\n', sqrt(mean(eA.^2)), sqrt(mean(eB.^2)));

% Effective time constant at a typical rise (local slope of the equation)
dTh = mean(TOv - Tav);
fprintf('\nAt the mean rise here (%.1f K):\n', dTh);
fprintf('  (A) behaves like tau_eff = %.1f h   (B) behaves like tau_eff = %.1f h\n', ...
        n * dTh^(1 - 1/n) * Tt_O/60, n * (dTh/THETA_O_R)^(1 - 1/n) * Tt_O/60);

%% ------------------------------------------------------------------------
function TO = rk4_run(f, U, Ta, TO0)
% RK4 with 5-min substeps; inputs held constant over each hour (like Simulink).
    h  = 300;  ns = 3600 / h;
    TO = zeros(size(U));  TO(1) = TO0;  x = TO0;
    for k = 1:numel(U) - 1
        for s = 1:ns
            k1 = f(x,          U(k), Ta(k));
            k2 = f(x + h/2*k1, U(k), Ta(k));
            k3 = f(x + h/2*k2, U(k), Ta(k));
            k4 = f(x + h*k3,   U(k), Ta(k));
            x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
        end
        TO(k+1) = x;
    end
end
