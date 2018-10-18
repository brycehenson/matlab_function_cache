# matlab_function_cache
***Bryce M. Henson***  
A custom disk based function cache for malab.

In my data processing workflow I commonly end up writing my own caching functionality into the fucntions that do the heavy lifting such as importing large datasets. This project aims to create a common utility that can easily be wrapped arround the heavy calculation parts to speed up multiple calls.

## Features
- cached inputs give fast lookup
- function output is not saved in the cache file in the folowing conditions, rather it is just used as a 'dummy' to instruct a function eval
  - if the last load time is longer than the calculation time
  - if the predicted load time is longer than the calculation time
- will hash function string name if too long  
- hash collision check
- indicated cache speedup for high verbose
- basic cache cleanup & clear

## To Do
contributors welcome! There is a lot to do to build this into a powerful tool. Drop me an email. 
- use estimated write speed to estimate if its worth saving the data and abort the save
- documentation and code flow checks
- more testing, particulary agianst memoize()
- smart cache cleaning
  - first in first out is the current method
  - ranking the use/cost of each may be helpfull. eg remove large mediaum age files before older dummy files
- single output wraper so simplify usage

## Contributions  
This project would not have been possible without the many open source tools that it is based on. In no particular order: 

* ***Jan*** [DataHash](https://au.mathworks.com/matlabcentral/fileexchange/31272-datahash?focused=8037540&tab=function)
