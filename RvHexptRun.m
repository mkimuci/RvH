function runSuccess = RvHexptRun(expt)

    %% ----------------------- Input Validation -----------------------
    if nargin < 1
        error('Not enough inputs. Are you running the main code?');
    end

    %% ----------------------- Run Initialization -----------------------
    runSuccess = true;

    % Prepare text for this run
    expt.roundText = sprintf('Round %d of %d', expt.iRun, expt.nRuns);
    if strcmp(expt.currentRunType, 'rerun')
        expt.roundText = ['Rerun: ' expt.roundText];
    end

    T_a = expt.timing.T_a;                     % e.g., 0.0
    T_b = expt.timing.T_b;                     % e.g., 2.0
    T_c = expt.timing.T_c;                     % e.g., 10.0
    minCross     = expt.timing.minCross;       % e.g., 3.0
    maxCross     = expt.timing.maxCross;       % e.g., 6.0
    audioDur     = expt.timing.audioDur;       % e.g., 2.0

    %% ----------------------- Start run --------------------------------
    try
        % Display wait message
        DrawFormattedText(expt.window, ...
            ['Please wait\n\n' expt.roundText ' will soon begin'], ...
             'center', 'center', expt.white);
        Screen('Flip', expt.window);

        % Wait for the MRI trigger key to start the run
        fprintf('Waiting for MRI trigger to start %s...\n', expt.roundText);
        DisableKeysForKbCheck([]);                  % Enable all keys
        KbTriggerWait(expt.keys.trigger);           % Wait for MRI trigger
        DisableKeysForKbCheck(expt.keys.trigger);   % Disable that key

        runStartTime = GetSecs;
        Screen('Flip', expt.window);

        if runCountdown(expt); runSuccess = false; return; end
        Screen('Flip', expt.window);  % Clear after countdown

        %% ----------------------- Retrieve Trials for This Run -----------
        visual = expt.allRuns(expt.iRun).visual;
        audio = expt.allRuns(expt.iRun).audio;

        %% ----------------------- Trials Loop ----------------------------
        for t = 1:expt.trialsPerRun
            % Basic trial info
            trialType    = visual{t};
            stimulusBase = audio{t};
            wavFilename  = [stimulusBase '.wav'];

            fprintf('Run %d/%d | Trial %d/%d | ', ...
                expt.iRun, expt.nRuns, t, expt.trialsPerRun);
            fprintf('Type: %s | Audio File: %s\n', ...
                trialType, wavFilename);

            % Compute total durations for this trial
            T_trial = T_a + T_b + T_c;
            T_cross = minCross + (maxCross - minCross)*rand;  % random cross

            %% ----------------------- Display Trial Type Icon ------------
            loadVisual(trialType, expt);
            
            % Wait T_a
            if WaitSecsEsc(T_a, expt); runSuccess = false; return; end
            
            %% ----------------------- Load and Play Audio Stimulus -------
            [sounds, freq, loadOK] = loadAudio(stimulusBase, trialType, audioDur, T_trial, expt);
            if ~loadOK, continue; end  % skip trial if loading failed
            
            try
                sound(sounds, freq);
            catch ME
                warning('AudioPlayback:Failed', ...
                    'Failed to play audio: %s. Skipping trial...', ME.message);
                continue;
            end

            % Trial onset (relative to run start)
            onset_trial = GetSecs - runStartTime;

            %% ----------------------- Start Recording -----------------------
            try
                record(expt.recObj);
            catch ME
                warning('AudioRecording:Failed', ...
                    'Failed to start recording: %s. Continuing without...', ...
                    ME.message);
            end

            % Wait T_b + T_c
            if WaitSecsEsc(T_b + T_c, expt); runSuccess = false; return; end

            %% ----------------------- Stop Recording -----------------------
            try
                stop(expt.recObj);
                audioData = getaudiodata(expt.recObj);

                % Save recording in separate helper
                saveRecordedAudio(expt, expt.iRun, t, trialType, wavFilename, audioData);
            catch ME
                warning('AudioRecording:Failed', ...
                    'Failed to save recording: %s. Continuing...', ...
                    ME.message);
            end

            %% ----------------------- Display Fixation Cross -----------------------
            DrawFormattedText(expt.window, '+', 'center', 'center', expt.white);
            Screen('Flip', expt.window);
            onset_cross = GetSecs - runStartTime;

            if WaitSecsEsc(T_cross, expt); runSuccess = false; return; end

            %% ----------------------- Log the Event -----------------------
            offset = GetSecs - runStartTime;
            fprintf(expt.CSVoutput, '%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f\n', ...
                trialType, stimulusBase, onset_trial, onset_cross, ...
                offset, T_trial, T_cross);
        end % end trials loop

        %% ----------------------- End of Run Message -----------------------
        if strcmp(expt.currentRunType, 'main')
            endRunText = sprintf('End of run %d.\n\nTake a short rest.', expt.iRun);
        else
            endRunText = sprintf('End of rerun run %d.\n\nProceeding...', expt.iRun);
        end
        DrawFormattedText(expt.window, endRunText, 'center', 'center', expt.white);
        Screen('Flip', expt.window);
        fprintf('%s completed.\n\nGreat job!', expt.roundText);
        WaitSecs(2);

        % Wait for "proceed" key
        while true
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(expt.keys.proceed)
                break;
            end
        end

    catch ME
        fprintf('Error in RvHexptRun: %s\n', ME.message);
        runSuccess = false;
        rethrow(ME);
    end

end


%% ----------------------------------------------------------
%  LOCAL HELPER FUNCTIONS
%% ----------------------------------------------------------
function abortDuringTrial = WaitSecsEsc(waitTime, expt)
    abortDuringTrial = false;
    startTime = GetSecs;
    
    while (GetSecs - startTime) < waitTime
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(expt.keys.escape)
            abortText = [expt.roundText ' aborted!\n\nPlease wait.'];
            DrawFormattedText(expt.window, abortText, ...
                'center', 'center', expt.white);
            Screen('Flip', expt.window);
            WaitSecs(1);
            abortDuringTrial = true;
            return;  % Return immediately
        end
        WaitSecs(0.01);  % Small pause so we don't hog CPU
    end
end

function abortDuringCountdown = runCountdown(expt)
    abortDuringCountdown = false;
    countdownSeconds = expt.timing.countdown;
    for secLeft = countdownSeconds:-1:1
        countdownText = sprintf('%s\n\nStarting in %d...', ...
            expt.roundText, secLeft);
        DrawFormattedText(expt.window, countdownText, ...
            'center', 'center', expt.white);
        Screen('Flip', expt.window);

        % Use your WaitSecsEsc(...) function to allow ESC checks
        if WaitSecsEsc(1, expt)
            sprintf('%s aborted during countdown.', expt.roundText);
            abortDuringCountdown = true;
            return;
        end
    end
end


function loadVisual(trialType, expt)
    switch trialType
        case 'con'
            currentTexture = expt.textures.iconCon;
        case 'lis'
            currentTexture = expt.textures.iconLis;
        case 'rep'
            currentTexture = expt.textures.iconRep;
        case 'hum'
            currentTexture = expt.textures.iconHum;
        otherwise
            currentTexture = expt.textures.iconCon;  % fallback
    end
    Screen('DrawTexture', expt.window, currentTexture);
    Screen('Flip', expt.window);
end

function [sounds, freq, loadOK] = loadAudio(stimulusBase, trialType, audioDur, T_trial, expt)
    soundFile = fullfile(expt.audioDir, [stimulusBase, '.wav']);

    sounds = [];
    freq = [];
    loadOK = false;

    if ~exist(soundFile, 'file')
        warning('Sound file not found: %s. Skipping trial.', soundFile);
        return;  % Return empty
    end

    % Read the file
    [sounds, freq] = audioread(soundFile);

    % Pad/truncate to exactly 'audioDur'
    paddedSamples = round(audioDur * freq);
    [numSamples, numChannels] = size(sounds);

    if numSamples < paddedSamples
        sounds = [sounds; zeros(paddedSamples - numSamples, numChannels)];
    elseif numSamples > paddedSamples
        sounds = sounds(1:paddedSamples, :);
    end

    % Repeat for 'lis' trials
    if strcmp(trialType, 'lis')
        audioRep = floor(T_trial / audioDur) + 1;
        sounds = repmat(sounds, audioRep, 1);
    end

    % Apply volume amplification
    sounds = sounds * expt.amplifyVolume;

    loadOK = true;
end

function saveRecordedAudio(expt, iRun, t, trialType, wavFilename, audioData)
    % Stop recording and save the recorded audio to a WAV file
    filename = sprintf('RvH_%s_%d_%02d_%s_%s', ...
                       expt.participantID, iRun, t, trialType, wavFilename);

    fullFilePath = fullfile(expt.recordingDir, filename);

    % Save as WAV
    audiowrite(fullFilePath, audioData, expt.recObj.SampleRate);
    fprintf('Trial ended. Recorded audio saved to %s\n', fullFilePath);
end
