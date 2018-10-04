+++
title = "Bulk Update lands in Django 2.2"
date = "2018-10-04T19:36:02+01:00"
tags = ['django']
+++

My work on [adding `bulk_update()` to Django](https://github.com/django/django/pull/9606) has
been merged and will be released in Django 2.2! Like my [filtered aggregates feature](/filtered-aggregates-lands-in-django-2.0/) 
it relies heavily on the wonderfully versatile `CASE` statement to achieve some pretty good speedups for certain use-cases.

The [development documentation](https://docs.djangoproject.com/en/dev/ref/models/querysets/#bulk-update) 
gives a pretty clear example as to why it's useful, but I'll expand on it below a bit.

## The problem

A not-so uncommon use case in Django is iterating through some models, changing a field and saving the results back to 
the database. For example:

```python
# Translate our posts into German
for post in Post.objects.all():
    post.title = translate_to_german(post.title)
    post.save()
```

Each call to `post.save()` will execute a single, individual `UPDATE` statement, so if you've got a million rows to update 
this can be a significant slowdown.

The most performant way of achieving this is to try and push the computation down into the database. For example here we 
tell the database to add 10,000 views to each of our posts:

```python
# Make our posts look really popular!
Post.objects.update(view_count=F('view_count') + 10000)
```

For simple numerical operations or basic string manipulations this is a great way of quickly updating a lot of rows. But 
in our first example we want to translate our post titles to German, no databases can do that natively (not yet at least!), 
so you are stuck with 1 query per model.

## The solution

With `.bulk_update()` you can now update these rows with a greatly reduced number of queries (typically 1):

```python
posts = list(Post.objects.all())
for post in posts:
    post.title = translate_to_german(post.title)
# Save all objects in 1 query
Post.objects.bulk_update(posts, ['title'])
```

Yay! Much better. With a large number of rows this is much more efficient, as the database has to do a *lot* less work.

## The implementation

The implementation turned out to be pretty straightforward. We utilize the `CASE` statement inside an `UPDATE` to customize 
the values we update. For example:

```sql
UPDATE posts
SET title=(CASE
            WHEN id=1 THEN 'Title 1'
            WHEN id=2 THEN 'Title 2'
           END)
WHERE id IN (1, 2)
```

The only tricky part of this process is with Postgres, which has some strict typing rules about expressions. If you have 
a `CASE` statement where all values are `NULL` it is unable to determine the type of the expression and fails. So we 
need to add an explicit `CAST`:

```sql
UPDATE posts
SET title=(CASE WHEN id=1 THEN NULL
                WHEN id=2 THEN NULL
           END)::TEXT
WHERE id IN (1, 2)
```

Django's expressions framework actually supported all of this already, so the method is just a nice wrapper around 
creating the `CASE` expressions and handing a few corner cases.

## Future work

Postgres actually [supports a nicer syntax for this](https://stackoverflow.com/questions/18797608/update-multiple-rows-in-same-query-using-postgresql)
which is even more performant than `CASE`:

```sql
update posts as t set
    title = c.title
from (values
    ('Title 1', 1),
    ('Title 2', 2)  
) as c(title, id) 
where c.id = t.id;
```

However this is going to take a bit more work as we currency do not support `VALUES` in this way. You can 
[follow the ticket here](https://code.djangoproject.com/ticket/29771#ticket).