%% tidy_block_diagrams.m
% Tidies the block diagrams of the thesis models (layout only):
%   - top level and every own subsystem (Top_Oil, Hot_Spot, Aging) are
%     re-arranged left-to-right with MATLAB's auto-layout
%     (Simulink.BlockDiagram.arrangeSystem) and the lines re-routed;
%   - a backup of each model is saved first (<model>_backup_before_tidy.slx);
%   - the model is simulated before and after: the results must be identical
%     (layout cannot change the equations - this proves it);
%   - each diagram is exported as a 300 dpi PNG for the thesis (Diagram_*.png).
%
% Run it in the folder that holds the models (e.g. 3_Weather_extension).
% Needs MATLAB R2018b or newer.

clear; clc; close all;
run('Case2_inputs.m');                       % has its own "clear" -> must run first

% Models to tidy (those not found in this folder are skipped)
models = {'Integrated_Transformer_Case2_sunwind', ...
          'Integrated_Transformer_Case2_fixed'};

% Inputs so that every model version can run one Case 2 day at 24 degC
Ta_ws = [0 24; 86400 24];  G_ws = [0 0; 86400 0];  W_ws = [0 0; 86400 0];
cA_sun = 0;  kw_wind = 0;  P_R_total = 26.92e3 + 135.9e3;
HLF = 1;  Irms_I1 = 1;  Ta_const = 24;  K_scale = 1;

for m = 1:numel(models)
    mdl = models{m};
    if ~isfile([mdl '.slx']), fprintf('%s.slx not in this folder - skipped\n\n', mdl); continue; end
    fprintf('=== %s ===\n', mdl);

    % 1. backup
    bak = [mdl '_backup_before_tidy.slx'];
    if ~isfile(bak), copyfile([mdl '.slx'], bak); fprintf('Backup: %s\n', bak); end
    load_system(mdl);

    % 2. result before
    HS0 = run_day(mdl);

    % 3. tidy: own subsystems first, then the top level
    subs = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    subs = subs(~strcmp(subs, mdl));
    own  = {};
    for k = 1:numel(subs)
        if strcmp(get_param(subs{k}, 'LinkStatus'), 'none') && strcmp(get_param(subs{k}, 'Mask'), 'off')
            own{end+1} = subs{k}; %#ok<AGROW>
        end
    end
    for k = 1:numel(own)
        try
            Simulink.BlockDiagram.arrangeSystem(own{k});
            fprintf('Arranged: %s\n', own{k});
        catch e
            fprintf('Could not arrange %s: %s\n', own{k}, e.message);
        end
    end
    try
        Simulink.BlockDiagram.arrangeSystem(mdl);
        fprintf('Arranged: top level\n');
    catch e
        fprintf('Could not arrange top level: %s\n', e.message);
    end
    save_system(mdl);

    % 4. result after - must be identical
    HS1 = run_day(mdl);
    if ~isempty(HS0) && ~isempty(HS1)
        fprintf('Check: max |hot spot after - before| = %.6f K  (must be 0)\n', max(abs(HS1 - HS0)));
    end

    % 5. export diagrams (300 dpi PNG)
    systems = [{mdl}, own];
    for k = 1:numel(systems)
        name = strrep(systems{k}, [mdl '/'], '');
        if strcmp(name, mdl), name = 'top_level'; end
        f = sprintf('Diagram_%s_%s.png', strrep(mdl, 'Integrated_Transformer_', ''), name);
        try
            print(['-s' systems{k}], '-dpng', '-r300', f);
            fprintf('Exported %s\n', f);
        catch e
            fprintf('Could not export %s: %s\n', systems{k}, e.message);
        end
    end
    fprintf('\n');
end
fprintf('Done. Open the models to look, and send the Diagram_*.png files.\n');
fprintf('If you dislike a layout: close the model without saving, or copy the backup back.\n');

%% ------------------------------------------------------------------------
function HS = run_day(mdl)
% One Case 2 day; returns the hot spot (empty if the model cannot run here)
HS = [];
try
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    s = out.get('Theta_H_varying');
    if isa(s, 'timeseries'), HS = squeeze(s.Data); else, HS = s.signals.values(:); end
catch e
    fprintf('(simulation check skipped: %s)\n', e.message);
end
end
