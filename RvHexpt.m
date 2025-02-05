function RvHexpt()

    %% ----------------------- Initialization -----------------------------
    try        
        expt = RvHexptSetup();
    catch ME
        error('Initialization failed: %s', ME.message);
    end

    %% ----------------------- Main Experiment Loop -----------------------
    iRun = 1;
    currentRunType = 'main';  % Default run type.
    while iRun <= expt.nRuns
        if RvHexptRun(expt, iRun, currentRunType)
            % Block succeeded; proceed to the next block.
            iRun = iRun + 1;
            currentRunType = 'main';
        else
            % Block failed; get the experimenter's choice.
            switch RvHexptRetry(expt, iRun)
                case 1  % Re-run the aborted block using 'rerun'
                    currentRunType = 'rerun';
                case 2  % Move on to the next block.
                    iRun = iRun + 1;
                    currentRunType = 'main';
                case 3  % Abort the experiment.
                    RvHexptCleanup(expt);
                    fprintf('Experiment aborted by experimenter.\n');
                    return;
            end
        end
    end

    %% ----------------------- Finalize Experiment ------------------------
    RvHexptCleanup(expt);
    disp('Experiment successfully completed.');
end
