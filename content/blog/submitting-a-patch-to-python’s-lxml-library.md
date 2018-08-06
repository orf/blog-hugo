---
title: "Submitting a patch to Python’s lxml library"
date: 2014-01-09 07:30:15.817398
permalink: /submitting-a-patch-to-python’s-lxml-library
tags:
   - projects
---

While working on a system for work I ran into a bug with Python’s lxml library and decided to fix it. I thought I would document how easy the process was, hopefully to encourage others to contribute to open source projects.

Lxml is a “pythonic binding for the libxml2 and libxslt libraries” which put plainly means it’s a Python library that makes calling functions from those native libraries (c/c++) easy. Which is nice because you get all the features and speed from those two very mature libraries wrapped up in a lovely Python API. It’s also hugely popular with nearly 600,000 downloads in the last month alone from the Python central package server.

One of the features it provides is the ability to diff two portions of HTML together. For example:

```python
from lxml.html.diff import htmldiff
html_1 = "<p>some text here</p>"
html_2 = "<p>some more text</p>"
print htmldiff(html_1, html_2)
"""<p>some <ins>more</ins> text <del>here</del></p>"""
```

Any text removed is wrapped in a <del\> tag, and any text inserted is wrapped in a <ins\> tag. The bug in question is that htmldiff ignored whitespace in HTML input, meaning things like newlines were lost while diffing:

```python
html_1 = "<pre>some text\n new line\n more lines</pre>"
html_2 = "<pre>some text\n new line</pre>"
print htmldiff(html_1, html_2)
"""<pre>some text new line <del>more lines</del></pre>"""
```

For the most part whitespace in HTML can be ignored, but in the case of a <pre\> tag it cannot – this tag is used for displaying preformatted text which means whitespace is respected and needs to be preserved.

The first step to fixing this was to take a look at the source. Lxml’s source code is all available [here on GitHub](https://github.com/lxml/lxml/) so I just forked the whole repository and started fiddling (forking means creating a copy of the repository that you can edit). I tracked down the problem quickly enough: when tokenising the input if there was any whitespace it simply set a boolean flag which was used to add a single space after it when outputting the tokens. This made the fix very simple: rather than store a boolean indicating if there was any trailing whitespace I could just use that field to store the actual trailing whitespace, which I did in this commit: [https://github.com/lxml/lxml/commit/44e697fa9a8b580326bfaf6ffffeda3220c6c733#diff-c70277a0d76841a33e740a43edf14d99](https://github.com/lxml/lxml/commit/44e697fa9a8b580326bfaf6ffffeda3220c6c733#diff-c70277a0d76841a33e740a43edf14d99). After writing a few tests and making a few more commits I had fixed the problem and so I was ready to submit the changes to lxml.

What’s the best way to do this? When using GitHub the best way is to make a pull request – this takes any changes you have made to your clone of the code and makes a nice page listing them. Here is the pull request I made: [https://github.com/lxml/lxml/pull/125](https://github.com/lxml/lxml/pull/125). One of the project leaders suggested a small change, which I implemented, and the pull request was accepted – the full list of changes made [can be found here](https://github.com/lxml/lxml/commits/master/src/lxml/html/diff.py?author=orf).

The bug was marked as fixed as of version 3.2.4 and overall it was pretty painless experience to go from finding the bug to submitting the pull request. GitHub definitely streamlines the whole process with their pull request functionality, otherwise I might have had to make a patch file and submitted it somewhere manually. That’s not impossible, but its certainly not as simple as clicking a button.
    