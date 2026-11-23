%% plot_all_figures.m - all thesis figures, same style as Monthly Report 6
% Run AFTER run_Cases, run_SA1, run_SA2_Share and run_SA2_TimeVarying,
% in the 03.11.2026 folder. Saves PNG files (300 dpi) in the subfolder "figures".
%
%   Fig03            load factor K, Cases 1-3
%   Fig04-06         Case 1: thermal response, aging acceleration factor, cumulative aging
%   Fig07-09         Case 2: same three
%   Fig10-12         Case 3: same three
%   Fig13-16         SA1 ambient: hot spot, top oil, F_AA, cumulative aging
%   Fig17-20         SA2 constant nonlinear share: same four
%   Fig21-24         SA2 Load D rectifier: thermal response, alpha(t), F_AA, cumulative aging
%
% Signal names: set them below if the automatic search picks the wrong one.
% The script prints the names it uses - check them once.
% Peak values for the thesis come from the tables, not from these curves.

clear; close all;
NAMES.HS  = 'Theta_H_varying';
NAMES.TO  = 'Theta_TO_varying';
NAMES.AG  = 'Aging_hours_varying';
NAMES.FAA = '';      % empty = search for a name containing "faa" or "accel"
NAMES.K   = '';      % empty = search for a name starting with "K" or containing "load"
SMOOTH    = true;    % smooth the small breaker notch at 06:00 (plots only)
outdir    = 'figures';
if ~isfolder(outdir), mkdir(outdir); end

%% ---------------- Cases 1-3 ---------------------------------------------
try
    caseLab = {'Case 1 - Rated Cyclic Loading', 'Case 2 - Moderate Cyclic Overloading', ...
               'Case 3 - Short-Term Overloading'};
    C = cell(1,3);
    for i = 1:3
        S = load(sprintf('Case%d_results.mat', i), 'R');
        if ~isfield(S.R, 'out')
            error('Case%d_results.mat has no full run. Rerun run_Cases with the new run_periodic.m.', i);
        end
        C{i} = build_curves(S.R.out, NAMES, SMOOTH, i == 1);
    end

    % Fig 3 - load factor
    f = new_fig(); hold on; h = gobjects(1,3);
    for i = 1:3, h(i) = plot(C{i}.t, C{i}.K, 'LineWidth', 1.8); end
    yline(1, 'k--', 'Rated Load (K = 1.0)', 'LabelHorizontalAlignment', 'right');
    xline([17 17.5], 'k--', {'17:00', '17:30'});
    finish('Comparison of Loading Profiles for Cases 1-3', 'Loading Factor, K (p.u.)', h, caseLab, 'east');
    save_fig(f, outdir, 'Fig03_Load_Cases');

    % Figs 4-12 - per case
    nr = 4;
    for i = 1:3
        tag = sprintf('Case %d', i);
        f = new_fig(); hold on;
        h = [plot(C{i}.t, C{i}.HS, 'LineWidth', 1.8), plot(C{i}.t, C{i}.TO, 'LineWidth', 1.8)];
        finish([tag ' - Transformer Thermal Response'], 'Temperature (°C)', h, ...
               {'Hot-Spot Temperature', 'Top-Oil Temperature'}, 'southeast');
        save_fig(f, outdir, sprintf('Fig%02d_Case%d_Thermal', nr, i));

        f = new_fig(); plot(C{i}.t, C{i}.FAA, 'LineWidth', 1.8);
        add_unity(C{i}.FAA);
        finish([tag ' - Aging Acceleration Factor'], 'Aging Acceleration Factor, F_{AA}');
        save_fig(f, outdir, sprintf('Fig%02d_Case%d_FAA', nr+1, i));

        f = new_fig(); plot(C{i}.t, C{i}.AG, 'LineWidth', 1.8);
        finish([tag ' - Cumulative Transformer Aging'], 'Equivalent Aging (h)');
        save_fig(f, outdir, sprintf('Fig%02d_Case%d_Aging', nr+2, i));
        nr = nr + 3;
    end
catch ME
    fprintf('Cases figures stopped: %s\n', ME.message);
end

%% ---------------- SA1 - ambient temperature -----------------------------
try
    S = load('SA1_results.mat');
    O = get_outs(S);
    if isfield(S, 'T_list'), T = S.T_list; else, T = [10 24 30 35 40]; end
    C   = cellfun(@(o) build_curves(o, NAMES, SMOOTH, false), O, 'UniformOutput', false);
    lab = arrayfun(@(x) sprintf('\\theta_A = %g °C', x), T, 'UniformOutput', false);
    four_figs(C, lab, 'ambient temperatures (Case 2 loading)', outdir, 13, 'SA1');
catch ME
    fprintf('SA1 figures stopped: %s\n', ME.message);
end

%% ---------------- SA2 - constant nonlinear share -------------------------
try
    S = load('SA2_share_results.mat');
    O = get_outs(S);
    if isfield(S, 'alpha_list'), a = S.alpha_list; else, a = [0 0.15 0.30 0.50]; end
    if max(a) <= 1, a = 100*a; end
    C   = cellfun(@(o) build_curves(o, NAMES, SMOOTH, false), O, 'UniformOutput', false);
    lab = arrayfun(@(x) sprintf('%g %% nonlinear load', x), a, 'UniformOutput', false);
    four_figs(C, lab, 'nonlinear load shares (Case 2 loading, 24 °C)', outdir, 17, 'SA2share');
catch ME
    fprintf('SA2 share figures stopped: %s\n', ME.message);
end

%% ---------------- SA2 - Load D as rectifier (time-varying) ---------------
try
    S = load('SA2_TV_results.mat');
    O = get_outs(S);
    C   = cellfun(@(o) build_curves(o, NAMES, SMOOTH, false), O, 'UniformOutput', false);
    lab = {'Case 2 (no harmonics)', 'Load D as rectifier'};  lab = lab(1:numel(C));
    ttl = 'SA2 - Load D Rectifier';

    f = new_fig(); hold on; h = gobjects(1, 2*numel(C)); L = cell(1, 2*numel(C));
    for i = 1:numel(C)
        ls = '-'; if i == 1, ls = '--'; end
        h(2*i-1) = plot(C{i}.t, C{i}.HS, ls, 'LineWidth', 1.8, 'Color', [0 0.447 0.741]);
        h(2*i)   = plot(C{i}.t, C{i}.TO, ls, 'LineWidth', 1.8, 'Color', [0.85 0.325 0.098]);
        L{2*i-1} = ['Hot spot - ' lab{i}];  L{2*i} = ['Top oil - ' lab{i}];
    end
    finish([ttl ' - Transformer Thermal Response'], 'Temperature (°C)', h, L, 'southeast');
    save_fig(f, outdir, 'Fig21_SA2TV_Thermal');

    f = new_fig();
    [ta, al] = find_sig(O{end}, {'alpha'});
    if isempty(ta)
        fprintf('Fig22 skipped: no logged signal with "alpha" in its name.\n'); close(f);
    else
        if max(al) <= 1, al = 100*al; end
        plot(ta/3600, al, 'LineWidth', 1.8);
        finish([ttl ' - Nonlinear Share of Load Current'], 'Rectifier share, \alpha (%)');
        save_fig(f, outdir, 'Fig22_SA2TV_Alpha');
    end

    f = new_fig(); hold on; h = gobjects(1, numel(C));
    for i = 1:numel(C), h(i) = plot(C{i}.t, C{i}.FAA, 'LineWidth', 1.8); end
    add_unity([C{1}.FAA; C{end}.FAA]);
    finish([ttl ' - Aging Acceleration Factor'], 'Aging Acceleration Factor, F_{AA}', h, lab, 'northwest');
    save_fig(f, outdir, 'Fig23_SA2TV_FAA');

    f = new_fig(); hold on; h = gobjects(1, numel(C));
    for i = 1:numel(C), h(i) = plot(C{i}.t, C{i}.AG, 'LineWidth', 1.8); end
    finish([ttl ' - Cumulative Transformer Aging'], 'Equivalent Aging (h)', h, lab, 'northwest');
    save_fig(f, outdir, 'Fig24_SA2TV_Aging');
catch ME
    fprintf('SA2 time-varying figures stopped: %s\n', ME.message);
end

fprintf('Done. Figures are in the folder "%s".\n', outdir);

%% ========================================================================
function four_figs(C, lab, what, outdir, nr, tag)
% Hot spot, top oil, F_AA and cumulative aging - one line per run.
    fields = {'HS', 'TO', 'FAA', 'AG'};
    titles = {'Hot-Spot Temperature', 'Top-Oil Temperature', ...
              'Aging Acceleration Factor', 'Cumulative Equivalent Aging'};
    ylabs  = {'Hot-Spot Temperature (°C)', 'Top-Oil Temperature (°C)', ...
              'Aging Acceleration Factor, F_{AA}', 'Equivalent Aging (h)'};
    files  = {'HotSpot', 'TopOil', 'FAA', 'Aging'};
    for k = 1:4
        f = new_fig(); hold on; h = gobjects(1, numel(C)); allv = [];
        for i = 1:numel(C)
            h(i) = plot(C{i}.t, C{i}.(fields{k}), 'LineWidth', 1.8);
            allv = [allv; C{i}.(fields{k})]; %#ok<AGROW>
        end
        if k == 1, yline(110, 'k--', '110 °C', 'LabelHorizontalAlignment', 'left'); end
        if k == 3, add_unity(allv); end
        finish(sprintf('%s at different %s', titles{k}, what), ylabs{k}, h, lab, 'northwest');
        save_fig(f, outdir, sprintf('Fig%02d_%s_%s', nr + k - 1, tag, files{k}));
    end
end

function f = new_fig()
    f = figure('Color', 'w', 'Position', [80 80 1300 700]);
end

function finish(ttl, ylab, h, lab, loc)
    grid on; box on; xlim([0 24]); xticks(0:2:24);
    xlabel('Time (h)'); ylabel(ylab); title(ttl);
    set(gca, 'FontName', 'Arial', 'FontSize', 11);
    if nargin >= 4, legend(h, lab, 'Location', loc); end
end

function add_unity(v)
% Reference line F_AA = 1 (aging at the rated rate), only if the curve gets near it.
    if max(v) > 0.5
        yline(1, 'k--', 'F_{AA} = 1 (reference aging rate)', 'LabelHorizontalAlignment', 'left');
    end
end

function save_fig(f, outdir, name)
    exportgraphics(f, fullfile(outdir, [name '.png']), 'Resolution', 300);
    fprintf('Saved %s.png\n', name);
end

function c = build_curves(o, N, smoothOn, verbose)
% All signals of one run on a common 1-minute grid (time in hours).
    tq = (0:1/60:24)';
    c.t = tq;
    c.HS  = grid1(o, {N.HS},  tq, smoothOn, verbose, 'hot spot');
    c.TO  = grid1(o, {N.TO},  tq, smoothOn, verbose, 'top oil');
    c.AG  = grid1(o, {N.AG},  tq, false,    verbose, 'cumulative aging');
    if isempty(N.FAA), pf = {'faa', 'f_aa', 'accel'}; else, pf = {N.FAA}; end
    c.FAA = grid1(o, pf, tq, smoothOn, verbose, 'aging acceleration factor');
    if isempty(N.K)
        pk = {'@K', 'load'};
    else
        pk = {N.K};
    end
    c.K   = grid1(o, pk, tq, false, verbose, 'load factor K');
end

function yq = grid1(o, pats, tq, smoothOn, verbose, what)
    [t, y, name] = find_sig(o, pats);
    if isempty(t)
        yq = nan(size(tq));
        if verbose, fprintf('  WARNING: no signal found for %s. Set its name at the top of the script.\n', what); end
        return
    end
    if verbose, fprintf('  %-26s -> %s\n', what, name); end
    [t, iu] = unique(t/3600, 'last');  y = y(iu);
    yq = interp1(t, y, tq, 'previous', 'extrap');      % keeps load steps sharp
    yl = interp1(t, y, tq, 'linear',   'extrap');
    if ~strcmp(what, 'load factor K'), yq = yl; end
    if smoothOn
        ys  = movmedian(yq, 9);
        idx = tq > 5.9 & tq < 6.4;
        yq(idx) = ys(idx);
    end
end

function [t, y, name] = find_sig(o, pats)
% First logged signal matching one of the patterns.
% An exact name matches exactly; '@K' = name starting with K (not aging);
% other patterns = part of the name (not case-sensitive).
    t = []; y = []; name = '';
    if isa(o, 'Simulink.SimulationOutput'), names = o.who; else, names = fieldnames(o); end
    for p = 1:numel(pats)
        pat = pats{p};
        i = find(strcmp(names, pat), 1);
        if isempty(i) && strcmp(pat, '@K')
            i = find(startsWith(names, 'K') & ~contains(lower(names), 'aging'), 1);
        elseif isempty(i)
            i = find(contains(lower(names), lower(pat)), 1);
        end
        if ~isempty(i)
            name = names{i};
            [t, y] = get_sig(o, name);
            return
        end
    end
end

function [t, y] = get_sig(o, name)
    if isa(o, 'Simulink.SimulationOutput'), s = o.get(name); else, s = o.(name); end
    if isa(s, 'timeseries')
        t = s.Time; y = squeeze(s.Data);
    elseif isstruct(s)
        t = s.time; y = squeeze(s.signals.values);
    else
        error('signal %s has an unknown format', name);
    end
    t = t(:); y = double(y(:));
    if numel(y) ~= numel(t), y = y(1:numel(t)); end
end

function O = get_outs(S)
% Saved simulation outputs in a loaded .mat file (field "outs" first).
    if isfield(S, 'outs'), O = collect(S.outs);
    else
        O = {}; f = fieldnames(S);
        for i = 1:numel(f), O = [O, collect(S.(f{i}))]; end %#ok<AGROW>
    end
    if isempty(O), error('no saved simulation outputs found in the file'); end
end

function c = collect(v)
    c = {};
    if isa(v, 'Simulink.SimulationOutput')
        for k = 1:numel(v), c{end+1} = v(k); end %#ok<AGROW>
    elseif iscell(v)
        for k = 1:numel(v), c = [c, collect(v{k})]; end %#ok<AGROW>
    elseif isstruct(v) && isfield(v, 'R') && isfield(v.R, 'out')
        c{end+1} = v.R.out;
    end
end
