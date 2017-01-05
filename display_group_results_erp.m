function display_group_results_erp(ANALYSIS)
%
% This script is will plot results from the group-level analyses.  
% This function is called by analyse_decoding_erp.
%
%
% Inputs:
%
%   ANALYSIS        structure containing analysis settings and data
% 
%
% Copyright (c) 2013-2016 Stefan Bode and contributors
% 
% This file is part of DDTBOX.
%
% DDTBOX is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.


%% SET GLOBAL VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

global DCGTODO;
global SLIST;


%% PLOTTING PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

% figure position__________________________________________________________
PLOT.FigPos = [100 100 800 400];

% define x/y-axis__________________________________________________________

% Y-axis depends on analysis mode
if ANALYSIS.analysis_mode ~= 3
    PLOT.Y_min = 40; % Y axis lower bound (in % accuracy)
    PLOT.Y_max = 70; % Y axis upper bound (in % accuracy)
    PLOT.Ysteps = 5; % Interval between Y axis labels/tick marks
elseif ANALYSIS.analysis_mode == 3
    PLOT.Y_min = -0.5; % Y axis lower bound (Fisher-Z corr coeff)
    PLOT.Y_max = 0.5; % Y axis upper bound (Fisher-Z corr coeff)
    PLOT.Ysteps = 0.1; % Interval between Y axis labels/tick marks
end

PLOT.X_min = 1; % X axis lower bound (first time point)
PLOT.X_max = ANALYSIS.xaxis_scale(2,end);
PLOT.Xsteps = ANALYSIS.step_width_ms;

PLOT.Ytick = [PLOT.Y_min:PLOT.Ysteps:PLOT.Y_max];
PLOT.Xtick = [ANALYSIS.xaxis_scale(1,1) : ANALYSIS.xaxis_scale(1,end)];

PLOT.XtickLabel = ANALYSIS.xaxis_scale(2,:) - ANALYSIS.pointzero; 

% define properties of significance markers________________________________
PLOT.Sign.LineColor = 'y';
if ANALYSIS.analysis_mode ~= 3
    PLOT.Sign.LinePos = [PLOT.Y_min+0.5 PLOT.Y_max-0.5];
elseif ANALYSIS.analysis_mode == 3
    PLOT.Sign.LinePos = [PLOT.Y_min PLOT.Y_max];
end
PLOT.Sign.LineWidth = 10;

% define properties of main plot___________________________________________
PLOT.Res.Line = '-ks';
PLOT.Res.LineWidth = 2;
PLOT.Res.MarkerEdgeColor = 'k';
PLOT.Res.MarkerFaceColor = 'w';
PLOT.Res.MarkerSize = 5;

PLOT.Res.Error = 'k';
PLOT.Res.ErrorLine = 'none';
PLOT.Res.ErrorLineWidth = 0.5;

% define properties of permutation / chance plot___________________________
PLOT.PermRes.Line = '-ks';
PLOT.PermRes.LineWidth = 2;
PLOT.PermRes.MarkerEdgeColor = 'b';
PLOT.PermRes.MarkerFaceColor = 'w';
PLOT.PermRes.MarkerSize = 5;

PLOT.PermRes.Error = 'b';
PLOT.PermRes.ErrorLine = 'none';
PLOT.PermRes.ErrorLineWidth = 0.5;

% define label / title properties__________________________________________
PLOT.xlabel.FontSize = 12;
PLOT.ylabel.FontSize = 12;

PLOT.xlabel.FontWeight = 'b';
PLOT.ylabel.FontWeight = 'b';

PLOT.xlabel.Text = 'Time-steps [ms]';
if ANALYSIS.analysis_mode ~= 3
    PLOT.ylabel.Text = 'Classification Accuracy [%]';
elseif ANALYSIS.analysis_mode == 3
    PLOT.ylabel.Text = 'Fisher-Z correlation coeff';
end

PLOT.PointZero.Color = 'r';
PLOT.PointZero.LineWidth = 3;
PLOT.PointZero.Point = find(ANALYSIS.data(3,:) == 1);

if ANALYSIS.stmode == 1 && ANALYSIS.analysis_mode ~=3
    PLOT.TileString = 'Spatial SVM ';
elseif ANALYSIS.stmode == 2 && ANALYSIS.analysis_mode ~=3
    PLOT.TileString = 'Temporal SVM ';
elseif ANALYSIS.stmode == 3 && ANALYSIS.analysis_mode ~=3
    PLOT.TileString = 'Spatiotemporal SVM ';
elseif ANALYSIS.stmode == 1 && ANALYSIS.analysis_mode ==3
    PLOT.TileString = 'Spatial SVR';  
elseif ANALYSIS.stmode == 2 && ANALYSIS.analysis_mode ==3
    PLOT.TileString = 'Temporal SVR '; 
elseif ANALYSIS.stmode == 3 && ANALYSIS.analysis_mode ==3
    PLOT.TileString = 'Spatiotemporal SVR ';  
end

PLOT.TitleFontSize = 14;
PLOT.TitleFontWeight = 'b';
%__________________________________________________________________________


%% PLOT THE RESULTS
%__________________________________________________________________________
% 
% plots the results depending on s/t-mode (information time-courses for
% spatial/spatio-temporal decoding; heat maps for temporal decoding)

if ANALYSIS.stmode == 1 || ANALYSIS.stmode == 3
    
    % determine the time-point for locking the data ("point zero")
%     [dummy pointzero] = min(abs(ANALYSIS.xaxis_scale(1,:)));
%     ANALYSIS.pointzero=pointzero; clear pointzero;
    
    % plot the information time-course for each analysis
    %______________________________________________________________________
    for ana = 1:size(ANALYSIS.RES.mean_subj_acc,1)
        
        fighandle = figure('Position',PLOT.FigPos);
        
        % get results to plot
        %__________________________________________________________________
        temp_data(1,:) = ANALYSIS.RES.mean_subj_acc(ana,:);
        temp_se(1,:) = ANALYSIS.RES.se_subj_acc(ana,:);
        
        % get permutation results to plot
        %__________________________________________________________________
        if ANALYSIS.permstats == 1
            temp_perm_data(1,1:size(ANALYSIS.RES.mean_subj_acc(ana,:),2)) = ANALYSIS.chancelevel;
            temp_perm_se(1,1:size(ANALYSIS.RES.mean_subj_acc(ana,:),2)) = zeros;
        elseif ANALYSIS.permstats == 2
            temp_perm_data(1,:) = ANALYSIS.RES.mean_subj_perm_acc(ana,:);
            temp_perm_se(1,:) = ANALYSIS.RES.se_subj_perm_acc(ana,:);
        end
        
        % mark significant points
        %__________________________________________________________________
        
        if ANALYSIS.disp.sign == 1
            for step = 1:size(temp_data,2)
                
                % plot if found significant...
                if ANALYSIS.RES.h_ttest(ana,step) == 1
                    
%                     % ... and if after baseline (careful - this might be a meaningful result!)
%                     if step >= PLOT.PointZero.Point

                        line([step step],PLOT.Sign.LinePos,'Color',PLOT.Sign.LineColor,'LineWidth',PLOT.Sign.LineWidth);
                        hold on;

%                     end 
                    
                end % if h_ttest
            end % step
        end % disp
        
        % plot main results
        %__________________________________________________________________
        plot(temp_data,PLOT.Res.Line,'LineWidth',PLOT.Res.LineWidth,'MarkerEdgeColor',PLOT.Res.MarkerEdgeColor,...
            'MarkerFaceColor',PLOT.Res.MarkerFaceColor,'MarkerSize',PLOT.Res.MarkerSize);
        hold on;      
        
        errorbar(temp_data,temp_se,PLOT.Res.Error,'linestyle',PLOT.Res.ErrorLine,...
            'linewidth',PLOT.Res.ErrorLineWidth);
        hold on;
        
        
        %% plot permutation / chance results
        %__________________________________________________________________
        if ANALYSIS.permdisp == 1
            
            plot(temp_perm_data,PLOT.PermRes.Line,'LineWidth',PLOT.PermRes.LineWidth,'MarkerEdgeColor',PLOT.PermRes.MarkerEdgeColor,...
                'MarkerFaceColor',PLOT.PermRes.MarkerFaceColor,'MarkerSize',PLOT.PermRes.MarkerSize);
            hold on;      

            errorbar(temp_perm_data,temp_perm_se,PLOT.PermRes.Error,'linestyle',PLOT.PermRes.ErrorLine,...
                'linewidth',PLOT.PermRes.ErrorLineWidth);
            hold on;
            
        end
        
        
        %% define labels, point zero, title
        %__________________________________________________________________
        
        axis([1 ANALYSIS.laststep PLOT.Y_min PLOT.Y_max]);
        
        xlabel(PLOT.xlabel.Text,'FontSize',PLOT.xlabel.FontSize,'FontWeight',PLOT.xlabel.FontWeight);
        ylabel(PLOT.ylabel.Text,'FontSize',PLOT.ylabel.FontSize,'FontWeight',PLOT.ylabel.FontWeight);
        
        
        %% define title
           
        if size(ANALYSIS.DCG,1)==1
                
            title([PLOT.TileString ANALYSIS.DCG ' N='  num2str(ANALYSIS.nsbj)],...
                'FontSize',PLOT.TitleFontSize,'FontWeight',PLOT.TitleFontWeight);
           
        elseif size(ANALYSIS.DCG,1)==2
                
            title([PLOT.TileString ANALYSIS.DCG{1} 'to' ANALYSIS.DCG{2} ' N='  num2str(ANALYSIS.nsbj)],...
                'FontSize',PLOT.TitleFontSize,'FontWeight',PLOT.TitleFontWeight);
           
        end

        
        %% mark point zero (data was time-locked to this event)
        line([PLOT.PointZero.Point PLOT.PointZero.Point], [PLOT.Y_max PLOT.Y_min],'Color',PLOT.PointZero.Color,...
            'LineWidth',PLOT.PointZero.LineWidth);
        
        
        %% define ticks and axis labels
        %__________________________________________________________________
        
        set(gca,'Ytick',PLOT.Ytick,'Xtick',PLOT.Xtick);
        set(gca,'XTickLabel',PLOT.XtickLabel);

        % clear temp-data
        clear temp_data;   
        clear temp_se; 
    
        
    end % channel
    
end % analysis mode