function choice = RvHexptRetry(expt, currentBlock)
% RvHexptRetry displays an on-screen prompt for an aborted block and
% returns the experimenter's choice:
%   1: Re-run the aborted block
%   2: Move on to the next block
%   3: Abort the whole experiment

fprintf(['Block %d of %d aborted!\n' ...
    'Choose an option:\n' ...
    '  Press 1: Re-run the aborted block %d\n' ...
    '  Press 2: Move on to the next block %d\n' ...
    '  Press 3: Abort the whole experiment\n'], ...
    currentBlock, expt.nRuns, currentBlock, currentBlock+1);

% Wait for a valid key press (1, 2, or 3)
choice = [];
while isempty(choice)
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown
        if keyCode(KbName('1!'))
            choice = 1;
        elseif keyCode(KbName('2@'))
            choice = 2;
        elseif keyCode(KbName('3#'))
            choice = 3;
        end
    end
    WaitSecs(0.01); % Avoid busy waiting
end
KbReleaseWait;  % Wait until all keys are released
end
