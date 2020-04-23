function [Cxx,Cxy,Cxz,folds] = mlscovmat(x,y,z,lags,type,zeropad,verbose)
%MLSCOVMAT  Covariance matrices for multisensory least squares estimation.
%   [CXX,CXY,CXZ] = MLSCOVMAT(X,Y,Z,LAGS) returns the covariance matrices
%   for multisensory least squares (MLS) estimation using time-lagged
%   features of X. X, Y and Z are matrices or cell arrays containing
%   corresponding trials of continuous data. LAGS is a vector of time lags
%   in samples.
%
%   If X, Y or Z are matrices, it is assumed that the rows correspond to
%   observations and the columns to variables. If they are cell arrays
%   containing multiple trials, the covariance matrices of each trial are
%   summed to produce CXX, CXY and CXZ.
%
%   [CXX,CXY,CXZ,FOLDS] = OLSCOVMAT(...) returns cell arrays containing the
%   individual folds in a structure with the following fields:
%       'xlag'      -- design matrices containing time-lagged features of X
%       'Cxx'       -- autocovariance matrices of XLAG
%       'Cxy'       -- cross-covariance matrices of XLAG and Y
%       'Cxz'       -- cross-covariance matrices of XLAG and Z
%
%   [...] = MLSCOVMAT(X,Y,Z,LAGS,TYPE) specifies the type of model that the
%   covariance matrices will be used to fit. Pass in 'multi' for TYPE to
%   use all lags simultaneously (default), or 'single' to use each lag
%   individually.
%
%   [...] = MLSCOVMAT(X,Y,Z,LAGS,TYPE,ZEROPAD) specifies whether to zero-
%   pad the outer rows of the design matrix or delete them. Pass in 1 for
%   ZEROPAD to zero-pad them (default), or 0 to delete them.
%
%   [...] = MLSCOVMAT(X,Y,Z,LAGS,TYPE,ZEROPAD,VERBOSE) specifies whether to
%   display details about cross-validation progress. Pass in 1 for VERBOSE
%   to display details (default), or 0 to not display details.
%
%   See also COV, LSCOV, OLSCOVMAT.
%
%   mTRF-Toolbox https://github.com/mickcrosse/mTRF-Toolbox

%   Authors: Mick Crosse <mickcrosse@gmail.com>
%            Nate Zuk <zukn@tcd.ie>
%   Copyright 2014-2020 Lalor Lab, Trinity College Dublin.

% Set default values
if nargin < 5 || isempty(type)
    type = 'multi';
end
if nargin < 6 || isempty(zeropad)
    zeropad = true;
end
if nargin < 7 || isempty(verbose)
    verbose = true;
end

% Get dimensions
xvar = size(x{1},2);
yvar = size(y{1},2);
nfold = numel(x);
switch type
    case 'multi'
        nvar = xvar*numel(lags)+1;
        nlag = 1;
    case 'single'
        nvar = xvar+1;
        nlag = numel(lags);
end
if nargout > 2
    ncell = nfold;
else
    ncell = 1;
end

% Verbose mode
if verbose
    v = verbosemode(0,nfold);
end

% Initialize variables
CxxInit = zeros(nvar,nvar,nlag);
CxyInit = zeros(nvar,yvar,nlag);
Cxx = CxxInit;
Cxy = CxyInit;
Cxz = CxyInit;
Cxxi = cell(ncell,1);
Cxyi = cell(ncell,1);
Cxzi = cell(ncell,1);
xlag = cell(ncell,1);
ii = 1;

for i = 1:nfold
    
    % Generate design matrix
    xlag{ii} = lagGen(x{i},lags,zeropad,1);
    
    switch type
        
        case 'multi'
            
            % Compute covariance matrices
            Cxxi{ii} = xlag{ii}'*xlag{ii};
            Cxyi{ii} = xlag{ii}'*y{i};
            Cxzi{ii} = xlag{ii}'*z{i};
            
        case 'single'
            
            % Initialize cells
            Cxxi{ii} = CxxInit;
            Cxyi{ii} = CxyInit;
            Cxzi{ii} = CxyInit;
            
            for j = 1:nlag
                
                % Index lag
                idx = [1,xvar*(j-1)+2:xvar*j+1];
                
                % Compute covariance matrices
                Cxxi{ii}(:,:,j) = xlag{ii}(:,idx)'*xlag{ii}(:,idx);
                Cxyi{ii}(:,:,j) = xlag{ii}(:,idx)'*y{i};
                Cxzi{ii}(:,:,j) = xlag{ii}(:,idx)'*z{i};
                
            end
            
    end
    
    % Sum covariance matrices
    Cxx = Cxx + Cxxi{ii};
    Cxy = Cxy + Cxyi{ii};
    Cxz = Cxz + Cxzi{ii};
    
    % Verbose mode
    if verbose
        v = verbosemode(i,nfold,v);
    end
    
    if nargout > 3
        ii = ii+1;
    end
    
end

% Format output
if nargout > 3
    folds = struct('xlag',{xlag},'Cxx',{Cxxi},'Cxy',{Cxyi},'Cxz',{Cxzi});
end

function v = verbosemode(fold,nfold,v)
%VERBOSEMODE  Execute verbose mode.
%   V = VERBOSEMODE(FOLD,NFOLD,V) prints details about the progress of the
%   main function to the screen.

if fold == 0
    v = struct('msg',[],'h',[],'tocs',[]);
    fprintf('Computing covariance matrices\n')
    v.msg = '%d/%d [';
    v.h = fprintf(v.msg,fold,nfold);
    v.tocs = 0; tic
else
    if fold == 1 && toc < 0.1
        pause(0.1)
    end
    fprintf(repmat('\b',1,v.h))
    v.msg = strcat(v.msg,'=');
    v.h = fprintf(v.msg,fold,nfold);
    v.tocs = v.tocs + toc;
    if fold == nfold
        fprintf('] - %.2fs/step\n',v.tocs/nfold)
    else
        tic
    end
end