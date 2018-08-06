---
title: "How much code is there in the Python Package Index?"
date: 2013-12-21 05:11:23.732171
tags:
   - experiments
---

Sometimes python related questions pop into my head, like [how slow are Django templates](https://tomforb.es/just-how-slow-are-django-templates) or how [hard would it be to inline Python function calls](https://tomforb.es/automatically-inline-python-function-calls) and I usually end up spending a couple of hours trying to answer them. The question that conveniently popped into my head yesterday as I was trying to avoid revising was *"How much code is there in the [Python Packaging Index](https://pypi.python.org/pypi), and how hard is it to count?"*

This seemed like a nice distraction from real work, so I set about trying to answer it. I will quickly run through how I made a program to answer this question, then present some statistics I gathered.

### Basic outline
The [Python Packaging Index](https://pypi.python.org/pypi) (PyPi for short) is a central index of Python packages published by developers. At the time of writing there are 37,887 published packages, any of which can be downloaded and installed with a single "pip install [packagename]" command.

For each package in the PyPi repository we need to do the following things:

<img src="https://docs.google.com/drawings/d/1kRGzlklCeRQMhGKmgRh20dqu-N7Vo9_pi21UhdA4stE/pub?w=628&amp;h=110">

PyPi exposes an XML-RPC API that anyone can use. Retrieving a list of all registered package names is as simple as:

```python
import xmlrpclib
client = xmlrpclib.ServerProxy('https://pypi.python.org/pypi')
all_packages = client.list_packages()
```

PyPi also exposes a convenient JSON API to retrieve data about a package. You can access this by simply appending a "/json" onto the end of any package page, for example [https://pypi.python.org/pypi/Django/json](https://pypi.python.org/pypi/Django/json) retrieves a JSON object describing the Django package. This object contains metadata about the package as well as the latest download URL's.

You can then find a suitable release (source distribution preferred), download it to a temporary file and extract it. Once its extracted a program like [CLOC](https://cloc.sourceforge.net/) can be run over the source tree to count the number of lines of code. You can find [my attempt at this program here](https://gist.github.com/orf/ce92408539d8379de55a#file-pypi_counter-py).

I ran the above script and after a couple of hours it had parsed every Python package it could, then I did some ad-hoc analysis on the data.

### Some statistics
The script managed to gather information about **36,940** packages. The script could not process the source code for **4,400** of those packages - this could be because no release was present, the download_url pointed to a HTML page rather than a package or the archive was corrupt/unsafe. This leaves **32,540** packages.

Those **32,540** packages contained **7.4GB** of data and had a total monthly download count of **54,340,576**. CLOC detected **127,635,341** lines of source code across **807,993** files, and of those **72,631,329** lines were Python across **484,788** files. The average package weighs in at **239kb**, contains **2,232** lines of Python code and has been downloaded **1,669** times in the last month.  

Packages can contain more than just Python files. The following graph is a breakdown of the most common languages detected in PyPi packages (the following graphs are interactive, please enable JavaScript if you can't view them):

<script type="text/javascript" src="//ajax.googleapis.com/ajax/static/modules/gviz/1.0/chart.js"> {"dataSourceUrl":"//docs.google.com/a/tomforb.es/spreadsheet/tq?key=0ArR3Zvt64iZfdFpoMHJUaDN6ck5ST0tkT09NU05iX2c&transpose=0&headers=1&range=A4%3AB18&gid=0&pub=1","options":{"vAxes":[{"title":"Language","useFormatFromData":true,"minValue":null,"viewWindowMode":null,"viewWindow":null,"maxValue":null},{"useFormatFromData":true}],"titleTextStyle":{"bold":true,"color":"#000","fontSize":16},"booleanRole":"certainty","title":"Most common languages on PyPi","height":370,"animation":{"duration":500},"domainAxis":{"direction":1},"legend":"right","hAxis":{"title":"Lines of code (Including comments)","useFormatFromData":true,"minValue":null,"viewWindow":{"min":null,"max":null},"logScale":false,"maxValue":null},"isStacked":false,"tooltip":{}},"state":{},"view":{},"isDefaultVisualization":false,"chartType":"BarChart","chartName":"Chart1"} </script>

It should be noted that CLOC is not perfect at detecting languages. I highly doubt there is much Pascal code on the PyPi, but CLOC may have counted it due to files having a .p extension. It's good for a rough estimate though.

<script type="text/javascript" src="//ajax.googleapis.com/ajax/static/modules/gviz/1.0/chart.js"> {"dataSourceUrl":"//docs.google.com/a/tomforb.es/spreadsheet/tq?key=0ArR3Zvt64iZfdFpoMHJUaDN6ck5ST0tkT09NU05iX2c&transpose=0&headers=1&range=A6%3AB10&gid=1&pub=1","options":{"vAxes":[{"useFormatFromData":true,"title":null,"minValue":null,"viewWindow":{"max":null,"min":null},"maxValue":null},{"useFormatFromData":true,"minValue":null,"viewWindow":{"max":null,"min":null},"maxValue":null}],"titleTextStyle":{"bold":true,"color":"#000","fontSize":16},"booleanRole":"certainty","title":"PyPi Package release types","height":371,"animation":{"duration":500},"legend":"right","hAxis":{"useFormatFromData":true,"minValue":null,"viewWindowMode":null,"viewWindow":null,"maxValue":null},"isStacked":false,"tooltip":{}},"state":{},"view":{},"isDefaultVisualization":false,"chartType":"ColumnChart","chartName":"Chart2"} </script>

Source distribution is by far the most common Python package format with **32,490** packages. The [Wheel](https://wheel.readthedocs.org/en/latest/) format is starting to appear but still has a long way to go with only **318** releases.

<script type="text/javascript" src="//ajax.googleapis.com/ajax/static/modules/gviz/1.0/chart.js"> {"dataSourceUrl":"//docs.google.com/a/tomforb.es/spreadsheet/tq?key=0ArR3Zvt64iZfdFpoMHJUaDN6ck5ST0tkT09NU05iX2c&transpose=0&headers=1&range=A5%3AB14&gid=2&pub=1","options":{"titleTextStyle":{"bold":true,"color":"#000","fontSize":16},"vAxes":[{"useFormatFromData":true,"minValue":null,"viewWindow":{"min":null,"max":null},"maxValue":null},{"useFormatFromData":true,"minValue":null,"viewWindow":{"min":null,"max":null},"maxValue":null}],"pieHole":0,"title":"Package Homepage Locations","booleanRole":"certainty","height":371,"animation":{"duration":0},"colors":["#3366CC","#DC3912","#FF9900","#109618","#990099","#0099C6","#DD4477","#66AA00","#B82E2E","#316395","#994499","#22AA99","#AAAA11","#6633CC","#E67300","#8B0707","#651067","#329262","#5574A6","#3B3EAC","#B77322","#16D620","#B91383","#F4359E","#9C5935","#A9C413","#2A778D","#668D1C","#BEA413","#0C5922","#743411"],"is3D":false,"hAxis":{"title":"Horizontal axis title","useFormatFromData":true,"minValue":null,"viewWindow":{"min":null,"max":null},"maxValue":null},"tooltip":{}},"state":{},"view":{},"isDefaultVisualization":false,"chartType":"PieChart","chartName":"Chart3"} </script>

GitHub is by far the most popular homepage for packages with over **16,000** references. BitBucket is beating Google Code with double the number of packages and SourceForge is quite rightfully languishing at the near bottom.

<script type="text/javascript" src="//ajax.googleapis.com/ajax/static/modules/gviz/1.0/chart.js"> {"dataSourceUrl":"//docs.google.com/a/tomforb.es/spreadsheet/tq?key=0ArR3Zvt64iZfdFpoMHJUaDN6ck5ST0tkT09NU05iX2c&transpose=0&headers=1&range=A7%3AB108&gid=3&pub=1","options":{"titleTextStyle":{"bold":true,"color":"#000","fontSize":16},"curveType":"function","animation":{"duration":500},"lineWidth":2,"hAxis":{"useFormatFromData":true,"title":"Comment percentage in code","minValue":0,"viewWindowMode":"explicit","viewWindow":{"min":0,"max":null},"maxValue":null},"vAxes":[{"useFormatFromData":true,"title":null,"minValue":0,"viewWindowMode":"explicit","viewWindow":{"min":0,"max":null},"maxValue":null},{"useFormatFromData":true,"minValue":null,"viewWindow":{"min":null,"max":null},"maxValue":null}],"booleanRole":"certainty","title":"Distribution of code comment percentage in PyPi packages","height":371,"legend":"right","focusTarget":"category","useFirstColumnAsDomain":true,"tooltip":{}},"state":{},"view":{},"isDefaultVisualization":false,"chartType":"LineChart","chartName":"Chart1"} </script>

This graph plots the percentage of comments across all packages. **1101** packages contained 50% or more comments, and **14,199** contained less than 15%


    