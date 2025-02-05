function runSuccess = RvHexptRun(expt, runNumber, runType)

    %% ----------------------- Input Validation -----------------------
    if nargin < 3
        error('Not enough inputs. Are you running the main code?');
    end

    %% ----------------------- run Initialization -----------------------
    % Initialize run success flag
    runSuccess = true;

    % Determine run type for messaging
    sessionText = sprintf('Session %d of %d', runNumber, expt.nRuns);
    if strcmp(runType, 'rerun')
        sessionText = ['Rerun' sessionText];
    end

    %% ----------------------- Define Key Bindings -----------------------
    % Define key codes for triggers and controls
    triggerKey = KbName('5%');      % MRI trigger key
    escapeKey = KbName('ESCAPE');  % Abort experiment
    proceedKey = KbName('6^');   % Proceed to next run

    %% ----------------------- Start run --------------------------------
    try
        % Display wait message
        DrawFormattedText(expt.window, ['Please wait\n\n' ...
            sessionText ' will soon begin'], ...
            'center', 'center', expt.white);
        Screen('Flip', expt.window);

        % Wait for the MRI trigger key to start the run
        fprintf('Waiting for MRI trigger to start %s...\n', sessionText);
        DisableKeysForKbCheck([]);           % Enable all keys
        KbTriggerWait(triggerKey);           % Wait for the MRI trigger
        DisableKeysForKbCheck(triggerKey);   % Disable the trigger key

        runStartTime = GetSecs;  % Record the start time of the run
        Screen('Flip', expt.window);

        %% ----------------------- Countdown Before run Starts -----------------------
        countdown = 5;  % Countdown before experiment starts (seconds)
        for countdownStep = countdown:-1:1
            countdownText = sprintf([sessionText '\n\nStarting in %d...'], countdownStep);
            DrawFormattedText(expt.window, countdownText, 'center', 'center', expt.white);
            Screen('Flip', expt.window);  % Update the screen with countdown

            % ----------------- Add Escape Key Check Here -----------------
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(escapeKey)
                abortText = 'Session aborted!';
                DrawFormattedText(expt.window, abortText, 'center', 'center', expt.white);
                Screen('Flip', expt.window);
                WaitSecs(2);
                runSuccess = false;
                return;
            end
            % ---------------------------------------------------------------

            WaitSecs(1);  % Wait for 1 second
        end
        Screen('Flip', expt.window);
        WaitSecs(1);

        %% ----------------------- Retrieve Trials for Current run -----------------------
        visual = expt.allRuns(runNumber).visual;
        audio = expt.allRuns(runNumber).audio;

        %% ----------------------- Trials Loop -----------------------
        for t = 1:expt.trialsPerRun
            %% ----------------------- Trial Parameters -----------------------
            trialType = visual{t};
            stimulusBase = audio{t};
            wavFilename = [stimulusBase '.wav'];

            %% ----------------------- Check for Special Key Presses -----------------------
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(escapeKey)
                    runSuccess = false;
                    return;
                end
            end

            %% ----------------------- Trial Start Message -----------------------
            fprintf('%s | Trial %d/%d started. Type: %s, Audio File: %s\n', ...
                sessionText, t, expt.trialsPerRun, trialType, wavFilename);

            %% ----------------------- Define Timing Parameters -----------------------
            T_a = 0.0;                     % Initial delay before trial (seconds)
            T_b = 2.0;                     % Duration of the trial (seconds)
            T_c = 10.0;                    % Duration of the fixation cross (seconds)
            T_trial = T_a + T_b + T_c;     % Total duration of the trial
            T_cross = 0.5 + 4.0 * rand;    % Duration of the fixation cross

            audioDur = 2.0;                % Duration of each audio clip (seconds)
            audioRep = floor(T_trial / audioDur);  % Repetitions for 'lis' trials

            %% ----------------------- Select and Display Trial Type Icon -----------------------
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
                    currentTexture = expt.textures.iconCon;  % Fallback to 'con' if undefined
            end

            % Display the texture without trial info
            Screen('DrawTexture', expt.window, currentTexture);
            Screen('Flip', expt.window);
            WaitSecs(T_a);  % Wait for initial delay

            %% ----------------------- Load and Play Audio Stimulus -----------------------
            soundFile = fullfile(expt.audioDir, wavFilename);

            % Check if the audio file exists
            if ~exist(soundFile, 'file')
                warning('Sound file not found: %s. Skipping trial.', soundFile);
                continue;  % Skip to the next trial
            end

            % Read the audio file
            [sounds, freq] = audioread(soundFile);

            % Ensure audio is exactly 'audioDur' seconds long
            paddedSamples = round(audioDur * freq);
            [numSamples, numChannels] = size(sounds);

            if numSamples < paddedSamples
                % Pad with zeros to reach 'audioDur' seconds
                sounds = [sounds; zeros(paddedSamples - numSamples, numChannels)];
            elseif numSamples > paddedSamples
                % Truncate to exactly 'audioDur' seconds
                sounds = sounds(1:paddedSamples, :);
            end

            if strcmp(trialType, 'lis')
                % For 'lis' trials, repeat the audio to fill trial duration
                sounds = repmat(sounds, audioRep, 1);
            end

            % Apply volume amplification
            sounds = sounds * expt.amplifyVolume;

            % Play the sound using MATLAB's built-in sound function
            try
                sound(sounds, freq);  % Play the audio stimulus
            catch ME
                warning('AudioPlayback:Failed', ...
                    'Failed to play audio: %s. Skipping...', ME.message);
                continue;  % Skip to the next trial
            end

            % Record onset time of the trial
            onset_trial = GetSecs - runStartTime;

            %% ----------------------- Start Recording -----------------------
            try
                record(expt.recObj);  % Start recording
            catch ME
                warning('AudioRecording:Failed', ...
                    'Failed to start recording: %s. Continuing without recording...', ME.message);
            end

            %% ----------------------- Wait for the Duration of the Trial -----------------------
            WaitSecs(T_trial);

            %% ----------------------- Stop Recording -----------------------
            try
                stop(expt.recObj);  % Stop recording
                audioData = getaudiodata(expt.recObj);  % Retrieve recorded data

                % Generate the filename with zero-padded trial number
                filename = sprintf('RvH_%s_%d_%02d_%s_%s', ...
                    expt.participantID, runNumber, t, ...
                    trialType, wavFilename);

                % Full path for the recording
                fullFilePath = fullfile(expt.recordingDir, filename);

                % Save the recorded audio to a WAV file
                audiowrite(fullFilePath, audioData, expt.recObj.SampleRate);
                fprintf(['Trial ended.' ...
                    ' Recorded audio saved to %s\n'], fullFilePath);
            catch ME
                warning('AudioRecording:Failed', ...
                    ['Trial ended. ' ...
                    'Failed to save recording: %s. ' ...
                    'Continuing...'], ME.message);
            end


            %% ----------------------- Display Fixation Cross -----------------------
            DrawFormattedText(expt.window, '+', 'center', 'center', expt.white);
            Screen('Flip', expt.window);
            onset_cross = GetSecs - runStartTime;  % Record onset of fixation
            WaitSecs(T_cross);  % Wait for fixation duration

            %% ----------------------- Record Event in Log -----------------------
            offset = GetSecs - runStartTime;  % Record offset time
            fprintf(expt.CSVoutput, '%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f\n', ...
                trialType, stimulusBase, onset_trial, onset_cross, ...
                offset, T_trial, T_cross);
        end  % End of trials loop

        %% ----------------------- End of run Message -----------------------
        if strcmp(runType, 'main')
            endRunText = sprintf(['End of session %d.\n\n' ...
                'Take a short rest.'], runNumber);
        else
            endRunText = sprintf(['End of rerun run %d.\n\n' ...
                'Proceeding...'], runNumber);
        end
        DrawFormattedText(expt.window, endRunText, 'center', 'center', expt.white);
        Screen('Flip', expt.window);
        fprintf('%s completed.\n', sessionText);
        WaitSecs(2);  % Short wait before proceeding
        
        while true
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(proceedKey)
                break;  % proceed to the next run
            end
        end

    catch ME
        % Handle any unexpected errors during the run
        fprintf('Error in RvHexptRun: %s\n', ME.message);
        runSuccess = false;
        % Re-throw the error to be caught by the outer function
        rethrow(ME);
    end

end
