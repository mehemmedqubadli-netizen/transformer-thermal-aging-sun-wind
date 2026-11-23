%% Case2_inputs.m - 50 MVA ONAN case-study transformer, Case 2 parameters
% Run this BEFORE Integrated_Transformer_Case2_fixed.slx
% (same values as SA2_inputs.m; HLF = 1 means no harmonics = Case 2)

clear; clc;   % removes the Norway validation values from the workspace

S_rated = 50e6;                          % VA
V_rated = 10.5e3;                        % Secondary voltage [V]
I_rated = S_rated/(sqrt(3)*V_rated);     % A
B       = 135.9/26.92;                   % Load/no-load loss ratio

T_amb      = 24;                         % Ambient [deg C]
Theta_TO_0 = 24;
Theta_H_0  = 24;

THETA_O_R = 49;                          % Top-oil rise above ambient [K]
THETA_H_R = 18;                          % Hot-spot gradient above top oil [K]

Tt_O = 180;                              % Time constants [min]
Tw_H = 6;

m     = 0.8;
n     = 0.8;
PEC_R = 0.42;                            % Rated eddy-current loss (pu of I^2R)

LIFE = 180000;                           % Normal insulation life [h]

% No harmonics (Case 2)
HLF     = 1;
Irms_I1 = 1;

disp('Case 2 inputs loaded (50 MVA).');
