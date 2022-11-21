---
title: "AWS may have broken your Cloudfront API for nearly a month"
date: 2022-11-20T22:42:54+01:00
tags: [] 
---

**tl;dr**: If you rely on the `x-forwarded-for` header with Cloudfront and have enabled Origin Shield, between October 
the 10th 2022 and November the 2nd 2022 the value of this header may have been incorrect for a percentage of requests. 
If your API relies on knowing the clients IP address in any way it may have been partially broken during this time.

### Details

[Amazon Cloudfront](https://aws.amazon.com/cloudfront/) is AWS's content delivery network. AWS runs a large number of 
edge locations across the world, and those locations proxy requests to your backend, optionally caching static files at 
the edge.  As outlined [in this fantastic post by foxy.io](https://www.foxy.io/blog/cloudfront-vs-cloudflare-and-how-to-reduce-response-times-for-both-by-35/), 
enabling [Origin Shield](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/origin-shield.html) on your 
Cloudfront distributions can drastically reduce latency. The gains are real:

{{< image-box name=latency.png >}}
Latency metrics from Australia, showing a 1 second (66%) reduction in latency.
{{< /image-box >}}

And the setup is simple, with no application changes needed.

### The issue

After rolling this out to some of our endpoints, we noticed a change in the distribution of the `x-forwarded-for` 
headers that we received from Cloudfront. [X-Forwarded-For](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For) 
is a header that contains a comma separated list of IPs from upstream reverse proxies.

After enabling Origin Shield we saw that the _first_ element of this request was *not* the clients real IP address, it 
was an IP address assigned to AWS! We quickly disabled Origin Shield and began investigating.

AWS publishes a list of all IP addresses they use [here](https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html). 
We exported all requests we received and compared the first value of `x-forwarded-for` to this published list of ranges, 
and plotted the counts:

{{< image-box name=graph.png >}}
{{< /image-box >}}

This header is commonly used for rate limiting, IP restrictions, fraud detection and anything else that may require the 
real clients IP address. For these requests with an incorrect `x-forwarded-for` value any functionality that uses it may 
be broken.

### Statement from AWS

We opened a support ticket with AWS on the 25th of October and gave them as much detail as we could. After investigating 
and acknowledging the issue they gave us the following statement:

> Starting on October 10, 2022 customers who utilize the "X-Forwarded-For" header and have Origin Shield enabled started
> experiencing 403 responses. Customers who utilize the web socket protocol and have Origin Shield enabled but do not 
> have Lambda@Edge enabled started experiencing 5XX responses. The root cause was a recent code change to enhance 
> and improve the performance of the CloudFront platform which inadvertently removed the "X-Forwarded-For" header 
> and/or misrouted web socket traffic towards Origin Shield. To immediately mitigate the impact, affected customers 
> can disable Origin Shield. The code change is being reverted and we expect completion by November 2, 2022.

I applaud them for quickly rolling back (they acknowledged the issue on the 1st of November), but this doesn't seem great. 
`X-Forwarded-For` is critical if you're using the clients IP address in any way, and the statement is slightly vague: 
the issue was not necessarily that clients received 403 responses, it's that the `x-forwarded-for` header was incorrect. 
And it was apparently like this for nearly a month until we noticed it.

