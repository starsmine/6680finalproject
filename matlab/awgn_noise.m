function y = awgn_noise(x, EbN0_dB)
% AWGN_NOISE  Add AWGN to a baseband signal.
%
%   y = awgn_noise(x, EbN0_dB)
%
%   x        : 1×N input signal
%   EbN0_dB  : Eb/N0 in dB (binary NRZ → Eb = 1)
%   y        : 1×N noisy output
%
%   Noise variance σ² = 1 / (2 * Eb/N0_linear) for binary NRZ where Eb=1.

    EbN0_lin = 10^(EbN0_dB / 10);
    sigma    = sqrt(1 / (2 * EbN0_lin));
    y        = x + sigma * randn(size(x));
end
