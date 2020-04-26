---
title: "Managing Rust bloat with Github Actions"
date: 2020-04-23T22:42:54+01:00
draft: true
tags: 
- projects
---

Cargo and [crates.io](https://crates.io/) are an amazing part of the Rust ecosystem and one of the things that makes 
Rust so pleasant to work with. However, it's quite easy for your cargo dependencies to pile up without you noticing. 
For example you might blindly add the (rather awesome) [reqwest](https://github.com/seanmonstar/reqwest) crate, not 
realizing that it [might increase your binary size by over 4mb](https://github.com/nushell/nushell/issues/342).

Now, you might be thinking to yourself, "does it really matter?", and the answer might well be "no". However, I think 
it's important to have _some idea_ about your binary sizes and number of dependencies in your project as you make changes. 
It might not be worth adding a specific library, and it's associated size overhead, when a smaller and simpler library might suffice.

### Introducing Cargo Bloat Action

View it on Github: https://github.com/orf/cargo-bloat-action/

Cargo Bloat Action is a Github Action that gives you insights into how code and dependency changes change both your 
dependency tree and your final binary size. 

{{< image-box name=comment.png >}}
An example pull request comment
{{< /image-box >}}

### How it works

Under the hood the action uses two tools: [cargo-bloat](https://github.com/RazrFalcon/cargo-bloat) and 
[cargo-tree](https://github.com/sfackler/cargo-tree). These are orchestrated by 
[a TypeScript file](https://github.com/orf/cargo-bloat-action/blob/master/src/main.ts).

#### Master builds

When a build is running on the master branch, any results are sent to a 
[small lambda](https://github.com/orf/cargo-bloat-backend) running on Google Cloud.

#### Pull Requests

When a pull request is made, the results from the last pull request are fetched from the lambda and used to generate 
lovely diffs, which are then displayed as comments in the merge request. 

#### Suggestions for improving Github Actions

Creating a lambda for this kind of sucks, and it's not super secure. I would think that recording and fetching some 
kind of metric (like code coverage, or binary size) is a pretty common occurrence - it would be fantastic if Github 
actions supported this out of the box. Maybe the ability to securely store and fetch up to 10kb of JSON per repository?
