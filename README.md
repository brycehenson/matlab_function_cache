# matlab_function_cache
***Bryce M. Henson***
A custom disk based function cache for malab.

In my data processing workflow I commonly end up writing my own caching functionality into the fucntions that do the heavy lifting such as importing large datasets. This project aims to create a common utility that can easily be wrapped arround the heavy parts to speed up multiple calls.

## Features
- cached inputs give fast lookup
- if the load time is longer than the calculation time will not load again (will just calculate the function)
  - in this case it removes the data in the cache file but keeps it as a pointer to do the calculation
  

## To Do
contributors welcome! There is a lot to do to build this into a powerful tool. Drop me an email. 
- documentation and code flow checks
- more testing, particulary agianst memoize()
- smart cache cleaning
  - first in first out is the current method
  - ranking the use/cost of each may be helpfull. eg remove large mediaum age files before older dummy files


  
