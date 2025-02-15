function expt = RvHexptSetup()

    %% ----------------------- MATLAB Initialization ----------------------
    clc; close all; sca;
    disp('Welcome to the RvH experiment!');
    datetimeNow = datetime('now', 'Format', 'yyyy-MM-dd''T''HH-mm-ss-SSS');
    fprintf('Current time is %s\n', char(datetimeNow));
    DisableKeysForKbCheck([]);

    % Operating system check
    disp('Checking Operating System...');
    if ismac
        paths.slashChar = '/';
        fprintf('macOS detected. Sync tests are disabled.\n');
        Screen('Preference', 'Verbosity', 0);
        Screen('Preference', 'SkipSyncTests', 1);
        Screen('Preference', 'VisualDebugLevel', 0);
    elseif ispc
        paths.slashChar = '\';
        fprintf('Windows detected. Sync tests are enabled.\n');
        Screen('Preference', 'Verbosity', 0);
        Screen('Preference', 'SkipSyncTests', 0);
    else
        error('Unsupported operating system!');
    end

    %% ----------------------- Participant ID Input -----------------------
    bValidID = false;
    while ~bValidID
        participantID = input('Enter Participant ID (default=00): ', 's');
        participantID = regexprep(participantID, '\s+', '');
        
        if isempty(participantID)
            participantID = '00';
            bValidID = true;
            disp('No Participant ID entered. Using default: 00');
        elseif all(isstrprop(participantID, 'alphanum'))
            bValidID = true;
            disp(['Participant ID set to: ' participantID]);
        else
            disp('Participant ID must be alphanumeric. Please try again.');
        end
    end

    %% ----------------------- Directory Setup ----------------------------
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(genpath(scriptDir));
    cd(scriptDir);

    stimuliDir = ['.' paths.slashChar 'stimuli' paths.slashChar];
    imgDir = [stimuliDir 'visual' paths.slashChar];
    audioDir = [stimuliDir 'audio' paths.slashChar];

    %% ----------------------- Setup Logging ------------------------------
    logDir = ['.' paths.slashChar 'logs' paths.slashChar];
    if ~exist(logDir, 'dir'), mkdir(logDir); end

    logFilename = sprintf('log_RvH_%s_%s.csv', ...
        participantID, char(datetimeNow));
    logFilePath = fullfile(logDir, logFilename);

    matrixDir = [logDir 'matrix' paths.slashChar];
    if ~exist(matrixDir, 'dir'), mkdir(matrixDir); end

    try
        CSVoutput = fopen(logFilePath, 'w');
        if CSVoutput == -1
            error('Failed to open log file for writing.');
        end
        fprintf(CSVoutput, ...
            ['condition,' ...
            'stimuli,' ...
            'onset_trial,' ...
            'onset_cross,' ...
            'offset,' ...
            'duration_trial,' ...
            'duration_cross\n']);
    catch ME
        error('Error setting up logging: %s', ME.message);
    end

    %% ----------------------- Experiment Parameters ----------------------    
    % Equipment-specific parameters (set for UCI FIBRE)
    amplifyVolume = 1;            % Volume amplification factor
    imgScaleFactor = 0.70;        % Image scaling factor
    fontSize = 72;

    % Experiment parameters
    Instructions = 'Preparing the experiment\n\nPlease wait...';
    InstructionWaitTime = 3;
    
    timing.countdown = 5.0;
    timing.T_a = 0.0;
    timing.T_b = 2.0;
    timing.T_c = 10.0;
    timing.minCross = 3.0;
    timing.maxCross = 6.0;
    timing.audioDur = 2.0;
    
    %% ----------------------- Load Task Images ---------------------------
    try
        iconCon = imread([imgDir 'ctr.png']);
        iconLis = imread([imgDir 'lis.png']);
        iconRep = imread([imgDir 'rep.png']);
        iconHum = imread([imgDir 'rep.png']);  % Same as Repetition!
    catch ME
        error('Error loading task images: %s', ME.message);
    end

    %% ----------------------- Load or Generate Paradigm Matrix -----------
    paradigmFileName = sprintf('paradigm_RvH_%s.mat', participantID);
    paradigmFilePath = fullfile(matrixDir, paradigmFileName);
    
    % If paradigm doesn't exist, generate a new one
    if ~exist(paradigmFilePath, 'file')
        disp('Paradigm file not found. Generating a new paradigm...');
        try
            % Generate a new paradigm (console output suppressed)
            [~, matFileName] = generate_RvH_pardigm(false);
            movefile(matFileName, paradigmFilePath);
            disp(['Paradigm file generated and saved: ' paradigmFilePath]);
        catch ME
            error('Failed to generate paradigm file: %s', ME.message);
        end
    end

    % Load the paradigm matrix
    try
        load(paradigmFilePath, 'allRuns', 'nRuns', 'trialsPerRun');
        disp(['Paradigm file loaded: ' paradigmFilePath]);
    catch ME
        error('Error loading paradigm file: %s', ME.message);
    end

    %% ----------------------- Setup Psychtoolbox Screen -----------------------
    try
        PsychDefaultSetup(2);
        screenNum = max(Screen('Screens'));
        white = WhiteIndex(screenNum);
        black = BlackIndex(screenNum);

        if ismac
            [window, ~] = PsychImaging('OpenWindow', screenNum, black, ...
                [0, 0, 800, 600]);  % Debugging window
        elseif ispc
            [window, ~] = PsychImaging('OpenWindow', screenNum, black);
        else
            error('Unsupported operating system.');
        end

        Screen('TextSize', window, fontSize);
        Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

        topPriorityLevel = MaxPriority(window);
        Priority(topPriorityLevel);
    catch ME
        error('Error setting up Psychtoolbox: %s', ME.message);
    end

    %% ----------------------- Pre-load Textures -----------------------
    fprintf('Pre-loading textures...\n');
    try
        textures.iconCon   = Screen('MakeTexture', window, imresize(iconCon, imgScaleFactor));
        textures.iconLis   = Screen('MakeTexture', window, imresize(iconLis, imgScaleFactor));
        textures.iconRep   = Screen('MakeTexture', window, imresize(iconRep, imgScaleFactor));
        textures.iconHum   = Screen('MakeTexture', window, imresize(iconHum, imgScaleFactor));
    catch ME
        error('Error pre-loading textures: %s', ME.message);
    end
    fprintf('Textures pre-loaded successfully.\n');


    %% ----------------------- Define Key Bindings -----------------------
    % Define key codes for triggers and controls
    keys.trigger = KbName('5%');      % MRI trigger key
    keys.escape = KbName('ESCAPE');  % Abort experiment
    keys.proceed = KbName('6^');   % Proceed to next run
    
    %% ----------------------- Display Instructions -----------------------
    try
        DrawFormattedText(window, Instructions, 'center', 'center', white);
        Screen('Flip', window);
        WaitSecs(InstructionWaitTime);
        Screen('Flip', window);
    catch ME
        error('Error displaying instructions: %s', ME.message);
    end
    
    %% ----------------------- Initialize Audio Recorder -----------------------
    % Ensure recording directory exists
    expt.recordingDir = ['.' paths.slashChar 'acousticdata' paths.slashChar];
    if ~isfolder(expt.recordingDir)
        mkdir(expt.recordingDir);
    end
    
    % Initialize the audiorecorder object
    fs = 44100;               % Sampling frequency
    nBits = 16;               % Bits per sample
    nChannels = 1;            % Mono recording
    recObj = audiorecorder(fs, nBits, nChannels);
    expt.recObj = recObj;
    
    %% ----------------------- Create the expt Structure ------------------
    expt.scriptDir           = scriptDir;
    expt.logDir              = logDir;
    expt.datetime            = datetimeNow;
    expt.participantID       = participantID;
    expt.paths               = paths;
    expt.imgScaleFactor      = imgScaleFactor;
    expt.fontSize            = fontSize;
    expt.window              = window;
    expt.textures            = textures;
    expt.keys                = keys;
    expt.audioDir            = audioDir;
    expt.amplifyVolume       = amplifyVolume;
    expt.CSVoutput           = CSVoutput;
    expt.white               = white;
    expt.allRuns             = allRuns;
    expt.nRuns               = nRuns;
    expt.trialsPerRun        = trialsPerRun;
    expt.logFilePath         = logFilePath;
    expt.black               = black;
    expt.screenNum           = screenNum;
    expt.Instructions        = Instructions;
    expt.InstructionWaitTime = InstructionWaitTime;
    expt.iRun = 0;
    expt.currentRunType = 'main';
    expt.timing = timing;

    %% ----------------------- Save expt Structure ------------------------
    try
        % Generate a timestamp for the filename
        exptMatFilename = sprintf('RvHexpt%s.mat', ...
            expt.participantID);
        exptMatFilePath = fullfile(logDir, exptMatFilename);
        
        % Save the expt structure
        save(exptMatFilePath, 'expt');
        fprintf('Experiment structure saved as: %s\n', exptMatFilePath);
    catch ME
        warning('Experiment:SaveExptFailed', ...
            'Failed to save expt structure: %s', ME.message);
    end

    fprintf('Initialization complete!\n');
end
