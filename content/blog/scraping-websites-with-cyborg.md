---
title: "Scraping websites with Cyborg"
date: 2016-01-04 00:13:02.499716
tags:
   - projects
---

I often find myself creating one-off scripts to scrape data off websites for various reasons. My go-to approach for this is to hack something together with [Requests](https://docs.python-requests.org/en/latest/) and [BeautifulSoup](https://pypi.python.org/pypi/beautifulsoup4), but this was getting tiring. Enter [Cyborg](https://github.com/orf/cyborg), my library that makes writing web scrapers quick and easy.

Cyborg is an asyncio-based pipeline orientated scraping framework - in English that means you create a couple of functions to scrape individual parts of a site and throw them together in a sequence, with each of those parts running asynchronously and in parallel. Imagine you had a site with a list of users and you wanted to get the age and profile picture of each of them. Here's how this is done in Cyborg, showing off some of the cool features:


```python
from cyborg import Job, scraper
from aiopipes.filters import unique
import sys

@scraper("https://somesite.com/list_of_users")
def scrape_user_list(data, response, output):
   for user in response.find("#list_of_users > li"):
       yield from output({
           "username": user.get(".username").text
       })

@scraper("https://somesite.com/user/{username}")
def scrape_user(data, response):
   data['age'] = response.get(".age").text
   data['profile_pic'] = response.get(".pic").attr["href"]
   return data

if __name__ == "__main__":
   pipeline = Job("UserScraper") | scrape_user_list | unique('username') | scrape_user.parallel(5)
   pipeline > sys.stdout
   pipeline.monitor() > sys.stdout
   pipeline.run_until_complete()
```

That's it! The idea behind Cyborg is to keep the focus on the actual scraping, but getting benefits that are usually hard like parallel tasks, error handing and monitoring for free.

The library is very much in alpha, but you can find the project [here on GitHub](https://github.com/orf/cyborg). Feedback welcome!

### Our pipeline
Our pipeline is defined like so:

```python
pipeline = Job("UserScraper") | scrape_user_list | unique('username') | scrape_user.parallel(5)
pipeline > sys.stdout
```

The `Job()` class is the start of our pipeline and it holds information like the name of the task ('UserScraper'). We use the `|` operator to add tasks to the pipeline, the first one being `scrape_user_list`. Any output from that task is passed to `unique`, which as you may have guessed filters out duplicate usernames that may be produced. This then passes output to the `scrape_user` function, and the `.parallel(5)` means start 5 parallel workers to process usernames.

The `>` operator is used to pipe the output of the pipeline to the standard output, but this could be any file-like object or function instead. This means you could write an `import_into_database` function that takes some scraped data and use SQL to add them to a database.

A key aim of Cyborg is to make monitoring the pipeline simple. The `pipeline.monitor() > sys.stdout` handles this for us by piping status information every second to the standard output. Below is some sample output from a real version of our pipeline (one that handles pagination and does a bit more work). You can see a progress bar for each task, including the 5 `scrape_user` workers. Error totals are also displayed here, if there are any.


    UserScraper: 3 pipes
    Runtime: 9 seconds
     |-------- scrape_user_list
               Input: 14/26 read.  53% done
               [=========*          ]  14/26
               Tasks:
     |-------- unique 
               Input: 825/825 read. 100% done
               [===================*] 825/825
     |-------- scrape_user
               Input: 8/825 read.   0% done
               [*                   ]   8/825
               Tasks:
      |------- [*                   ]   3/66
      |------- [*                   ]   3/92
      |------- [===*                ]   5/22
      |------- [===============*    ]   8/10


### Scrapers
A scraper is a function decorated with `@scraper`, with the first argument being the page URL that is to be scraped. The response to that URL is passed as a parameter to the function, and the function should parse it to extract relevant information.

The `scrape_user_list` function is fairly simple, it takes a static URL (`/list_of_users`) and runs a simple CSS query on it to find HTML elements we are interested in using. It then uses `yield from output` to output a dictionary to the next phase of the pipeline. We need to use a `yield from` statement here as our scraper could produce an arbitrary number of outputs, so the `yield from` ensures that output is buffered until tasks further down the pipeline are ready to handle them.

The dictionary produced by `scrape_user_list` is used to format the `scrape_user` URL. So if `scrape_user_list` produces `{'username': 'test'}` then `scrape_user`'s URL will be resolved to `/user/test`. This is then fetched and the age + profile picture is extracted from the response and the output passed on. As this is the last function in the pipeline then it gets output to `stdout` in JSON format.


## The library itself
The library is pretty new, I wrote a 'draft' version that I wasn't very happy and this is a re-write much closer to what I had imagined originally. You can [find the code on GitHub](https://github.com/orf/cyborg), or use `pip install cyborg` to get it installed locally.
    