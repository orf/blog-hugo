---
title: "Transplanting/Replacing Django child instances without deleting the parent"
date: 2012-08-31 17:19:20.756751
permalink: /transplanting-replacing-django-child-instances-without-deleting-the-parent
---

Django has a very neat feature called [Multi Table Inheritance](https://docs.djangoproject.com/en/dev/topics/db/models/#multi-table-inheritance) which allows you to create a 'parent' model with common fields and a variety of 'child' ones with specific fields. For example:

```python
class Place(models.Model):
    name = models.CharField(max_length=255)
    telephone = models.CharField(max_length=255)
    email = models.EmailField()

class ChipShop(Place):
    chips_price = models.IntegerField()

class IndianRestaurant(Place):
    curry_price = models.IntegerField()
```


Each ChipShop and IndianRestaurant inherits all the fields from the Place model and you can get all the ChipShops and IndianRestaurants by querying on Place:

```python
for place in Place.objects.all():
    if is_chipshop(place):
        print "%s: Price of Chips: %s"%(place.name, place.chipshop.chips_price)
    else:
        print "%s: Price of Curry: %s"%(place.name, place.indianrestaurant.curry_price)
```


This is pretty cool because you can have as many models as you like inheriting from Place, allowing you to add common fields and functions very very easily with no magic - just normal python subclassing. In my opinion one of its most useful features comes when dealing with foreign keys: You can have lots of foreign keys pointing to a Place, which in turn references a ChipShop or an IndianRestaurant. This means any child of Place can access those related models!

I recently ran into a situation where I wanted to take a ChipShop and turn it into an IndianRestaurant *without* touching the parent Place row (and thus not disturbing any of the foreign keys pointing to it). This is harder than it sounds with Django - deleting a child row will also delete the parent row, which will in turn delete or null all the rows with foreign keys pointing to the parent which is definitely not what we want! Long story short here is a solution that will allow you to delete the child ChipShop row and replace it with a IndianRestaurant without deleting the parent and thus keep foreign keys pointing to the parent Place alive:

```python
from django.db import connection, transaction
place = models.Place.get(id=10)
cursor = connection.cursor()
cursor.execute("DELETE FROM %s WHERE place_ptr_id = %s"%(ChipShop._meta.db_table, place.id))
transaction.commit_unless_managed()
new_chipshop_child = ChipShop()
new_chipshop_child.place_ptr = place
new_chipshop.__dict__.update(place.__dict__)
new_chipshop.save()
```

This works because using cursor.execute will bypass Django's ORM, which in turn bypasses the code that deletes the parent along with the child. Django's multi-table-inheritance works by creating a parent table and then creating a table for each of the children with an integer primary key in the format "parentname_ptr_id", where parentname is the name of the parent class's table. This primary key is the same value as the parent's primary key. So all we need to do is delete that using raw SQL then create a new child, point it to the parent by setting parent_ptr (which will populate parent_ptr_id) and copying all the attributes over by by updating the children's __dict__. Simples.

I wish there was a better way to do this, I have filed a ticket requesting this feature be made available and I will wait to see what the developers say before updating this post.
    