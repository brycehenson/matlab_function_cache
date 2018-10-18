

%add all subfolders to the path
this_folder = fileparts(which(mfilename));
% Add that folder plus all subfolders to the path.
addpath(genpath(this_folder));

%%
cache_clear


%%
%function_cache_test
copt=[];
function_cache([],@magic,{1e4});



%%
%function_cache_test
copt=[];
copt.force_cache_save=true;
%copt.do_save_factor=1e3;

copt.verbose=3;
copt.dir=fullfile('.','cache');
function_cache(copt,@magic,{1e4});

%%
hash_opt=[];
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'SHA-512'; 
%note this is the wrong usage, you are sneaking data in the function handle!
%if the hash_opt were to change then function_cache would not know about it
test_fun=@(x) DataHash(magic(x), hash_opt);
out1=function_cache(copt,test_fun,{1e2});
out1=out1{:};
%%
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'MD5'; 
input={1e1};
out2=test_fun(input{:});
out3=function_cache(copt,test_fun,input);
out3=out3{:};
%the change to test_fun has not been applied even tho the hash_opt has
isequal(out1,out2)
isequal(out2,out3)
%%
%but then when we redefine test_fun
test_fun=@(x) DataHash(magic(x), hash_opt);
out3=test_fun(input{:});
%and call the cache, it increctly thinks that the function is equal and loads from disk
out4=function_cache(copt,test_fun,input);
out4=out4{:};
isequal(out3,out4)

%% the correct way

fun_in={10^3.0,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x)^50), y);
out3=test_fun(fun_in{:});
%and call the cache, it increctly thinks that the function is equal and loads from disk
out4=function_cache(copt,test_fun,fun_in);
out4=out4{:};
isequal(out3,out4)



%% benchamrk the speeds
copt=[];
copt.force_cache=false;
copt.force_recalc=false;
copt.force_no_write=true; %to be implemented
copt.verbose=0;
copt.dir=fullfile('.','cache');
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'SHA-512'; 
%this is the correct usage
fun_in={10^3.0,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x)^50), y);
cache_time=timeit(@() function_cache(copt,test_fun,fun_in));
out1=function_cache(copt,test_fun,fun_in);
brute_time=timeit(@() test_fun(fun_in{:}));
out2=test_fun(fun_in{:});
logical_str={'fail','pass'};
fprintf('Test Speedup       : %s\n',logical_str{(cache_time<brute_time)+1})
fprintf('Test Equal Resluts : %s\n',logical_str{(isequal(out1,out2))+1})
fprintf('time cache %.3f s  brute %.3f s\n',cache_time,brute_time)

%% give it a real hard problem
copt=[];
copt.force_cache=false;
copt.force_recalc=false;
copt.verbose=1;
copt.dir=fullfile('.','cache');
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'SHA-512'; 
%note this is the wrong usage!
fun_in={10^3.8,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x)^2), y);
out1=function_cache(copt,test_fun,fun_in);
out2=test_fun(fun_in{:});
logical_str={'fail','pass'};
fprintf('Test Equal Resluts : %s\n',logical_str{(isequal(out1,out2))+1})




%% Test cache cleaning

%function_cache_test
copt=[];
copt.force_cache=false;
copt.force_recalc=false;
copt.depth_n=300;
copt.verbose=3;
copt.dir=fullfile('.','cache');
sizes=linspace(10,1e2,200);
iimax=numel(sizes);
for ii=1:iimax
    function_cache(copt,@magic,{sizes(ii)});
end



%% Test function name hashing
copt=[];
copt.force_cache=false;
copt.force_recalc=false;
copt.verbose=3;
copt.dir=fullfile('.','cache');
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'SHA-512'; 
%note this is the wrong usage!
fun_in={10^3.2,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x).^2.12345648756465741257655213762412342312), y);
out1=function_cache(copt,test_fun,fun_in);
out2=test_fun(fun_in{:});
logical_str={'fail','pass'};
fprintf('Test Equal Resluts : %s\n',logical_str{(isequal(out1,out2))+1})


