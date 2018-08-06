---
title: "Using Python metaclasses to make awesome Django model field choices"
date: 2012-08-13 21:57:14.020946
tags:
   - projects
---

*Edit: This code is now on PyPi: [https://pypi.python.org/pypi/django-choice-object](https://pypi.python.org/pypi/django-choice-object)*

tl;dr Metaclasses are awesome

When using Django's Model or Form frameworks you can [define a fixed set of choices for fields](https://docs.djangoproject.com/en/dev/ref/models/fields/#choices) which are list of tuples containing a value and some text to associate with that value. The docs give the example code below to demonstrate how to define and use them, recommending that you define each of the choice values inside the Model as well as the list of choice tuples.

```python
class Student(models.Model):
    FRESHMAN = 'FR'
    SOPHOMORE = 'SO'
    JUNIOR = 'JR'
    SENIOR = 'SR'
    YEAR_IN_SCHOOL_CHOICES = (
        (FRESHMAN, 'Freshman'),
        (SOPHOMORE, 'Sophomore'),
        (JUNIOR, 'Junior'),
        (SENIOR, 'Senior'),
    )
    year_in_school = models.CharField(max_length=2,
                                      choices=YEAR_IN_SCHOOL_CHOICES,
                                      default=FRESHMAN)
```

I personally think that it looks ugly and violates DRY (something Django tries hard not to do) by doing it this way. It seems to me that this is inadequate because if you have a lot of fields with different and distinct choices the models themselves can get very long and messy or if you have two models that need the same choices you have to either have inter-model dependencies which is almost as bad as your other option of duplicating the choices in the other models definition. In my experience the display name of the choice is very similar to the name of the value it is referencing, for example in the code above each of the display text is just a correctly capitalized version of its value's reference so it seems almost silly having to write "sophomore" or "junior" 3 times to define a simple choice.

Wouldn't it be freaking awesome if you could define Django field choices like so:

```python
class YearInSchool(Choice):
    FRESHMAN = 'FR', 'Fresher' # Fresher is the display text
    SOPHOMORE =  'SO'
    JUNIOR = 'JR'
    SENIOR = 'SR', "Senior Student"

class Student(models.Model):
    year_in_school = models.CharField(max_length=2, choices=YearInSchool,
                                  default=YearInSchool.FRESHMAN)

freshers = Student.objects.filter(year_in_school=YearInSchool.FRESHMAN).all()
```

Well with a bit of metaclass magic you can. A [metaclass in python](https://stackoverflow.com/questions/100003/what-is-a-metaclass-in-python?answertab=votes#tab-top) is a class who's instances __are__ classes instead of instances __of__ classes. Kind of. If you are confused by that then have a look at this example code:

```python
class Choice(object):
    class __metaclass__(type):
        def __init__(self, *args, **kwargs):
            print "I am alive!"
            print self

        def __iter__(self):
            for i in xrange(10):
                yield i
```

If you know anything about Python classes then this should look familiar. We define a class called Choice and inside that class we define another one called __metaclass__ which has two special functions (shown by the double underscores surrounding the function name), __init__ and __iter__. Those two methods are 'special' ones that most people know - __init__ gets called when an instance of the class is being created and __iter__ gets called when that instance is being enumerated. With metaclasses its exactly the same but instead of acting on instances of the class it acts on the class itself. Immediately after defining the class above the __init__ gets called and you should see "I am alive!" get printed out as well as the class object self is referencing. Using the code above we can enumerate our class (the __iter__ function gets called)

```pythonshell
>>> list(Choice)
[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

Its as simple as that. You can probably see where I am going here - it wouldn't be hard at all to create a class  that returns its class fields in a form Django accepts for choices when it is being enumerated. Because i'm such a nice guy the code I have come up with is below:

```python
import inspect

class Choice(object):

    class __metaclass__(type):
        def __init__(self, name, type, other):
            self._data = []
            for name, value in inspect.getmembers(self):
                if not name.startswith("_") and not inspect.isfunction(value):
                    if isinstance(value,tuple) and len(value) > 1:
                        data = value
                    else:
                        data = (value, " ".join([x.capitalize() for x in name.split("_")]),)
                    self._data.append(data)
                    setattr(self, name, data[0])


        def __iter__(self):
            for value, data in self._data:
                yield value, data
```

Any subclass of Choice will introspect itself after it has been defined and extract its choices. A choice can be defined as one value or a tuple of (value, display_text). If the display text is not explicitly defined then it is generated from the field name (underscores converted to spaces and capitalized). After this the display name is removed from the class so when you reference it only the value is returned

```python
>>> class UserLevels(Choice):
       USER = 1
       MODERATOR = 2
       ADMIN = 3, "Gods"
>>> list(UserLevels)
[(3, 'Gods'), (2, 'Moderator'), (1, 'User')]
>>> UserLevels.ADMIN
3
```

So yeah. Metaclasses are pretty damn sweet and this makes my Django projects models (which often have 20+ different choice definitions) a lot nicer to look at.

__UPDATE__
You want a way to get the name from a value? No problem. Christopher Trudeau got in contact with me and proposed this code, the difference being an added _get_value_ function that returns the name based on the value, e.g Choice.get_value(1). Thanks Chris!

```python
class Enum(object):
    class __metaclass__(type):
        def __init__(self, *args, **kwargs):
            self._data = []
            for name, value in inspect.getmembers(self):
            if not name.startswith('_') and not inspect.ismethod(value):
                if isinstance(value, tuple) and len(value) > 1:
                    data = value
                else:
                    pieces = [x.capitalize() for x in name.split('_')]
                    data = (value, ' '.join(pieces))
                self._data.append(data)
                setattr(self, name, data[0])

        self._hash = dict(self._data)

        def __iter__(self):
            for value, data in self._data:
                yield (value, data)

    @classmethod
    def get_value(self, key):
        return self._hash[key]
```
    