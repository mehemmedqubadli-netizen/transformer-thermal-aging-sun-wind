%% SA2_1_rectifier_spectrum.m - harmonic spectrum of a six-pulse diode rectifier
% Runs SA2_Rectifier_Spectrum.slx (same folder), takes the FFT of the phase-a
% current over the last 5 cycles and gives each harmonic relative to the
% fundamental (rho). These values are used by run_SA2_TimeVarying.m and
% run_SA2_Share.m (built 2 Nov 2026).
%
% Expected: h5 19.5 %, h7 13.3 %, h11 7.8 %, h13 6.2 %  ->  THD 26.3 %, F_HL 5.12
% (ideal six-pulse: 1/h = 20 / 14.3 / 9.1 / 7.7 %)
% The model must log the transformer current with a To Workspace block
% named I_tr (Timeseries).

clear; clc;
out = sim('SA2_Rectifier_Spectrum');

I  = out.I_tr;                                 % three-phase current
t  = I.Time;
d  = squeeze(I.Data);
if size(d,1) == 3 && size(d,2) ~= 3, d = d.'; end
ia = d(:,1);                                   % phase a

f0 = 50;  Ncyc = 5;  Nfft = 20000;             % last 5 cycles, evenly resampled
tu = linspace(t(end) - Ncyc/f0, t(end), Nfft + 1);  tu(end) = [];
x  = interp1(t, ia, tu);
X  = abs(fft(x)) / Nfft * 2;                   % amplitude spectrum

hh  = 1:25;
IhA = X(Ncyc*hh + 1);                          % amplitude of harmonic h [A peak]
rho = IhA / IhA(1);                            % relative to fundamental
THD_rect  = sqrt(sum(rho(2:end).^2));
F_HL_rect = sum(rho.^2 .* hh.^2) / sum(rho.^2);

fprintf('Rectifier THD = %.1f %%,  F_HL = %.2f\n', 100*THD_rect, F_HL_rect);
hk = [5 7 11 13 17 19 23 25];
disp(table(hk', 100*rho(hk)', 100./hk', ...
     'VariableNames', {'Harmonic', 'Simulated_pct', 'Ideal_1_over_h_pct'}));

save('rect_spectrum.mat', 'rho', 'hh', 'IhA', 'THD_rect', 'F_HL_rect');
disp('Saved rect_spectrum.mat');
