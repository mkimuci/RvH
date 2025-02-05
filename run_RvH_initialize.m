function expt = run_RvH_initialize(participantID)
    % run_RvH_initialize
    % -------------------
    % Initializes the experiment by handling parameters, setting up directories,
    % loading resources, configuring Psychtoolbox, and preparing logging.
    %
    % Parameters:
    %   participantID (string, optional): Participant ID, e.g., '001'.
    %   - If not provided, prompts the user.
    %   - Defaults to '000' if no input is provided.
    %
    % Returns:
    %   expt (struct): Structure containing all experiment-related variables.

    %% ----------------------- Initialization -----------------------
    clc; close all; sca;

    % Experiment-specific parameters
    amplifyVolume = 1;            % Volume amplification factor
    imgScaleFactor = 0.50;        % Image scaling factor
    fontSize = 60;

    % Operating system check
    fprintf('Checking Operating System...\n');
    if ismac || ispc
        paths.slashChar = '/';
        Screen('Preference', 'Verbosity', 0);
        Screen('Preference', 'SkipSyncTests',1);
        Screen('Preference', 'VisualDebugLevel',0);
        fprintf('macOS detected. Sync tests are disabled.\n');
    % elseif ispc
    %     paths.slashChar = '\';
    %     Screen('Preference', 'SkipSyncTests', 0);
    %     fprintf('Windows detected. Sync tests are enabled.\n');
    else
        error('Unsupported operating system. Supports macOS and Windows.');
    end

    % Experiment parameters
    Instructions = 'Preparing...';
    InstructionWaitTime = 3;

    %% ----------------------- Directory Setup -----------------------
    scriptDir = fileparts(mfilename('fullpath'));  % More reliable than 'which'
    cd(scriptDir);

    stimuliDir = ['.' paths.slashChar 'stimuli' paths.slashChar];
    imgDir = [stimuliDir 'visual' paths.slashChar];
    audioDir = [stimuliDir 'audio' paths.slashChar];
    matrixDir = [stimuliDir 'matrix' paths.slashChar];

    if ~exist(matrixDir, 'dir')
        mkdir(matrixDir);
    end

    %% ----------------------- Load Task Images -----------------------
    try
        iconCon = imread([imgDir 'ctr.png']);
        iconLis = imread([imgDir 'lis.png']);
        iconRep = imread([imgDir 'rep.png']);
        iconHum = imread([imgDir 'rep.png']);  % Same as Repetition!
        [iconStart, ~, alpha] = imread([imgDir 'start.png']);
    catch ME
        error('Error loading task images: %s', ME.message);
    end

    %% ----------------------- Load or Generate Paradigm Matrix -----------------------
    paradigmFileName = fullfile(matrixDir, sprintf('paradigm_RvH_%s.mat', participantID));

    if ~exist(paradigmFileName, 'file')
        disp('Paradigm file not found. Generating a new one...');
        [~, matFileName] = generate_RvH_pardigm(false);  % Suppress console output

        sourceFile = matFileName;
        paradigmFileName = fullfile(matrixDir, sprintf('paradigm_RvH_%s.mat', participantID));

        try
            movefile(sourceFile, paradigmFileName);
            disp(['Paradigm file generated and saved as: ' paradigmFileName]);
        catch ME
            error('Failed to move paradigm file: %s', ME.message);
        end
    end

    try
        load(paradigmFileName, 'allRuns', 'nRuns', 'trialsPerRun');
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
            winRect = [100, 300, 900, 900];
            [window, ~] = PsychImaging('OpenWindow', screenNum, black, winRect);
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
        textures.iconStart = Screen('MakeTexture', window, imresize(iconStart, imgScaleFactor));
    catch ME
        error('Error pre-loading textures: %s', ME.message);
    end
    fprintf('Textures pre-loaded successfully.\n');

    %% ----------------------- Setup Logging -----------------------
    currentTime = datetime('now', 'Format', 'yyyy-MM-dd_HHmmss');
    filenameTimestamp = char(currentTime);
    logDir = ['.' paths.slashChar 'logs' paths.slashChar];

    if ~exist(logDir, 'dir')
        mkdir(logDir);
    end

    logFilename = sprintf('log_RvH_%s_%s.csv', participantID, filenameTimestamp);
    logFilePath = fullfile(logDir, logFilename);

    try
        CSVoutput = fopen(logFilePath, 'w');
        if CSVoutput == -1
            error('Failed to open log file for writing.');
        end
        fprintf(CSVoutput, 'condition,stimuli,onset_trial,onset_cross,offset,duration_trial,duration_cross\n');
    catch ME
        error('Error setting up logging: %s', ME.message);
    end

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
    
    %% ----------------------- Create the expt Structure -----------------------
    expt.datetime            = char(currentTime);
    expt.participantID       = participantID;
    expt.paths               = paths;
    expt.imgScaleFactor      = imgScaleFactor;
    expt.fontSize            = fontSize;
    expt.window              = window;
    expt.textures            = textures;
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

    % Initialize Rerun Blocks List
    expt.reRun = [];

    %% ----------------------- Save expt Structure ------------------------
    try
        % Generate a timestamp for the filename
        exptMatFilename = sprintf('expt_RvH_%s.mat', ...
            expt.participantID);
        exptMatFilePath = fullfile(logDir, exptMatFilename);
        
        % Save the expt structure
        save(exptMatFilePath, 'expt');
        fprintf('Experiment structure saved as: %s\n', exptMatFilePath);
    catch ME
        warning('Experiment:SaveExptFailed', ...
            'Failed to save expt structure: %s', ME.message);
    end

    fprintf('Initialization complete.\n');
end
