---
title: "HtmlToWord"
date: 2013-02-18 05:38:08.720020
permalink: /htmltoword
tags:
   - projects
---

*You can find the [code here on github](https://github.com/orf/HtmlToWord) and the package [here on PyPi](https://pypi.python.org/pypi/HtmlToWord)*

I have written and continue to maintain a reporting system for a group of [pentesters](https://en.wikipedia.org/wiki/Penetration_test). During/after the tests the results and details are inputted into a web application using a WYSIWYG editor called [Redactor](https://redactorjs.com/) (which is pretty awesome!) and the system generates a word document based upon this input which is then sent to the client. There doesn't seem to be a reliable way of inputting HTML into a Word document via COM (apart from simulating pasting HTML, which is too hacky and offers too little control) so I ended up writing this little library to do it for me, and I think it could be useful to someone else.

[HtmlToWord](https://github.com/orf/HtmlToWord) is a Python library that takes HTML input (like that outputted from a WYSIWYG editor) and converts it to a stream of instructions that will render the HTML onto a Word document. It supports most common HTML tags ([full list here](https://github.com/orf/HtmlToWord#supported-tags-and-extentions)) but doesn't support any form of line styles (yet?).

Example:

    parser = HtmlToWord.Parser()
    Html = '''<h3>This is a title</h3>
              <p><img src='https://placehold.it/150x150' alt='I go below the image as a caption'></p>
              <p><i>This is <b>some</b> text</i> in a <a href="https://google.com">paragraph</a></p>
              <ul>
                  <li>Boo! I am a <b>list</b></li>
              </ul>'''

    parser.ParseAndRender(Html, word, document.ActiveWindow.Selection)

This code will create a new Word document and fill it like so:

![](./PJcHQJG.png)

Its pretty neat I think - I can't be the *only* one with this kind of issue so I hope this library helps someone.
    