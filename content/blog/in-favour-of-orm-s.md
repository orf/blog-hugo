---
title: "In favour of ORM's"
date: 2012-05-14 19:01:27.528062
permalink: /in-favour-of-orm-s
---

I recently read [this post](https://www.revision-zero.org/orm-haters-do-get-it) entitled "(Some) ORM Haters Do Get It" and I wanted to make a few points in favour of ORM's.

The author of the post argues that ORM's are bad because of [impedance mismatch](https://en.wikipedia.org/wiki/Object-relational_impedance_mismatch). I don't know enough about that subject to comment on it but I have been using ORM's long enough to think that their advantages outweigh their disadvantages. Below I will present a few cases where ORM's are very useful.


### Security ###
Security is a big issue when it comes to web applications. Injection related vulnerabilities rank #1 on the [OWASP top 10 list](https://www.applicure.com/blog/owasp-top-10-2010) which means they consider it the most critical flaw and its easy to see why - they are so common and can do a lot of damage to improperly configured systems. These vulnerabilities usually happen when un-sanitized data is inserted blindly into SQL queries:

```
executeQuery("SELECT * FROM users WHERE user_id = " . $_GET["target_id"])
```

Because the user data (in this case in the WHERE condition) is not escaped or sanitized a malicious user could easily inject malicious SQL into the query to alter the query logic and return another users account.

Using an ORM protects you against that by automatically separating the data from the query. Running the following statement using SQLAlchemy yields the SQL below:
```python
Session.query(Users).filter_by(id=10).one()
```

```sql
SELECT mytable.id AS mytable_id 
FROM mytable 
WHERE mytable.id = ?
```

The data (in this case 10) is sent after this, and the "?" character tells the database to do the right thing and treat the input as data rather than as part of the query, which means malicious input can't alter the query logic.


### Efficiency ###
ORM's are an abstraction layer, and like most abstractions they add overhead, however they can also make database queries more efficient.

Imagine a simple table with an ID column and a text column. If a developer wished to query the text column using a case insensitive ILIKE query:
```sql
SELECT * FROM my_table WHERE text_column ILIKE myinput%
```
This seems like the right thing to do - ILIKE is the same as LIKE except its case insensitive. *Wrong*. On PostgreSQL (and other databases) using ILIKE is not as efficient as the following statement which can utilize an index instead of performing a full table scan:
```sql
SELECT * FROM my_table WHERE lower(text_column) LIKE lower(myinput%)
```

SQLAlchemy automatically does this for you when you use the ILIKE function. Because an ORM is (supposed to be) database independent you could move your code and models to a different database on which ILIKE is more efficient than the code using lower() and the query would be executed more efficiently without you needing to re-write a single line of code.


### Queries as objects ###
When you start treating queries as objects you can do some interesting things. In my film recommendation site the user can choose to filter their recommendations based on a few criteria (director, IMDB score etc). If the user doesn't specify a search query for a certain criteria then that condition is not added to the query:

```python
rec_query = db.session.query(Movie.imdb_id).filter(Movie.imdb_id.in_(id_counters.keys()))
if filter_imdb_score > 0:
    rec_query = rec_query.filter(Movie.imdb_score >= filter_imdb_score)
if filter_director:
    rec_query = rec_query.filter(Movie.director.ilike(filter_director+"%"))
```

Its as simple as that. Without using an ORM (or some other form of query-as-an-object construct) you would have to manipulate raw strings, which can get messy and under some circumstances might result in invalid SQL.

### Migrations ###
Some people argue (as the author points out) that ORM's make migrations hard. I disagree, it couldn't be simpler:

```bash
./manage.py schemamigration myapp --auto && ./manage.py migrate myapp
```

This example uses the [South library](https://south.aeracode.org/docs) to handle the migrations for you (there is a library available for SQLAlchemy as well but I have not used it). Its as simple as editing your Django model to add, remove, rename or otherwise alter a field definition and then run the commands above (substituting myapp for your django application) and you are done - the database schema is updated to reflect the changes and South keeps track of what version of the schema you are using. It also supports [migrating the actual data](https://south.aeracode.org/docs/tutorial/part3.html) when you are doing more advanced migrations.

You can roll back changes just as easily by specifying a version:
```bash
$ ./manage.py migrate myapp 0005
```
It also handles conflict resolution for you. Its pretty neat.
    