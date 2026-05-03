function ber = ber_measure(bits, decisions)
% BER_MEASURE  Compute Bit Error Rate between original bits and decisions.
%
%   ber = ber_measure(bits, decisions)
%
%   bits      : 1×N original transmitted symbols (+1/-1)
%   decisions : 1×N received hard decisions   (+1/-1)
%   ber       : scalar BER (0 → 1)
%
%   Both vectors must be the same length.  Any length mismatch is an error.

    % Force row-vector shape to avoid implicit expansion (1xN vs Nx1).
    bits      = bits(:).';
    decisions = decisions(:).';

    if length(bits) ~= length(decisions)
        error('ber_measure: bits and decisions must be the same length.');
    end

    errors = sum(bits ~= decisions);
    ber    = errors / length(bits);
end
