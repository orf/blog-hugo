+++
title = "Filtered aggregates lands in Django 2.0!"
date = "2018-05-12T15:00:39+01:00"
tags = ['django']
+++

Big Django projects often suffer from a few problems regarding database modelling and relations. Django provides 
incredibly easy to use tools to model your domain along with an awesomely powerful ORM to query on them. 
Often back office reporting software written in Django makes extensive use of the annotations and aggregations features:

```python
annotated_employees = Employee.objects.annotate(
    total_expenses=Sum('expenses__cost'),
    total_holidays=Count('holidays')
)

for employee in annotated_employees:
    print(f'Expense total: {employee.total_expenses}')
    print(f'Holidays taken: {employee.total_holidays}')
```

This works well but you run into an immediate problem if you want to only count *taken holidays* or *approved expenses*. 
The results of the computations above give no way to filter on the subset of rows you want to aggregate. This is a problem 
that I ran into a lot, so much so that I decided to have a go at fixing it in Django itself. I'm happy to say that [this 
was merged and released in Django 2.0](https://github.com/django/django/pull/8352/)! All built in aggregations now take
a `filter` argument that is a `Q` object, allowing you to do advanced filtering on all rows. You can even filter on 
sub-relations!

```python
annotated_employees = Employee.objects.annotate(
    total_expenses=Sum('expenses__cost', filter=Q(is_approved=True)),
    total_holidays=Count('holidays', filter=Q(cancelled=False)),
)
```

### The implementation

The SQL 2003 standard provides [a nice way to do this](https://modern-sql.com/feature/filter): `SUM(field) FILTER (WHERE ...)`. 
Unfortunately only Postgres supports this syntax, so for all other backends we emulate it with a `CASE` statement:

```sql
SUM(CASE WHEN condition THEN field)
```

This works because `SUM()` and other built in aggregates ignore `NULL` values, and if `condition` is `false` then `NULL` 
is returned.