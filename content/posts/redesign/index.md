---
title: "Redesigning my blog"
date: 2019-09-21T21:28:03+01:00
tags: ["projects"]
---

I like Hugo a lot. It's really fast and really simple. However it's very much still evolving, and 
the theme I was using had not been updated in nearly a year. This meant that it broke with the new release of 
Hugo, and I was generally getting a bit sick of the design.

Now I'm not a designer by any measure, but I do know what I like when I see it. And I know I didn't like most of the
other Hugo blog templates: they seemed cluttered and didn't focus on the content. I don't care about comments, social 
buttons or tag clouds. If you're reading a post it's likely because I posted it on some news aggregator and it got 
traction, not because you visit daily and wait for new posts, so it should focus on that content over everything else.

So I decided to write a Hugo theme for my blog using the [Bulma framework](https://bulma.io/). You can view the code 
here: https://github.com/orf/bare-hugo-theme.

### Creating a theme

All in all the experience with writing a Hugo theme has been very pleasant. You can bootstrap one quickly with 
`hugo new theme`, and once you're used to the way Hugo looks up templates 
(which [isn't exactly super simple](https://gohugo.io/templates/lookup-order/#)) it feels quite natural.

Bulma is super nice. I'm not sure I like it any more or less than Bootstrap but it works and it works well. The 
documentation is great and everything fits together nicely.

One of the hardest parts was, surprisingly, icons! I initially went with the classic Font-Awesome, but I didn't like 
the way it had to fetch the entire catalogue of icons when I was just using four. I tried using the font-awesome "kits" 
system they are pushing but I found that it absolutely destroyed the page load metrics I was looking at in Chrome. It 
also ended up making a lot of requests:

{{< image-box name=screenshot.png >}}
Waterfall!
{{< /image-box >}}


### Stripping unused css

One of my favorite things about this new design is that it leverages postcss to purge unused CSS selectors from the 
outputted bundle! This is amazing: it reduces the CSS bundle size to 10kb from over 160kb. You can do this in any 
Hugo project by including this `postcss.config.js` file:

```javascript
module.exports = {
    plugins: {
        '@fullhuman/postcss-purgecss': {
            content: ['themes/bare/layouts/**/*.html'],
            whitelist: [
                'highlight',
                'language-bash',
                'pre',
                'video',
                'code',
                'content',
                'h3',
                'h4',
                'ul',
                'li'
            ]
        },
        autoprefixer: {},
        cssnano: {preset: 'default'}
    }
};
```

And including this `package.json` file:

```json
{
  "dependencies": {
    "@fullhuman/postcss-purgecss": "^1.3.0",
    "autoprefixer": "^9.6.1",
    "cssnano": "^4.1.10",
    "postcss-cli": "^6.1.3",
    "purgecss": "^1.4.0"
  }
}
```
