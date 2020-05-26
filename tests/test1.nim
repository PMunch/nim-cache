import unittest
import "../src/cache.nim"
import os
import times
import lists

type FreshIndicator = distinct bool

proc `==`(a: var FreshIndicator, b: bool): bool =
  result = a.bool == b
  reset a

var fresh: FreshIndicator

proc greet(x: string): string =
  sleep(100)
  fresh = true.FreshIndicator
  return "hello " & x

suite "least recently used cache":
  test "simple entry":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("peter") == "hello peter"
    assert fresh == false
    assert x.len == 1
  test "get with cutoff":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("peter", epochTime()) == "hello peter"
    assert fresh == true
    assert x.get("peter") == "hello peter"
    assert fresh == false
  test "clean based on time":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert x.get("bob") == "hello bob"
    assert fresh == false
    var oldest = epochTime() # both were fetched before this
    assert x.get("peter") == "hello peter" # This should update last used time
    assert fresh == false
    assert x.len == 2 # peter and bob
    x.clean oldest
    assert x.len == 1 # only bob should be left
    assert x.get("bob") == "hello bob"
    assert fresh == true # Check that bob was removed from the cache
    assert x.get("peter") == "hello peter"
    assert fresh == false # Check that peter is still in the cache
  test "clean based on count":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("tim") == "hello tim"
    assert fresh == true
    assert x.get("bob") == "hello bob" # bob should now be the only left after cleaning
    assert fresh == false
    assert x.len == 3
    x.clean 1
    assert x.len == 1
    assert x.get("bob") == "hello bob"
    assert fresh == false
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("tim") == "hello tim"
    assert fresh == true
  test "invalidate entry":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    x.invalidate "peter"
    assert x.get("peter") == "hello peter"
    assert fresh == true
  test "iterate in order":
    var x = initLRUCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("peter") == "hello peter" # This should update last used time
    assert fresh == false
    assert x.len == 2 # peter and bob
    var i = 0
    for value in x:
      assert value == ["hello bob", "hello peter"][i]
      inc i

suite "least recently fetched cache":
  test "simple entry":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("peter") == "hello peter"
    assert fresh == false
    assert x.len == 1
  test "get with cutoff":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("peter", epochTime()) == "hello peter"
    assert fresh == true
    assert x.get("peter") == "hello peter"
    assert fresh == false
  test "clean based on time":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    var oldest = epochTime() # peter was fetched before this
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert x.get("bob") == "hello bob"
    assert fresh == false
    assert x.get("peter") == "hello peter" # This should not affect anything
    assert fresh == false
    assert x.len == 2 # peter and bob
    x.clean oldest
    assert x.len == 1 # only peter should be left
    assert x.get("bob") == "hello bob"
    assert fresh == false # Check that bob was removed from the cache
    assert x.get("peter") == "hello peter"
    assert fresh == true # Check that peter is still in the cache
  test "clean based on count":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("tim") == "hello tim"
    assert fresh == true
    assert x.get("bob") == "hello bob" # This should not affect anything
    assert fresh == false
    assert x.len == 3
    x.clean 1
    assert x.len == 1
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("tim") == "hello tim"
    assert fresh == false
  test "invalidate entry":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    x.invalidate "peter"
    assert x.get("peter") == "hello peter"
    assert fresh == true
  test "iterate in order":
    var x = initLRFCache(greet)
    assert x.get("peter") == "hello peter"
    assert fresh == true
    assert x.get("bob") == "hello bob"
    assert fresh == true
    assert x.get("peter") == "hello peter" # This should not do anything
    assert fresh == false
    assert x.len == 2 # peter and bob
    var i = 0
    for value in x:
      assert value == ["hello peter", "hello bob"][i]
      inc i
