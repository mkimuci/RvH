function RvHexptCleanup(expt)

    %% ----------------------- Input Validation -----------------------
    if nargin < 1
        error('Not enough inputs. Are you running the main code?');
    end

    %% ----------------------- Save expt Structure ------------------------
    try
        exptMatFilename = sprintf('RvHexpt%s.mat', expt.participantID);
        exptMatFilePath = fullfile(expt.logDir, exptMatFilename);
        
        % Save the expt structure
        save(exptMatFilePath, 'expt');
        fprintf('Experiment structure saved: %s\n', exptMatFilePath);
    catch ME
        warning('Experiment:SaveExptFailed', ...
            'Failed to save expt structure: %s', ME.message);
    end

    %% ----------------------- Display End of Experiment Message ----------
    try
        endExpText = 'Experiment completed.\n\nThank you!';
        DrawFormattedText(expt.window, endExpText, ...
            'center', 'center', expt.white);
        Screen('Flip', expt.window);
        WaitSecs(3);
    catch ME
        warning('Experiment:EndMessageFailed', ...
            'Error displaying end of experiment message: %s', ME.message);
    end

    %% ----------------------- Cleanup ------------------------------------
    try
        fclose(expt.CSVoutput);
        Screen('CloseAll');
    catch ME
        warning('Experiment:CleanupFailed', ...
            'Error during cleanup: %s', ME.message);
    end

    %% ----------------------- Final Message ------------------------------
    disp('Experiment saved and system cleand up.');
end
