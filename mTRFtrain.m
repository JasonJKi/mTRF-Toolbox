function [w,t,b] = mTRFtrain(stim,resp,fs,dir,tmin,tmax,lambda,varargin)
%MTRFTRAIN mTRF Toolbox model estimation.
%   W = MTRFTRAIN(STIM,RESP,FS,DIR,TMIN,TMAX,LAMBDA) returns the normalized
%   weights W of the linear model that maps the stimulus features STIM and
%   brain responses RESP in the direction DIR. To fit an encoding model
%   (stimulus to brain) pass in DIR=1, or to fit a decoding model (brain to
%   stimulus) pass in DIR=-1. FS is a scalar containing the sample rate
%   in Hertz. TMIN and TMAX are scalars containing the minimum and maximum
%   time lags in milliseconds for generating time-lagged input features.
%   LAMBDA is a scalar containing the regularization parameter for
%   controlling overfitting.
%
%   If STIM or RESP are multivariate, it is assumed that rows correspond to
%   observations and columns to variables. If they are univariate, it is
%   assumed that the first non-singleton dimension corresponds to
%   observations. STIM and RESP must have the same number of observations.
%
%   [...,T] = MTRFTRAIN(...) returns a vector containing the exact time
%   lags in milliseconds used to calculate the model.
%
%   [...,B] = MTRFTRAIN(...) returns a scalar or vector containing the
%   models bias term.
%
%   [...] = MTRFTRAIN(...,'PARAM1',VAL1,'PARAM2',VAL2,...) specifies
%   additional parameters and their values. Valid parameters are the
%   following:
%
%   Parameter   Value
%   'method'    a string specifying the regularization method to be used
%                   'Ridge'     Ridge regularization (default)
%                   'Tikhonov'  Tikhonov regularization
%   'scale'     a logical scalar specifying whether to scale regularization
%               parameter LAMBDA according to the data dimensions: pass in
%               0 to apply no scaling (default) or 1 to apply scaling
%   'dim'       a scalar specifying the dimension to work along: pass in 1
%               to work along the columns (default) or 2 to work along the
%               rows
%   'rows'      a string specifying the rows to use in the case of any
%               missing values (NaNs)
%                   'all'       use all rows, regardless of NaNs (default)
%                   'complete'  use only rows with no NaN values
%
%   See README for examples of use.
%
%   See also LAGGEN, MTRFPREDICT, MTRFTRANSFORM, MTRFCROSSVAL.
%
%   mTRF Toolbox https://github.com/mickcrosse/mTRF-Toolbox

%   References:
%      [1] Lalor EC, Pearlmutter BA, Reilly RB, McDarby G, Foxe JJ (2006)
%          The VESPA: a method for the rapid estimation of a visual evoked
%          potential. NeuroImage 32:1549-1561.
%      [2] Crosse MC, Di Liberto GM, Bednar A, Lalor EC (2016) The
%          multivariate temporal response function (mTRF) toolbox: a MATLAB
%          toolbox for relating neural signals to continuous stimuli. Front
%          Hum Neurosci 10:604.

%   Authors: Mick Crosse, Giovanni Di Liberto, Edmund Lalor
%   Email: mickcrosse@gmail.com, edmundlalor@gmail.com
%   Website: www.lalorlab.net
%   Lalor Lab, Trinity College Dublin, IRELAND
%   April 2014; Last revision: 23-Oct-2019

% Decode input variable arguments
[method,scale,dim,rows] = decode_varargin(varargin);

% Define X and Y
if tmin > tmax
    error('Value of TMIN must be < TMAX.')
elseif dir == 1
    x = stim; y = resp;
elseif dir == -1
    x = resp; y = stim;
    [tmin,tmax] = deal(tmax,tmin);
end
clear stim resp

% Arrange data column-wise
if dim == 2
    x = x'; y = y';
end
if size(x,1) == 1 && size(x,2) > 1
    x = x';
end
if size(y,1) == 1 && size(y,2) > 1
    y = y';
end
if size(x,1) ~= size(y,1)
    error('STIM and RESP must have the same number of observations.')
end

% Use only rows with no NaN values if specified
if strcmpi(rows,'complete')
    x = x(~any(isnan(y),2),:);
    y = y(~any(isnan(y),2),:);
    y = y(~any(isnan(x),2),:);
    x = x(~any(isnan(x),2),:);
elseif strcmpi(rows,'all') && (any(any(isnan(x))) || any(any(isnan(y))))
    error(['STIM or RESP missing values. Set argument ROWS to '...
        '''complete''.'])
end

% Convert time lags to samples
tmin = floor(tmin/1e3*fs*dir);
tmax = ceil(tmax/1e3*fs*dir);

% Generate time-lagged features
X = [ones(size(x,1),1),lagGen(x,tmin:tmax)];

% Set up regularization method
dim = size(X,2);
if strcmpi(method,'Ridge') % Ridge regularization
    M = eye(dim,dim); M(1,1) = 0;
elseif strcmpi(method,'Tikhonov')  % Tikhonov regularization
    if size(x,2) > 1
        warning(['Tikhonov regularization may cause cross-channel '...
            'leakage for multivariate regression.'])
    end
    d = 2*eye(dim);d([dim+2,end]) = 1;
    u = [zeros(dim,1),eye(dim,dim-1)];
    l = [zeros(1,dim);eye(dim-1,dim)];
    M = d-u-l; M(:,1) = 0; M(1,:) = 0;
    M = M/2;
end

% Scale lambda according to data dimensions if specified
if scale
    if strcmpi(method,'Ridge')
        lambda = lambda*size(x,1)*size(x,2)*fs;
    elseif strcmpi(method,'Tikhonov')
        lambda = lambda*size(x,1)*size(x,2)*fs^3;
    end
end

% Compute model weights
w = (X'*X+lambda*M)\(X'*y);

% Normalize W to account for sample rate
w = w*fs;

% Format output variable arguments
t = (tmin:tmax)/fs*1e3;
b = w(1,:);
w = reshape(w(2:end,:),[size(x,2),length(t),size(y,2)]);

function [method,scale,dim,rows] = decode_varargin(varargin)
%decode_varargin decode input variable arguments
%   [PARAM1,PARAM2,...] = DECODE_VARARGIN('PARAM1',VAL1,'PARAM2',VAL2,...)
%   decodes the input variable arguments of the main function.

varargin = varargin{1,1};
if any(strcmpi(varargin,'method')) && ~isempty(varargin{find(strcmpi(...
        varargin,'method'))+1})
    method = varargin{find(strcmpi(varargin,'method'))+1};
    if ~any(strcmpi(method,{'Ridge','Tikhonov'}))
        error(['Invalid value for argument METHOD. Valid values are: '...
            '''Ridge'', ''Tikhonov''.'])
    end
else
    method = 'Ridge'; % default: use ridge method
end
if any(strcmpi(varargin,'scale')) && ~isempty(varargin{find(strcmpi(...
        varargin,'scale'))+1})
    scale = varargin{find(strcmpi(varargin,'scale'))+1};
    if ~isscalar(scale) || scale~=0 && scale~=1
        error(['Argument SCALE must be a logical scalar of value 0 (no '...
            'scaling) or 1 (apply scaling).'])
    end
else
    scale = 0; % default: apply no scaling
end
if any(strcmpi(varargin,'dim')) && ~isempty(varargin{find(strcmpi(...
        varargin,'dim'))+1})
    dim = varargin{find(strcmpi(varargin,'dim'))+1};
    if ~isscalar(dim) || dim~=1 && dim~=2
        error(['Dimension argument must be a positive integer scalar '...
            'within indexing range.'])
    end
else
    dim = 1; % default: work along columns
end
if any(strcmpi(varargin,'rows')) && ~isempty(varargin{find(strcmpi(...
        varargin,'rows'))+1})
    rows = varargin{find(strcmpi(varargin,'rows'))+1};
    if ~any(strcmpi(rows,{'all','complete'}))
        error(['Invalid value for argument ROWS. Valid values are: '...
            '''all'', ''complete''.'])
    end
else
    rows = 'all'; % default: use all rows
end