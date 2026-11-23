function R = run_periodic(mdl, tol, maxRuns, agingName)
%RUN_PERIODIC  Run a model until the day ends where it started.
%   R = run_periodic(mdl)  uses the inputs already in the base workspace
%   (e.g. after Case2_inputs). Run 1 starts cold at T_amb; each next run
%   starts from the end values of the previous one, until start and end
%   agree within tol (default 0.05 degC).
%
%   Output R: peakHS, peakTO, aging, endTO, endHS, aging_cold, nRuns,
%             t, HS, TO (time in s, temperatures in degC), and out (the
%             full final simulation output, used by plot_all_figures).
%
%   agingName: name of the logged aging signal. If empty, the first logged
%   signal with "aging" in its name is used (the name is printed - check it).

if nargin < 2 || isempty(tol),       tol = 0.05;    end
if nargin < 3 || isempty(maxRuns),   maxRuns = 6;   end
if nargin < 4,                       agingName = ''; end

load_system(mdl);
set_param(mdl, 'MaxStep', '60');            % 60 s, same in every study

Tamb = evalin('base', 'T_amb');
TO0 = Tamb;  HS0 = Tamb;                     % run 1 = cold start

for k = 1:maxRuns
    assignin('base', 'Theta_TO_0', TO0);
    assignin('base', 'Theta_H_0',  HS0);
    out = sim(mdl);

    [t, hs] = getsig(out, 'Theta_H_varying');
    [~, to] = getsig(out, 'Theta_TO_varying');
    if isempty(agingName)
        names = out.who;
        ia = find(contains(lower(names), 'aging'), 1);
        if isempty(ia), error('No logged signal with "aging" in its name. Pass agingName.'); end
        agingName = names{ia};
        fprintf('  (aging signal used: %s)\n', agingName);
    end
    [~, ag] = getsig(out, agingName);

    fprintf('  run %d: start TO/HS %.2f / %.2f  ->  end %.2f / %.2f degC, aging %.2f h\n', ...
            k, TO0, HS0, to(end), hs(end), ag(end));
    if k == 1, aging_cold = ag(end); end

    done = k > 1 && abs(to(end) - TO0) < tol && abs(hs(end) - HS0) < tol;
    if done, break; end
    TO0 = to(end);  HS0 = hs(end);
end
if ~done, warning('%s: not converged after %d runs', mdl, maxRuns); end

R = struct('model', mdl, 'peakHS', max(hs), 'peakTO', max(to), ...
           'aging', ag(end), 'aging_cold', aging_cold, ...
           'startTO', TO0, 'startHS', HS0, 'endTO', to(end), 'endHS', hs(end), ...
           'nRuns', k, 't', t, 'HS', hs, 'TO', to);
R.out = out;                                 % full final run (all logged signals, for plots)
end

%% ------------------------------------------------------------------------
function [t, y] = getsig(out, name)
% Works for To Workspace in Timeseries or Structure With Time format.
    s = out.get(name);
    if isa(s, 'timeseries')
        t = s.Time;  y = squeeze(s.Data);
    elseif isstruct(s)
        t = s.time;  y = squeeze(s.signals.values);
    else
        error('Signal %s: use Timeseries or Structure With Time in the To Workspace block.', name);
    end
    t = t(:);  y = y(:);
end
