function [fun_out,fun_args]=function_cache(varargin)
%function_cache - flexible disk based cache of a matlab function call
%                 with some reasonable optimizations.
% This code takes a function handle and some input to that function and will
% look for a cached version. If it exsts (cache hit) it will just load the 
% saved output and retunr that. Otherwise (cache miss) it will run
% the function and then save the output for the next time this is asked
% for. 
% The output is saved in the format 
%      'cache__[function handle str|function handle hash]__[inputshash].mat'
% The function name is hashed if it is longer than the hash would be.
% There are a few basic optimizations:
% - can make a 'dummy' cache file that just directs the code to run function if no cache speedup, used for:
%   - if after first function eval, load time estimate (from output size in memory)
%     will be longer than function run time
%   - actual load time was longer than last function eval time
%
% The cache is cleaned based on removing everything older than cache_opts.depth_seconds 
% then oldest loaded killed(deleted) first unitl cache_opts.depth_gb ,cache_opts.depth_n is satisfied.
% hash collisions the probablility with even the pleb grade MD2 is 1/(2^128) but if you need a collsion check
% then you can un-comment whats below '========START COLLISION CHECK ======'

% Syntax:  [fun_out,fun_args_out]=function_cache(cache_opts,function_handle,fun_args)
%
% Inputs:
%    cache_opts            - options structure, all fields optional, for basic use just pass []
%       cache_opts.dir                  - string, cache directory
%       cache_opts.verbose              - how much output 0 to 3
%       cache_opts.force_cache_save     - force saving the cache file even if it would be slower
%       cache_opts.force_cache_load     - force loading from the cache even if the fun_args are wrong
%                                         [TO DO] Implement some kind of picking for this case
%       cache_opts.force_recalc         - force the function recalculation
%       cache_opts.clean_cache          - logical, do the cache clean, for more speed turn off
%       cache_opts.depth_n              - number of cache files to keep for THIS FUNCTION ONLY all others are
%                                         ignored
%       cache_opts.depth_gb             - size of cache files to keep for THIS FUNCTION ONLY all others are
%                                         ignored
%       cache_opts.depth_seconds        - oldest file to keep for THIS FUNCTION ONLY all others are ignored
%       cache_opts.load_speed_mbs       - estimated disk read speed in MB/s, for estimating if its worth writing
%                                         the cache file
%       cache_opts.do_save_factor       - how much longer est load can be than calc to continue with saving cache
%                                         this also can be used to compensate for the mem/disk size compression
%       cache_opts.do_load_factor       - how much longer the last load can be compared to calc without just
%                                         turning it into a dummy and running the function
%    fun_handle            - function handle that you wish to evaluate
%    fun_args              - arguments for the fun_handle, will be run as fun_handle(fun_args)
% Outputs:
%    fun_out   - struct, containing all the outputs from fun_out{:}=fun_handle(fun_args)
%                to use as notmal use [out1,out2]=fun_out{:}; or for single output functions consider simple_function_cache 
%    fun_args  - the arguments the function was called with, only needes when the cache has been force loaded

% Example: 
%     hash_opt=[];
%     hash_opt.Format = 'base64'; 
%     hash_opt.Method = 'SHA-512'; 
%     cache_clear
%     %lets define a real slow function with a reasonably small output
%     test_fun=@(x,y) DataHash(sum(inv(magic(x)^2)), y);
%     fun_in={round(rand(1)*10)+10^3.6,hash_opt}; %add random to prevent any matlab layer caching
%     %call the cache for the first time
%     tic
%     out2=function_cache([],test_fun,fun_in);
%     cache_runtime1=toc;
%     out2=out2{:};
%     %then the function by itself
%     tic
%     out1=test_fun(fun_in{:});
%     fun_runtime=toc;
%     %and then the cache again
%     tic
%     out3=function_cache([],test_fun,fun_in);
%     cache_runtime2=toc;
%     out3=out3{:};
%     fprintf('function runtime %.2fms, cache runtimes %.2f ,%.2f',[fun_runtime,cache_runtime1,cache_runtime2]*1e3)
%     isequal(out1,out2,out3)
% 
%     Other m-files required: cache_clean,cache_clear
%     Also See:simple_function_cache,test_function_cache,
%     Subfunctions: delete_data_from_cache_file
%     MAT-files required: none
%
% Known BUGS/ Possible Improvements
%    - more commenting
%    - global cache size limiting
%    - selector for cache_opts.force_cache_load
%    - memory based cache using global
%    - force_cache_nosave
%    - poor performance saving cells
%
% Author: Bryce Henson
% email: Bryce.Henson@live.com
% Last revision:2018-08-19

%------------- BEGIN CODE --------------

%adaptive hashing function
hash_function=@DataHash;
%GetMD5


%split input
cache_opts=varargin{1};
fun_handle=varargin{2};
fun_args=varargin{3:end};
%optional inputs
if ~isfield(cache_opts,'dir'),cache_opts.dir=fullfile('.','cache'); end
if ~isfield(cache_opts,'force_cache_save'),cache_opts.force_cache_save=false; end
if ~isfield(cache_opts,'force_cache_load'),cache_opts.force_cache_load=false; end
if ~isfield(cache_opts,'force_recalc'),cache_opts.force_recalc=false; end
if ~isfield(cache_opts,'verbose'),cache_opts.verbose=1; end
if ~isfield(cache_opts,'clean_cache'),cache_opts.clean_cache=true; end
if ~isfield(cache_opts,'depth_n'),cache_opts.depth_n=1000; end
if ~isfield(cache_opts,'depth_gb'),cache_opts.depth_gb=10; end
if ~isfield(cache_opts,'depth_seconds'),cache_opts.depth_seconds=60*60*24*30; end %default at one month old
if ~isfield(cache_opts,'load_speed_mbs'),cache_opts.load_speed_mbs=400; end %estimated read speed in MB/s
%how much longer est load can be than calc to continue, this also can be used to compensate for the mem/disk size compression
if ~isfield(cache_opts,'do_save_factor'),cache_opts.do_save_factor=1.0; end 
if ~isfield(cache_opts,'do_load_factor'),cache_opts.do_load_factor=1.2; end %how much longer est save can be than calc to continue
if ~isfield(cache_opts,'save_compressed'),cache_opts.save_compressed=false; end %if the cache should use compression

%START internal options, no need to change
cache_opts.delim='__'; %double _ to prevent conflicts with function names
cache_opts.file_name_start='cache';
hash_opt.Format = 'base64';   %if using base64 the hash must be processed with urlencode() to make file sys safe
hash_opt.Method = 'MD5';     %dont need that many bits
%END internal options,

if cache_opts.verbose>0, fprintf('===========function_cache Starting===========\n'), end
if (exist(cache_opts.dir, 'dir') == 0), mkdir(cache_opts.dir); end %check that cache directory exists

%hash string can use urlencode and the 'base64' option to decrease charaters from 32 to 24, without having any
%issued with /*% in file names
fun_str=func2str(fun_handle); %turn function to string

if cache_opts.verbose>1, fprintf('Hashing function inputs...'), end
hash_time=tic;
hash_fun_inputs=urlencode(hash_function(fun_opts, hash_opt)); %hash the input and use urlencode to make it file system safe
hash_time=toc(hash_time);
if cache_opts.verbose>1, fprintf('Done\n'), end
if cache_opts.verbose>2, fprintf('input hashing time   : %.3fs\n',hash_time), end

if numel(fun_str)>numel(hash_fun_inputs)%hash the function name if its too long
    fun_str=urlencode(hash_function(fun_str, hash_opt));
end

if cache_opts.force_recalc && cache_opts.force_cache_load
    error('force_recalc and force_cache_load both true, make up your mind!!!')
end

if cache_opts.save_compressed
    save_compressed_cell={'-v7.3'};
else
    save_compressed_cell={'-nocompression','-v7.3'}; %
end

load_from_cache_logic=~cache_opts.force_recalc;
%look for a file that matches this function call
if load_from_cache_logic
    dir_q=fullfile(cache_opts.dir,[cache_opts.file_name_start,cache_opts.delim,fun_str,cache_opts.delim,hash_fun_inputs,'.mat']);
    dir_content=dir(dir_q);
    file_names_raw = {dir_content.name};
    %much of this processing is redundant with the dir_q comand
    %check that there is an end .mat
    fname_match=cellfun(@(x) isequal(x(end-3:end),'.mat'),file_names_raw);
    file_names_split=cell(size(file_names_raw));
    % split by cache_opts.delim after striping the end .mat
    file_names_split(fname_match)=cellfun(@(x) strsplit(strrep(x,'.mat',''),cache_opts.delim),...
        file_names_raw(fname_match),'UniformOutput',0);
    %pass only file names that split 3 times at the cache_opts.delim
    fname_match(fname_match)=cellfun(@(x) size(x,2)==3,file_names_split(fname_match));
    %pass only file names that start with cache_opts.file_name_start
    fname_match(fname_match)=cellfun(@(x) isequal(x{1},cache_opts.file_name_start),file_names_split(fname_match));
    %pass only file names that have the function string as the second part
    fname_match(fname_match)=cellfun(@(x) isequal(fun_str,x{2}),file_names_split(fname_match));
    match_all_but_hash=fname_match;
    %pass only file names that have the options hash as the third part
    fname_match(fname_match)=cellfun(@(x) isequal(hash_fun_inputs,x{3}),file_names_split(fname_match));
    if cache_opts.force_cache_load && numel(file_names_raw)==0
        warning('force_cache option:no cache files found that are suitable, will have to run function');
        cache_opts.force_cache_load=false;
    end
    %i think this operation should go elsewhere
    if cache_opts.clean_cache
        cache_clean(cache_opts,fun_str,hash_fun_inputs)
    end
    
    if cache_opts.force_cache_load
        %catch the case that the force_cache flag was used but there is nothing matching that function call
        if numel(file_names_raw)==0
             load_from_cache_logic=false;
        else
            %to improve should use the latest cache file, unsure about current behaviour
            cache_file_name=file_names_raw{1};
        end
    else
        if  sum(fname_match)~=0
            first_true_idx = find(fname_match, 1, 'first'); %realy there should never be two identical ones
            cache_file_name=file_names_raw{first_true_idx};
            % ======= HASH COLLISION CHECK ======
            % this is soooo unlikely (P~1/(2^128) for MD2) you can leave it commented out
            % ========START COLLISION CHECK ======
%             cache_file_path=fullfile(cache_opts.dir,cache_file_name);
%             fun_args_new=fun_args;
%             load(cache_file_path,'fun_args')
%             if ~isequal(fun_args_new,fun_args)
%                %hash collsion check failed, strictly speaking it should go check other hash matches but the
%                %probability ~0
%                warning('hash collision detected abandon cache load\n')
%                load_from_cache_logic=false;
%             end
            % ========END COLLISION CHECK ======
        else
            %couldnt find any matches so will just have to run function
            load_from_cache_logic=false;
        end
    end
end
%


if load_from_cache_logic 
    if cache_opts.verbose>0, fprintf('cache hit\n'), end
    if cache_opts.verbose>2, fprintf('file name: %s\n',cache_file_name), end
    cache_file_path=fullfile(cache_opts.dir,cache_file_name);
    load(cache_file_path,'cache_stats') %this is also very fast (~1ms) so no need to time
    %update the last time the cache was loaded, even when the function was run instead
    nowdt=datetime('now');
    cache_stats.cache_load_datetime.posix=posixtime(nowdt);
    cache_stats.cache_load_datetime.iso=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    
    load_from_cache_logic=~cache_stats.dummy;
    %test if the load time last load was longer than the runtime, dont do this check if force_cache_save or force_cache_load
    if isfield(cache_stats,'load_time') && load_from_cache_logic && ~(cache_opts.force_cache_save || cache_opts.force_cache_load)
        %total_cache_overhead=cache_stats.save_time+cache_stats.load_time;
        if cache_stats.load_time>cache_stats.fun_time*cache_opts.do_load_factor 
            load_from_cache_logic=false;
        end
    end
    if load_from_cache_logic
        if cache_opts.verbose>1, fprintf('loading from disk...'), end
        tic
        load(cache_file_path,'fun_args','fun_out')
        cache_stats.load_time=toc;
        if cache_opts.verbose>1, fprintf('Done\n'), end
        if cache_opts.verbose>2, fprintf('cache load time       : %.3fs\n',cache_stats.load_time), end
        if cache_opts.verbose>2, fprintf('cache load speed(disk): %.3f MB/s\n',...
                cache_stats.size_out_disk*1e-6/cache_stats.load_time), end
        if cache_opts.verbose>2, fprintf('cache load speed(mem) : %.3f MB/s\n',...
                cache_stats.size_out_mem*1e-6/cache_stats.load_time), end
        if cache_opts.verbose>2, fprintf('cache speedup factor  : %.3f \n',cache_stats.fun_time/cache_stats.load_time), end
    else
        if cache_opts.verbose>0
            fprintf('loading is too slow, will run function instead\n') 
        end
        %deleting the data from cache
        if ~cache_stats.dummy %dummy flag means that it was already deleted
            if cache_opts.verbose>2, fprintf('Deleting cache value to save space\n'), end
            delete_data_from_cache_file(cache_file_path)
            cache_stats.dummy=true;
        end
    end
    save(cache_file_path,'cache_stats','-append')
else
    if cache_opts.verbose>0, fprintf('cache miss\n'), end
    cache_stats=[];
    cache_stats.hash_time=hash_time;
    %dummy cache is a cache file that only exists to direct this script to run the funtion, it will have its data
    %removed
    cache_stats.dummy=false; 
end

if  ~load_from_cache_logic 
    %calculate the function  
    if cache_opts.verbose>1, fprintf('==========START Calculating Function=========\n'), end
    tic;
    fun_out{:}=fun_handle(fun_args{:}); %run the function
    cache_stats.fun_time=toc;
    if cache_opts.verbose>1, fprintf('===========END Calculating Function==========\n'), end
    if cache_opts.verbose>2, fprintf('function execute time: %.3fs\n',cache_stats.fun_time), end
    nowdt=datetime('now');
    cache_stats.fun_eval_datetime.posix=posixtime(nowdt);
    cache_stats.fun_eval_datetime.iso=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    cache_file_name=['cache',cache_opts.delim,fun_str,cache_opts.delim,hash_fun_inputs,'.mat'];
    if cache_opts.verbose>2, fprintf('file name: %s\n',cache_file_name), end
    cache_file_path=fullfile(cache_opts.dir,cache_file_name);
    run_save_factor=2; %should make user var
    
    if ~cache_stats.dummy
        %figure out how large the output is in memory
        w=whos('fun_out');
        cache_stats.size_out_mem=w.bytes;
        if cache_opts.verbose>2, fprintf('function output size is %fMB in memory\n',cache_stats.size_out_mem*1e-6), end
        %estimate how long it will take to save the output
        est_load_time=(cache_stats.size_out_mem*1e-6)/cache_opts.load_speed_mbs;
        if ~cache_opts.force_cache_save && est_load_time>cache_opts.do_save_factor*cache_stats.fun_time  
            if cache_opts.verbose>0
                fprintf('if cache is saved, the estimated load time is %.1f x function execute time\n',est_load_time/cache_stats.fun_time)
                fprintf('will not save cashe!\n')
            end
            cache_stats.dummy=true;
        end
        if cache_stats.dummy %if this is the first function eval and decide to slow to save, so will save as a dummy
            save(cache_file_path,'cache_opts','fun_args','fun_handle','-nocompression','-v7.3'); 
        else
            tic
            save(cache_file_path,'cache_opts','fun_args','fun_handle','fun_out',save_compressed_cell{:});
            cache_stats.save_time=toc;
            if cache_opts.verbose>2, fprintf('output save time: %.3fs\n',cache_stats.save_time), end
            %warn the user if the save time was longer than the run time and NOT cache_stats.dummy
            if cache_opts.verbose>1 && cache_stats.save_time>cache_stats.fun_time*run_save_factor
                warning(' save time %.1f x function execute time',cache_stats.save_time/cache_stats.fun_time)
                warning('It is unlikely that there will be any cache speedup')
            end
            saved_dir=dir(cache_file_path);
            cache_stats.size_out_disk=saved_dir.bytes;
            if cache_opts.verbose>2
                fprintf('mem to disk compression %.1f x \n',cache_stats.size_out_mem/cache_stats.size_out_disk)
            end
        end
    end %prev dummy cache existed and was just running functtion
    save(cache_file_path,'cache_stats','-append'); %this is fast so no need to time it
end
if cache_opts.verbose>0, fprintf('=============function_cache Done=============\n'), end
end

function delete_data_from_cache_file(cache_file_path)
%fastest way to delete the data from the cache file
%load everything other than the 'fun_out' variable remove the file and make a new one
output_var_name='fun_out';
fun_out=['ERROR:this is a dummy file'];
varlist=who('-file',cache_file_path);
varlist=varlist(~cellfun(@(x) isequal(x,output_var_name),varlist));
load(cache_file_path,varlist{:})
delete(cache_file_path)
cache_stats.dummy=true;
varlist{end+1}=output_var_name;
save(cache_file_path,varlist{:})
end



