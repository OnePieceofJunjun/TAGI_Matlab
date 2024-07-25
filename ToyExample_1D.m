%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% File:         regression_NEURIPS
% Description:  Apply tagi (Update-by-Layer) to y = x^3 + \epsilon
% Author:       Luong-Ha Nguyen & James-A. Goulet
% Created:      November 21, 2019
% Updated:      November 21, 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all
set(0,'DefaultAxesFontName','Helvetica')
set(0,'defaultLineLineWidth',2)
set(0,'DefaultAxesFontSize',16)
set(0,'defaulttextfontsize',16)
format shortE
rand_seed=4;
RandStream.setGlobalStream(RandStream('mt19937ar','seed',rand_seed));  %Initialize random stream number based on clock
% rng(123456)
%% Data
fun         = @(x) (5*x).^3/50;
n_obs       = 20;
n_val       = 20;
NN.sv       = 3/50;
NN.sx       = 0.0;
x_true      = (rand(n_obs, 1)*8 - 4)/5;
x_obs       = x_true + normrnd(0,NN.sx, [n_obs, 1]);
x_plot      = linspace(-1, 1, 100);
y_true      = fun(x_true);
y_true_plot = fun(x_plot);
y_obs       = y_true + normrnd(0, NN.sv, [n_obs, 1]);
x_val       = (rand(n_val, 1)*8 - 4)/5;
y_val       = fun(x_val) + normrnd(0, NN.sv, [n_val, 1]);
nx          = size(x_obs, 2);
ny          = size(y_obs, 2);

%% Neural Network properties
% GPU
NN.gpu                       = 0;
% Data type object single or double precision
NN.dtype                     = 'single';
% Number of input covariates
NN.nx                        = nx;
% Number of output responses
NN.ny                        = ny;
% Batch size
NN.batchSize                 = 1;
NN.errorRateDisplay          = 0;
% Number of nodes for each layer
NN.nodes                     = [NN.nx 100 NN.ny];
% Input standard deviation
NN.sx                        = nan;
% Observations standard deviation
% NN.sv                        = 0.2345;
% Maximal number of learnign epoch
NN.maxEpoch                  = 50;
% Factor for initializing weights & bias
NN.factor4Bp                 = 1E-2*ones(1,numel(NN.nodes)-1);
NN.factor4Wp                 = 0.25*ones(1,numel(NN.nodes)-1);
% Activation function for hidden layer {'tanh','sigm','cdf','relu','softplus'}
NN.hiddenLayerActivation     = 'relu';
% Activation function for hidden layer {'linear', 'tanh','sigm','cdf','relu'}
NN.outputActivation          = 'linear';
% Weight percentaga being set to 0
NN.dropWeight                = 1;
NN.errorRateEval             = 0;
% Replicate a net for testing
NNtest                       = NN;


% Train network
% Indices for each parameter group
NN = indices.parameters(NN);
NN = indices.covariance(NN);
% Initialize weights & bias
[mp, Sp] = tagi.initializeWeightBias(NN);

% Test network
NNtest.batchSize = 1;
NNtest.trainMode = 0;
% Indices for each parameter group
NNtest = indices.parameters(NNtest);
NNtest = indices.covariance(NNtest);


% Loop initialization
NN.trainMode = 1;
stop         = 0;
epoch        = -1;
FigHandle = figure;
set(FigHandle, 'Position', [100, 100, 1000, 400])
%Loglikelihood for validation and training 
LL_val = zeros(NN.maxEpoch,1);
LL_obs = zeros(NN.maxEpoch,1);
%Patameters for early stopping
patience = 10; % Number of epochs to wait for improvement
best_epoch = 0;
best_LL_val = -Inf;% Best LL
wait=0; %counter 
%Criteria thresholds for judging generalization
min_improvement = 1e-5;% minimum improvement to consider progress
improvement_window = 5;% Number of epochs to consider for improvement
% Store improvements for judgeing generalization
val_improvements=zeros(NN.maxEpoch,1);
train_improvements=zeros(NN.maxEpoch,1);

%set(gcf,'Color',[1 1 1])
while ~stop
    epoch = epoch + 1;
    if epoch>0
        [mp, Sp, ~, ~] = tagi.network(NN, mp, Sp, x_obs, y_obs);
        if epoch == NN.maxEpoch
            stop = 1;
        end
        plot_val=1;
        if plot_val
            %% Plot LL
            [~, ~, ynVal, SynVal] = tagi.network(NNtest, mp, Sp, x_val, y_val);
            [~, ~, yntrain, Syntrain] = tagi.network(NNtest, mp, Sp, x_obs, y_obs);
            
            
            subplot(1,2,2)
            LL_val(epoch)=log(mvnpdf(y_val,ynVal,diag(SynVal)));
            LL_obs(epoch)=log(mvnpdf(y_obs,yntrain,diag(Syntrain)));
            % Calculate improvements
            if epoch > 1
                val_improvements(epoch) = LL_val(epoch)-LL_val(epoch-1);
                train_improvements(epoch) = LL_obs(epoch)-LL_obs(epoch-1);
            end

            
            % Check for improvements in validation
            if LL_val(epoch)>best_LL_val
                best_LL_val = LL_val(epoch);
                wait = 0;
                best_epoch = epoch;
            else 
                wait = wait + 1
                if wait >= patience
                    stop = 1; %Stop training if no improvement for patience epoch
                end
            end


            
            scatter(epoch,LL_obs(epoch),'ok')
            hold on
            scatter(epoch,LL_val(epoch),'dm')
            xlim([0,NN.maxEpoch])
            %ylim([-70,-50])
            
            xlabel('Epoch \#','Interpreter','Latex')
            ylabel('log-likelihood','Interpreter','latex')
            drawnow
        end
    end


    
    
    
    %if epoch==50
    subplot(1,2,1)
    
    % Testing
    n_pred  = 100;
    xp      = linspace(-1.2,1.2,n_pred)';
    yp      = fun(xp);
    [~, ~, ynTest, SynTest] = tagi.network(NNtest, mp, Sp, xp, yp);
    
    %% Plot 1D results
    scatter(x_obs*5,y_obs*50,'ok')
    hold on
    scatter(x_val*5,y_val*50,'dm')
    
    plot(x_plot*5,y_true_plot*50,'-k','Linewidth',1)
    
    plot(xp*5, ynTest*50,'r','Linewidth',1)
    patch(5*[xp' fliplr(xp')],50*[ynTest' + 3*sqrt(SynTest') fliplr(ynTest' - 3*sqrt(SynTest'))],'red','EdgeColor','none','FaceColor','red','FaceAlpha',0.2)
    set(gca,'ytick',[-50 0 50], 'xtick', [-5 0 5])
    xlabel('$x$','Interpreter','latex')
    ylabel('$y$','Interpreter','latex')
    xlim([-6,6])
    ylim([-100,100])
    subplot(1,2,1)
    h=legend('$y_{train}$','$y_{validation}$','$g(x)=x^3$','$E[\mathbf{Y}^{(\mathtt{O})}]$','$E[\mathbf{Y}^{(\mathtt{O})}]\pm3\sigma$');
    set(h,'Interpreter','latex','Location','northwest')
    hold off
    drawnow
    %end
    
end
    fprintf('epoch=%d.\n',epoch)
    %Output the best epoch based on the validation LL
    fprintf('Best epoch based on Val_LL:%d\n', best_epoch)
    %Judge generalization
    if epoch-improvement_window >= 1
         mean_val_improvement = mean(val_improvements(epoch-improvement_window:epoch));
         mean_train_improvement = mean(train_improvements(epoch-improvement_window:epoch));
%         mean_val_improvement = mean(val_improvements(end-improvement_window:end));
%         mean_train_improvement = mean(train_improvements(end-improvement_window:end));      
        if mean_train_improvement < min_improvement && mean_val_improvement < min_improvement
            fprintf('The model is underfitting.\n');
        elseif mean_train_improvement > mean_val_improvement% Equal to ploting purpose of figure(d)in Tagi paper = comparision of the train and validation
            fprintf('The model is overfiting.\n');
        else 
            fprintf('The model is gernalizes well.\n');
        end
    else
         fprintf('The model geralizations well.\n');
    end



set(gcf,'Color',[1 1 1])
opts=['scaled y ticks = false,',...
    'scaled x ticks = false,',...
    'x label style={font=\large},',...
    'y label style={font=\large},',...
    'z label style={font=\large},',...
    'legend style={font=\large},',...
    'title style={font=\large},',...
    'mark size=5',...
    ];
% matlab2tikz('figurehandle',gcf,'filename',[ 'ToyExample_1D_early_stop_50.tex'] ,'standalone', true,'showInfo', false,'floatFormat','%.5g','extraTikzpictureOptions','font=\large','extraaxisoptions',opts);




