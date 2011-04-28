if isunix
[mpath ig ig]=fileparts(mfilename('fullpath'));
vbfretpath=[mpath '../../'];
addpath(genpath('vbfretpath/aux/KPMtools'));
addpath(genpath('vbfretpath/aux/netlab'));
addpath(genpath('vbfretpath/aux/vbhmm'));
addpath(genpath('vbfretpath/aux/stats'));
addpath(genpath('vbfretpath/aux/vbemgmm'));
addpath(genpath('vbfretpath/'));
addpath(genpath('vbfretpath/dat/'));
addpath(genpath('vbfretpath/src'));
addpath(genpath('../'));
addpath(genpath('../../'));
addpath(genpath('../gui/src/'));
addpath('./src')
end

%dname = 'ic12puroEfgGdpnp50nm1_hFRET_out_D011910'
%dname = 'ic12puroEfgGdpnp50nm2_hFRET_out_D011910'
dname = 'ic12puroEfgGdpnp50nm3_hFRET_out_D011910'


load(dname,'u','FRET','data','labels')
d_t = clock; 
save_name = sprintf('%s_out_D%02d%02d%02d_T%d%d',dname,d_t(2),d_t(3),d_t(1)-2000,d_t(4),d_t(5))
vb_opts = get_hFRET_vbopts();


% just a 2 state system
ua{1} = ones(2);
% a 4 state system (negative control?)
ua{2} = ones(4);
% tr1: both slow transitioning tr2: both fast transitioning verison 1
ua{3} = [10 1  0  0;...
         1 10  0  0;...
         0 0   1  1;...
         0 0   1  1];

% tr1: both slow transitioning tr2: both fast transitioning verison 2
ua{4} = [1   0.1  0  0;...
         0.1 1    0  0;...
         0   0    1  1;...
         0   0    1  1];


% tr1: low state slow transitioning transitioning tr2: both fast transitioning verison 1
ua{5} = [10  1  0  0;...
         1   1    0  0;...
         0   0    1  1;...
         0   0    1  1];
     
% tr1: low state slow transitioning transitioning tr2: both fast transitioning verison 2
ua{6} = [1   0.1  0  0;...
         1   1    0  0;...
         0   0    1  1;...
         0   0    1  1];

% tr1: high state slow transitioning transitioning tr2: both fast transitioning verison 1
ua{7} = [1   1    0  0;...
         1   10   0  0;...
         0   0    1  1;...
         0   0    1  1];
     
% tr1: high state slow transitioning transitioning tr2: both fast transitioning verison 2
ua{8} = [1    1    0  0;...
         0.1  1    0  0;...
         0    0    1  1;...
         0    0    1  1];

% initialize priors to test
H = length(ua);

priors = cell(1,H);
% u master
uM = u{10,2};

for h=1:H
    if length(ua{h}) == 2
        priors{h} = uM;
        priors{h}.upi = [1 1];
        priors{h}.ua = ua{h};
    else
        priors{h}.W = [uM.W uM.W];
        priors{h}.v = [uM.v' uM.v']';
        priors{h}.beta = [uM.beta' uM.beta']';
        priors{h}.mu = [uM.mu uM.mu];
        priors{h}.upi = [1 1 1 1];
        priors{h}.ua = ua{h}+1e-5;
    end
end 


% VBHMM preprocessing
% get number of traces in data
N = length(FRET);   
out0 = cell(H,N);
LP0 = -inf*ones(H,N);

R = 10;
I = 25;
out = cell(R,H);
LP = cell(R,H);
z_hat = cell(R,H);
x_hat = cell(R,H);
u_old = u;
u = cell(R,H);
theta = cell(R,H);
Hbest = zeros(1,H);


for r = 1:R
    for h =  1:H
        if r == 1
            u0 = priors{h};
        else
            u0 = u{r-1,h};
        end
        
        out{r,h} = cell(1,N); LP{r,h} = -inf*ones(1,N);
        z_hat{r,h} = cell(1,N); x_hat{r,h} = cell(1,N);
        
        for n=1:N
                disp(sprintf('r: %d h: %d n:%d',r,h,n))
            for i = 1:I
                initM = get_M0(u0,length(FRET{n}));
                temp_out = VBEM_eb(FRET{n}, initM, u0,vb_opts);
                % Only save the iterations with the best out.F
                if temp_out.F(end) > LP{r,h}(n)
                    LP{r,h}(n) = temp_out.F(end);
                    out{r,h}{n} = temp_out;
                end
            end 
        end

        for n = 1:N
            [z_hat{r,h}{n} x_hat{r,h}{n}] = chmmViterbi_eb(out{r,h}{n},FRET{n});
        end
        % compute posterior hyperparmaters and most probable posterior parameters
        [u{r,h} theta{r,h}] = get_ML_par(out{r,h},u0);

        save(save_name)
    end
end 