---
title: "Visualizing how S3 deletes 1 billion objects with Athena and Rust"
date: 2022-09-15T00:00:00+0100
tags:
- rust
- projects
---

{{< image-sidebar name=animation_5.gif width="is-three-fifths-desktop" title="The visualization">}}
A few weeks ago I had the chance to delete 1 petabyte of data spread across 1 billion objects from S3. Well, actually 
940 million, but close enough to the click-baitable 1 billion. I thought it would be interesting challenge to try and 
visualize the execution of these deletions and possibly gain some insights into how
[S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html) work under the 
hood.

The post below details how I generated the gif shown on this page using Athena and a custom Rust tool, including an 
interesting bug I encountered with Athena along the way.

#### A note about how S3 objects are deleted

Lifecycle policy deletions in a versioned S3 bucket go through several phases. At first each key gets a
["Delete Marker"](https://docs.aws.amazon.com/AmazonS3/latest/userguide/DeleteMarker.html) added to it. Delete markers
are a special kind of object that hides the key from standard `ListObjects` calls, making keys appear like they are no
longer present.

After a configurable amount of time all "noncurrent versions" of objects are expired,
which means all data that has a delete marker as it's "current version" will be permanently erased. After this, S3
cleans up all "expired delete markers" - that is delete markers where all the data for the key has been deleted.

<div style="font-size: 80%">

```goat
   .---------------------.   .-------------.   .-----------------------. 
   | Delete Marker Added |-> | Key Expired |-> | Delete Marker Expired |
   '---------------------'   '-------------'   '-----------------------'
```

</div>

The visualization represents this flow with yellow, red and black

{{< /image-sidebar >}}

## Getting the data

We want to represent each file as a pixel in a GIF image and change it's colour as it's state changes. To do this we
need two sets of data: the set of all keys in the bucket and the set of all state changes on the keys.

There are two sources of data we can utilize to build all the information we need to create the visualisation:
[S3 bucket inventories](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-inventory.html) and
[S3 server access logs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html).

Setting these up for querying with Athena is fairly simple and well documented.

### Segmenting our image

{{< image-sidebar goat=box.goat width="is-three-fifths-desktop" title="Example segments">}}

Once we have this data in an Athena table, we need to assign a pixel to every file in S3. Naively this could be
assumed to be as simple as:

```sql
select key, row_number(order by key) as unique_pixel
from set_of_all_keys
order by key
```

However, this is kind of query is very slow to process when using Athena because it effectively means it cannot
parallelize the query across multiple workers. A simple approach to this is breaking the image down into segements,
where the `(segment, index)` value uniquely identifies a pixel within the image. This allows Athena to process each
segment in parallel.

The diagram shows how this works: the image is broken up into possibly uneven segments from left to right. Each segment 
is then broken down into individual pixels.

{{< /image-sidebar >}}

Once we have this, a given key can be identified by a `(segment, index)` tuple which we can then easily convert to a 
stable pixel x/y coordinate.

To start with this we want to find a suitable "prefix" we will use to group our rows together. The prefix should
ideally be evenly distributed. You could split the key and take the first N characters of a specific part of the key,
as depending on how your keys are generated this may result in a more evenly distributed set of prefixes.
In the example below we're taking the first 2 characters of the 4th part of the bucket key:

```sql 
-- Split /foo/bar/baz into [/foo, /bar, /b], then join it back into a string to form the prefix
select array_join(slice(split(key, '/'), 1, 2) || ARRAY[SUBSTR(split(key, '/')[3], 1, 1)], '/')
from...
```

However below we just use the first 5 characters for simplicity:

{{< sql-sidebar name="two" >}}

Now we have our set of keys and their associated prefixes we need to associate numeric `(segment, index)` values with
each of them. Because the set of unique *prefixes* is much smaller than the set of keys, we are able to use a simple 
`row_number()` window function to order them. We then end up with `(key, segment, index)`:

{{< sql-sidebar name="three" >}}

Now that we have this, we can reduce this down into a small set of we can convert these into a much smaller set of 
`(segment, max_index)`, which form basically a bounding box within the image. This will come in handy later when we 
start generating the image:

{{< sql-sidebar name="four" >}}

Now we have each key in the bucket mapped to a `(segment, index)` tuple we can parse our access logs to produce a 
stream of events. S3 access logs are delivered as uncompressed text files, so they can be a bit expensive to query. S3 
will log a `S3.CREATE.DELETEMARKER` and `S3.EXPIRE.OBJECT` event for lifecycle executions, so we filter for those 
requests and produce a simple table of requests against keys:

{{< sql-sidebar name="access-logs" >}}

And now we have our request logs and `(key, segment, index)` mapping we can combine them all together to produce a table 
of events, segments and the indexes that those events operated on. We can reduce and increase the granularity of these 
events (and thus the image) by adjusting the size of the bucket that all events are grouped into:

{{< sql-sidebar name="five" >}}

Hurray! With this we have all the data we need to build the visualization!

#### Athena bug: Output rows are not sorted

After running this and downloading the files I found to my surprise that they are not correctly sorted:

```shell
$ gzcat file.gz | jq -c "{a: .bucket, b: .operation, c: .segment}" | sort -c 
sort: -:264: disorder: {"a":"..21:00...","b":"delete","c":106208}
```

And indeed, looking for all rows with this timestamp shows that there appears to be an ordering issue: 

```json lines
{"a":"22:00","c":36254}
{"a":"22:00","c":175581} # Incorrect!
{"a":"22:00","c":175582} # Incorrect!
{"a":"23:00","c":1939}   # Incorrect!
{"a":"22:00","c":174409}
{"a":"22:00","c":174410}
```

It seems like Athena outputted the _end_ of the `22:00:00` group, and the start of the `23:00:00` group, before it had 
finished writing the `22:00:00` group. Very nnnoying, but it's ok to sort locally with `jq`.

## Building the visualizer with Rust

It was a joy to build this in Rust, and you can view the complete tool [on Github](https://github.com/orf/s3-deletion-visualizer). 
The code below is an approximation of the actual code for brevity.

### Defining our structures

We're reading JSON files that Athena produces, so the obvious way to do this is to use [Serde](https://serde.rs/). We 
just need to define a few structures that derive from `Deserialize` and we're good to go:

```rust
use serde::Deserialize;

// {"segment":233023,"num":33}
#[derive(Deserialize, Debug)]
struct Segment {
    segment: usize,
    num: usize,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
enum Operation {
    Delete,
    Expire,
}

// {"bucket":"2022-09-02 15:55:00.0","operation":"delete","segment":133135,"items":[1,2,3,4,5,6]}
#[derive(Deserialize, Debug)]
struct Event {
    pub bucket: DateTime<Utc>,
    pub operation: Operation,
    pub segment: usize,
    pub items: Vec<i32>,
}
```

Once we've done that we can define our `State`, where we hold information about all the events. I chose to store the 
state of all files in a single contiguous vector, which worked out to use only a gigabyte of memory in total. We then 
store the smaller `(segment, max(index))` bounding boxes in `offsets`, which means that given a `(segment, index)` tuple 
we can compute the pixel by indexing into `offsets` and adding `index` to the returned value. This gets us an index  
into the `files` vec:

```rust
#[derive(Clone, Debug, Eq, PartialEq)]
enum FileState {
    // File exists
    Present,
    // Key is deleted
    DeleteMarker,
    // File completely deleted
    Expired,
    // The delete marker is gone
    DeleteMarkerDeleted,
}

struct State {
    offsets: Vec<usize>,
    files: Vec<FileState>
}

impl State {
    fn set_item(&mut self, segment: usize, index: usize, state: FileState) {
        let offset = self.offsets[segment - 1];
        let idx = offset + index - 1;
        self.files[idx] = state
    }
}
```

And then we can have some logic to turn our `State` into an image using the [image crate](https://crates.io/crates/image). 
This was the slowest part of the process

```rust
use image::{Rgb, RgbImage};

impl State {
    fn get_frame(&self, image_size: u32) -> RgbImage {
        // The slowest part of the whole shebang.
        image::ImageBuffer::from_fn(image_size, image_size, |x, y| {
            let row_idx = y * image_size;
            let idx = row_idx + x;
            match self.files.get(idx as usize) {
                None => Rgb([0, 0, 0]),
                Some(v) => turn_state_into_rgb(v),
            }
        });
    }
}
```

And then we can start loading our events! As Athena outputs multiple (sorted 😅) files, we can create a serde iterator 
from each of the files and use `kmerge_by` from the awesome [itertools crate](https://crates.io/crates/itertools) to
yield them in a sorted fashion! We then group the events by the bucket (the time period when the events happened).

Being able to do something like this feels very 'python-y' and it's one of the reasons I love working with Rust. 

```rust
use itertools::Itertools;

fn main() {
    let state = State::new();
    
    let mut event_iterators = vec![];
    let events_files = fs::read_dir("some-event-dir")?;
    for event in events_files {
        let file = File::open(event?.path())?;
        let reader = BufReader::new(GzDecoder::new(file));
        let event_lines = serde_json::Deserializer::from_reader(reader)
            .into_iter::<Event>();
        event_iterators.push(Box::new(event_lines));
    }
    
    let items = event_iterators
        .into_iter()
        .kmerge_by(|a, b| a.bucket < b.bucket)
        .group_by(|e| e.bucket);
    
    for (group, events) in items.into_iter() {
        println!("Group: {}", group);
        for event in events {
            state.update(event);
        }
        
        let image = state.get_frame(1_000);
        image.save(format!("images/{}.png", group))?;
    }
}
```

Once we have our stream of sorted events being fed to us as simple Rust structs, we can manipulate our state:

```rust
impl State {
    fn update(&self, event: Event) {
        let current_state = self.get_state(event.bucket, event.index);
        // Do some logic here to transition objects. i.e if the object is present  
        // and the event is 'delete', then it is now FileState::Deleted.
        let new_state = compute_new_state(event, current_state);
        self.set_item(event.bucket, event.index, new_state);
    }
}
```

And that is it! Now we have a directory full of PNG images that we can create a gif from using [imagemagick](https://imagemagick.org/index.php):

```shell
$ convert -delay 5 -loop 0 images/*.png animation.gif
```

## Learnings

This was a great excuse to brush up on my SQL skills, learn more about Athena and get the chance to play with some Rust 
imaging libraries.

As for S3? The gif clearly shows that each of the underlying storage partitions executes the lifecycle policies 
independently, and that these partitions are a function of the object key.

In total it took about 6 days to delete all the objects.
