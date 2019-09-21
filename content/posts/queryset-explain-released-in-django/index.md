+++
title = "Queryset.explain() released in Django 2.1"
date = "2018-08-01T20:29:29+01:00"
tags = ['django']
+++

While working on any large-ish Django project you are bound to come across a slow query that's 
perhaps missing an index or doing something else expensive. My workflow for diagnosing this was to 
get the query that is being executed (`str(queryset.query)`) and paste it into a database shell, 
prefixing it with `EXPLAIN`. The database would then give you the query plan which reveals the most 
expensive parts and can be a great help in optimizing it. This can be quite cumbersome though as 
you often have to fix up parts of the query to make it successfully execute, and it involves copy-pasting 
into another tool.

The latest release of Django (2.1) includes a feature that I implemented which should 
automate all of this for you in a way that works with whatever database you are using:
[Queryset.explain()](https://docs.djangoproject.com/en/2.1/ref/models/querysets/#django.db.models.query.QuerySet.explain).

Quite simply, given a `Queryset` you can run `print(queryset.explain())` and it will execute the 
query with the appropriate prefix for your database and return the query plan.

For example, from the Django documentation:

```python
>>> print(Blog.objects.filter(title='My Blog').explain())
Seq Scan on blog  (cost=0.00..35.50 rows=10 width=12)
  Filter: (title = 'My Blog'::bpchar)
``` 

This is obviously a pretty simple query, but if you're using `select_related()` or doing other 
complex joins it will show you the complete plan.

If you're using Postgres or MySQL you can add keywords to the call to get more detailed information: 

```python
>>> print(Blog.objects.filter(title='My Blog').explain(verbose=True))
Seq Scan on public.blog  (cost=0.00..35.50 rows=10 width=12) (actual time=0.004..0.004 rows=10 loops=1)
  Output: id, title
  Filter: (blog.title = 'My Blog'::bpchar)
Planning time: 0.064 ms
Execution time: 0.058 ms
```

## Implementation

The [code changes needed to implement this in Django](https://github.com/django/django/pull/9053) 
where not too bad, compared to other database related work that I have done in the past.

All backends define a `explain_prefix` string, and while executing  the `QuerySet` we check if the query is an
'explained' query (`.explain()` has been called on it). If so we prefix the query with this string and execute the query.

The results of this is different for each backend. With Postgres you get a nice human-readable string back, but with 
MySQL you get a table result that we coerce into a string before returning.

There is some extra logic to handle special database-specific parameters (`verbose` in Postgres for example), but that 
is pretty much it.

### Why does this not work on Oracle?

I'm glad you asked. The documentation says that:

> explain() is supported by all built-in database backends except Oracle because an implementation there isn’t straightforward.

This is a huge understatement. During my work on this feature I was amazed at how complex this was to implement on Oracle, 
versus the simplicity of other databases. Here is how you get the query execution plan:

1. Prefix your query with `EXPLAIN PLAN FOR`
2. This writes your query plan into a special table. You need to give `EXPLAIN PLAN FOR` a specific UID per plan.
   1. The special table is not created per-user, and there is no way to know it has been renamed
3. Execute [`DBMS_XPLAN.DISPLAY()`](https://docs.oracle.com/cd/B19306_01/server.102/b14211/ex_plan.htm#i16971)
   procedure to convert the plan into a human readable output
   1. You need the correct statement ID given above
   2. You also have no real way of knowing if this function is available or can be called without error

So this is a pretty complex workflow to just get a query plan, but it's doable. I had this feature working in my 
branch and it seemed OK. Until I hit a blocker.

<center><strong>You cannot explain parameterized queries</strong></center>

<center>![](./wat.jpg)</center>

Yeah. So... that's a blocker. All queries in Django are parameterized to prevent SQL injections, so rather than executing 
```SQL
SELECT * FROM table WHERE id = 1;
```

Django would execute:

```SQL
SELECT * FROM table WHERE id = ?;
```

and pass `1` as the parameter (denoted as `?` in the query above). With oracle you cannot do this, all parameters must 
be filled in.

So that's why we cannot support Oracle with this, which kind of sucks.