function generate_RvH_pardigms()
% This script calls generate_RvH_pardigm() to generate multiple paradigms.
% It measures time taken for each paradigm, records the attempts,
% and at the end prints out the average attempts and average time.
%
% When calling the function, we pass `true` to suppress console outputs,
% so we only get a single line per paradigm here.

numParadigms = 5;
paradigmStart = 201;

allAttempts = zeros(1, numParadigms);
allTimes = zeros(1, numParadigms);

for i = 1:numParadigms
    paradigmNum = paradigmStart + (i - 1);
    tStart = tic;
    % Call with suppression enabled:
    [attempts, matFileName] = generate_RvH_pardigm(true);
    elapsedTime = toc(tStart);

    [~, name, ext] = fileparts(matFileName);
    newFileName = sprintf('%s_%d%s', name, paradigmNum, ext);
    movefile(matFileName, newFileName);
    fprintf('Paradigm %d created in %d attempts, took %.3f seconds.\n', ...
        paradigmNum, attempts, elapsedTime);

    allAttempts(i) = attempts;
    allTimes(i) = elapsedTime;
end

fprintf('Average attempts: %.2f\n', mean(allAttempts));
fprintf('Average time per paradigm: %.3f seconds.\n', mean(allTimes));
end
