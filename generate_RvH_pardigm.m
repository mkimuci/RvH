function [attempts, matFileName] = generate_RvH_pardigm(suppressOutput)
% generate_RvH_pardigm: Generates a single paradigm as previously defined.
% Now accepts a boolean argument suppressOutput:
%    If true, all console outputs (fprintf) are suppressed.
%    If false or not provided, outputs are displayed.
%
% Returns:
%    attempts      - Number of attempts made before success.
%    matFileName   - Name of the saved .mat file ('paradigm_RvH.mat')

if nargin < 1
    suppressOutput = false;
end

maxTime = 1; % 1 second time limit per attempt

Cvals = {'C1','C2','C3'};
Pvals = {'P1','P2','P3'};
Svals = {'S1','S2','S3','S4'};
Avals = {'A1','A2','A3','A4'};

bDummy = true;
nDummy = 1;
C_Dummy = Cvals{3}; 

[Ci, Pi] = ndgrid(1:numel(Cvals), 1:numel(Pvals));
conditions = arrayfun(@(c,p) [Cvals{c} Pvals{p}], ...
    Ci(:), Pi(:), 'UniformOutput', false);

nCon = numel(conditions);    % 9
nS = numel(Svals);           % 4
nA = numel(Avals);           % 4
nStimPerCond = nS*nA;        % 16

totalTrials = nCon * nStimPerCond; % 144
nRuns = 8;
trialsPerRun = totalTrials/nRuns;  % 18

% Calculate separate S and A constraints
baseS = trialsPerRun/nS;
baseA = trialsPerRun/nA;

S_minCount = floor(baseS * (1-0.3));
S_maxCount = floor(baseS * (1+0.3));
A_minCount = floor(baseA * (1-0.3));
A_maxCount = floor(baseA * (1+0.3));

C_maxSeq = 3;
P_maxSeq = 3;

possibleTrials = cell(nCon, nStimPerCond);
for c = 1:nCon
    idx = 1;
    for s = 1:nS
        for a = 1:nA
            possibleTrials{c, idx} = sprintf('%s-%s%s', ...
                conditions{c}, Svals{s}, Avals{a});
            idx = idx + 1;
        end
    end
end

S_count = zeros(nRuns, nS);
A_count = zeros(nRuns, nA);
runs = cell(nRuns, trialsPerRun);

outputFile = 'paradigm_RvH.mat';
attempts = 0;

while true
    attempts = attempts + 1;
    startTime = tic;

    % Shuffle each condition's trials for variability
    allTrials = possibleTrials;
    for c = 1:nCon
        allTrials(c,:) = allTrials(c, randperm(nStimPerCond));
    end

    state.conditions = conditions;
    state.Cvals = Cvals;
    state.Pvals = Pvals;
    state.Svals = Svals;
    state.Avals = Avals;
    state.nCon = nCon;
    state.nS = nS;
    state.nA = nA;
    state.nRuns = nRuns;
    state.trialsPerRun = trialsPerRun;
    state.possibleTrials = possibleTrials;
    state.allTrials = allTrials;
    state.S_minCount = S_minCount;
    state.S_maxCount = S_maxCount;
    state.A_minCount = A_minCount;
    state.A_maxCount = A_maxCount;
    state.C_maxSeq = C_maxSeq;
    state.P_maxSeq = P_maxSeq;
    state.S_count = S_count;
    state.A_count = A_count;
    state.runs = runs;

    [success, state] = runBacktracking(state, startTime, maxTime);

    if ~success
        if ~suppressOutput
            fprintf(['No valid assignment found within %g second(s). ' ...
                'Retrying...\n'], maxTime);
        end
        continue;
    end

    % Shuffle trials within each run to avoid consecutive same Cs or Ps
    for r = 1:nRuns
        attemptsShuffle = 0;
        validOrder = false;
        while ~validOrder && attemptsShuffle < 100
            attemptsShuffle = attemptsShuffle + 1;
            trialOrder = randperm(trialsPerRun);
            candidateRun = state.runs(r, trialOrder);
            if noSeqCP(candidateRun, ...
                    state.C_maxSeq, state.P_maxSeq)
                state.runs(r,:) = candidateRun;
                validOrder = true;
            end
        end
        if ~validOrder && ~suppressOutput
            fprintf(['Warning: Could not find a valid shuffle for ' ...
                'run %d within 100 attempts.\n'], r);
        end
    end

    runOrder = randperm(nRuns);
    state.runs = state.runs(runOrder, :);
    state.S_count = state.S_count(runOrder, :);
    state.A_count = state.A_count(runOrder, :);

    [C_equal, P_equal] = checkCAndPCounts(state);
    if ~C_equal
        if ~suppressOutput
            fprintf(['Final check failed: ' ...
                'C counts per run are not all equal to 6.\n']);
        end
        continue;
    else
        if ~suppressOutput
            fprintf(['C counts per run check passed. ' ...
                'They are all 6.\n']);
        end
    end

    if ~P_equal
        if ~suppressOutput
            fprintf(['Final check failed: ' ...
                'P counts per run are not all equal to 6.\n']);
        end
        continue;
    else
        if ~suppressOutput
            fprintf(['P counts per run check passed. ' ...
                'They are all 6.\n']);
        end
    end

    [S_valid, A_valid] = checkSAndAConstraints(state);
    if ~S_valid
        if ~suppressOutput
            fprintf(['Final check failed: ' ...
                'S counts per run are not all within [%d, %d].\n'], ...
                S_minCount, S_maxCount);
        end
        continue;
    else
        if ~suppressOutput
            fprintf(['S counts per run check passed. ' ...
                'They are all within [%d, %d].\n'], ...
                S_minCount, S_maxCount);
        end
    end

    if ~A_valid
        if ~suppressOutput
            fprintf(['Final check failed: ' ...
                'A counts per run are not all within [%d, %d].\n'], ...
                A_minCount, A_maxCount);
        end
        continue;
    else
        if ~suppressOutput
            fprintf(['A counts per run check passed. ' ...
                'They are all within [%d, %d].\n'], ...
                A_minCount, A_maxCount);
        end
    end

    if ~checkAllUniqueOnce(state)
        if ~suppressOutput
            fprintf(['Final check failed: ' ...
                'Not all unique trials appear exactly once.\n']);
        end
        continue;
    else
        if ~suppressOutput
            fprintf('All unique trials check passed.\n');
        end
    end

    % Add dummy trials
    if bDummy
        % Increase the dimensions of 'state.runs' 
        oldTrialsPerRun = size(state.runs, 2);
        newTrialsPerRun = oldTrialsPerRun + nDummy;
        newRuns = cell(state.nRuns, newTrialsPerRun);
    
        % Insert dummy trials at the start of each run
        for r = 1:state.nRuns
            P_rand = state.Pvals{randi(numel(state.Pvals))};
            S_rand = state.Svals{randi(numel(state.Svals))};
            A_rand = state.Avals{randi(numel(state.Avals))};
    
            dummyTrial = sprintf('%s%s-%s%s', ...
                C_Dummy, P_rand, S_rand, A_rand);
    
            % Prepend the dummy trial
            newRuns(r, :) = [dummyTrial, state.runs(r,:)];
        end
    
        state.runs = newRuns; % Update runs
        state.trialsPerRun = state.trialsPerRun + nDummy;
    end

    usedNs = containers.Map('KeyType','char','ValueType','any');
    state.allRuns = struct('visual',cell(state.nRuns,1),'audio',cell(state.nRuns,1));
    
    for r = 1:state.nRuns
        visual = cell(1, state.trialsPerRun);
        audio = cell(1, state.trialsPerRun);
    
        for t = 1:state.trialsPerRun
            trial = state.runs{r,t};
            parts = split(trial, '-');
            CP = parts{1};
            SA = parts{2};
    
            Cpart = CP(1:2);
            Ppart = CP(3:4);
            Spart = SA(1:2);
            Apart = SA(3:4);
    
            % Determine visual
            if strcmp(Cpart,'C1')
                visual{t} = 'con';
            elseif strcmp(Cpart,'C2')
                visual{t} = 'lis';
            elseif strcmp(Cpart,'C3')
                if any(strcmp(Spart, {'S1','S2','S4'}))
                    visual{t} = 'rep';
                elseif strcmp(Spart,'S3')
                    visual{t} = 'hum';
                end
            end
    
            % Determine audio pattern base (without N)
            basePattern = buildAudioPattern(Ppart, Spart, Apart);
    
            % Determine N
            if t == 1
                N = 0;
            else
                if ~isKey(usedNs, basePattern)
                    usedNs(basePattern) = [1 2 3];
                end
                available = usedNs(basePattern);
                N = available(randi(length(available)));
                usedNs(basePattern) = setdiff(available, N);
            end
            
            audio{t} = [basePattern num2str(N)];
        end
    
        state.allRuns(r).visual = visual;
        state.allRuns(r).audio = audio;
    end

    for r = 1:state.nRuns
        for t = 1:state.trialsPerRun
            a = state.allRuns(r).audio{t};
            % Check if N=0
            if endsWith(a, '0')
                % Replace with a random number from {1,2,3}
                newN = randi(3);
                a = [extractBefore(a, strlength(a)) num2str(newN)];
                state.allRuns(r).audio{t} = a;
            end
        end
    end

    runs = state.runs; %#ok<NASGU>
    allRuns = state.allRuns;
    trialsPerRun = state.trialsPerRun;

    matFileName = outputFile;
    save(matFileName, 'allRuns', 'runs', 'conditions', ...
        'Cvals', 'Pvals', 'Svals', 'Avals', ...
        'nCon', 'nS', 'nA', 'nRuns', 'trialsPerRun', ...
        'allTrials', 'possibleTrials', ...
        'S_minCount', 'S_maxCount', 'A_minCount', 'A_maxCount');

    if ~suppressOutput
        fprintf('Success after %d attempts. Paradigm saved to %s\n', ...
            attempts, matFileName);
    end

    break;
end

end

%% Subfunctions
function [success, state] = runBacktracking(state, startTime, maxTime)
[success, state] = assignCondition(state, startTime, maxTime, 1);
end

function [done, state] = assignCondition(state, startTime, maxTime, cIdx)
if toc(startTime) > maxTime
    done = false;
    return;
end

if cIdx > state.nCon
    for rr = 1:state.nRuns
        if any(state.S_count(rr,:) < state.S_minCount) || ...
            any(state.A_count(rr,:) < state.A_minCount)
            done = false;
            return;
        end
    end
    done = true;
    return;
end

conditionTrials = state.allTrials(cIdx, :);
[done, state] = assignRunPairs(state, startTime, maxTime, cIdx, 1, ...
    conditionTrials);
end

function [done, state] = assignRunPairs(state, startTime, maxTime, ...
    cIdx, rIdx, remainingTrials)
if toc(startTime) > maxTime
    done = false;
    return;
end

if rIdx > state.nRuns
    [done, state] = assignCondition(state, startTime, maxTime, cIdx+1);
    return;
end

nRemaining = length(remainingTrials);
if nRemaining < 2
    done = false;
    return;
end

pairs = nchoosek(1:nRemaining, 2);

done = false;
for pi = 1:size(pairs,1)
    if toc(startTime) > maxTime
        done = false;
        return;
    end

    trialIndices = pairs(pi,:);
    chosenTrials = remainingTrials(trialIndices);
    if canPlaceTrials(state, chosenTrials, rIdx)
        state = placeTrials(state, chosenTrials, rIdx, true);
        newRemaining = remainingTrials;
        newRemaining(trialIndices) = [];

        [done, state] = assignRunPairs(state, startTime, maxTime, ...
            cIdx, rIdx+1, newRemaining);
        if done
            return;
        end

        state = placeTrials(state, chosenTrials, rIdx, false); % backtrack
    end
end
end

function yes = canPlaceTrials(state, trialSet, runNum)
[ds, da] = countSA(state, trialSet);
newS = state.S_count(runNum,:) + ds;
newA = state.A_count(runNum,:) + da;
yes = ~(any(newS > state.S_maxCount) || any(newA > state.A_maxCount));
end

function state = placeTrials(state, trialSet, runNum, addFlag)
[ds, da] = countSA(state, trialSet);
if addFlag
    fillPos = find(cellfun('isempty', state.runs(runNum,:)), 1);
    state.runs(runNum, fillPos:fillPos+1) = trialSet;
    state.S_count(runNum,:) = state.S_count(runNum,:) + ds;
    state.A_count(runNum,:) = state.A_count(runNum,:) + da;
else
    for tt = 1:length(trialSet)
        pos = find(strcmp(state.runs(runNum,:), trialSet{tt}), 1);
        state.runs(runNum, pos) = {[]};
    end
    state.S_count(runNum,:) = state.S_count(runNum,:) - ds;
    state.A_count(runNum,:) = state.A_count(runNum,:) - da;
end
end

function [ds, da] = countSA(state, trialSet)
ds = zeros(1,state.nS);
da = zeros(1,state.nA);
for tt = 1:length(trialSet)
    trial = trialSet{tt};
    parts = split(trial,'-');
    SA = parts{2};
    sPart = SA(1:2);
    aPart = SA(3:4);

    sIndex = find(strcmp(sPart, state.Svals));
    aIndex = find(strcmp(aPart, state.Avals));
    ds(sIndex) = ds(sIndex) + 1;
    da(aIndex) = da(aIndex) + 1;
end
end

function [C_equal, P_equal] = checkCAndPCounts(state)
Cvals = state.Cvals;
Pvals = state.Pvals;
nRuns = state.nRuns;
runs = state.runs;

C_equal = true;
P_equal = true;

for r = 1:nRuns
    C_count = zeros(1,numel(Cvals));
    P_count = zeros(1,numel(Pvals));
    for t = 1:state.trialsPerRun
        trial = runs{r,t};
        parts = split(trial,'-');
        CP = parts{1};
        Cpart = CP(1:2);
        Ppart = CP(3:4);

        cIdx = find(strcmp(Cpart, Cvals));
        pIdx = find(strcmp(Ppart, Pvals));

        C_count(cIdx) = C_count(cIdx) + 1;
        P_count(pIdx) = P_count(pIdx) + 1;
    end
    if any(C_count ~= 6)
        C_equal = false;
    end
    if any(P_count ~= 6)
        P_equal = false;
    end
    if ~C_equal || ~P_equal
        break;
    end
end
end

function [S_valid, A_valid] = checkSAndAConstraints(state)
runs = state.runs;
Svals = state.Svals;
Avals = state.Avals;
nRuns = state.nRuns;
trialsPerRun = state.trialsPerRun;

S_min = state.S_minCount;
S_max = state.S_maxCount;
A_min = state.A_minCount;
A_max = state.A_maxCount;

S_valid = true;
A_valid = true;

for r = 1:nRuns
    S_count = zeros(1,numel(Svals));
    A_count = zeros(1,numel(Avals));
    for t = 1:trialsPerRun
        trial = runs{r,t};
        parts = split(trial,'-');
        SA = parts{2};
        sPart = SA(1:2);
        aPart = SA(3:4);

        sIndex = find(strcmp(sPart, Svals));
        aIndex = find(strcmp(aPart, Avals));
        S_count(sIndex) = S_count(sIndex)+1;
        A_count(aIndex) = A_count(aIndex)+1;
    end
    if any(S_count < S_min | S_count > S_max)
        S_valid = false;
    end
    if any(A_count < A_min | A_count > A_max)
        A_valid = false;
    end
    if ~S_valid || ~A_valid
        return;
    end
end
end

function uniqueOnce = checkAllUniqueOnce(state)
uniqueOnce = true;
sortedAllTrials = sort(reshape(state.runs, 1, []));
sortedPossibleTrials = sort(reshape(state.possibleTrials, 1, []));
if ~isequal(sortedAllTrials, sortedPossibleTrials)
    uniqueOnce = false;
end
end

function isValid = noSeqCP(runTrials, C_maxSeq, P_maxSeq)
isValid = true;
lastC = '';
lastCcount = 0;
lastP = '';
lastPcount = 0;

for i = 1:length(runTrials)
    trial = runTrials{i};
    parts = split(trial,'-');
    CP = parts{1};
    Cpart = CP(1:2); 
    Ppart = CP(3:4);

    if strcmp(Cpart, lastC)
        lastCcount = lastCcount + 1;
    else
        lastC = Cpart;
        lastCcount = 1;
    end

    if strcmp(Ppart, lastP)
        lastPcount = lastPcount + 1;
    else
        lastP = Ppart;
        lastPcount = 1;
    end

    if lastCcount >= C_maxSeq || lastPcount >= P_maxSeq
        isValid = false;
        return;
    end
end
end

function pattern = buildAudioPattern(Ppart, Spart, Apart)
Pnum = Ppart(2);
A = str2double(Apart(2));
S = str2double(Spart(2));

if S == 1
    switch A
        case 1, pattern = ['P' Pnum '_S1_ba_ba_ba_ba_'];
        case 2, pattern = ['P' Pnum '_S1_di_di_di_di_'];
        case 3, pattern = ['P' Pnum '_S1_gu_gu_gu_gu_'];
        case 4, pattern = ['P' Pnum '_S1_le_le_le_le_'];
    end
elseif S == 2
    switch A
        case 1, pattern = ['P' Pnum '_S2_ba_di_ba_di_'];
        case 2, pattern = ['P' Pnum '_S2_di_ba_di_ba_'];
        case 3, pattern = ['P' Pnum '_S2_gu_le_gu_le_'];
        case 4, pattern = ['P' Pnum '_S2_le_gu_le_gu_'];
    end
elseif S == 4
    switch A
        case 1, pattern = ['P' Pnum '_S4_ba_di_gu_le_'];
        case 2, pattern = ['P' Pnum '_S4_di_gu_le_ba_'];
        case 3, pattern = ['P' Pnum '_S4_gu_le_ba_di_'];
        case 4, pattern = ['P' Pnum '_S4_le_ba_di_gu_'];
    end
elseif S == 3
    switch A
        case 1, pattern = ['P' Pnum '_S3_humming1_'];
        case 2, pattern = ['P' Pnum '_S3_humming2_'];
        case 3, pattern = ['P' Pnum '_S3_humming3_'];
        case 4, pattern = ['P' Pnum '_S3_humming4_'];
    end
end
end
