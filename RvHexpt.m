function RvHexpt()
% RvHexpt - Main function for the Repetition vs Humming experiment.
% This function initializes, executes, and finalizes the RvH experiment.
% To run this experiment, type "RvHexpt" in the console with no arguments.
% Minkyu Kim, Auditory & Language Neuroscience Lab, UC Irvine, 02/14/2025.
% Thanks to Jonathan Venezia and Oren Poliva.
%
% Experiment Flow:
%   1. Initialization: Set up experiment parameters and resources.
%   2. Main Experiment Loop: Execute each run with retry/abort options.
%   3. Finalization: Clean up and release resources.

    %% ----------------------- 1. Initialization --------------------------
    try        
        expt = RvHexptSetup();
    catch ME
        error('Initialization failed: %s', ME.message);
    end

    %% ----------------------- 2. Main Experiment Loop --------------------
    for iRun = 1:expt.nRuns
        expt.iRun = iRun;
        expt.currentRunType = 'main';  % Default run type.
        while ~RvHexptRun(expt)  % Execute a run
            switch RvHexptRetry(expt)
                case 1  % Re-run the aborted block using 'rerun'
                    expt.currentRunType = 'rerun';
                case 2  % Move on to the next block.
                    break;
                case 3  % Abort the experiment.
                    RvHexptCleanup(expt);
                    fprintf('Experiment aborted by experimenter.\n');
                    return;
            end
        end
    end

    %% ----------------------- 3. Finalize Experiment ---------------------
    RvHexptCleanup(expt);
    disp('Experiment successfully completed.');
end