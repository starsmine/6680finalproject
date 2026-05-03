function [decisions, tap_sum_q] = dfe_reference_fixed(rx_q, coeffs_q15, out_frac)
% DFE_REFERENCE_FIXED  Fixed-point MATLAB reference that mirrors RTL behavior.
%
%   [decisions, tap_sum_q] = dfe_reference_fixed(rx_q, coeffs_q15, out_frac)
%
%   rx_q        : 1xN signed fixed-point samples (int16-like values), e.g. Q4.11
%   coeffs_q15  : 1xNUM_TAPS signed Q1.15 coefficients (int16-like values)
%   out_frac    : fractional bits of rx_q format (11 for Q4.11)
%
%   decisions   : 1xN hard decisions in {-1,+1}
%   tap_sum_q   : 1xN fixed-point feedback estimate in same format as rx_q
%
% RTL-equivalent details:
%   - decision shift register initializes to 0 bits (which map to -1 in the MAC)
%   - decision mapping: bit 1 -> +0x7FFF, bit 0 -> -0x8000
%   - MAC uses Q1.15 x Q1.15 => Q2.30, arithmetic shift by (30-out_frac)
%   - subtractor saturates to int16 range before slicing

    if nargin < 3
        out_frac = 11;
    end

    rx_q       = int32(rx_q(:).');
    coeffs_q15 = int32(coeffs_q15(:).');

    N        = numel(rx_q);
    num_taps = numel(coeffs_q15);

    decisions = zeros(1, N, 'int32');
    tap_sum_q = zeros(1, N, 'int32');

    % RTL reset state: all decision bits = 0
    decision_bits = zeros(1, num_taps, 'int32');

    shift_amt = 30 - out_frac;

    for k = 1:N
        acc = int64(0);

        % Tap bank MAC
        for i = 1:num_taps
            if decision_bits(i) ~= 0
                dec_val = int32(32767);   % +0x7FFF
            else
                dec_val = int32(-32768);  % -0x8000
            end
            acc = acc + int64(dec_val) * int64(coeffs_q15(i));
        end

        tap_sum = int32(bitshift(acc, -shift_amt));
        tap_sum_q(k) = tap_sum;

        % Saturating subtractor (int16 bounds)
        sub = rx_q(k) - tap_sum;
        if sub > 32767
            eq = int32(32767);
        elseif sub < -32768
            eq = int32(-32768);
        else
            eq = int32(sub);
        end

        % Slicer: decision=1 for eq >= 0, else 0
        if eq >= 0
            d = int32(1);
            decision_bits = [int32(1), decision_bits(1:end-1)];
        else
            d = int32(-1);
            decision_bits = [int32(0), decision_bits(1:end-1)];
        end
        decisions(k) = d;
    end

    decisions = double(decisions);
    tap_sum_q = double(tap_sum_q);
end
