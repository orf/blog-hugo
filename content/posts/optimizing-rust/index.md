---
title: "Optimizing Rust by writing idiomatic code"
date: 2019-11-17T17:31:31Z
draft: true
tags: 
- projects
- experiments
---

This post is about something that's refreshingly surprising I found in Rust, especially coming from Python. In Python, 
and other languages, you often have to make the conscious choice between writing nice, idiomatic code and writing 
optimally performant code. This trade-off ranges from the trivial, like an extra function call here and there, to the 
more complex such as avoiding blindly mutating function arguments and instead returning new instances of dictionaries 
or lists. On the flip side code that is written to be super-performant is often horribly ugly and hard to understand 
and might avoid idiomatic features/common patterns that are seen to be slow.

