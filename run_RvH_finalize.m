function run_RvH_finalize(expt)
    % run_RvH_finalize
    % -----------------
    % Handles the end-of-experiment procedures, including displaying the end message,
    % saving the expt structure, and performing cleanup tasks.
    %
    % Parameters:
    %   expt (struct): Structure containing all experiment-related variables.
    %
    % Returns:
    %   None

    %% ----------------------- Save expt Structure ------------------------
    try
        exptMatFilename = sprintf('expt_RvH_%s.mat', ...
            expt.participantID);
        exptMatFilePath = fullfile(expt.paths.slashChar, ...
            'logs', exptMatFilename);
        
        % Save the expt structure
        save(exptMatFilePath, 'expt');
        fprintf('Experiment structure saved as: %s\n', exptMatFilePath);
    catch ME
        warning('Experiment:SaveExptFailed', ...
            'Failed to save expt structure: %s', ME.message);
    end

    %% ----------------------- Display End of Experiment Message ----------
    try
        endExpText = 'Experiment completed.\nThank you!';
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
        sca;
    catch ME
        warning('Experiment:CleanupFailed', ...
            'Error during cleanup: %s', ME.message);
    end

    %% ----------------------- Final Message ------------------------------
    disp('Experiment saved and system cleand up.');
end
