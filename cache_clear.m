function cache_clear(varargin)
if nargin==0
    cache_opts=[];
else
    cache_opts=varargin{1};
end
if ~isfield(cache_opts,'dir'),cache_opts.dir=fullfile('.','cache'); end
file_path=fullfile(cache_opts.dir,'*');
delete(file_path)
end