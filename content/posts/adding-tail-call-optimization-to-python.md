---
title: "Adding tail-call optimization to Python"
date: 2013-10-15 19:04:05.293813
tags:
   - experiments
---

Tail-call optimization is a trick many languages and compilers use to avoid creating excess stack frames when dealing with recursive code like this:

```python
def call_1000_times(count=0):
    if count == 1000:
        return True
    else:
        return call_1000_times(count + 1)
```

This function simply calls itself with modified arguments until a condition is met (the count is 1000) at which point it returns True. Because all the function mostly does is return the result of another function call the stack frame does not need to be kept around in memory and can be disposed of or the parents frame could be re-used.

The reference Python implementation (CPython) does not implement tail-call optimization, so running the above code will [hit the recursion limit](https://docs.python.org/2/library/sys.html#sys.getrecursionlimit) and throw an exception.

### Pure python tail-call optimization?
I hacked around for a bit and came up with a pure-python function decorator that will automagically optimize recursive functions like the one below. It appears to be calling itself recursively but its actually doing no such thing else it would hit the recursion limit and explode with an exception:

```python
sys.setrecursionlimit(10)
@tail_call()
def test_tail_count(count=0):
   return count if count == 7000 else test_tail_count(count + 1)
>>> print test_tail_count()
7000
```

#### How?
*If you are feeling brave you can view the code here on GitHub: [https://gist.github.com/orf/41746c53b8eda5b988c5](https://gist.github.com/orf/41746c53b8eda5b988c5)*

I developed two different ways of implementing tail-call recursion, both with advantages/disadvantages.

##### Functools.partial

In the code above the tail_call() wrapper replaces the reference to the test function with a [functools.partial](https://docs.python.org/2/library/functools.html#functools.partial) object while the function is being evaluated. This allows the wrapper to execute each function sequentially rather than recursively, thus avoiding the recursion limit.

This method well and theoretically requires no code changes to the function itself, but it does have some downsides:

   * You can't use the result of calling test function while inside the test function as its not actually called (yet).
   * It's about 20% slower than the normal recursive method
   * It won't work with multithreaded code, as the reference to the function is replaced while it is executing

##### Return tuples
This method is actually slightly faster than normal recursive code according to the benchmarks in the gist above. The test_tail_count function would have to be changed to return a tuple of arguments to be passed to the next call rather than pretending to call itself recursively:

```python
@tail_call(tuple_return=True)
def test_tail_count(count=0):
   return count if count == 7000 else (count + 1, )
```

This has very little overhead as tuples are pretty cheap to create in Python. However it's not as readable as the first method and I haven't worked out how to support keyword arguments yet.

#### Benchmarks
I ran some quick and dirty benchmarks to see how these performed. Each test calculates the 1700th number of the [Fibonacci sequence](https://en.wikipedia.org/wiki/Fibonacci_number) recursively 1000 times and the total time taken is displayed below. I've found that the greater the fibonacci number the faster the optimized versions are compared to the standard recursive method - I used 1700 but your mileage may vary.

   * test_fib_optimize 2.6015851634
   * test_fib_tuple_optimized 1.83400634784
   * test_fib_no_optimize 1.97867649889

As you can see the tuple return method is slightly faster than the standard recursive method, and the functools.partial method is the slowest.


    