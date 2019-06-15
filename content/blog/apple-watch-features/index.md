+++
title = "Creating an index of Apple Watch features per-country"
date = "2019-06-04T21:52:41+01:00"
tags = ["projects"]
+++

tl;dr: check out https://applewatchfeatures.com/ or view [the source here](https://github.com/orf/apple-watch-features)

I recently brought an Apple Watch. It's a pretty fantastic product! One thing that quite 
annoyed me while evaluating if I should buy it is that eatures can vary quite drastically per country, 
and there was no simple way to get a list of the features available where I live!

Apple [does of course have a page that gives a breakdown](https://www.apple.com/uk/watchos/feature-availability/), 
but it's not exactly easy to read:

<video autoplay loop playsinline muted>
  <source src="./recording.mp4" type="video/mp4">
  <source src="./recording.webm" type="video/webm">
  <img src="./recording.gif"/>
</video>

It gives a big breakdown of every feature and every country. You would have to go and compose a list yourself!

So I built a quick script to scrape this page and produce a useful site that gives you a breakdown per-country:

![](./screenshot.png)

## How it works

[The scraper itself](https://github.com/orf/apple-watch-features/blob/master/scraper.py#L74-L88) is quite simple, 
it goes through the `.section-table` elements and produces a list of feature names and the countries where this 
feature is supported. Once we have a complete set of all features we can work out which countries *don't* have a feature, 
and write all this information to a large number of `.json` files.

The hard part here was that the names Apple gives some countries are not their official ones. 
[So I wrote a pretty hacky method to normalize them as best I could](https://github.com/orf/apple-watch-features/blob/master/scraper.py#L46-L67).

I decided to use Hugo to generate the final site, so the scraper 
[produces a Hugo content page](https://github.com/orf/apple-watch-features/blob/master/scraper.py#L123-L136) for each 
country. Hugo will [read the JSON contents when it builds the site](https://github.com/orf/apple-watch-features/blob/master/layouts/_default/single.html#L17-L37) 
and produce pages listing the features.

Another neat feature I added was the ability to use [Netlify redirects](https://www.netlify.com/docs/redirects/), which 
allows you to press a button and be redirected to your countries features without needing me to write any JavaScript!

Pretty cool little project, if I do say so myself.