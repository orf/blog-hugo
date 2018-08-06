---
title: "Suggestions added to Django manage.py"
date: 2018-02-24
permalink: /django-manage-suggestions
tags:
   - django
---

My recently merged PR for [ticket #28398](https://code.djangoproject.com/ticket/28398) adds very simple 'did you mean'
suggestions to Django's `manage.py` command, which is the primary way of interacting with Django from the terminal. So in Django 
2.1 this is what you will expect to see if you misspell a management command:

```
$ python3 manage.py run-server
Unknown command 'run-server'. Did you mean runserver?
Type 'manage.py help' for usage.
```

There are many criticisms that you can levy at the NodeJS/Javascript ecosystem but one thing that they tend 
to get correct is 'developer friendliness', e.g tools that lend themselves to being easy to use out of 
the box with little or no configuration. This means that tools are expected to auto-reload, produce coloured output
and be fairly simple to invoke right off the bat. Obviously this isn't a universal rule - things like webpack configuration
is an art unto itself, but in general I think it holds true, and I think perhaps the Python ecosystem could take a few lessons 
from NodeJS (especially around packaging, but that's getting better thanks to `pipenv` and `pipsi`). That being said, since 
[switching to gatsby](/goodbye-simple-hello-gatsby) I've found a [few](https://github.com/gatsbyjs/gatsby/issues/3551) 
[bugs](https://github.com/gatsbyjs/gatsby/issues/4216) with the development experience.
 
This may seem like something pretty insignificant to anyone who has worked with Django for any extended period of time 
but for an absolute beginner it can be quite helpful. I've onboarded a couple of junior developers who had very 
little experience with Django and one thing that tripped them up initially was the name of the commands they should run, 
and how if they made a typo in the command name the output is indistinguishable from the command not existing at all.

The implementation for this was very simple, [and you can see the code here](https://github.com/django/django/pull/9703/files). 
Specifically it leverages a great standard library function 
[`difflib.get_close_matches`](https://docs.python.org/3.6/library/difflib.html#difflib.get_close_matches), which simply 
takes a search string (the command a user is trying to execute) and an iterable of things to match from. So when a user 
invokes a command that isn't known we feed a list of all possible commands (built in *and* third party!) into this method, 
along with the users input, and it returns the closest match.

I think this method is a hidden gem in the standard library, and can be invoked like this:

```python
from difflib import get_close_matches
matches = get_close_matches('run-server', ['runserver', 'migrate'])
# matches = ['runserver']
```

If it wasn't for this standard library method Django would have to ship it's own algorithm for suggesting commands.
There is a somewhat simple and effective algorithm you can use, called the 
[Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance#Computing_Levenshtein_distance), but having 
a standard library function to take care of this for us is great as it takes the maintenance burden for that potentially 
hairy code away from Django.