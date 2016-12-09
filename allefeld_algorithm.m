function [Results, Params] = allefeld_algorithm(observed_data, permtest_data, varargin)
%
% This script implements the group-level statistical inference testing
% based on the minimum statistic (described in detail in Allefeld et al.,
% 2016). The testing procedure includes a test for global null (i.e. that
% no subject show any effects, i.e. a fixed effects analysis) and also
% tests for the prevalence of an effect as a proportion of the sample.
%
% Allefeld, C., Gorgen, K., Haynes, J.D. (2016). Valid population inference
% for information-based imaging: From the second-level t-test to prevalence
% inference. Neuroimage 141, 378-392.
%
% Code for the algorithm in this script is adapted from the prevalence-permutation
% repository of Carsten Allefeld. The original code can be found at:
% https://github.com/allefeld/prevalence-permutation
%
%
% Inputs:
%
%   observed_data       two-dimensional matrix of classifier accuracies:
%                       observed_data(time window, subject). Accuracies need
%                       to have been already averaged across
%                       cross-validation steps and repeated analyses.
%
%   permtest_data       three-dimensional matrix of classifier accuracies
%                       derived from each permutation sample.
%                       permtest_data(time window, subject, permutation)
%
%  'Key1'               Keyword string for argument 1
%
%   Value1              Value of argument 1
%
%   ...                 ...
%
% Optional Keyword Inputs:
%
%   P2                  The number of second-level permutations to
%                       generate. Default = 100000
%
%   alpha_level         The nominal alpha level for significance testing.
%                       Default = 0.05
%
%
% Outputs:
%
%   Results structure containing:
%   .puGN         uncorrected p-values for global null hypothesis         (Eq. 24)
%   .pcGN         corrected p-values for global null hypothesis           (Eq. 26)
%   .puMN         uncorrected p-values for majority null hypothesis       (Eq. 19)
%   .pcMN         corrected p-values for majority null hypothesis         (Eq. 21)
%   .gamma0u      uncorrected prevalence lower bounds                     (Eq. 20)
%   .gamma0c      corrected prevalence lower bounds                       (Eq. 23)
%   .classification_acc_typical     median values of test statistic where pcMN <= alpha     (Fig. 4b)
%   
%   Params stucture containing analysis parameters and properties:
%   .n_time_windows    number of time windows used in analyses
%   .N            number of subjects
%   .P1           number of first-level permutations + 1 (extra 1 is observed data)
%   .P2           number of second-level permutations actually generated
%   .alpha_level  nominal alpha level
%   .puMNMin      smallest possible uncorrected p-value for majority H0
%   .pcMNMin      smallest possible corrected p-value for majority H0
%   .gamma0uMax   largest possible uncorrected prevalence lower bound
%   .gamma0cMax   largest possible corrected prevalence lower bound       (Eq. 27)
%
%
% Example:      % [Results, Params] = allefeld_algorithm(observed_data, permtest_data, 'P2', 100000, 'alpha_level', 0.05)

%
% Copyright (C) 2016 Daniel Feuerriegel and Contributors
%
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version. This program is distributed in the hope that
% it will be useful, but without any warranty; without even the implied
% warranty of merchantability or fitness for a particular purpose. See the
% GNU General Public License <http://www.gnu.org/licenses/> for more details.

%% Handling variadic inputs
% Define defaults at the beginning
options = struct(...
    'alpha_level', 0.05,...
    'P2', 100000);

% Read the acceptable names
option_names = fieldnames(options);

% Count arguments
n_args = length(varargin);
if round(n_args/2) ~= n_args/2
   error([mfilename ' needs property name/property value pairs'])
end

for pair = reshape(varargin,2,[]) % pair is {propName;propValue}
   inp_name = lower(pair{1}); % make case insensitive

   % Overwrite default options
   if any(strcmp(inp_name, option_names))
      options.(inp_name) = pair{2};
   else
      error('%s is not a recognized parameter name', inp_name)
   end
end
clear pair
clear inp_name

% Renaming variables for use below:
alpha_level = options.alpha_level;
P2 = options.P2;
clear options;


%% Organising Data

n_subjects = size(observed_data, 2); % Number of subject datasets
n_time_windows = size(observed_data, 1); % Number of time windows to analyse
n_permutations_per_subject = size(permtest_data, 3); % Number of permutation sample analyses per subject
P1 = n_permutations_per_subject + 1; % Number of first-level permutations + 1 extra for observed data

% Checking if the P2 value is larger than the possible number of unique
% permutations
if P2 > P1 ^ n_subjects 

    % Warn that the number of second-level permutations has been adjusted
    fprintf('\n\n Warning: Selected number of second-level permutations is more than the \n number of possible unique permutations. Setting P2 to the \n number of permutations per subject ^ number of subjects... \n\n'); 
    
    % Set P2 to the number of unique second-level permutations
    P2 = P1 ^ n_subjects;
    
end
    
% Stating how the permutation test will be done (all permutations or
% random draws)
if P2 == P1 ^ n_subjects
    fprintf('\n\n enumerating all %d second-level permutations\n\n', P2)
else
    fprintf('\n\n randomly generating %d of %d possible second-level permutations\n\n', ...
        P2, P1 ^ n_subjects)
end


%% Step 1
% Step 1: Compute the first-level estimates of classification accuracy for
% the observed data and permutation samples.

classification_acc = observed_data; % Observed data accuracies

% First permutation must be same as observed data
classification_acc_perm(1:n_time_windows, 1:n_subjects, 1) = classification_acc;

% Rest of permutation accuracies are randomly generated in this script.
classification_acc_perm(1:n_time_windows, 1:n_subjects, 2:P1) = permtest_data;


%% Step 2
% Step 2: Calculate the minimum classification accuracy m(step) across all 
% included subjects for each analysis time step/time window. The minimum
% classification accuracy from permutation samples is computed for each
% second-level permutation j = 1, ... P2. Here, P2 is the number of
% second-level permutations. A second-level permutation is a combination of
% first-level permutations, so there are P1 ^ n_subjects possible permutations. 
% If there are too many to calculate we can just use random draws using
% Monte-Carlo estimation. However, j = 1 must be the combination of
% 'neutral' permutations (i.e. the 1st entry of permutation accuracies from
% each subject, equalling the observed classification accuracies.

% Preallocate rank vectors (for calculating p-values)
uRank = zeros(n_time_windows, 1); % For uncorrected p-values
cRank = zeros(n_time_windows, 1); % For corrected p-values

% Perform second-level permutations
for j = 1:P2
    % Select first-level permutations
    if P2 == P1 ^ n_subjects % complete enumeration
        % Translate index of second-level permutation (j)
        % into indices of first-level permutations (is)
        jc = j - 1;
        is = nan(n_subjects, 1); % Preallocate first-level permutation accuracies vector
        for k = 1:n_subjects
            is(k) = rem(jc, P1) + 1;
            jc = floor(jc / P1);
        end
    else        % Monte Carlo
        % randomly select permutations, except for first
        if j == 1
            is = ones(n_subjects, 1);
        else
            is = randi(P1, n_subjects, 1);
        end % of if j == 1
    end % of if P2
    
    % translate indices of first-level permutations to indices into matrix classification_acc_perm
    ind = sub2ind([n_subjects, P1], (1 : n_subjects)', is);
    
    % test statistic: minimum across subjects
    m = min(classification_acc_perm(:, ind), [], 2);
    
    % store result of neutral permutation (actual value) for each voxel
    if j == 1
        m1 = m;
    end
    
    % Compare actual (observed) value with permutation value for each voxel separately,
    % determines uncorrected p-values for global null hypothesis.
    uRank = uRank + (m >= m1);          % part of Eq. 24
    % Compare actual (observed) value at each voxel with maximum across voxels,
    % determines corrected p-values for global null hypothesis.
    cRank = cRank + (max(m) >= m1);     % Eq. 25 & part of Eq. 26


    % compute results,
    % based on permutations performed so far: j plays the role of P2
    % uncorrected p-values for global null hypothesis
    puGN = uRank / j;                               % part of Eq. 24
    % corrected p-values for global null hypothesis
    pcGN = cRank / j;                               % part of Eq. 26
    % significant voxels for global null hypothesis
    sigGN = (pcGN <= alpha_level);
    
    
    % * Step 5a: compute p-values for given prevalence bound
    % (here specifically gamma0 = 0.5, i.e the majority null hypothesis)
    % uncorrected p-values for majority null hypothesis
    puMN = ((1 - 0.5) * puGN .^ (1/n_subjects) + 0.5) .^ n_subjects;  % Eq. 19
    % corrected p-values for majority null hypothesis
    pcMN = pcGN + (1 - pcGN) .* puMN;               % Eq. 21
    % significant voxels for majority null hypothesis
    sigMN = (pcMN <= alpha_level);
    % lower bound on corrected p-values for majority null hypothesis
    puMNMin = ((1 - 0.5) * 1/j .^ (1/n_subjects) + 0.5) .^ n_subjects;
    pcMNMin = 1/j + (1 - 1/j) .* puMNMin;
    % * Step 5b: compute prevalence lower bounds for given alpha
    % uncorrected prevalence lower bounds
    gamma0u = (alpha_level .^ (1/n_subjects) - puGN .^ (1/n_subjects)) ./ (1 - puGN .^ (1/n_subjects)); % Eq. 20
    gamma0u(alpha_level < puGN) = nan;                    % undefined
    % corrected prevalence lower bounds
    alphac = (alpha_level - pcGN) ./ (1 - pcGN);          % Eq. 22
    gamma0c = (alphac .^ (1/n_subjects) - puGN .^ (1/n_subjects)) ./ (1 - puGN .^ (1/n_subjects)); % Eq. 23
    gamma0c(puGN > alphac) = nan;                   % undefined
    % upper bound for lower bounds
    gamma0uMax = (alpha_level .^ (1/n_subjects) - 1/j .^ (1/n_subjects)) ./ (1 - 1/j .^ (1/n_subjects));
    alphacMax = (alpha_level - 1/j) / (1 - 1/j);          % Eq. 27
    gamma0cMax = (alphacMax .^ (1/n_subjects) - 1/j .^ (1/n_subjects)) ./ (1 - 1/j .^ (1/n_subjects)); % Eq. 27
    % The criterion for the corrected prevalence lower bound to be
    % defined, `puGN <= alphac`, is not equivalent to the significance
    % criterion for the GN, `pcGN <= alpha`, but is slightly more
    % conservative. A possible disagreement may be detected by
    % comparing the lines
    %   global null hypothesis is rejected
    % and
    %   prevalence bound is defined
    % in the diagnostic output. The two numbers should normally be
    % identical, but the second one can be smaller.
    
    
end % of for j


%% Collate results for output


% Copy results into structures for output
% Results structure
Results = struct;
Results.puGN = puGN; % uncorrected p-values for global null hypothesis
Results.pcGN = pcGN; % corrected p-values for global null hypothesis
Results.sigGN = sigGN; % significant time windows for global null hypothesis
Results.puMN = puMN; % uncorrected p-values for majority null hypothesis
Results.pcMN = pcMN; % corrected p-values for majority null hypothesis
Results.gamma0u = gamma0u; % uncorrected prevalence lower bounds
Results.gamma0c = gamma0c; % corrected prevalence lower bounds

% where majority null hypothesis can be rejected, typical value of the
% classifier accuracy
classification_acc_typical = nan(n_time_windows, 1);
classification_acc_typical(sigMN) = median(classification_acc(sigMN, :, 1), 2);
Results.classification_acc_typical = classification_acc_typical; 

% Params structure
Params = struct;
Params.n_time_windows = n_time_windows; % Number of time windows analysed
Params.N = n_subjects; % Number of subjects
Params.P1 = P1; % Number of 1st-level permutations
Params.P2 = P2; % Number of 2nd-level permutations performed
Params.alpha = alpha_level; % alpha level
Params.puMNMin = puMNMin; % lower bound on uncorrected p-values for majority null hypothesis
Params.pcMNMin = pcMNMin; % lower bound on corrected p-values for majority null hypothesis
Params.gamma0uMax = gamma0uMax; % upper bound for lower bounds (uncorrected)
Params.gamma0cMax = gamma0cMax; % upper bound for lower bounds (corrected)














