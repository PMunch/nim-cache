## This module implements a simple cache. The cache takes a getter procedure
## with an input argument and an output and wraps it in such a way that
## querying the cache for this value will either fetch the value from the cache
## or call the getter and get the value while populating the cache. The cache
## also supports manually invalidating entries based on input argument, as well
## as the two strategies LeastRecentlyUsed and LeastRecentlyFetched which
## allows clearing either the entries that haven't been used for the longest,
## or which was fetched the longest time ago respectively. The implementation
## is fairly optimised, but further optimisations could be made.

import lists, tables, times

type
  CacheStrategy* = enum LeastRecentlyUsed, LeastRecentlyFetched
  CacheEntry[X, Y] = object
    key: X
    value: Y
    timestamp: float
  Cache*[X, Y; strat: static[CacheStrategy]] = ref object
    values: Table[X, DoublyLinkedNode[CacheEntry[X, Y]]]
    order: DoublyLinkedList[CacheEntry[X, Y]]
    getter: proc(x: X): Y

proc initCache*[X, Y; strat: static[CacheStrategy]](
    getter: proc(x: X): Y): Cache[X, Y, strat] =
  ## Initialise the cache. Takes a procedure that takes an argument and returns
  ## something. `X` has to be
  ## [hashable](https://nim-lang.org/docs/tables.html#basic-usage-hashing).
  ## Also accepts a `CacheStrategy` that determines how the cache works when
  ## cleaning and getting entries.
  Cache[X, Y, strat](
    getter: getter, order: initDoublyLinkedList[CacheEntry[X, Y]]())

template initLRUCache*[X, Y](
  getter: proc(x: X): Y): Cache[X, Y, LeastRecentlyUsed] =
  ## Convenience template to create a `LeastRecentlyUsed` cache.
  initCache[X, Y, LeastRecentlyUsed](getter)

template initLRFCache*[X, Y](
  getter: proc(x: X): Y): Cache[X, Y, LeastRecentlyFetched] =
  ## Convenience template to create a `LeastRecentlyFetched` cache.
  initCache[X, Y, LeastRecentlyFetched](getter)

proc get*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], x: X, oldest = 0.0): Y =
  ## Gets an element from the cache, if it doesn't exist the registered getter
  ## procedure will get called and the cache will be populated with this value.
  ## If you supply an `oldest` value it will either check that the last usage
  ## of the element, or its fetched time is after this timestamp depending on
  ## the `CacheStrategy`. If it isn't it will be updated in the cache by
  ## calling the getter again.
  if not cache.values.hasKey(x) or
    cache.values[x].value.timestamp < oldest:
    if cache.values.hasKey(x):
      cache.order.remove cache.values[x]
      cache.values.del x
    let
      val = cache.getter(x)
      node = newDoublyLinkedNode(
        CacheEntry[X, Y](key: x, value: val, timestamp: epochTime()))
    cache.order.append node
    cache.values[x] = node
    return val
  else:
    let node = cache.values[x]
    when strat == LeastRecentlyUsed:
      node.value.timestamp = epochTime()
      cache.order.remove node
      cache.order.append node
    return node.value.value

proc clean*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], maxItems: int) =
  ## Remove elements in order until the length of the cache is equal or smaller
  ## than maxItems. The order depends on the `CacheStrategy` and is either
  ## first used to last used or oldest to youngest.
  while cache.values.len > maxItems:
    let first = cache.order.head
    cache.values.del first.value.key
    cache.order.remove first

proc clean*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], oldest: float) =
  ## Remove elements in order until the element is either last used after
  ## `oldest` or was fetched after `oldest` depending on `CacheStrategy`.
  while cache.values.len > 0:
    let first = cache.order.head
    if first.value.timestamp < oldest:
      cache.values.del first.value.key
      cache.order.remove first
    else: break

proc len*[X, Y; strat: static[CacheStrategy]](cache: Cache[X, Y, strat]): int =
  ## Returns the amount of elements in the cache.
  cache.values.len

proc invalidate*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], key: X) =
  ## Removes an element from the cache by the given key. Next time this is
  ## accessed it will be fetched again.
  if cache.values.hasKey(key):
    cache.order.remove cache.values[key]
    cache.values.del key

iterator items*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat]): Y =
  ## Iterate over the values in the cache, in either first used to last used or
  ## oldest to youngest order depending on `CacheStrategy`.
  for item in lists.items(cache.order):
    yield item.value

iterator pairs*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat]): (X, Y) =
  ## Iterate over the key/value pairs in the cache, in either first used to
  ## last used or oldest to youngest order depending on `CacheStrategy`.
  for item in lists.items(cache.order):
    yield (item.key, item.value)

iterator nodes[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat]): DoublyLinkedNode[CacheEntry[X, Y]] =
  for item in cache.order.nodes:
    yield item

proc `$`*[X, Y; strat: static[CacheStrategy]](cache: Cache[X, Y, strat]): string =
  ## Creates a string representation of the cache, mainly useful for debugging
  ## purposes.
  result = "{"
  for node in cache.nodes:
    result &= "\"" & $node.value.key &
      ": (value: \"" & $node.value.value &
      "\", " & (when strat == LeastRecentlyUsed: "lastUsed" else: "fetched") &
        ": " & $node.value.timestamp & "), "
  result.setLen result.len - 2
  result &= "}"

proc hasKey*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], key: X): bool =
  ## Return true if the cache has the given key or if getting it would result
  ## in a new call to the getter.
  cache.hasKey(key)

proc clear*[X, Y; strat: static[CacheStrategy]](cache: Cache[X, Y, strat]) =
  ## Removes all values from the cache.
  cache.values.clear
  cache.order = initDoublyLinkedList[CacheEntry[X, Y]]()

template `[]`*[X, Y; strat: static[CacheStrategy]](
  cache: Cache[X, Y, strat], key: X): Y =
  ## Alias for `get` without an `oldest` time limit.
  cache.get(key)
