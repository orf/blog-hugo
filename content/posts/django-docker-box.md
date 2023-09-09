---
title: "Django Docker Box is now an official Django project!"
date: 2019-10-17T22:40:54+01:00
tags:
- projects
- django
---

When I was working on [adding `queryset.explain()` to Django]({{< ref "posts/queryset-explain-released-in-django" >}})
I got annoyed by how complex it was to set up a local Django environment with multiple databases and versions.
The traditional way of handling this was to use [django-box](https://github.com/django/django-box) which utilizes 
Vagrant to spin up a VM and install different types of database. But it suffered from a few problems:

1. It was really slow
2. It didn't help you test against different database *versions*
3. It used Vagrant, which is like totally not cool anymore.

So I built [django-docker-box](https://github.com/django/django-docker-box) to make this easier. I made it for my 
personal use at first, but after I put it on Github people responded really positively to it. And, in the last couple 
of weeks it's been ~~shamelessly stolen from my personal github~~ made an official Django project as a replacement 
for django-box entirely 🎉

## How does it work?

Basically it's [190 lines of YAML](https://github.com/django/django-docker-box/blob/master/docker-compose.yml).

It turns out that `docker-compose` is a near perfect match for this kind of tool. It allows you to really quickly 
spin up and switch different database versions. For example you can now do:

`POSTGRES_VERSION=9.6 docker-compose run --rm postgres`

This will cause Docker to pull the `postgres:9.6` image and spin it up while running the tests.

The tests themselves execute in a docker image, [defined here](https://github.com/django/django-docker-box/blob/master/Dockerfile). 
What's great is that this image is pushed on every CI build, so you can run `docker-compose pull` to get the latest 
image with all the dependencies installed. Getting everything downloaded and installed used to a big pain point at 
Django hackathons and I hope that this will help (as long as the WiFi holds up!).

All in all you can use this to run any one of the 64 different combinations of Python + Database version that Django 
supports. To prove that this is a viable solution 
[I got the full-matrix test suite running on Travis-CI](https://travis-ci.org/django/django-docker-box/builds/572634144) 
and even uncovered some bugs in environments that Jenkins does not cover.

### Integrating with Django

As the docker-compose files live outside of the Django source tree some interesting problems are raised. How do we 
install the Django `pip` dependencies as part of the image build? At first I used a docker volume and installed them 
at build time, but this sucked because the dependencies would need to be re-installed a lot and could not be shared 
between different invocations of the tool.

So I came up with a neat workaround: the `DJANGO_PATH` environment variable is 
[used as the build context](https://github.com/django/django-docker-box/blob/master/docker-compose.yml#L6), which 
allows us to [copy and install the Django test requirements at build time](https://github.com/django/django-docker-box/blob/master/Dockerfile#L34-L36).

## What about Oracle?

As usual: a complete clusterfuck. The less said the better to be honest, so the tl;dr is:

1. It kind of supports it, but not really.
2. It requires an Oracle license to pull the database image.
3. The database takes upwards of 40 minutes to boot on the first run, and is 7+ GB.
4. You need to download the connection drivers separately, because we cannot distribute them.

I got around #2 by using a random Oracle DB image I found on the Docker hub, but that got taken down for copyright 
infringement 🤷‍. So whatever. If someone wants to improve support in this area then they can.
