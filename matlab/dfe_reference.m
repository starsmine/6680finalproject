function [decisions, tap_history] = dfe_reference(rx, coeffs)
% DFE_REFERENCE  Floating-point Decision Feedback Equalizer reference model.
%
%   [decisions, tap_history] = dfe_reference(rx, coeffs)
%
%   rx          : 1×N received signal (after channel + noise)
%   coeffs      : 1×NUM_TAPS DFE feedback tap coefficients
%                 (applied to past hard decisions)
%   decisions   : 1×N hard decisions (+1/-1)
%   tap_history : N×NUM_TAPS matrix — feedback tap values at each step
%                 (useful for debugging convergence)
%
%   Algorithm (per sample k):
%     feedback(k) = sum( coeffs .* past_decisions )
%     equalized(k) = rx(k) - feedback(k)
%     decision(k)  = sign( equalized(k) )   (ties → +1)

    N        = length(rx);
    num_taps = length(coeffs);

    decisions   = zeros(1, N);
    tap_history = zeros(N, num_taps);

    % Circular buffer of past decisions, initialised to 0
    past = zeros(1, num_taps);

    for k = 1:N
        feedback    = coeffs * past.';          % dot product
        equalized   = rx(k) - feedback;
        d           = sign(equalized);
        if d == 0; d = 1; end                   % resolve tie

        decisions(k)   = d;
        tap_history(k,:) = past;

        % Shift buffer: oldest entry drops off, newest decision enters
        past = [d, past(1:end-1)];
    end
end
