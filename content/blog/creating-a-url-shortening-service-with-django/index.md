---
title: "Creating a URL shortening service with Django"
date: 2012-04-20 17:11:49.705511
permalink: /creating-a-url-shortening-service-with-django
tags:
   - projects
---

*View it live [here](https://links.tomforb.es) or get the [code here](https://github.com/orf/tinylink)*

The first URL shortening site I saw was several years ago and was called [TinyURL](https://tinyurl.com/). Soon after Twitter gained popularity a whole slew of them popped up ([bitly](https://bitly.com/), [tiny.cc](https://tiny.cc/), [is.gd](https://is.gd/)) to cater for the masses constrained by Twitters 140 character limit, but a lot shut down because it is fairly hard to monetize and Twitter shortens URL's now, making them a bit pointless.

At its heart a URL shortening service is simply a database that maps a short string to a URL, not exactly rocket science to create. Below I will give a basic walk through guide to creating one yourself. Knowledge of Django and Python is assumed.

Start by making a project and creating our models:

```python
#models.py
from django.db import models
import string

_char_map = string.ascii_letters+string.digits

def index_to_char(sequence):
    return "".join([_char_map[x] for x in sequence])


class Link(models.Model):
    link = models.URLField()
    hits = models.IntegerField(default=0)

    def __repr__(self):
        return "<Link (Hits %s): %s>"%(self.hits, self.link)

    def get_short_id(self):
        _id = self.id
        digits = []
        while _id > 0:
            rem = _id % 62
            digits.append(rem)
            _id /= 62
        digits.reverse()
        return index_to_char(digits)

    @staticmethod
    def decode_id(string):
        i = 0
        for c in string:
            i = i * 64 + _char_map.index(c)
        return i
```

This model is fairly basic - it stores a URL and a integer representing the number of times the link has been clicked (we will write the view for this later). The get_short_id() method returns the character representation of the ID - we have 62 possible characters (a-z A-Z 0-9) so we convert the number to base 62 and map the digits to characters in our alphabet. This means we can give visitors URL's like *https://mylinksite/abcde* and the *abcde* portion of the URL will hold the link ID. This looks a lot nicer than just using the numeric ID in the URL.

Now create a simple template. The {% raw %}`{% if %}`{% endraw %} statements are there so we can display the generated URL to the user

```html
<html>
    <body>
        <h1>Enter a URL to shorten:</h1>
        <form method="POST" action="/">
            <input type="text" name="url" placeholder="Enter a URL">
            <input type="submit">
        </form>
        {% if short_url %}
           <b>URL shortened:</b> {{ short_url }}
        {% endif %}
    </body>
</html>
```

Now we need to make the view. This is pretty simple: we take the URL provided by the user in the "url" POST field and store it in the database and return a URL to be displayed to the user. Code that ensures the input is valid and present is not included for brevity.

```python
#views.py
from tiny_link import models
from django.shortcuts import render_to_response
from django.template import RequestContext

def home(request):
   short_url = None
   if request.method == "POST":
      link_db = models.Link()
      link_db.link = request.POST.get("url")
      link_db.save()
      short_url = request.build_absolute_uri(link_db.get_short_id())
   return render_to_response("index.html",
                             {"short_url":short_url},
                             context_instance=RequestContext(request))
```

Simple! Now we will make a quick view to redirect the user:

```python
#views.py
from django.shortcuts import redirect, get_object_or_404
from django.db.models import F

def link(request, id):
   db_id = models.Link.deocde_id(id)
   link_db = get_object_or_404(models.Link, id=db_id)
   models.Link.objects.filter(id=db_id).update(hits=F('hits')+1)
   return redirect(link_db.link)
```

This view is pretty simple - we decode the given string (e.g abcd) into an integer, and we use that to get the link from the database. After that we issue a UPDATE statement that increments the hits by 1 (this should be done at the database level else increments might get lost due to concurrent updating of the model with stale data), and then we send the user on their merry way.

Now edit your URL file to serve the views:

```python
from django.conf.urls import patterns, include, url

urlpatterns = patterns('',
    url(r'^$', 'tiny_link.views.home'),
    url(r'^(?P<id>[a-zA-Z0-9])$', 'tiny_link.views.link'),
    url(r'^(?P<id>[a-zA-Z0-9])/stats$', 'tiny_link.views.stats'),
)
```

And thats a wrap. The code linked at the top of the page has a few more bells and whistles, including per-day visitor tracking and graphs (soon), but the core is the same. In my opinion creating a URL shortener is more simple than the canonical "create a blog" introduction project.
    