function [fun_out,fun_opts,cache_opts]=function_cache(varargin)
%flexible disk based cache with reasonable optimizations
%to improve
% - memory based cache
% - optional estimated write time to compare with exe time and prevent write
%   - add option to prevent writing cache cache_opts.force_no_write=true;
% - hash function name if too long


%mandatory
%cache_opts,function_handle,var_opts


cache_opts=varargin{1};
fun_handle=varargin{2};
fun_opts=varargin{3:end};

%optional inputs
if ~isfield(cache_opts,'dir'),cache_opts.dir=fullfile('.','cache'); end
if ~isfield(cache_opts,'force_cache'),cache_opts.force_cache=false; end
if ~isfield(cache_opts,'force_recalc'),cache_opts.force_recalc=false; end
if ~isfield(cache_opts,'verbose'),cache_opts.verbose=1; end
if ~isfield(cache_opts,'depth_n'),cache_opts.depth_n=1000; end
if ~isfield(cache_opts,'depth_gb'),cache_opts.depth_gb=10; end
if ~isfield(cache_opts,'depth_seconds'),cache_opts.depth_seconds=60*60*24*30; end %default at one month old

%START internal options, no need to change
cache_opts.delim='__'; %double _ to prevent conflicts with function names
cache_opts.file_name_start='cache';

hash_opt.Format = 'hex';   %because \ can be produced from the 'base64' option
hash_opt.Method = 'MD2'; 
%END internal options,

if cache_opts.verbose>0, fprintf('===========function_cache Starting===========\n'), end
%check that directory exists
if (exist(cache_opts.dir, 'dir') == 0), mkdir(cache_opts.dir); end

fun_str=func2str(fun_handle);
hash_fun_inputs=DataHash(fun_opts, hash_opt);

%hash the function name if its too long
if numel(fun_str)>numel(hash_fun_inputs)
    fun_str=DataHash(fun_str, hash_opt);
end
if cache_opts.force_recalc && cache_opts.force_cache
    error('force_recalc and force_cache both true, make up your mind!!!')
end

load_from_cache_logic=~cache_opts.force_recalc;

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
    if cache_opts.force_cache && numel(file_names_raw)==0
        warning('no cache files found that are suitable, will have to run function');
        cache_opts.force_cache=false;
    end    
    cache_clean(cache_opts,fun_str,hash_fun_inputs)

    
    if cache_opts.force_cache
        if numel(file_names_raw)==0
             load_from_cache_logic=false;
        else
            cache_file_name=file_names_raw{1};
        end
    else
        if  sum(fname_match)~=0
            first_true_idx = find(fname_match, 1, 'first'); %realy there should never be two identical ones
            %check for a hash collision
            cache_file_name=file_names_raw{first_true_idx};
            fun_opts_new=fun_opts;
            cache_file_path=fullfile(cache_opts.dir,cache_file_name);
            load(cache_file_path,'fun_opts')
            if ~isequal(fun_opts_new,fun_opts)
                %hash collsion check failed
                warning('hash collision detected\n')
                load_from_cache_logic=false;
            end
        else
            load_from_cache_logic=false;
        end
    end
end
%

if  ~load_from_cache_logic 
    if cache_opts.verbose>0, fprintf('cache miss\n'), end
    cache_stats=[];
    %dummy cache is a cache file that only exists to direct this script to run the funtion, it will have its data
    %removed
    cache_stats.dummy=false; 
    tic;
    %calculate the function
    if cache_opts.verbose>1, fprintf('Calculating function...'), end
    fun_out=fun_handle(fun_opts{:});
    cache_stats.fun_time=toc;
    if cache_opts.verbose>1, fprintf('Done\n'), end
    if cache_opts.verbose>2, fprintf('function execute time: %.3fs\n',cache_stats.fun_time), end
    nowdt=datetime('now');
    cache_stats.fun_eval_datetime.posix=posixtime(nowdt);
    cache_stats.fun_eval_datetime.iso=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    cache_file_name=['cache',cache_opts.delim,fun_str,cache_opts.delim,hash_fun_inputs,'.mat'];
    if cache_opts.verbose>2, fprintf('file name: %s\n',cache_file_name), end
    cache_file_path=fullfile(cache_opts.dir,cache_file_name);
    tic
    save(cache_file_path,'cache_opts','fun_opts','fun_handle','fun_out','-v7.3');
    cache_stats.save_time=toc;
    if cache_opts.verbose>2, fprintf('output save time: %.3fs\n',cache_stats.save_time), end
    %this is fast so no need to time it
    save(cache_file_path,'cache_stats','-append');
    %warn the user if the save time was longer than the run time
    run_save_factor=2;
    if cache_opts.verbose>1 && cache_stats.save_time>cache_stats.fun_time*run_save_factor
        fprintf(2,'WARNING: save time %.1f x function execute time\n',cache_stats.save_time/cache_stats.fun_time)
        fprintf(2,'It is unlikely that there will be any cache speedup\n')
    end
    
    %cleanup cache
    %cache_clean(cache_opts,fun_handle,dir_content)
else
    if cache_opts.verbose>0, fprintf('cache hit\n'), end
    if cache_opts.verbose>2, fprintf('file name: %s\n',cache_file_name), end
    
    cache_file_path=fullfile(cache_opts.dir,cache_file_name);
    %this is also very fast (~1ms) so no need to time
    load(cache_file_path,'cache_stats')
    %total_cache_overhead=cache_stats.save_time;
    %update the last time the cache was loaded, even when the function was run instead
    nowdt=datetime('now');
    cache_stats.cache_load_datetime.posix=posixtime(nowdt);
    cache_stats.cache_load_datetime.iso=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
    
    load_the_cache=~cache_stats.dummy;
    load_time_existed=false;
    if isfield(cache_stats,'load_time') && load_the_cache
        load_time_existed=true;
        %total_cache_overhead=cache_stats.save_time+cache_stats.load_time;
        if cache_stats.load_time>cache_stats.fun_time*2 %add a user option for the multipler here;
            load_the_cache=false;
            if cache_opts.verbose>0
                fprintf('loading too slow last time, will run function instead\n') 
            end
        end
    end
    if load_the_cache
        if cache_opts.verbose>1, fprintf('loading from disk...'), end
        tic
        load(cache_file_path,'fun_opts','fun_out')
        cache_stats.load_time=toc;
        if cache_opts.verbose>1, fprintf('Done\n'), end
        if cache_opts.verbose>2, fprintf('cache load time      : %.3fs\n',cache_stats.load_time), end
        if cache_opts.verbose>2, fprintf('cache speedup factor : %.3f \n',cache_stats.fun_time/cache_stats.load_time), end
    else
        %deleting the data from cache
        if ~cache_stats.dummy
            if cache_opts.verbose>2, fprintf('Deleteing cache value to save space\n'), end
            delete_data_from_cache(cache_file_path)
            cache_stats.dummy=true;
        end
        if cache_opts.verbose>1, fprintf('Calculating function...'), end
        tic
        fun_out=fun_handle(fun_opts{:});
        cache_stats.fun_time=toc;
        if cache_opts.verbose>1, fprintf('Done\n'), end
        if cache_opts.verbose>2, fprintf('function execute time: %.3fs\n',cache_stats.fun_time), end
    end
    save(cache_file_path,'cache_stats','-append')
end
if cache_opts.verbose>0, fprintf('=============function_cache Done=============\n'), end

end

function delete_data_from_cache(cache_file_path)
%fastest way to delete the data from the cache file
%load everything other than the 'fun_out' variable remove the file and make a new one
output_var_name='fun_out';
fun_out=['ERROR: something went wrong this cache was set as a dummy to save space as',...
            'it was faster to run the function, the user should never be seeing this output'];
        
varlist=who('-file',cache_file_path);
varlist=varlist(~cellfun(@(x) isequal(x,output_var_name),varlist));
load(cache_file_path,varlist{:})
delete(cache_file_path)
cache_stats.dummy=true;
varlist{end+1}=output_var_name;
save(cache_file_path,varlist{:})
end



