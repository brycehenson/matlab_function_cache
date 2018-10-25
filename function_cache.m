function [fun_out,fun_opts,cache_opts]=function_cache(varargin)
%flexible disk based cache with some reasonable optimizations
% - hash function name if too long
% - can cache file into dummy that just directs it to run function if no speedup
%   - estimates if load time will be longer than function run time (on first function run)
%   - actual load time was longer than last function eval time

%to improve
% - memory based cache using global
% - function to delete everything in cache
% - optional estimated write time to compare with exe time and prevent write
%   - add option to prevent writing cache cache_opts.force_no_write=true;



%mandatory
%cache_opts,function_handle,var_opts

%hash collision
%   - the probablility with even the pleb grade MD2 is 1/(2^128) I really dont think its worth worrying about this
%   problem

%hash string
% can use urlencode and the 'base64' option to decrease charaters from 32 to 24


%split input
cache_opts=varargin{1};
fun_handle=varargin{2};
fun_opts=varargin{3:end};
%optional inputs
if ~isfield(cache_opts,'dir'),cache_opts.dir=fullfile('.','cache'); end
if ~isfield(cache_opts,'force_cache_save'),cache_opts.force_cache_save=false; end
if ~isfield(cache_opts,'force_cache_load'),cache_opts.force_cache_load=false; end
if ~isfield(cache_opts,'force_recalc'),cache_opts.force_recalc=false; end
if ~isfield(cache_opts,'verbose'),cache_opts.verbose=1; end
if ~isfield(cache_opts,'depth_gb'),cache_opts.clean_cache=true; end
if ~isfield(cache_opts,'depth_n'),cache_opts.depth_n=1000; end
if ~isfield(cache_opts,'depth_gb'),cache_opts.depth_gb=10; end
if ~isfield(cache_opts,'depth_seconds'),cache_opts.depth_seconds=60*60*24*30; end %default at one month old
if ~isfield(cache_opts,'load_speed_mbs'),cache_opts.load_speed_mbs=100; end %estimated read speed in Mb/s
%how much longer est load can be than calc to continue, this also can be used to compensate for the mem/disk size compression
if ~isfield(cache_opts,'do_save_factor'),cache_opts.do_save_factor=3; end 
if ~isfield(cache_opts,'do_load_factor'),cache_opts.do_load_factor=1.2; end %how much longer est save can be than calc to continue

%START internal options, no need to change
cache_opts.delim='__'; %double _ to prevent conflicts with function names
cache_opts.file_name_start='cache';
hash_opt.Format = 'base64';   %if using base64 the hash must be processed with urlencode() to make file sys safe
hash_opt.Method = 'MD5';     %dont need that many bits
%END internal options,

if cache_opts.verbose>0, fprintf('===========function_cache Starting===========\n'), end
if (exist(cache_opts.dir, 'dir') == 0), mkdir(cache_opts.dir); end %check that cache directory exists

fun_str=func2str(fun_handle); %turn function to string
if cache_opts.verbose>1, fprintf('Hashing function inputs...'), end
hash_time=tic;
hash_fun_inputs=urlencode(DataHash(fun_opts, hash_opt)); %hash the input and use urlencode to make it file system safe
hash_time=toc(hash_time);
if cache_opts.verbose>1, fprintf('Done\n'), end
if cache_opts.verbose>2, fprintf('input hashing time   : %.3fs\n',hash_time), end

if numel(fun_str)>numel(hash_fun_inputs)%hash the function name if its too long
    fun_str=urlencode(DataHash(fun_str, hash_opt));
end

if cache_opts.force_recalc && cache_opts.force_cache_load
    error('force_recalc and force_cache_load both true, make up your mind!!!')
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
%             fun_opts_new=fun_opts;
%             load(cache_file_path,'fun_opts')
%             if ~isequal(fun_opts_new,fun_opts)
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
        load(cache_file_path,'fun_opts','fun_out')
        cache_stats.load_time=toc;
        if cache_opts.verbose>1, fprintf('Done\n'), end
        if cache_opts.verbose>2, fprintf('cache load time      : %.3fs\n',cache_stats.load_time), end
        if cache_opts.verbose>2, fprintf('cache speedup factor : %.3f \n',cache_stats.fun_time/cache_stats.load_time), end
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
    fun_out{:}=fun_handle(fun_opts{:}); %run the function
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
            if cache_opts.verbose>1
                fprintf('if cache is saved, the estimated load time is %.1f x function execute time\n',est_load_time/cache_stats.fun_time)
                fprintf('will not save cashe!\n')
            end
            cache_stats.dummy=true;
        end
        if cache_stats.dummy %if this is the first function eval and decide to slow to save, so will save as a dummy
            save(cache_file_path,'cache_opts','fun_opts','fun_handle','-v7.3');
        else
            tic
            save(cache_file_path,'cache_opts','fun_opts','fun_handle','fun_out','-v7.3');
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
                fprintf('cache disk compression %.1f x \n',cache_stats.size_out_mem/cache_stats.size_out_disk)
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



