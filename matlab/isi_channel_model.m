function [x, y_clean, y_noisy] = isi_channel_model(N, h, sigma, seed, sps)
% ISI_CHANNEL_MODEL  Realistic NRZ ISI channel with AWGN.
%
%   [x, y_clean, y_noisy] = isi_channel_model(N, h, sigma, seed, sps)
%
%   N      : number of symbols
%   h      : FIR ISI taps (example: [1.0 0.5 -0.2])
%   sigma  : noise standard deviation
%   seed   : RNG seed for reproducible runs
%   sps    : samples per symbol (default 8)
%
%   x       : PAM2 symbols in {-1, +1}  (1 x N)
%   y_clean : oversampled waveform after NRZ pulse + ISI, no noise  (1 x N*sps)
%   y_noisy : y_clean + AWGN  (1 x N*sps)

    if nargin < 1 || isempty(N),     N     = 2000;           end
    if nargin < 2 || isempty(h),     h     = [1.0, 0.5, -0.2]; end
    if nargin < 3 || isempty(sigma), sigma = 0.2;            end
    if nargin < 5 || isempty(sps),   sps   = 8;              end
    if nargin >= 4 && ~isempty(seed)
        rng(seed);
    end

    % PAM2 symbols
    x = 2 * randi([0, 1], 1, N) - 1;

    % Upsample and apply rectangular NRZ pulse (hold each symbol for sps samples)
    x_up    = upsample(x, sps);
    x_nrz   = conv(x_up, ones(1, sps), 'full');
    x_nrz   = x_nrz(1:N*sps);          % trim to exact length

    % ISI channel — taps spaced sps samples apart so each tap hits the
    % next symbol, not the next sample within the same symbol
    h_up    = zeros(1, (length(h)-1)*sps + 1);
    h_up(1:sps:end) = h;                % place taps at symbol boundaries
    y_full  = conv(x_nrz, h_up, 'full');
    y_clean = y_full(1:N*sps);          % causal, trim to signal length

    % AWGN
    noise   = sigma * randn(size(y_clean));
    y_noisy = y_clean + noise;
end
