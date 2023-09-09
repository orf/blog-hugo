---
title: "Invited to join the Django software foundation"
date: "2018-12-02T19:58:01Z"
tags:
   - django
---

A few days ago I was invited to become a member of the
[Django software foundation](https://www.djangoproject.com/foundation/) due to my contributions to Django. 
Awesome! Now I get to hang about in the super-secret mailing list and discuss django-related illuminati business.

### Removal of core developers

The hot news in Django-land is the proposal to [dissolve the django core development group](https://github.com/django/deps/pull/47/). 
The long and short of it is that Django-core (the core developers working in Django) has stagnated for far too long 
and it's time for a change. 

[A lot has been written about this](https://www.b-list.org/weblog/2018/nov/20/core/) and overall I think it's a great 
proposal. There are big problems with the current model and it will be interesting to see where this goes 
and if it helps. 

Part of the underlying problem is Django is very widely used but the core team is pretty small and percentage-wise 
fairly inactive. We desperately need to make the onboarding process for new Django contributors as painless as possible, 
and there are a few ideas floating around for this. One of my personal pet-peevs is 
[the Django ticket system itself](https://code.djangoproject.com/query). I think that by itself puts a lot of people 
off contributing and is an under-appreciated pain point.

### Future Django work

I've got two big Django-related PR's in the pipeline. The first is to integrate 
[my `docker-compose` based test-suite runner](https://github.com/django/django/pull/10725) into core, which will 
hopefully make it easier for new contributors to get started.

The second [is to completely overhaul the autoreloader implementation](https://github.com/django/django/pull/8819). 
This likely deserves a blog post in itself, but the tl;dr is that the autoreload code is some of the oldest and least 
tested code in Django right now. It's also some of the most important - anyone developing with Django will interact with
the autoreloader on a near constant basis.

