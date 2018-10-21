function fun_out=simple_function_cache(varargin)
%wraper to make calling function_cache a little more compact when the fucntion you wish to evaluate only returns a
%single single obj
fun_out=function_cache(varargin{:});
fun_out=fun_out{1};
end
