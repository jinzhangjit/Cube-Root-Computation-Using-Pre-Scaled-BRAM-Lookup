%==========================================================================
% MATLAB Script: precision_analysis.m
%
% Theoretical precision analysis for the proposed pre-scaled BRAM cube-root
% architecture. This script reproduces:
%
%   (a) The effective bit precision p_eff of the proposed method.
%   (b) The per-subinterval error-bound table (Table V in the paper),
%       computed from Formula (12):
%           |eps_a|_max <= W_r / (6 * N * L_r^(2/3))
%       and the relative-error / effective-precision relation:
%           eps_rel_max = |eps_a|_max / x_min,   x_min = L_r^(1/3)
%           p_eff       = -log2(eps_rel_max)
%   (c) Fig. 4 -- Relative error vs. input y for the proposed method.
%   (d) Fig. 5 -- Probability density of the relative error.
%

%==========================================================================

clear; clc; close all;

%% -------------------------------------------------------------------------
% Output paths and log file
% -------------------------------------------------------------------------
out_dir = fullfile('..', 'results', 'matlab');
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end
log_file  = fullfile(out_dir, 'matlab_precision_analysis.log');
fig4_file = fullfile(out_dir, 'fig4_rel_error.png');
fig5_file = fullfile(out_dir, 'fig5_error_pdf.png');

if exist(log_file, 'file') == 2
    delete(log_file);
end
diary(log_file);
diary on;

fprintf('==========================================================\n');
fprintf(' Theoretical Precision Analysis -- Proposed Method\n');
fprintf(' Pre-Scaled BRAM Cube Root Architecture\n');
fprintf('==========================================================\n\n');

%% -------------------------------------------------------------------------
% Fixed-point configuration (must match RTL)
% -------------------------------------------------------------------------
INPUT_INT_BITS   = 2;    % Q2.22 input
INPUT_FRAC_BITS  = 22;
OUTPUT_INT_BITS  = 1;    % Q1.23 output
OUTPUT_FRAC_BITS = 23;

% Test domain: y in [0.5, 4)
Y_MIN = 0.5;
Y_MAX = 3.9999;

NUM_POINTS    = 100000;  % Dense sweep for empirical Fig. 4 and Fig. 5
NUM_HIST_BINS = 60;

% Subintervals: D_0=[0.5,1), D_1=[1,2), D_2=[2,4)
L_r_vals = [0.5, 1.0, 2.0];   % left endpoint
W_r_vals = [0.5, 1.0, 2.0];   % width
N_per_subinterval = 128;      % midpoint samples per sub-interval

%% -------------------------------------------------------------------------
% STEP 1 -- Per-subinterval error-bound table (Paper Table V)
% -------------------------------------------------------------------------
fprintf('Step 1: Per-Subinterval Error Bound (Eq. 12)\n');
fprintf('----------------------------------------------\n');
fprintf('  Formula: |eps_a|_max <= W_r / (6 * N * L_r^(2/3))\n');
fprintf('  Formula: p_eff       = -log2(|eps_a|_max / x_min),  x_min = L_r^(1/3)\n\n');

eps_a_max_all   = zeros(3, 1);
eps_rel_max_all = zeros(3, 1);
p_eff_all       = zeros(3, 1);

fprintf('  %-7s | %-12s | %-12s | %-12s | %-12s | %-10s\n', ...
        'Sub-int', '[L_r, L_r+W_r)', 'L_r^(2/3)', '|eps_a|_max', 'eps_rel_max(%)', 'p_eff(bit)');
fprintf('  %s\n', repmat('-', 1, 86));

for r = 0:2
    L_r   = L_r_vals(r+1);
    W_r   = W_r_vals(r+1);
    L_r23 = L_r ^ (2/3);

    eps_a_max   = W_r / (6 * N_per_subinterval * L_r23);
    x_min       = L_r ^ (1/3);
    eps_rel_max = eps_a_max / x_min;
    p_eff_r     = -log2(eps_rel_max);

    eps_a_max_all(r+1)   = eps_a_max;
    eps_rel_max_all(r+1) = eps_rel_max;
    p_eff_all(r+1)       = p_eff_r;

    fprintf('  D_%d     | [%.2f, %.2f)  | %-12.4f | %-12.4e | %-12.4f | %-10.4f\n', ...
            r, L_r, L_r + W_r, L_r23, eps_a_max, eps_rel_max * 100, p_eff_r);
end

[worst_eps_rel, worst_idx] = max(eps_rel_max_all);
p_eff_theoretical = -log2(worst_eps_rel);

fprintf('\n  Worst-case sub-interval : D_%d\n', worst_idx - 1);
fprintf('  Maximum relative error  : %.4e (%.4f %%)\n', worst_eps_rel, worst_eps_rel * 100);
fprintf('  THEORETICAL EFFECTIVE PRECISION : %.4f bits\n\n', p_eff_theoretical);

%% -------------------------------------------------------------------------
% STEP 2 -- Empirical verification of the proposed method
% -------------------------------------------------------------------------
fprintf('Step 2: Empirical Verification on %d Q2.22 Test Points\n', NUM_POINTS);
fprintf('--------------------------------------------------------\n');

% Q2.22-quantized test inputs spread across [0.5, 4)
y_real      = linspace(Y_MIN, Y_MAX, NUM_POINTS)';
y_fixed     = round(y_real * 2^INPUT_FRAC_BITS);
y_quantized = y_fixed / 2^INPUT_FRAC_BITS;

% Ideal cube root reference (double precision)
x_ideal = nthroot(y_quantized, 3);

% Build the 384-entry pre-scaled BRAM (Q1.23 quantized, midpoint sampling).
% Layout matches the RTL: addresses 0..127 -> D_0, 128..255 -> D_1, 256..383 -> D_2.
NUM_RANGES = 3;
bram = zeros(NUM_RANGES * N_per_subinterval, 1);
for r = 0:2
    L_r = L_r_vals(r+1);
    W_r = W_r_vals(r+1);
    for i = 0:N_per_subinterval-1
        y_mid = L_r + (i + 0.5) / N_per_subinterval * W_r;
        bram(r * N_per_subinterval + i + 1) = nthroot(y_mid, 3);
    end
end
bram_quant = round(bram * 2^OUTPUT_FRAC_BITS) / 2^OUTPUT_FRAC_BITS;

% Bit-extraction-style address generation (functionally equivalent to the RTL)
x_out = zeros(NUM_POINTS, 1);
for idx = 1:NUM_POINTS
    y_val = y_quantized(idx);
    if     y_val >= 2,  range_sel = 2; y_base = 2.0; y_width = 2.0;
    elseif y_val >= 1,  range_sel = 1; y_base = 1.0; y_width = 1.0;
    else                range_sel = 0; y_base = 0.5; y_width = 0.5;
    end
    frac_index = floor((y_val - y_base) / y_width * N_per_subinterval);
    frac_index = max(0, min(frac_index, N_per_subinterval - 1));
    bram_addr  = range_sel * N_per_subinterval + frac_index + 1;
    x_out(idx) = bram_quant(bram_addr);
end

% Relative error (in percent)
rel_err_pct = abs(x_out - x_ideal) ./ x_ideal * 100;

max_rel_err  = max(rel_err_pct);
mean_rel_err = mean(rel_err_pct);
p_eff_meas   = -log2(max_rel_err / 100);

fprintf('  Maximum relative error   : %.4f %%  (theoretical %.4f %%)\n', ...
        max_rel_err, worst_eps_rel * 100);
fprintf('  Average relative error   : %.4f %%\n', mean_rel_err);
fprintf('  Measured effective bits  : %.4f bits  (theoretical %.4f bits)\n\n', ...
        p_eff_meas, p_eff_theoretical);

%% -------------------------------------------------------------------------
% Fig. 4 -- Relative error vs. input y
% -------------------------------------------------------------------------
fprintf('Generating Fig. 4: Relative error vs. input y ...\n');
proposed_color = [0.0, 0.45, 0.74];

fig4 = figure('Position', [100, 100, 800, 460]);
plot(y_quantized, rel_err_pct, '.', 'Color', proposed_color, 'MarkerSize', 2);
hold on;
xl = xlim;
plot(xl, [max_rel_err, max_rel_err], 'r--', 'LineWidth', 1.5);
plot(xl, [worst_eps_rel * 100, worst_eps_rel * 100], 'k:', 'LineWidth', 1.5);

% Sub-interval boundaries
yl = ylim;
plot([1, 1], [0, yl(2)], 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
plot([2, 2], [0, yl(2)], 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
text(0.62, yl(2) * 0.92, 'D_0', 'FontSize', 10);
text(1.40, yl(2) * 0.92, 'D_1', 'FontSize', 10);
text(2.85, yl(2) * 0.92, 'D_2', 'FontSize', 10);

xlabel('Input y', 'FontSize', 12);
ylabel('Relative Error (%)', 'FontSize', 12);
title(sprintf(['Relative Error vs. Input y (Proposed Method)' ...
               '\nMax = %.4f %%, p_{eff} = %.2f bits'], ...
               max_rel_err, p_eff_meas), 'FontSize', 11);
legend({'Per-point relative error', ...
        sprintf('Measured max = %.4f %%', max_rel_err), ...
        sprintf('Theoretical bound = %.4f %%', worst_eps_rel * 100)}, ...
        'Location', 'best');
grid on;
xlim([Y_MIN, Y_MAX]);

saveas(fig4, fig4_file);
fprintf('  Saved: %s\n\n', fig4_file);

%% -------------------------------------------------------------------------
% Fig. 5 -- Probability density of the relative error
% -------------------------------------------------------------------------
fprintf('Generating Fig. 5: Probability density of relative error ...\n');

edges       = linspace(0, max_rel_err * 1.1, NUM_HIST_BINS + 1);
[counts, ~] = histcounts(rel_err_pct, edges);
bin_centers = (edges(1:end-1) + edges(2:end)) / 2;
prob_pct    = counts / sum(counts) * 100;

fig5 = figure('Position', [150, 150, 800, 420]);
bar(bin_centers, prob_pct, 1, 'FaceColor', proposed_color, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.75);
hold on;

yl = ylim;
plot([max_rel_err, max_rel_err], [0, yl(2)], 'r-', 'LineWidth', 1.5);
plot([worst_eps_rel * 100, worst_eps_rel * 100], [0, yl(2)], 'k--', 'LineWidth', 1.5);

xlabel('Relative Error (%)', 'FontSize', 12);
ylabel('Probability (%)', 'FontSize', 12);
title(sprintf(['Probability Density of Relative Error (Proposed Method)' ...
               '\nMax = %.4f %%, p_{eff} = %.2f bits'], ...
               max_rel_err, p_eff_meas), 'FontSize', 11);
legend({'Empirical PMF', ...
        sprintf('Measured max = %.4f %%', max_rel_err), ...
        sprintf('Theoretical bound = %.4f %%', worst_eps_rel * 100)}, ...
        'Location', 'best');
grid on;
xlim([0, max_rel_err * 1.1]);

saveas(fig5, fig5_file);
fprintf('  Saved: %s\n\n', fig5_file);

%% -------------------------------------------------------------------------
% Final summary
% -------------------------------------------------------------------------
fprintf('==========================================================\n');
fprintf(' SUMMARY (used in Tables IV and V of the paper)\n');
fprintf('==========================================================\n');
fprintf('  Theoretical max relative error   : %.4f %%\n',  worst_eps_rel * 100);
fprintf('  Measured    max relative error   : %.4f %%\n',  max_rel_err);
fprintf('  Average     relative error       : %.4f %%\n',  mean_rel_err);
fprintf('  Theoretical effective precision  : %.4f bits\n', p_eff_theoretical);
fprintf('  Measured    effective precision  : %.4f bits\n', p_eff_meas);
fprintf('==========================================================\n');
fprintf(' Generated files:\n');
fprintf('   %s\n', log_file);
fprintf('   %s\n', fig4_file);
fprintf('   %s\n', fig5_file);
fprintf('==========================================================\n');

diary off;
