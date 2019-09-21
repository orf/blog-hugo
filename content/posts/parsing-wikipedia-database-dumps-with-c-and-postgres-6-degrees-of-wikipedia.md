---
title: "Parsing Wikipedia database dumps with C-sharp and Postgres (6 degrees of Wikipedia)"
date: 2012-09-12 00:46:42.022160
tags:
   - projects
   - experiments
---

*tl;dr C# and Postgres are pretty damn fast. View code [on github](https://github.com/orf/Wikipedia-XML-Processor)*

Recently I began working on a little experiment after I saw that [Wikipedia offers XML dumps of their entire database for people to use](https://dumps.wikimedia.org/enwiki/latest/). I wanted to create a website where users could enter two article titles and it would compute the shortest path between those two articles by the inter-article links on Wikipedia, a bit like [6 Degrees of Wikipedia](https://mu.netsoc.ie/wiki/). In this post I will describe the database backend and how I processed the dumps into a format that can be easily queried.

Wikipedia offers several different types of dumps with varying file sizes and varying content, but the one I used was enwiki-latest-pages-articles.xml.bz2, which clocks in at 8.6gb compressed and __38gb uncompressed__. This big XML file contains all the current revisions for all the pages on the English Wikipedia which is perfect for this purpose.

### The Schema
The first stage is to create our database schema. I came up with this simple one which fit the bill:


    CREATE TABLE pages (
       id SERIAL,
       title varchar(255) NOT NULL,
       redirect varchar(255),
       links integer[],
       CONSTRAINT pkey PRIMARY KEY (id)
    )


The ID column is a unique integer assigned to every page, the title is the pages title, the redirect column is a string with a value of the title the page redirects to (its NULL if its not a redirect page) and the links column is an array of integers.

#### Why use an array column and not a join table?
The classic way of implementing a many-to-many relationship is using a [join/junction table](https://en.wikipedia.org/wiki/Junction_table) where one row is equal to one relation. Wikipedia has over 6 million actual content pages (not redirects, special or talk pages) and around 98,899,387 links - that would be one big ass table. Postgres could easily handle a table that big but I doubt my laptop would. Array columns seemed to provide a low-overhead alternative which would save space and (I hoped) perform pretty well at scale. It also has the advantage of not needing a JOIN query to fetch the relations, which means it only needs to query one table which should reduce IO and make queries faster.

### Step 1: Parsing the XML to extract links and titles.
Because the XML file is 38gb uncompressed I could not simply load it into memory and process it, I had to process it tag by tag in a stream. Conveniently C# provides some nice classes to do just this: [XMLReader](https://msdn.microsoft.com/en-us/library/system.xml.xmlreader.aspx) and [FileStream](https://msdn.microsoft.com/en-us/library/system.io.filestream(v=vs.110).aspx). Combining these two allows you to read the XML file page by page and process it:


    using (FileStream file = new FileStream(filename, FileMode.Open))
    {
          Interlocked.Add(ref TotalBytes, file.Length);
          using (var reader = XmlReader.Create(file))
          {
              while (reader.ReadToFollowing("page"))
              {
                 // Do some stuff here
              }
          }
    }


The program launches a thread per core and each thread processes one page at a time sequentially, running a regular expression over the entire page to extract the links from it. It then sanitizes it and writes out the page info and the links to two randomly and uniquely named files - one a XML for future processing containing only the pages title, redirect information and its extracted links and the other a CSV file containing only the page title and its redirect target, if any.

### Step 2: Import the CSV files into the database
The CSV file is used to bulk import all the titles and redirect targets into the Postgres table using the COPY command:


    COPY pages (title, redirect) FROM 'input_file.csv' WITH (FORMAT 'csv', DELIMITER '|', ESCAPE '\')

This is hugely more efficient than issuing a lot of INSERT statements because it reduces the overhead associated with such commands. You can [read more about it here](https://www.postgresql.org/docs/9.2/static/sql-copy.html)

### Step 3: Import the links
This is by far the most time consuming stage. The processed and refined XML files created during stage #1 are processed by a bunch of threads. Each page is read in turn and its link titles are read into an array, which is then used in the following query to turn those titles into a array of integers which we can use in the array column:


    SELECT DISTINCT id FROM pages WHERE title IN (LIST_OF_TITLES) AND redirect IS NULL
    UNION SELECT id FROM pages WHERE title IN (
            SELECT redirect FROM pages WHERE title IN (LIST_OF_TITLES) 
            AND redirect IS NOT NULL
    )

Annoyingly some pages on Wikipedia are simply redirect pages - for example the page for ['Buddhists'](https://en.wikipedia.org/wiki/Buddhists) redirects to the page titled [ 'Buddhism'](https://en.wikipedia.org/wiki/Buddhism). Obviously we don't want redirect pages counting as a link - we want all pages that link to 'Buddhists' to actually link to 'Buddhism' in our database. This is very tricky to do, but the above query accomplishes it with some limitations - it won't handle multiple redirects (pages that redirect to a redirect which redirects to a 'real' page). It works by getting all content pages from the list of titles (WHERE redirect IS NULL) then unioning that result set with a query that selects from a subquery that selects the redirect title from all links that are redirects. 

It is often good practice to offload your work to the database as much as possible we can combine the above query into a single UPDATE statement like so:


    UPDATE pages SET links = ARRAY(_insert_query_here_) WHERE title = :title

This greatly improves the number of updates per second we can get (My laptop achieves between 1.8k and 2.2k) because fetching the results from the first query and then executing a second one adds unnecessary overhead and the whole process takes about an hour to run.

### Step 4: Querying the dataset
Finding the links between the pages is pretty simple. You find the ID's of the two pages that the user wants to find a path between then use an 'IN' statement to get all the pages that those pages link to. You then do this again for each of those pages and see if there is a path between any of the pages retrieved.

#### Finding the outgoing links to a page
As stated before the query is simple and fast (its only a primary key lookup):


    SELECT * FROM pages WHERE id IN (list of IDs from the pages links column)

This query will return all the pages (and their links) from the table which we can use to find a path between the two target pages.

#### Finding the inbound links to a page
Postgres supports [several different index types](https://www.postgresql.org/docs/9.2/static/indexes-types.html) which is pretty cool. There are two index types that can handle array data: GIN and GiST. The documentation says that GiST is faster to update but slower to query and GIN is better for data that doesn't often change - because our database will be pretty much read-only the GIN index is the one we want. The program creates the index after all the links are added which allows us to query the database to find what pages link to a certain page like so:


    SELECT title FROM pages WHERE links @> ARRAY[1];

This will return all the pages that link to the page with the ID of 1. This isn't needed with our 6 degrees application and the query itself takes a while to execute (over 5 seconds in most cases) but its pretty cool and I might find some uses for it later.

### The future
I'm writing a web application to query the dataset and display it in a nice format and I will cover that in a future post. I have found C# to be impressively fast compared to other languages and Postgres has performed amazingly as usual. 

I have made a github repo with the C# project I used to parse the dump, you can find it [here](https://github.com/orf/Wikipedia-XML-Processor).
    