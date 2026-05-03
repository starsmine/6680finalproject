% export_vectors.m
% Generate fixed-point channel samples and TX bits for the HDL testbench.
%
% Outputs written to ../vectors/:
%   channel_out.hex   one 4-digit uppercase hex value per line (Q4.11 signed)
%   tx_bits.txt       original PAM2 symbols (+1 / -1), one per line
%
% Format note:
%   Q4.11 means scale by 2^11 = 2048.  Range ≈ [-8, 8) maps to [-16384, 16383].
%   Values are stored as 16-bit two's-complement hex so $readmemh can load them.
%
% Parameters here MUST match the DUT instantiation in tb_dfe.sv.

clear; clc;
addpath(fileparts(mfilename('fullpath')));   % make sure matlab/ is on path

%% ---- Report artifact output setup --------------------------------------
script_dir    = fileparts(mfilename('fullpath'));
run_id        = datestr(now, 'yyyymmdd_HHMMSS');
artifact_dir  = fullfile(script_dir, '..', 'report_artifacts', 'export_vectors', run_id);
if ~exist(artifact_dir, 'dir')
    mkdir(artifact_dir);
end
log_file = fullfile(artifact_dir, 'console.txt');
diary(log_file);
cleanupObj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('Artifact directory: %s\n', artifact_dir);

%% ---- Parameters (keep in sync with tb_dfe.sv and validate_hdl.m) -------
N        = 2000;
h        = [1.0, 0.5, -0.2];   % channel taps;  post-cursors fed to DFE = h(2:end)
EbN0_dB  = 12;
seed     = 101;
sps      = 8;

FRAC_BITS = 11;                 % Q4.11 fractional bits
SCALE     = 2^FRAC_BITS;        % = 2048
MAX_VAL   =  2^15 - 1;          %  32767 = 0x7FFF
MIN_VAL   = -2^15;              % -32768 = 0x8000

%% ---- Run channel model --------------------------------------------------
[x, y_clean, ~] = isi_channel_model(N, h, 0, seed, sps);
y_noisy          = awgn_noise(y_clean, EbN0_dB);

%% ---- Sample at symbol centres ------------------------------------------
sample_idx = floor(sps / 2);                   % index of first symbol centre
rx_sym     = y_noisy(sample_idx : sps : end);  % symbol-rate samples
rx_sym     = rx_sym(1:N);                      % trim to exactly N

%% ---- Scale to Q4.11 fixed-point and saturate ---------------------------
rx_fp = round(rx_sym * SCALE);
rx_fp = max(min(rx_fp, MAX_VAL), MIN_VAL);     % clamp to 16-bit range

%% ---- Write channel_out.hex ---------------------------------------------
vectors_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'vectors');
if ~exist(vectors_dir, 'dir')
    mkdir(vectors_dir);
end

fid = fopen(fullfile(vectors_dir, 'channel_out.hex'), 'w');
for k = 1:N
    % typecast int16 → uint16 to get raw two's-complement bits, then print hex
    val = typecast(int16(rx_fp(k)), 'uint16');
    fprintf(fid, '%04X\n', val);
end
fclose(fid);

%% ---- Write tx_bits.txt -------------------------------------------------
fid = fopen(fullfile(vectors_dir, 'tx_bits.txt'), 'w');
for k = 1:N
    fprintf(fid, '%d\n', x(k));
end
fclose(fid);

fprintf('Wrote %d samples  →  vectors/channel_out.hex\n', N);
fprintf('Wrote %d symbols  →  vectors/tx_bits.txt\n',     N);

%% ---- Save run metadata for report traceability -------------------------
results = struct();
results.N = N;
results.h = h;
results.EbN0_dB = EbN0_dB;
results.seed = seed;
results.sps = sps;
results.frac_bits = FRAC_BITS;
results.scale = SCALE;
results.max_val = MAX_VAL;
results.min_val = MIN_VAL;
results.vectors_dir = vectors_dir;

save(fullfile(artifact_dir, 'export_vectors_results.mat'), 'results');

fid = fopen(fullfile(artifact_dir, 'export_vectors_summary.txt'), 'w');
fprintf(fid, 'N=%d\n', results.N);
fprintf(fid, 'h=[%s]\n', num2str(results.h));
fprintf(fid, 'EbN0_dB=%.2f\n', results.EbN0_dB);
fprintf(fid, 'seed=%d\n', results.seed);
fprintf(fid, 'sps=%d\n', results.sps);
fprintf(fid, 'frac_bits=%d\n', results.frac_bits);
fprintf(fid, 'scale=%d\n', results.scale);
fprintf(fid, 'max_val=%d\n', results.max_val);
fprintf(fid, 'min_val=%d\n', results.min_val);
fprintf(fid, 'vectors_dir=%s\n', results.vectors_dir);
fclose(fid);

fprintf('Saved report artifacts to: %s\n', artifact_dir);
