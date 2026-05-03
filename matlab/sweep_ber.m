% sweep_ber.m
% Sweep Eb/N0 and plot BER curves: no-equalizer vs MATLAB DFE vs fixed-point DFE.
%
% Outputs:
%   BER_SWEEP_DATA.mat  (for replotting later)
%   Figure showing three curves

clear; clc;
addpath(fileparts(mfilename('fullpath')));   % make sure matlab/ is on path

%% ---- Report artifact output setup --------------------------------------
script_dir    = fileparts(mfilename('fullpath'));
run_id        = datestr(now, 'yyyymmdd_HHMMSS');
artifact_dir  = fullfile(script_dir, '..', 'report_artifacts', 'sweep_ber', run_id);
if ~exist(artifact_dir, 'dir')
    mkdir(artifact_dir);
end
report_fig_dir = fullfile(script_dir, '..', 'report_assets');
if ~exist(report_fig_dir, 'dir')
    mkdir(report_fig_dir);
end
log_file = fullfile(artifact_dir, 'console.txt');
diary(log_file);
cleanupObj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('Artifact directory: %s\n', artifact_dir);

%% ---- Parameters (keep in sync with export_vectors.m) -------------------
N        = 2000;
h        = [1.0, 0.5, -0.2];   % channel taps
seed     = 101;
sps      = 8;
FRAC_BITS = 11;
SCALE    = 2^FRAC_BITS;

% Eb/N0 sweep
ebn0_db_list = 4:2:16;  % 4, 6, 8, 10, 12, 14, 16 dB
N_points     = length(ebn0_db_list);

%% ---- Pre-compute coefficients in fixed-point -----
dfe_coeffs    = h(2:end);
coeffs_q15    = round(dfe_coeffs * 2^15);
coeffs_q15    = max(min(coeffs_q15, 32767), -32768);

%% ---- Sweep ---------------------------------------------------------------
ber_no_eq  = zeros(1, N_points);
ber_float  = zeros(1, N_points);
ber_fixed  = zeros(1, N_points);

fprintf('Sweeping Eb/N0 from %.1f to %.1f dB...\n', ebn0_db_list(1), ebn0_db_list(end));

for pt = 1:N_points
    ebn0_db = ebn0_db_list(pt);
    
    % Generate channel and add noise
    [x, y_clean, ~] = isi_channel_model(N, h, 0, seed, sps);
    y_noisy         = awgn_noise(y_clean, ebn0_db);
    
    % Sample at symbol centres
    sample_idx = floor(sps / 2);
    rx_sym     = y_noisy(sample_idx : sps : end);
    rx_sym     = rx_sym(1:N);
    
    % No-equaliser
    d_raw = sign(rx_sym);
    d_raw(d_raw==0) = 1;
    ber_no_eq(pt) = ber_measure(x, d_raw);
    
    % Floating-point DFE
    [d_float, ~] = dfe_reference(rx_sym, dfe_coeffs);
    ber_float(pt) = ber_measure(x, d_float);
    
    % Fixed-point DFE
    rx_q = round(rx_sym * SCALE);
    rx_q = max(min(rx_q, 32767), -32768);
    [d_fxp, ~] = dfe_reference_fixed(rx_q, coeffs_q15, FRAC_BITS);
    ber_fixed(pt) = ber_measure(x, d_fxp);
    
    fprintf('  Eb/N0 = %2.1f dB : no-eq BER = %.4f, float DFE = %.4f, fixed DFE = %.4f\n', ...
            ebn0_db, ber_no_eq(pt), ber_float(pt), ber_fixed(pt));
end

%% ---- Save data for later replotting -----------
save('BER_SWEEP_DATA.mat', 'ebn0_db_list', 'ber_no_eq', 'ber_float', 'ber_fixed');
save(fullfile(artifact_dir, 'BER_SWEEP_DATA.mat'), 'ebn0_db_list', 'ber_no_eq', 'ber_float', 'ber_fixed');

tbl = table(ebn0_db_list(:), ber_no_eq(:), ber_float(:), ber_fixed(:), ...
    'VariableNames', {'EbN0_dB', 'BER_NoEq', 'BER_DFE_Float', 'BER_DFE_Fixed'});
writetable(tbl, fullfile(artifact_dir, 'ber_sweep_table.csv'));

%% ---- Plot ----------------------------------------------------------------
fig = figure('Position', [100 100 800 600]);
semilogy(ebn0_db_list, ber_no_eq, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
hold on;
semilogy(ebn0_db_list, ber_float, 'g-s', 'LineWidth', 2, 'MarkerSize', 6);
semilogy(ebn0_db_list, ber_fixed, 'r-^', 'LineWidth', 2, 'MarkerSize', 6);
grid on;
xlabel('Eb/N0 (dB)', 'FontSize', 12);
ylabel('Bit Error Rate', 'FontSize', 12);
title('DFE vs No-Equalizer: BER vs Eb/N0', 'FontSize', 14);
legend('No Equaliser', 'DFE (Float)', 'DFE (Fixed)', 'FontSize', 11, 'Location', 'southwest');
set(gca, 'FontSize', 11);

print(gcf, '-dpng', 'ber_sweep.png');
print(gcf, '-dpng', fullfile(artifact_dir, 'ber_sweep.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'ber_sweep.png'));
fprintf('\nPlot saved to ber_sweep.png\n');
fprintf('Saved report artifacts to: %s\n', artifact_dir);
fprintf('Saved report figure: %s\n', fullfile(report_fig_dir, 'ber_sweep.png'));
