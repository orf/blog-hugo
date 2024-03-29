---
title: "Creating an index of Apple Watch/MacOS/iOS features per-country"
date: "2019-06-04T21:52:41+01:00"
tags: ["projects"]
---

tl;dr: check out https://applewatchfeatures.com/, https://iosfeatures.com/ and https://macosfeatures.com/

I recently brought an Apple Watch. It's a pretty fantastic product! One thing that quite 
annoyed me while evaluating if I should buy it is that features can vary quite drastically per country, 
and there was no simple way to get a list of the features available where I live!

Apple [does of course have a page that gives a breakdown](https://www.apple.com/watchos/feature-availability/), but it's not exactly easy to read.

It gives a big breakdown of every feature and every country. You would have to go and compose a list yourself!

So I built a quick script to scrape this page and produce a useful site that gives you a breakdown per-country:

![](./screenshot.png)

You can see the [features available in Portugal here](https://applewatchfeatures.com/features/pt/), or 
[select your own country here](https://applewatchfeatures.com/)

## How it works

The scraper itself is quite simple, it goes through the `.section-table` elements and produces a list of feature names
and the countries where this feature is supported. Once we have a complete set of all features we can work out which 
countries *don't* have a feature, and write all this information to a large number of `.json` files.

The hard part here was that the names Apple gives some countries are not their official ones. I created a number of 
overrides by hand, which seems to work well enough.

I decided to use Hugo to generate the final site, so the scraper produces a Hugo content page for each 
country. Hugo will read the JSON contents when it builds the site and produce pages listing the features.

Another neat feature I added was the ability to use [Netlify redirects](https://www.netlify.com/docs/redirects/), which 
allows you to press a button and be redirected to your countries features without needing me to write any JavaScript!

Pretty cool little project, if I do say so myself.
