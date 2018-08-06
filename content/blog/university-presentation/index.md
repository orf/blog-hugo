---
title: "University Presentation"
date: 2013-11-27 18:19:28.225421
permalink: /university-presentation
---

So I did a presentation on Information Security at University today. I think it went rather well, however I couldn't show a couple of the demonstrations due to some SkyDrive files only being available online. That sucked because those were my best demonstrations, but overall I was happy.

A few people asked me to put the website code up, so you can find it here: [https://github.com/orf/vulnerable_website](https://github.com/orf/vulnerable_website) (or just view the [code online here](https://github.com/orf/vulnerable_website/blob/master/presentation_website.py))

If you haven't used Python before then I really recommend it. To get the website up and running follow these steps:

   * [Download Python 2.7.6 here](https://www.python.org/download/releases/2.7.6/) and install
   * Download [PIP (a python package installer) from here](https://pypi.python.org/packages/source/p/pip/pip-1.4.1.tar.gz#md5=6afbb46aeb48abac658d4df742bff714)
   * Extract, and run "python setup.py install" from within the directory. If you get an error complaining that "python" doesn't exist then you need to add C:\python27 to your system path. Give it a google for detailed instructions.
   * Once that's finished just run "pip install flask"
   * Go grab the vulnerable website code and then run "python vulnerable_website.py" and you are ready to roll.
    