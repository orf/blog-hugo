---
title: "I hope I hate this code one day"
date: 2019-09-28T16:25:53+01:00
tags: ["projects"]
---

I remember the first program I built fully on my own: a music downloader. There was a site that would basically index random
music files found on Google and present you with a way to search them. I guess they would periodically search google 
for things like `intitle:index.of mp3` (which [you can still do](https://www.google.com/search?q=intitle:index.of%20+?last%20modified?%20+?parent%20directory?%20+(mp3|wma|ogg)%20-htm%20-html%20-php%20-asp)) 
and store links to the files they found. My program would let you type in a query into your console, search for that 
query in the website and allow you to select a file to download.

The code (and the site) is now long gone but the memory of how I parsed the HTML lives on in my head:

```python
files = []
for line in page_html.split('\n'):
   if line.startswith('<a class="download'):
       url = line.split(' ')[3].replace('href="', "").replace('"', '')
       files.append(url)
```

With the experience I've gained since I wrote that code I know how much is wrong with this. What if the HTML is 
minified and doesn't contain newlines? What if the attribute orderings change? What if the `download` class changes? 
And don't even think about [using regex to parse it](https://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags).

But at the time I didn't know how to parse HTML and I didn't care. I think there's a certain liberty to that which you 
lose as you grow as a developer and this hampers your ability to pick up a new language.

I found this was hampering me while learning Rust. I'm in the middle of writing my first Rust project which involves 
launching a number of individual subprocesses and displaying their output interleaved in the console. Rust is a powerful
language with a lot of interesting features and I wanted to try and write idiomatic code from the get-go. So for 
example I started to try and make use of traits and lifetimes to pass references and avoiding cloning, but I 
found I was spending all my time on this and it was getting in the way of my ability to make something that *worked*. 
Sure, passing a reference to a `String` that has a correct lifetime is more efficient and likely prettier than 
`string.clone()`, but while learning I don't think you should get stuck on things like this. 

Get it working, then learn how it **should** work.

Back to my project: I'm taking the stdout from a number of processes spawned via a [rayon parallel iterator](https://docs.rs/rayon/1.2.0/rayon/). 
I want to display the current state of each thread in the console and control how they are displayed. For this I went
with a standard [mpsc channel](https://doc.rust-lang.org/std/sync/mpsc/fn.channel.html) with multiple senders and 
one receiver:

```rust
fn monitor_threads(rx: Receiver<(ThreadId, String)>) {
    let states: Vec<(ThreadId, String)> = vec![];
    for (thread_id, msg) in rx.iter() {
        // Do we have this state in our states?
        if states.iter().any(|(t, _)| t == &thread_id) {
            // Update the tuple with the new message
            stack.iter_mut().filter(|t| t.0 == thread_id).for_each(
               |t| t.1 = msg.clone()
            );
        } else {
            // Push the job state to the vector
            stack.push((thread_id, msg.clone()));
        }
        // Display the states, and erase the previous output 
        //using ansii escape sequences.
        print_thread_states(states);
    }
}
```

I'm not sure a `Vec` is the best structure here, and I doubt this is the most efficient way of updating it.

To send updates to it:

```rust
fn run_stuff(jobs: Vec<Job>) {
    let (tx, rx) = channel();
    let monitor_thread = thread::spawn(move || {
        monitor_threads(rx);
    });
   
    jobs.par_iter().for_each(|j| {
        let process = j.spawn_process();
        for line in process.lines() {
            // Truncate the line to 70 characters and send it to the monitor.
            let line = line.trim();
            if line.len() >= 70 {
                line.truncate(70);
                line.push_str("...");
            }
            tx.send((thread::current().id(), line.clone()));
        }
    });
    monitor_thread.join();
}
```

I have a feeling that this isn't great. I'm sure there is a better way to do all of this, like some fantastic way of 
avoid the need to clone the `String`'s being sent to the channel, or to avoid the inefficiencies around truncating the 
output. Maybe there is even an [antigravity module](https://xkcd.com/353/) that I can use to just avoid this whole mess
entirely.

But, **it doesn't matter**. It's more fun and I'm learning more by not getting lost in the weeds of how I think, from my 
other experiences, that this **should** be done and just doing it. And I hope one day I know enough about Rust to look
back at this code and hate it in the same way that I did with my music downloader. 

I think that's something we should all aspire to when we are learning a new language.