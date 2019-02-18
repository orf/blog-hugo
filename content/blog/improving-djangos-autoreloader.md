---
title: "Adding Watchman support to Django's autoreloader"
date: "2019-01-13T12:07:22Z"
draft: true
tags:
  - django
---

Over a year ago I set out to try and improve Django's autoreloader implementation. My 
[PR was recently merged](https://github.com/django/django/pull/8819/) and I thought I would write down a few things 
about it, and autoreloading in general, here.

The role of an autoreloader is conceptually pretty simple: When a developer changes a file your software should detect 
this and make those changes visible to the developer. Autoreloaders are pretty ubiquitious - most development tools and 
frameworks ship with one and for the most part they give a great speed boost while you are working. 

A good autoreloader is also surprisingly hard to implement and suffers from a fairly unique set of problems. The 
implementation can differ signficantly between languages - some languages make auto-reloading easier to implement and 
some, like Python, make it harder. However broadly speaking an autoreloader is one of two types: hot or cold. 
The most common type is a cold autoreloader which is typically implemented by simply restarting the system when a change 
is detected, therefore allowing it to load the new code and thus make your changes available. An example of this would
be a tool that refreshes your browser window when a your JavaScript project is modified, or in Django's case restarts 
the `python` executable itself. Whilst this is the easiest to implement it's also not the greatest experience: you loose 
all state when the system is reloaded: in the case of a web page this would include anything you've written in a text box. 
Annoying!

The second type is hot-reloading, which is far more complicated to implement but offers a much nicer development
experience. Hot reloaders attempt to modify the existing, running code with your modifications without needing a restart. 
The most simple example of this I can think of is changing a CSS file in a browser: the hot-reloader simply needs to 
add the new stylesheet to the page and the browser will take care of actually applying those styles. This is simple 
because the CSS language lacks features that would make this more difficult, but for more complicated languages like 
JavaScript and Python this is practically impossible in the general case. Take 


I'm not going to delve much into how these are implemented, other than to point out why it is impossible to implement in 
Python in

  

Most development tools and frameworks ship with an autoreloader, 
they are fairly ub
and the implementation varies significantly across languages and technologies, but they all fall into two categories: 
hot reloading and cold reloading.