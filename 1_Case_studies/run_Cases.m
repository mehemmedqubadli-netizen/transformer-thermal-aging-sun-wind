function run_Cases()
%RUN_CASES  Cases 1-3 of the 50 MVA transformer, corrected model, periodic start.
% Same parameters for all three (Case2_inputs); only the breaker settings
% inside the models differ. Saves Case1/2/3_results.mat and Cases_table.mat.
% (Written as a function because Case2_inputs starts with "clear".)

models = {'Integrated_Transformer_Case1_fixed', ...
          'Integrated_Transformer_Case2_fixed', ...
          'Integrated_Transformer_Case3_fixed'};
names  = {'Case1', 'Case2', 'Case3'};
ref    = [ 90.2  72.2  0.92;      % values from 4 Nov (before MaxStep = 60 s)
          105.3  82.3  2.73;
          121.9  87.8  4.05];

peakHS = zeros(3,1); peakTO = peakHS; aging = peakHS; endTO = peakHS; endHS = peakHS;

for i = 1:3
    fprintf('\n=== %s ===\n', names{i});
    evalin('base', 'Case2_inputs');            % loads 50 MVA parameters into base workspace
    R = run_periodic(models{i});
    save([names{i} '_results.mat'], 'R');

    peakHS(i) = R.peakHS;  peakTO(i) = R.peakTO;  aging(i) = R.aging;
    endTO(i)  = R.endTO;   endHS(i)  = R.endHS;
    fprintf('  %s: peak HS %.1f (4 Nov: %.1f) | peak TO %.1f (%.1f) | aging %.2f h (%.2f)\n', ...
            names{i}, R.peakHS, ref(i,1), R.peakTO, ref(i,2), R.aging, ref(i,3));
end

Cases = table(peakHS, peakTO, aging, endTO, endHS, 'RowNames', names);
disp(Cases);
save('Cases_table.mat', 'Cases');
end
