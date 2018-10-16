function cache_clean(cache_opts,fun_str,hash_fun_inputs)
%should add option for cache too old
%clean up the cache directory
%dont delete what the main function is about to load
%many ways to clean up
%   remove oldest creation first
%   remove oldest acessed first
%may not handle directories correctly

dir_q=fullfile(cache_opts.dir,[cache_opts.file_name_start,cache_opts.delim,fun_str,cache_opts.delim,'*.mat']);
dir_content=dir(dir_q);
file_dates=cell2mat({dir_content.datenum});
file_dates=posixtime(datetime(file_dates,'ConvertFrom','datenum'));
file_sizes=cell2mat({dir_content.bytes});
file_names={dir_content.name};

nowdt=datetime('now');
now_posix=posixtime(nowdt);

if numel(file_names)>cache_opts.depth_n
    fprintf('cache too big in N need to clean up\n')
end
if sum(file_sizes)*1e-9>cache_opts.depth_gb
    fprintf('cache too big in gb need to clean up\n')
end
if max(file_dates+cache_opts.depth_seconds)<now_posix
    fprintf('cache too old need to clean up\n')
end

% split by cache_opts.delim after striping the end .mat
file_names_split=cellfun(@(x) strsplit(strrep(x,'.mat',''),cache_opts.delim),...
   file_names,'UniformOutput',0);
%pass only file names that do hot have the input hash your about to load
mask=cellfun(@(x) ~isequal(hash_fun_inputs,x{3}),file_names_split);
file_names=file_names(mask);
file_dates=file_dates(mask);
file_sizes=file_sizes(mask);

%this is the simplest implmentation, by sorting by time we delete the oldest
%does the file mode date change when acessed??
%this could be done better be weigting based on file size ect
[~,ordering]=sort(file_dates);
file_names=file_names(ordering);
file_dates=file_dates(ordering);
file_sizes=file_sizes(ordering);


disk_size_kill=cumsum(file_sizes)>cache_opts.depth_gb*1e9;
old_kill=(file_dates+cache_opts.depth_seconds)<now_posix;
number_kill=(1:numel(disk_size_kill))>cache_opts.depth_n;

any_kill=disk_size_kill | old_kill | number_kill;

kill_index=(1:numel(any_kill)).*any_kill;
kill_index=kill_index(kill_index~=0);

iimax=numel(kill_index);
for ii=1:iimax
    file_path=fullfile(cache_opts.dir,file_names{ii});
    delete(file_path);
end

   
end