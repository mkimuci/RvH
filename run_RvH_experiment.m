function run_RvH_experiment(participantID)
    % run_RvH_experiment
    % -------------------
    % Runs an experiment session using a pre-generated paradigm matrix.
    %
    % Parameters:
    %   participantID (string, optional): Participant ID, e.g., '001'.
    %   - If not provided, prompts the user.
    %   - Defaults to '000' if no input is provided.
    addpath(genpath("C:\Users\mkkim11\RvH_0124"));

    %% ----------------------- Parameter Handling -------------------------
    if nargin < 1
        prompt = 'Enter Participant ID (default: 000): ';
        participantID = input(prompt, 's');
        if isempty(participantID)
            participantID = '000';
            disp('No Participant ID entered. Using default: 000');
        else
            disp(['Participant ID set to: ' participantID]);
        end
    end

    %% ----------------------- Initialization -----------------------------
    try
        expt = run_RvH_initialize(participantID);
    catch ME
        error('Initialization failed: %s', ME.message);
    end

    %% ----------------------- Main Experiment Loop -----------------------
    try
        for iRun = 1:expt.nRuns
            blockSuccess = run_RvH_block(expt, iRun, 'main');
            if ~blockSuccess
                expt.reRun = [expt.reRun, iRun]; %#ok<AGROW>
            end
        end

        %% ----------------------- Rerun Blocks if Needed ---------------------
        if ~isempty(expt.reRun)
            disp('Blocks marked for rerun. Restarting blocks...');
            for rerunBlock = unique(expt.reRun)
                blockSuccess = run_RvH_block(expt, rerunBlock, 'rerun');
                if ~blockSuccess
                    disp(['Rerun block ' num2str(rerunBlock) ' failed. ' ...
                        'Please check manually.']);
                end
            end
        end

    catch ME
        % Handle the abort gracefully
        sca;
        disp(ME.message);  % Display the error message to the user
        run_RvH_finalize(expt);  % Finalize the experiment (e.g., save data, close screens)
        fprintf('Experiment terminated: %s\n', ME.message);
        return;  % Exit the function to prevent further execution
    end

    %% ----------------------- Finalize Experiment -----------------------
    run_RvH_finalize(expt);
    disp('Experiment successfully completed.');
end
