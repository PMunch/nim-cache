# cache
This module implements a simple cache. The cache takes a getter procedure
with an input argument and an output and wraps it in such a way that
querying the cache for this value will either fetch the value from the cache
or call the getter and get the value while populating the cache. The cache
also supports manually invalidating entries based on input argument, as well
as the two strategies LeastRecentlyUsed and LeastRecentlyFetched which
allows clearing either the entries that haven't been used for the longest,
or which was fetched the longest time ago respectively. The implementation
is fairly optimised, but further optimisations could be made.
