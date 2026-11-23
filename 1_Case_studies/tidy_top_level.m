%% tidy_top_level.m
% Tidies the TOP LEVEL of the thesis models (Figure 3.3 and Figure A.1):
% power path on one line (source -> transformer -> measurement -> loads),
% signal path above it from left to right (current -> K -> top oil ->
% hot spot -> aging -> displays). Only block positions and line routes
% change; the equations and parameters are untouched.
%
% HOW TO USE
%   1. Put this file in the folder with the models (e.g. 1_Case_studies).
%   2. Run it. It makes a backup of every model before changing it.
%   3. Open the model, run its input script (e.g. Case3_inputs) and press Run,
%      so the Display blocks show values.
%   4. Press the space bar (fit to view), then take a screenshot with
%      Win+Shift+S and paste it into Word as Figure 3.3.

models = [dir('Integrated_Transformer_Case*_fixed.slx'); dir('Integrated_Transformer_Case2_sunwind.slx')];
if isempty(models), error('No Integrated_Transformer_Case*_fixed.slx in this folder.'); end

for k = 1:numel(models)
    mdl = erase(models(k).name, '.slx');
    bak = [mdl '_backup_before_toplevel.slx'];
    if ~isfile(bak), copyfile(models(k).name, bak); end
    load_system(mdl);
    try, hilite_system(find_system(mdl, 'SearchDepth', 1, 'Type', 'Block'), 'none'); catch, end
    lay(mdl);
    save_system(mdl);
    fprintf('Tidied %s (backup: %s)\n', mdl, bak);
end
fprintf('Done. Open a model, run its inputs script, press Run, then screenshot.\n');

%% ------------------------------------------------------------------------
function lay(m)
P = containers.Map();
% ---- power path (bottom) ----
P('powergui')                 = [30   40  110  80];
P('Three-Phase Source')       = [30  200  115 260];
P('Three-Phase Transformer Inductance Matrix Type (Two Windings)') = [190 170 270 290];
P('Three-Phase V-I Measurement') = [350 175 440 285];
P('Load A')                   = [520  470 576 535];
xs = [640 770 900 1030];                       % breakers B..E and their loads
br = {'Three-Phase Breaker', 'Three-Phase Breaker1', 'Three-Phase Breaker2', 'Three-Phase Breaker3'};
ld = {'Load B', 'Load C', 'Load D', 'Load E'};
for i = 1:4
    P(br{i}) = [xs(i) 340 xs(i)+66 420];
    P(ld{i}) = [xs(i)+5 470 xs(i)+61 535];
end
% ---- signal path (top) ----
P('Demux') = [500 90 505 130];
P('Gain1') = [550 95 590 125];                % 1/sqrt(2)
P('Gain')  = [630 95 670 125];                % 1/I_rated -> K
P('Display1')  = [720  20 810  50];           % K
P('Scope')     = [720 -30 750   0];
P('K_varying') = [830  20 920  50];
P('Top_Oil_Thermal_Model')   = [760 130 920 190];
P('Display2')                = [980 200 1070 230];   % top oil
P('Hot_Spot_Thermal_Model')  = [980 100 1140 160];
P('Display3')                = [1200 170 1290 200];  % hot spot
P('Aging_Loss_of_Life_Model')= [1200  60 1340 160];
P('To Workspace')        = [1420  20 1510  45];
P('Display5')            = [1530  20 1620  45];
P('To Workspace1')       = [1420  95 1510 120];
P('Display6')            = [1530  95 1620 120];
P('LoL_percent_varying') = [1420 165 1510 190];
P('Display7')            = [1530 165 1620 190];

% remember signal connections, move blocks, then redraw signal lines
blocks = find_system(m, 'SearchDepth', 1, 'Type', 'Block');
pairs = zeros(0, 2);
for b = 1:numel(blocks)
    ph = get_param(blocks{b}, 'PortHandles');
    for ip = ph.Inport
        L = get_param(ip, 'Line');
        if L ~= -1, pairs(end+1, :) = [get_param(L, 'SrcPortHandle') ip]; end %#ok<AGROW>
    end
end
for b = 1:numel(blocks)
    nm = get_param(blocks{b}, 'Name');
    key = strtrim(regexprep(strrep(nm, newline, ' '), ' +', ' '));
    if ~isKey(P, key) && isKey(P, strrep(nm, newline, ' ')), key = strrep(nm, newline, ' '); end
    if ~isKey(P, key), fprintf('  (left in place: %s)\n', key); continue; end
    set_param(blocks{b}, 'Position', P(key));
end
% delete and redraw signal lines with clean routing
Ls = find_system(m, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for L = Ls'
    try
        if ~isempty(get_param(L, 'SrcPortHandle')) && get_param(L, 'SrcPortHandle') ~= -1 ...
                && strcmp(get_param(get_param(L, 'SrcPortHandle'), 'PortType'), 'outport')
            delete_line(L);
        end
    catch
    end
end
for i = 1:size(pairs, 1)
    try, add_line(m, pairs(i,1), pairs(i,2), 'autorouting', 'smart');
    catch, try, add_line(m, pairs(i,1), pairs(i,2), 'autorouting', 'on'); catch, end, end
end
% re-route the power (physical) lines so they follow the moved blocks
Ls = find_system(m, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
try, Simulink.BlockDiagram.routeLine(Ls); catch, end
set_param(m, 'ZoomFactor', 'FitSystem');
end
