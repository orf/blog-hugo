---
title: "Making a film recommendation site by cheating"
date: 2012-05-08 05:51:42.682949
tags:
   - projects
---

_View the site here: [https://movies.tomforb.es](https://movies.tomforb.es) or the code [here](https://github.com/orf/MovieFinder)_

To distract me from my ever approaching 1st year exams I decided to create a site that recommends people films to watch based upon their previous viewing habits. I gave it to my girlfriend to use and evaluate and she gave positive feedback - we even found and enjoyed a few films through it that we would never have found without it. As with most things technological the how is better than the why and what, so in this post I will talk a bit about its internals and specifically how it works by cheating.


### How to use it ###
The site is pretty cool. You sign in using Facebook (or sign up using your email) and you will be taken to a page where you can search for previous films you have watched. Simply type in a name of a film you have liked and press the green thumbs up next to its name to add it to the list of films you have enjoyed. Once you have added a few (10+) films click on the "Show me my recommendations" button and you will be taken to a page listing films the site thinks you will like. For each recommendation you will get a film poster, a short description and some other metadata about it (like who stars in it, its ratings and language). You can watch the youtube trailer for it by clicking the blue film icon, or if you have seen it you can add it to your watch list with the green thumbs up, and conversely if you have seen it and disliked it click the red thumbs down to hide the film forever. Click the plus button if you are interested in seeing it to save it for watching later.


### tl;dr ###
The site cheats and uses the IMDB's static search files hosted on S3 meaning it doesn't need to have a complete movie dataset. When a user says they have watched a film the site cheats and pulls the metadata  from IMDB using a task queue into the database along with all the films the IMDB recommends. When a user wishes to see his recommendations the most recommended films out of all the films he has watched and liked are displayed.


### How it works ###
The site itself is a mix of technologies: its written in Python using the Flask micro-framework, served by a few gunicorn instances sitting behind nginx. It uses PostgreSQL to store the data and celery to pull jobs from a RabbitMQ task queue. The frontend uses Backbone.js to power it (and this was my first experience using it - a positive one).


#### The Backend ####

The way the site "cheats" might take a bit of explaining, and will start with the search page. Most sites use database driven searches - a user types a query into a form and via AJAX or a normal browser request the site software searches the database for their query and returns some results. [IMDB](https://imdb.com) does something different (and noticing this inspired me to write the site) - they appear to pre-cache all possible search queries into a set of static JSON files that are then served out of a [Amazon S3](https://aws.amazon.com/s3/) bucket. When a user searches for "The Avengers" a static file the_avengers.json is pulled from the server which contains a JSON encoded object with info about the movies that match the query. The advantage of doing it this way is speed - no search requests hit the database and static files are very easily, efficiently and quickly served. The disadvantages is that you loose the ability to dynamically query (only title based queries are available for IMDB users). Anyway because IMDB handles searches like this I simply wrote my own IMDB search handler in Javascript that mimics the IMDB's homepage's - it pulls data from the same source, not hitting my site at all. This also means I don't have to have a complete dataset like the IMDB does, I just cheat and use theirs.

The real trickery starts when a user "likes" a film from the search page. When this happens the film appears instantly in the "likes" section, but really a message is sent to the server with the IMDB ID of the film and the software checks the database. If a film with that IMDB is not in it then a task is dispatched into the queue for processing, and at a later point (mostly nearly instantly) the task workers pick up the IMDB id and go fetch the film info from the IMDB page using [IMDBpy](https://imdbpy.sourceforge.net/downloads.html) and add the metadata to the database.

After we have the metadata about the film the user wants to watch we need to compute what other films he might enjoy. I could spend [millions on creating my own ranking algorithm](https://en.wikipedia.org/wiki/Netflix_Prize) but I don't have nearly as many datapoints or resources as Netflix or Amazon. So lets cheat. The site pulls all the recommendations from the IMDB page as well, and then launches new task's to pull the info about each of the films if they don't already exist in the database.

This whole process normally takes only a few seconds to complete so is mostly transparent to the user, because by the time they have loaded the recommendations page most, if not all of the recommendations have been fetched. The ranking algorithm for the recommendations is kind of cheating as well: we simply grab the recommendations from all of the films the user likes from the database and rank them by the number of times they appear - i.e films that are recommended the most times by the films the user has liked appear at the top and those recommended the least appear at the bottom. Its a little more complex than that when it comes to the filtering rules the user has applied, but that's pretty much the jist.


#### The frontend ####
The frontend isn't very interesting. I decided to give [backbone.js](https://documentcloud.github.com/backbone/) a spin for this project and I sort of regret it. Don't get me wrong, Backbone.js is pretty good but I found the lack of tutorials and samples hindered my progress. Using Backbone.js to model the data is pretty cool - because it only interacts with the server via AJAX requests to pull and push JSON-encoded data I could (if I was crazy) re-write the entire thing in C#, PHP or Ruby without changing the frontend. Its also a lot more efficient than rendering the whole page server-side and pushing it to the client which means the interface feels more responsive and the server load stays low.

So... yeah. I'm always bad at ending blog posts, so go away.
    