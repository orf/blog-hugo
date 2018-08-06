---
title: "Simple."
date: 2012-03-29 04:07:15.509958
permalink: /simple
tags:
    - projects
---

I like things to be simple. So I wrote my own blog software to replace the rather un-simple WordPress. Its not that WordPress its hard to use or install, far from it, Its just got a lot of bloatware in my opinion, so I replaced it with __Simple__.

__Simple__ uses MarkDown to format posts, an aims to be as simple as possible. It consists of a single Python file with a few external resources (css, js and templates), and it has very few dependencies. The footprint on the server is incredibly low and the response time is better than that of WordPress running on Apache. Best of all it doesn't require some big database server like MySQL or PostgreSQL, it runs off a simple Sqlite database file.

When you type a post you appear to type directly on the page, there is no annoying WYSIWYG editor to get in the way:
![Draft](https://i.imgur.com/T9BX4.png)

Posts are arranged into two groups: drafts and non-drafts. You can slowly start work on several ideas at once, and once they form into proper posts publish them to the frontpage.

Its got some nice code highlighting as well, which was one thing that was annoying me with WordPress:
```python
import math
def test(x,y):
         return (x+y) + math.sqrt(x)
```

So yeah. This is one of my new projects.






    