# matlab_function_cache
**Bryce M. Henson**   
A custom disk based function cache for malab.
## Status
**This code is ready for limited use in other projects** as the cache cleaning is not completely implemented.

## Description
In my data processing workflow I commonly end up writing my own caching functionality into the fucntions that do the heavy lifting such as importing large datasets. This project aims to create a common utility that can easily be wrapped arround the heavy calculations to speed up multiple calls and allow cache portability between computers.

This code takes a function handle and some input to that function and will look for a cached version. If it exsts (cache hit) it will just load the  saved output and retuns that. Otherwise (cache miss) it will run the function and then save the output for the next time this is asked for. 
The output is saved in the format  'cache__[function handle str|function handle hash]__[inputshash].mat' The function name is hashed if it is longer than the hash would be.

## Usage
for functions that return a single output
```
simple_function_cache([],@magic,{1e4})
```
for multiple outputs
```
outputs=function_cache([],@complicated_function,{1e4,'option1',34});
[output1,output2]=outputs{1:2}
```

## Features
- inputs are hashed using getmd5 for speed
- function output is not saved in the cache file in the folowing conditions, rather it is just used as a 'dummy' to instruct a function eval
  - if the last load time is longer than the calculation time
  - if the predicted load time (based on the in memory output size) at the first function evaluation is longer than the calculation time
- will hash function string name if too long  
- hash collision check
- indicated cache speedup for high verbose
- basic cache cleanup & clear

## To Do
contributors welcome! There is a lot to do to build this into a powerful tool. Drop me an [email](mailto:bryce.m.henson+github.matlab_function_cache@gmail.com?subject=I%20would%20Like%20to%20Contribute[github][matlab_function_cache])
.
- have default options written out as a file
- change cache options to be passed as string value pairs
- documentation and code flow checks
- mock relative file paths
  - so that cache can be portable between many computers when using the same central server
- more testing, 
  - want to go through every evaluation path
  - performance, particulary agianst memoize()
- cache cleaning
  - gloabal cleaning
  - smart cache cleaning
    - first in first out is the current method
    - ranking the use/cost of each may be helpfull. eg remove large mediaum age files before older dummy files

## Contributions  
This project would not have been possible without the many open source tools that it is based on. In no particular order: 
- **Jan** [DataHash](https://au.mathworks.com/matlabcentral/fileexchange/31272-datahash?focused=8037540&tab=function)
- **Jan** [GetMD5](https://au.mathworks.com/matlabcentral/fileexchange/25921-getmd5)
- **Denis Gilbert**    [M-file Header Template](https://au.mathworks.com/matlabcentral/fileexchange/4908-m-file-header-template)
