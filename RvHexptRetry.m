function choice = RvHexptRetry(expt)
    % RvHexptRetry displays an on-screen prompt for an aborted run and
    % returns the experimenter's choice

    %% ----------------------- Input Validation -----------------------
    if nargin < 1
        error('Not enough inputs. Are you running the main code?');
    end

    fprintf(['Run %d of %d aborted!\n' ...
        'Choose an option:\n' ...
        '  Press 1: Re-run the aborted run (Run %d)\n' ...
        '  Press 2: Move on to the next run (Run %d)\n' ...
        '  Press 3: Abort the whole experiment\n'], ...
        expt.iRun, expt.nRuns, expt.iRun, expt.iRun+1);
    
    % Precompute key codes for faster checking.
    key1 = KbName('1!');
    key2 = KbName('2@');
    key3 = KbName('3#');
    
    % Wait for a valid key press (1, 2, or 3).
    choice = [];
    while isempty(choice)
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(key1)
                choice = 1;
            elseif keyCode(key2)
                choice = 2;
            elseif keyCode(key3)
                choice = 3;
            end
        end
        WaitSecs(0.01);  % Avoid busy waiting.
    end
    KbReleaseWait;  % Wait until all keys are released before returning.
end