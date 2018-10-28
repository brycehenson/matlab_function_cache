function test_data=data_load_test_fun(fopt,runtime)
file_path=fopt.path;
load(file_path,'test_data')
tic
%lets define a reall slow function with a reasonably small output
rng(0);
wait_time=runtime-toc;
if wait_time>0
    pause(wait_time);
else
    warning('runtime exceeded requested')
end
end

