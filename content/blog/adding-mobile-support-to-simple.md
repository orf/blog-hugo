---
title: "Adding mobile support to Simple"
date: 2012-09-22 17:50:04.589203
tags:
    - simple
---

Last week I finally got round to adding support for mobile devices to [Simple](https://github.com/orf/simple) (the software that powers this blog). I thought I would write a quick post about getting a mobile version of your site up and running using [Bootstrap](https://twitter.github.com/bootstrap/) from Twitter without changing much code at all.

When including the responsive version of Bootstrap in a page it exposes a few classes you can use to modify the displayed content of the page depending on if the device that is viewing the page is a computer, tablet or phone: visible-phone, visible-tablet, visible-desktop (and hidden-* counterparts). These classes work by using [CSS Media Queries](https://cssmediaqueries.com/) to detect the display size of the screen - you can have a play with the default bootstrap values [here](https://twitter.github.com/bootstrap/scaffolding.html#responsive) by re-sizing your browser window.

Integrating these with Simple was ridiculously easy: Add a hidden-phone class to the sidebar and other small elements and a visible-phone to a smaller header which appears above the post rather than as a sidebar. One thing that did stump me for a while is you have to add this tag inside the head of the page:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

Once you have added that tag to the page head then making a mobile version of the site is as simple as modifying a few element classes. It should be noted that __this is not the best way to make a mobile version of your site__: the entire page is still downloaded to the phone and processed even if only a small portion of it is being displayed. This is a bit of a waste - building a proper mobile version of your site is preferable but this solution works great for Simple, who's pages are pretty small and almost all of the content is displayed on the mobile version.

I'm loving Bootstrap more every time I use it - its awesome and packed full of lovely features, and getting a mobile version of Simple working in under half an hour was pretty neat. Go visit this page on your phone for a demo.
    