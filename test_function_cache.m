
%to add
%large input test




%add all subfolders to the path
this_folder = fileparts(which(mfilename));
% Add that folder plus all subfolders to the path.
addpath(genpath(this_folder));

%%


%%
copt=[];
copt.verbose=3;
cache_clear 
%lets define a reall slow function with a reasonably small output
test_fun=@slow_test_fun1;
fun_in={10^7,1e6};
%call the cache for the first time
timer1=tic;
out2=function_cache(copt,test_fun,fun_in);
cache_runtime1=toc(timer1);
out2=out2{:};
%then the function by itself
timer1=tic;
out1=test_fun(fun_in{:});
fun_runtime=toc(timer1);
%and then the cache again
timer1=tic;
out3=function_cache(copt,test_fun,fun_in);
cache_runtime2=toc(timer1);
out3=out3{:};
fprintf('function runtime %.2fms, cache runtimes %.2f ,%.2f ms\n',[fun_runtime,cache_runtime1,cache_runtime2]*1e3)
cache_overhead_time=[cache_runtime1-fun_runtime];
fprintf('cache overhead %.2f ms\n',cache_overhead_time*1e3)
cache_speedup_time=[fun_runtime-cache_runtime2];
fprintf('repeats to win back overhead %.2f',cache_overhead_time/cache_speedup_time)
isequal(out1,out2,out3)

%% slow with small output
copt=[];
copt.verbose=3;
copt.save_compressed=false;
cache_clear 
%lets define a reall slow function with a reasonably small output
test_fun=@slow_test_fun2;
fun_in={1,1e7};
%call the cache for the first time
timer1=tic;
out2=function_cache(copt,test_fun,fun_in);
cache_runtime1=toc(timer1);
out2=out2{:};
%then the function by itself
timer1=tic;
out1=test_fun(fun_in{:});
fun_runtime=toc(timer1);
%and then the cache again
timer1=tic;
out3=function_cache(copt,test_fun,fun_in);
cache_runtime2=toc(timer1);
out3=out3{:};
cache_overhead_time=[cache_runtime1-fun_runtime];
cache_speedup_time=[fun_runtime-cache_runtime2];
logic_str = {'FAIL', 'pass'};
fprintf('TEST: outputs equal      : %s\n',logic_str{isequal(out1,out2,out3)+1})
fprintf('TEST: saved cache faster : %s\n',logic_str{(cache_speedup_time>0)+1})
fprintf('INFO: function runtime %.2fms, cache runtimes %.2f ,%.2f ms\n',[fun_runtime,cache_runtime1,cache_runtime2]*1e3)
fprintf('INFO: cache overhead %.2f ms\n',cache_overhead_time*1e3)
fprintf('INFO: repeats to win back overhead %.2f\n',cache_overhead_time/cache_speedup_time)


%% slow with large output
copt=[];
copt.verbose=3;
copt.save_compressed=false;
cache_clear 
%lets define a reall slow function with a reasonably small output
test_fun=@slow_test_fun2;
fun_in={1,1e8};
%call the cache for the first time
timer1=tic;
out2=function_cache(copt,test_fun,fun_in);
cache_runtime1=toc(timer1);
out2=out2{:};
%then the function by itself
timer1=tic;
out1=test_fun(fun_in{:});
fun_runtime=toc(timer1);
%and then the cache again
timer1=tic;
out3=function_cache(copt,test_fun,fun_in);
cache_runtime2=toc(timer1);
out3=out3{:};
cache_overhead_time=[cache_runtime1-fun_runtime];
cache_speedup_time=[fun_runtime-cache_runtime2];
logic_str = {'FAIL', 'pass'};
fprintf('test outputs equal      : %s\n',logic_str{isequal(out1,out2,out3)+1})
fprintf('test saved cache faster : %s\n',logic_str{(cache_speedup_time>0)+1})
fprintf('function runtime %.2fms, cache runtimes %.2f ,%.2f ms\n',[fun_runtime,cache_runtime1,cache_runtime2]*1e3)
fprintf('cache overhead %.2f ms\n',cache_overhead_time*1e3)
fprintf('repeats to win back overhead %.2f\n',cache_overhead_time/cache_speedup_time)


%% Directory Hopping
% this is a test for the relative file paths function
%case 1
%say your running a analysis function on a remote computer and the data is stored on a central server, It can be
%(somtimes) advantagous to save that cache on the remote computer so that if the same analysis function is called on a
%different computer it can see this centeral cache. However the problem is that while the locations are symanticaly the
%same the literal paths are different (data at X:\data\ vs Y:\user\data\).
%case 2
%the idea is that we pass a mock working
%directory to the function_cache() along with a path to where in the input arguments it specifies the data path. This
%could be implemented crudely by doing a cd call before and after the 'guts' of function_cache but this is somehwat
%overhead laden. Insead we modify a version of the function arguments and hash that.

%first test the relative path generator
mock_dir='C:\Users\Bryce\Dropbox\UNI\project\programs\matlab_function_cache\test\layer1';
abs_path= 'C:\Users\Bryce\Dropbox\UNI\project\programs\matlab_function_cache\test\layer1\d.mat';
[abs_path_no_file,name,ext] = fileparts(abs_path);
abs_path_file=[name,ext]
relativepath(abs_path_no_file,mock_dir)


%%

folder_names1={'test','layer1'};
mkdir(folder_names{1})
mkdir(fullfile('.',folder_names{:}))
rng(0);
test_data=rand(1,1e5);
test_data_orig=test_data;
rel_file_path=fullfile('.',folder_names1{:},'d.mat');
abs_file_path1=fullfile(pwd,folder_names1{:},'d.mat'); 
save(abs_file_path1,'test_data')
fopt_struct=[];
fopt_struct.path=abs_file_path1;
fun_in={fopt_struct,1};
copt=[];
copt.verbose=3;
copt.mock_working_dir=fullfile(pwd,folder_names1{:});
copt.path_directions={1,'path'};
test_data_loaded1=data_load_test_fun(fopt_struct,1);
timer1=tic;
test_data_loaded2=function_cache(copt,@data_load_test_fun,fun_in);
cache_runtime1=toc(timer1);

%ok so now we move the data directory
pause(3)
folder_names2={'test','layer2'};
movefile(fullfile('.',folder_names1{:}),fullfile('.',folder_names2{:}))


%run again but now in a different directory
abs_file_path2=fullfile(pwd,folder_names2{:},'d.mat'); 
fopt_struct=[];
fopt_struct.path=abs_file_path2;
fun_in={fopt_struct,1};
copt=[];
copt.verbose=3;
copt.mock_working_dir=fullfile(pwd,folder_names2{:});
copt.path_directions={1,'path'};

timer1=tic;
test_data_loaded2=function_cache(copt,@data_load_test_fun,fun_in);
cache_runtime2=toc(timer1);

logic_str = {'FAIL', 'pass'};
fprintf('Test: Speedup with directory movement : %s\n',logic_str{(cache_runtime2<cache_runtime1)+1})

%%
%then the function by itself
timer1=tic;
out1=test_fun(fun_in{:});
fun_runtime=toc(timer1);
%and then the cache again
timer1=tic;
out3=function_cache(copt,test_fun,fun_in);
cache_runtime2=toc(timer1);
out3=out3{:};
cache_overhead_time=[cache_runtime1-fun_runtime];
cache_speedup_time=[fun_runtime-cache_runtime2];
logic_str = {'FAIL', 'pass'};
fprintf('test outputs equal      : %s\n',logic_str{isequal(out1,out2,out3)+1})
fprintf('test saved cache faster : %s\n',logic_str{(cache_speedup_time>0)+1})
fprintf('function runtime %.2fms, cache runtimes %.2f ,%.2f ms\n',[fun_runtime,cache_runtime1,cache_runtime2]*1e3)
fprintf('cache overhead %.2f ms\n',cache_overhead_time*1e3)
fprintf('repeats to win back overhead %.2f\n',cache_overhead_time/cache_speedup_time)



%%
%function_cache_test
copt=[];
function_cache([],@magic,{1e4});


%%

simple_function_cache([],@magic,{1e2})


%%
%function_cache_test
copt=[];
copt.force_cache_save=true;
%copt.do_save_factor=1e3;

copt.verbose=3;
copt.dir=fullfile('.','cache');
function_cache(copt,@magic,{1e4});

%% HOW NOT TO USE THIS FUNCTION
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
fun_in={10^3.0,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x)^50), y);
cache_time=timeit(@() function_cache(copt,test_fun,fun_in));
out1=function_cache(copt,test_fun,fun_in);
brute_time=timeit(@() test_fun(fun_in{:}));
out2=test_fun(fun_in{:});
logic_str={'fail','pass'};
fprintf('Test: Speedup       : %s\n',logic_str{(cache_time<brute_time)+1})
fprintf('Test: Equal Resluts : %s\n',logic_str{(isequal(out1,out2))+1})
fprintf('time cache %.3f s  brute %.3f s\n',cache_time,brute_time)

%% give it a real hard problem
copt=[];
copt.force_cache=false;
copt.force_recalc=false;
copt.verbose=1;
copt.dir=fullfile('.','cache');
hash_opt.Format = 'base64';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'SHA-512'; 
fun_in={10^3.8,hash_opt};
test_fun=@(x,y) DataHash(sum(magic(x)^2), y);
out1=function_cache(copt,test_fun,fun_in);
out2=test_fun(fun_in{:});
logic_str={'fail','pass'};
fprintf('Test: Equal Results : %s\n',logic_str{(isequal(out1,out2))+1})




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
logic_str={'fail','pass'};
fprintf('Test Equal Resluts : %s\n',logic_str{(isequal(out1,out2))+1})



%%
function out=slow_test_fun1(complexity,size)
%output is higly compressable
hash_opt=[];
hash_opt.Format = 'base64'; 
hash_opt.Method = 'SHA-512'; 
x=round(sqrt(complexity));
size=round(size);
%lets define a reall slow function with a reasonably small output
out= DataHash(sum(inv(magic(x)^2)), hash_opt);
%and repeat it lots of time
out=repmat(out,[size,1]);
end

function out=slow_test_fun2(runtime,size)
tic
%lets define a reall slow function with a reasonably small output
rng(0);
out=rand(1,size);
wait_time=runtime-toc;
if wait_time>0
    pause(wait_time);
else
    warning('runtime exceeded requested')
end
end

