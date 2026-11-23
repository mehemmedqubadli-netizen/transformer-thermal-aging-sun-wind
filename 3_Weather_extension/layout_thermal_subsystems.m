%% layout_thermal_subsystems.m
% Hand-made, clean layout of the thermal subsystems (layout only, the
% equations are not changed):
%   Top_Oil_Thermal_Model  and  Hot_Spot_Thermal_Model
% Works for the Case models (Case2_fixed, Case2_sunwind, Case1/Case3 fixed)
% and the constant-share SA2 models (extra HLF gain after u^2).
%
% Layout (left -> right):
%   row 1  cooling:  ambient / top oil -> (theta - ref) -> ^(1/n) [-> x (1+kw*W)]
%   row 2  1/n (or 1/m) from the two constants
%   row 3  wind (only in the weather model)
%   row 4  THETA_R^(1/n)
%   row 5  load:     K -> u^2 [-> HLF] -> loss terms -> U [+ sun]
%   right: heating - cooling -> gain -> x 1/tau -> integrator -> outputs
%
% - all lines are removed and drawn again (orthogonal routing)
% - Sum blocks are drawn rectangular so their inputs sit on the left side
% - the unused inport "In3" of the hot-spot subsystem is removed (not connected)
% - the model is simulated before and after: the result must be identical
% - each subsystem is exported twice (print and saveas) - use whichever
%   shows the block texts (constants, gains, 1/s) correctly
%
% Run in the folder with the models. A backup is made first.

clear; clc; close all;
run('Case2_inputs.m');                       % has its own "clear" -> must run first
models = {'Integrated_Transformer_Case2_sunwind', 'Integrated_Transformer_Case2_fixed'};

Ta_ws = [0 24; 86400 24];  G_ws = [0 0; 86400 0];  W_ws = [0 0; 86400 0];
cA_sun = 0;  kw_wind = 0;  P_R_total = 26.92e3 + 135.9e3;
HLF = 1;  Irms_I1 = 1;  Ta_const = 24;  K_scale = 1;

for m = 1:numel(models)
    mdl = models{m};
    if ~isfile([mdl '.slx']), fprintf('%s.slx not here - skipped\n', mdl); continue; end
    fprintf('=== %s ===\n', mdl);
    bak = [mdl '_backup_before_layout.slx'];
    if ~isfile(bak), copyfile([mdl '.slx'], bak); fprintf('Backup: %s\n', bak); end
    load_system(mdl);
    HS0 = run_day(mdl);

    lay_top_oil([mdl '/Top_Oil_Thermal_Model']);
    lay_hot_spot([mdl '/Hot_Spot_Thermal_Model']);
    save_system(mdl);

    HS1 = run_day(mdl);
    if ~isempty(HS0) && ~isempty(HS1) && numel(HS0) == numel(HS1)
        fprintf('Check: max |hot spot after - before| = %.6f K  (must be 0)\n', max(abs(HS1 - HS0)));
    end
    short = strrep(mdl, 'Integrated_Transformer_', '');
    for s = {'Top_Oil_Thermal_Model', 'Hot_Spot_Thermal_Model', 'Aging_Loss_of_Life_Model'}
        export_diagram([mdl '/' s{1}], sprintf('Diagram_%s_%s', short, s{1}));
    end
    export_diagram(mdl, sprintf('Diagram_%s_top_level', short));
    fprintf('\n');
end
fprintf('Done. Open the subsystems to look, and send the Diagram_* files.\n');

%% ======================== Local functions ===============================
function lay_top_oil(sys)
P = common_positions();
P.THETA_O_R = [130 390 210 420];
P.Theta_minus_ambient = [220 70 250 150];
P.One_for_n = [130 192 160 212];  P.n = [130 228 160 248];  P.One_over_n = [210 185 240 255];
P.B = [130 585 170 615];  P.One_for_loss_ratio = [130 685 170 715];
P.K2_times_B = [210 540 240 600];  P.Numerator = [280 545 310 625];  P.Denominator = [280 640 310 720];
P.Tt_O = [640 640 700 660];  P.One_over_Tt_O = [740 595 770 665];
P.dTheta_TO_dt = [800 320 830 400];
P.Theta_TO = [1020 353 1050 367];  P.outTheta_TO_varying = [990 400 1090 425];  P.Scope = [1000 280 1030 310];
% ambient source: From Workspace (weather model) or Constant
P.Ambient_Ta = [40 115 140 145];  P.Constant1 = [90 115 120 145];
% weather blocks (only present in the sun + wind model)
P.Wind_W = [130 290 230 320];  P.Wind_kw = [290 290 340 320];  P.One_plus = [380 290 420 320];
P.Cooling_times_wind = [460 115 490 175];
P.Solar_G = [130 770 230 800];  P.Sun_cA_over_PR = [290 770 350 800];  P.U_plus_sun = [430 580 460 660];
apply_layout(sys, P, 'THETA_O_R');
end

function lay_hot_spot(sys)
% remove the unused third inport if it is not connected
b = [sys '/In3'];
if getSimulinkBlockHandle(b) > 0
    ph = get_param(b, 'PortHandles');
    if get_param(ph.Outport(1), 'Line') == -1, delete_block(b); fprintf('Removed unused In3\n'); end
end
P = common_positions();
P.THETA_H_R = [130 390 210 420];
P.Theta_TO = [40 123 70 137];
P.Theta_H_minus_Theta_TO = [220 70 250 150];
P.One_for_m = [130 192 160 212];  P.m = [130 228 160 248];  P.One_over_m = [210 185 240 255];
P.PEC_R = [130 645 195 675];  P.One_for_PEC = [130 685 170 715];
P.Load2_times_loss_factor = [210 540 240 600];  P.One_plus_PEC_R = [280 640 310 720];
P.Tw_H = [640 640 700 660];  P.One_over_Tw_H = [740 595 770 665];
P.dTheta_H_dt = [800 320 830 400];
P.Theta_H = [1020 353 1050 367];  P.outTheta_H_varying = [990 400 1090 425];  P.Hot_Spot_Scope = [1000 280 1030 310];
apply_layout(sys, P, 'THETA_H_R');
end

function P = common_positions()
P.K_electrical = [20 548 50 562];
P.Load_squared = [80 537 120 573];
P.Load_loss_ratio = [360 600 390 660];
P.Rated_rise_power = [330 385 380 465];
P.Cooling_power = [330 90 380 170];
P.Heating_term = [530 420 560 480];
P.Heating_minus_cooling = [620 300 650 380];
P.One_for_time_constant = [640 600 690 620];
P.Integrator = [880 345 910 375];
end

function apply_layout(sys, P, ratedName)
blocks = find_system(sys, 'SearchDepth', 1, 'Type', 'Block');
blocks = blocks(~strcmp(blocks, sys));
% 1. remember every connection (source port -> destination port)
pairs = zeros(0, 2);
for k = 1:numel(blocks)
    ph = get_param(blocks{k}, 'PortHandles');
    for ip = ph.Inport
        L = get_param(ip, 'Line');
        if L ~= -1, pairs(end+1, :) = [get_param(L, 'SrcPortHandle') ip]; end %#ok<AGROW>
    end
end
% 2. remove all lines
Ls = find_system(sys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(Ls)
    if ishandle(Ls(k)), delete_line(Ls(k)); end
end
% 3. gains: correction gain THETA_R^(1-1/n) on the right, HLF gain after u^2 (SA2 models)
for k = 1:numel(blocks)
    if ~strcmp(get_param(blocks{k}, 'BlockType'), 'Gain'), continue; end
    g = get_param(blocks{k}, 'Gain');  nm = get_param(blocks{k}, 'Name');
    if contains(g, ratedName)
        P.(matlab.lang.makeValidName(nm)) = [700 320 750 360];
    elseif contains(g, 'HLF')
        P.(matlab.lang.makeValidName(nm)) = [145 540 180 570];
    end
end
% 4. move blocks; Sum blocks rectangular (inputs on the left)
for k = 1:numel(blocks)
    nm = matlab.lang.makeValidName(get_param(blocks{k}, 'Name'));
    if strcmp(get_param(blocks{k}, 'BlockType'), 'Sum'), set_param(blocks{k}, 'IconShape', 'rectangular'); end
    if isfield(P, nm)
        set_param(blocks{k}, 'Position', P.(nm));
    else
        fprintf('  (no position defined for %s - left where it is)\n', get_param(blocks{k}, 'Name'));
    end
end
% 5. draw the lines again
for k = 1:size(pairs, 1)
    try
        add_line(sys, pairs(k,1), pairs(k,2), 'autorouting', 'smart');
    catch
        add_line(sys, pairs(k,1), pairs(k,2), 'autorouting', 'on');
    end
end
% 6. note (weather model) at the bottom
a = find_system(sys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'annotation');
for k = 1:numel(a)
    try, set_param(a(k), 'Position', [40 840 700 860]); catch, end
end
fprintf('Laid out %s (%d blocks, %d connections)\n', sys, numel(blocks), size(pairs, 1));
end

function export_diagram(sys, base)
try, print(['-s' sys], '-dpng', '-r300', [base '_print.png']); catch e, fprintf('print failed: %s\n', e.message); end
try, saveas(get_param(sys, 'Handle'), [base '_saveas.png']); catch e, fprintf('saveas failed: %s\n', e.message); end
try, print(['-s' sys], '-dsvg', [base '.svg']); catch, end
end

function HS = run_day(mdl)
HS = [];
try
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    s = out.get('Theta_H_varying');
    if isa(s, 'timeseries'), HS = squeeze(s.Data); else, HS = s.signals.values(:); end
catch e
    fprintf('(simulation check skipped: %s)\n', e.message);
end
end
