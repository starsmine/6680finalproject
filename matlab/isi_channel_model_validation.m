% START_SQUARE_ONE_ISI  Square-one ISI + noise validation script.
% Run this before DFE/HDL integration.

clear; clc; close all;

%% 0) Report artifact output setup
script_dir    = fileparts(mfilename('fullpath'));
run_id        = datestr(now, 'yyyymmdd_HHMMSS');
artifact_dir  = fullfile(script_dir, '..', 'report_artifacts', 'isi_channel_model_validation', run_id);
if ~exist(artifact_dir, 'dir')
	mkdir(artifact_dir);
end
report_fig_dir = fullfile(script_dir, '..', 'report_assets');
if ~exist(report_fig_dir, 'dir')
	mkdir(report_fig_dir);
end
log_file = fullfile(artifact_dir, 'console.txt');
diary(log_file);
cleanupObj = onCleanup(@() diary('off'));

fprintf('Artifact directory: %s\n', artifact_dir);

%% 1) Parameters to tune
N     = 2000;
h     = [1.0, 0.5, -0.2];
sigma = 0.2;
EbN0_dB = 12;
use_awgn_helper = true;  % true: add noise via awgn_noise(y_clean, EbN0_dB)
seed  = 101;
sps   = 8;      % samples per symbol — increase for smoother waveform

%% 2) Run model
[x, y_clean, y_noisy] = isi_channel_model(N, h, sigma, seed, sps);
if use_awgn_helper
	y_noisy = awgn_noise(y_clean, EbN0_dB);
end

%% 3) Simple verification
noise = y_noisy - y_clean;

fprintf('ISI check\n');
fprintf('  N: %d\n', N);
fprintf('  taps: [%s]\n', num2str(h));
if use_awgn_helper
	fprintf('  noise mode: awgn_noise, Eb/N0 = %.2f dB\n', EbN0_dB);
else
	fprintf('  noise mode: sigma direct\n');
	fprintf('  sigma (set): %.6f\n', sigma);
end
fprintf('  sigma (measured): %.6f\n', std(noise));

%% 4) Quick visual sanity (show first 30 symbols worth of waveform)
nSym_plot = 50;
x_stairs = repelem(x(1:nSym_plot), sps);   % hold each symbol for sps samples
figure;
stairs(x_stairs, 'k', 'DisplayName', 'input x');
hold on;
plot(y_clean(1:nSym_plot*sps), 'b', 'DisplayName', 'after ISI (clean)');
plot(y_noisy(1:nSym_plot*sps), 'r', 'DisplayName', 'after ISI + noise');
grid on;
legend('Location', 'best');
title('ISI + AWGN Bring-Up');
xlabel('Sample Index');
ylabel('Amplitude');
print(gcf, '-dpng', fullfile(artifact_dir, 'waveform_bringup.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'waveform_bringup.png'));

%% 5) Eye diagram (no ISI, no noise) — report-ready reference
x_eye = repelem(x, sps);
eyediagram(x_eye, 2*sps);
title('Eye Diagram - No ISI, No Noise (Ideal NRZ PAM2)');
print(gcf, '-dpng', fullfile(artifact_dir, 'eye_no_isi_no_noise.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'eye_no_isi_no_noise.png'));

%% 6) Eye diagram — 2 symbol periods per trace
eyediagram(y_noisy, 2*sps);
title('Eye Diagram - Input (Noisy Channel Output)');
print(gcf, '-dpng', fullfile(artifact_dir, 'eye_input_noisy.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'eye_input_noisy.png'));

%% 7) Baseline BER (no equalizer)
% Sample once per symbol at the center of each symbol period.
sample_idx = floor(sps/2);
rx_sym = y_noisy(sample_idx:sps:sample_idx + (N-1)*sps);

decisions = sign(rx_sym);
decisions(decisions == 0) = 1;   % tie-break at threshold

ber_no_eq = ber_measure(x, decisions);
fprintf('  BER (no equalizer): %.4e\n', ber_no_eq);

%% 8) DFE reference phase (symbol-rate)
% Initial DFE taps from channel post-cursors: h(2:end)
dfe_coeffs = h(2:end);
[dfe_decisions, ~] = dfe_reference(rx_sym, dfe_coeffs);

% Recreate equalised symbol stream for visualisation.
num_taps = length(dfe_coeffs);
past = zeros(1, num_taps);
eq_sym = zeros(1, N);
for k = 1:N
	eq_sym(k) = rx_sym(k) - dfe_coeffs * past.';
	past = [dfe_decisions(k), past(1:end-1)];
end

ber_dfe = ber_measure(x, dfe_decisions);
fprintf('  BER (DFE reference): %.4e\n', ber_dfe);
fprintf('  BER improvement factor: %.2fx\n', ber_no_eq / max(ber_dfe, 1e-12));

%% 9) Eye diagrams at DFE input/output (decision-rate, held for display)
rx_eye = repelem(rx_sym, sps);
eq_eye = repelem(eq_sym, sps);

figure;
eyediagram(rx_eye, 2*sps);
title('Eye Diagram — DFE Input (symbol-rate samples)');
print(gcf, '-dpng', fullfile(artifact_dir, 'eye_dfe_input_symbolrate.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'eye_dfe_input_symbolrate.png'));

figure;
eyediagram(eq_eye, 2*sps);
title('Eye Diagram — Post-DFE Equalised (symbol-rate samples)');
print(gcf, '-dpng', fullfile(artifact_dir, 'eye_post_dfe_symbolrate.png'));
print(gcf, '-dpng', fullfile(report_fig_dir, 'eye_post_dfe_symbolrate.png'));

%% 10) Save numeric summary for report tables
results = struct();
results.N = N;
results.h = h;
results.sigma_set = sigma;
results.use_awgn_helper = use_awgn_helper;
results.EbN0_dB = EbN0_dB;
results.seed = seed;
results.sps = sps;
results.sigma_measured = std(noise);
results.ber_no_eq = ber_no_eq;
results.ber_dfe = ber_dfe;
results.ber_improvement_factor = ber_no_eq / max(ber_dfe, 1e-12);

save(fullfile(artifact_dir, 'results.mat'), 'results');

fid = fopen(fullfile(artifact_dir, 'results_summary.txt'), 'w');
fprintf(fid, 'N=%d\n', results.N);
fprintf(fid, 'h=[%s]\n', num2str(results.h));
fprintf(fid, 'sigma_set=%.6f\n', results.sigma_set);
fprintf(fid, 'sigma_measured=%.6f\n', results.sigma_measured);
fprintf(fid, 'EbN0_dB=%.2f\n', results.EbN0_dB);
fprintf(fid, 'seed=%d\n', results.seed);
fprintf(fid, 'sps=%d\n', results.sps);
fprintf(fid, 'ber_no_eq=%.8f\n', results.ber_no_eq);
fprintf(fid, 'ber_dfe=%.8f\n', results.ber_dfe);
fprintf(fid, 'ber_improvement_factor=%.4f\n', results.ber_improvement_factor);
fclose(fid);

fprintf('Saved figures and summaries to: %s\n', artifact_dir);
fprintf('Saved report figure: %s\n', fullfile(report_fig_dir, 'eye_no_isi_no_noise.png'));
fprintf('Saved report figures: %s\n', report_fig_dir);