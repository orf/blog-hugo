---
title: "I scanned every package on PyPi and found 57 live AWS keys"
date: 2023-01-06T18:31:57Z
tags: 
 - projects
 - security
---

After inadvertently finding [that InfoSys leaked an AWS key on PyPi]({{< ref "infosys-leak" >}}) I wanted to know 
how many other live AWS keys may be present on Python package index. After scanning every release published to PyPi 
I found 57 valid access keys from organisations like:
* [Amazon themselves](https://inspector.pypi.io/project/amazon_pay/2.5.1/packages/db/20/cc6965de19ba9839823043d50de44ececffeeaa6712c77b16721224ad9c3/amazon_pay-2.5.1.tar.gz/amazon_pay-2.5.1/amazon_pay/integration_test.py#line.6) 😅
* [Intel](https://inspector.pypi.io/project/devcloud/0.0.2/packages/9f/59/739768bdffb30404afe359bea1975664e78d2d272124a08e98591ef3e8a0/devcloud-0.0.2-py3-none-any.whl/devcloud/result.py#line.16)
* [Stanford](https://inspector.pypi.io/project/igibson/2.2.1/packages/42/05/b8fcef6fc4585475c1bdef81877a6c37dab1b67ae4ab161ba6771d88d6e0/igibson-2.2.1.tar.gz/igibson-2.2.1/igibson/utils/data_utils/ext_object/scripts_wip/test_amazon_new_api.py#line.42),
  [Portland](https://inspector.pypi.io/project/psu_export/3.0.9/packages/4f/f8/2742a7b6c049e7711915505af70f748783641b6d0efa849b428374e7b066/psu_export-3.0.9-py2.py3-none-any.whl/demo/local_settings.py#line.56) 
  and [Louisiana](https://inspector.pypi.io/project/BigJob2/0.54/packages/7a/a0/9945db2b1a1e9895942f55426c5a009c5fb8c43321642874f9f8647edc2e/BigJob2-0.54.tar.gz/BigJob2-0.54/tests/cloud/aws_test_sagabj.py#line.17) 
  University
* [The Australian Government](https://inspector.pypi.io/project/datacube_ows/1.8.6/packages/25/4b/31a3f45df3b28a4ee2b77e366198f92b3713e96e79a3935e08a7e9eb93a9/datacube_ows-1.8.6.tar.gz/datacube_ows-1.8.6/datacube_ows/wsgi_local.py#line.12)
* [General Atomics fusion department](https://inspector.pypi.io/project/omfit-classes/3.2022.45.2/packages/37/f7/4128313b0bf1e9fec2adb59b3587acb898e4ea6e8ffea33d543b51847edb/omfit_classes-3.2022.45.2.tar.gz/omfit_classes-3.2022.45.2/omfit_classes/startup_framework.py#line.1335)
* [Terradata](https://inspector.pypi.io/project/presto_docker_devenv/0.2/packages/cc/63/a3e1a2b014a9bddd17527edb78479f208d2e57df187048c2aa3916d26a4d/presto_docker_devenv-0.2-py2.7.egg/images/presto-local/debug#line.37)
* [Delta Lake](https://inspector.pypi.io/project/deltalake/0.5.6/packages/95/3b/d6a7690421ef15fbc960d48e886664f0735a93e0afc1ac1a12185329debf/deltalake-0.5.6.tar.gz/deltalake-0.5.6/tests/conftest.py#line.9)
* And [Top Glove, the worlds largest glove manufacturer 🧤](https://inspector.pypi.io/project/athenatos3/0.0.1/packages/24/a8/7eacb82b353f33f75fa20c3a2d5dd6252c29c16c2d6e747b3722804b28d1/athenatos3-0.0.1-py3-none-any.whl/athenatos3/athenatos3.py#line.4)

This post outlines the way I scanned PyPi, [showcases a project I've built](#automatically-scanning-new-packages-with-github-actions) that automatically scans all new PyPi releases 
to notify AWS of potentially leaked keys, [presents some analysis](#analysis-of-the-leaked-keys) of the keys I've found 
and [draws a few conclusions](#conclusions) at the end.

## How?

Detecting AWS keys is actually fairly simple. A keypair consists of two components: the `key ID` and the `key secret`. 
The `key ID` can be detected with the regular expression `((?:ASIA|AKIA|AROA|AIDA)([A-Z0-7]{16}))`, and the secret key 
can be detected with a much more general `[a-zA-Z0-9+/]{40}`. We can tie these together to find "key IDs close to secret keys, surrounded by quotes" 
with this monster regex ([regex101](https://regex101.com/r/TNEdbR/1)):

```regexp
(('|\")((?:ASIA|AKIA|AROA|AIDA)([A-Z0-7]{16}))('|\").*?(\n^.*?){0,4}(('|\")[a-zA-Z0-9+/]{40}('|\"))+|('|\")[a-zA-Z0-9+/]{40}('|\").*?(\n^.*?){0,3}('|\")((?:ASIA|AKIA|AROA|AIDA)([A-Z0-7]{16}))('|\"))+
```

We can use the amazing [ripgrep](https://github.com/BurntSushi/ripgrep) to search packages for this pattern:

```shell
$ wget "https://files.pythonhosted.org/.../amazon_pay-2.5.1.tar.gz"
$ rg --text -z --multiline $chonky_regex amazon_pay-2.5.1.tar.gz
2195:#        mws_access_key='AKIAJIUGYOGHT2ONMCOQ',
2196:#        mws_secret_key='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',
```

And then we can try these keys with the `aws` CLI tool. If this returns a value then we've got a valid set of credentials!

```shell
$ AWS_SECRET_KEY=X AWS_ACCESS_KEY_ID=Y aws sts get-caller-identity
{
  "UserId":"985141293874",
  "Account":"985141293874",
  "Arn":"arn:marketplacewebservice:iam::985141293874:root"
}
```

The devil is in the details though - the `-z` flag doesn't support searching zip files, so we need to use a custom shell 
script to handle this, and there are some nuances around extracting the matches (using the JSON output) etc.
Once overcome, we can combine this a [static dump of pypi data](https://github.com/orf/pypi-data) to run the whole 
pipeline in parallel like so:

```shell
# Illustrative example, reduced in complexity quite a bit
$ git clone https://github.com/orf/pypi-data.git
$ fd -t f --min-depth=2 . 'release_data/' | parallel --xargs jq 'to_entries[] | .value.urls[].url' > all_urls.txt
$ cat all_urls.txt | parallel -I@ "wget @ -O downloads/@ && rg --json -z --multiline $chonky_regex downloads/@" > matches.txt
```

This took ~27 hours to run on my macbook using my home internet connection.

## Automatically scanning new packages with Github Actions

I took the process outlined above and converted it into a Rust tool: https://github.com/orf/aws-creds-scanner

{{< image-sidebar name=report.png width="is-three-fifths-desktop" content-title="">}}

This tool runs periodically via Github Actions and sca  ns new releases from PyPi, HexPM and RubyGems for AWS keys. If there 
are any keys found then a report is [generated and committed](https://github.com/orf/aws-creds-scanner/blob/main/keys/pypi/pkg-testaws-handsonter/pkg_testaws_handsonter-0.0.1-py3-none-any.whl.md) to repository.

This report contains the keys that have been found, as well as a public link to the keys and other metadata about the 
release. Because these keys are committed to a public Github repository, Github's [Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning) 
service kicks in and notifies AWS that the keys are leaked.

This causes AWS to open a support ticket with you to notify you of the leak, and apply a quarantine policy on the key to 
prevent some high-risk actions from being taken (i.e starting EC2 instances, adjusting permissions, etc).

![](./ticket.png)

{{< /image-sidebar >}}

Running a rust tool every half an hour via Github Actions isn't exactly a web-scale solution to the problem, but it's 
an effective "post-proof-of-concept" that is pretty cost effective ($0!). Rather than use a database to keep track of 
packages that have been processed Github Actions [commits a JSON file](https://github.com/orf/aws-creds-scanner/commit/458f62ab213332918b7363125999425f340a9d72) 
keeping a kind of cursor to the last package it has processed. Subsequent invocations fetch the next set of packages 
after this cursor.

I quite like this pattern - it's not perfect and does not handle individual package failures well, but it works quite 
nicely for periodic tasks like this.

## Analysis of the leaked keys

The oldest still active key was uploaded nearly 10 years ago in 2013, and the newest one was published on the 20th of 
December.

{{< image-sidebar name=breakdown.png width="is-three-fifths-desktop" content-title="">}}

### Key Types

By looking at the name of the principal the key belongs to I attempted to categorize the type of key:

* Root (e.g `arn:aws:iam:..:root`): 11
* User (e.g `arn:aws:iam:..:user/ivan.vasquez`): 18
* Service (e.g `arn:aws:iam:..:user/S3TempUploader`): 22

{{< /image-sidebar >}}


### Types of leaks

Key leaks seem to be broken down into three categories: Accidentally committed files/changes, Test data/test files and 
"Legitimate" usage.

#### Accidentally published files

Authors of Python libraries can push different platform-specific files for each version they release. 
[Tensorflow](https://pypi.org/project/tensorflow/#files) has 16 different versions for different Windows, Linux and MacOS 
versions. While usually these releases all contain exactly the same code, differences are possible.

One example comes from a package version published [by Terradata](https://inspector.pypi.io/project/presto_docker_devenv/0.2/packages/cc/63/a3e1a2b014a9bddd17527edb78479f208d2e57df187048c2aa3916d26a4d/presto_docker_devenv-0.2-py2.7.egg/images/presto-local/debug#line.38). 
The file containing the key, `presto-local/debug`, does not exist in [the _source_ version](https://inspector.pypi.io/project/presto_docker_devenv/0.2/packages/bc/b5/c997b2e174c6a42da60ab3a876d3d76f7f8372c2dd9fce96e9695ab8b146/presto-docker-devenv-0.2.tar.gz/) 
and only exists in the platform-specific `.egg` releases.

It seems that while publishing a release, some files where accidentally bundled before publishing. This implies the release 
was not fully automated.

Amazon themselves fell victim to this: [the `amazon_pay` SDK version 2.5.1](https://inspector.pypi.io/project/amazon_pay/2.5.1/packages/db/20/cc6965de19ba9839823043d50de44ececffeeaa6712c77b16721224ad9c3/amazon_pay-2.5.1.tar.gz/amazon_pay-2.5.1/amazon_pay/integration_test.py#line.6) 
contains an accidental integration test that the developer was working on. This file is not present in previous or 
future releases. There are [other examples of mistakenly added integration tests](https://inspector.pypi.io/project/redisscheduler/1.2.16/packages/93/e8/4c37a2ef79bbb3834307ca5416ba806fe93ed677e3d0c415c7729332a1d5/RedisScheduler-1.2.16.tar.gz/RedisScheduler-1.2.16/RedisScheduler/test.py), 
one from a [third party Amazon SDK](https://inspector.pypi.io/project/python-amazon-mws/0.5/packages/26/74/b93d7d29c87a898ef7b2de8c72c41dc1681f540dd9660fbfdfc9deca39b3/python-amazon-mws-0.5.tar.gz/python-amazon-mws-0.5/mws/test_calls.py).

#### Test files

12 of the 57 keys appear to be included as part of a test suite. These are usually in the form of [integration test credentials](https://inspector.pypi.io/project/pghoard/2.1.0/packages/0a/41/d59cb2fb09ef0ff2ae4eb8ca05a87a31c39741e8bd9e27e657cb73d9ffd1/pghoard-2.1.0.tar.gz/pghoard-2.1.0/test/test_storage_configs.py#line.21).

[DeltaLake added keys to their tests](https://inspector.pypi.io/project/deltalake/0.5.6/packages/95/3b/d6a7690421ef15fbc960d48e886664f0735a93e0afc1ac1a12185329debf/deltalake-0.5.6.tar.gz/deltalake-0.5.6/tests/conftest.py#line.7), 
but later [refactored it to use LocalStack](https://inspector.pypi.io/project/deltalake/0.6.4/packages/b6/e0/d2e6d05fab423d9b440f531ef8ce7193fc87437dcd354a6f1da3251adabc/deltalake-0.6.4.tar.gz/deltalake-0.6.4/tests/conftest.py#line.14).

Other tests are a mix of "accidentally published files" and ad-hoc integration tests, like this [file-level test](https://inspector.pypi.io/project/django_framework/0.1.68/packages/e2/3e/14df84f5a6f5ff0120add4f414bb030936c21bed0ec0abf53c6f2d95d47f/django_framework-0.1.68.tar.gz/django_framework-0.1.68/django_framework/helpers/s3_helpers.py#line.136).

Most test keys are used with S3, but there was one specific test from [BigJob2 that appears to launch an EC2 instance](https://inspector.pypi.io/project/bigjob/0.50d/packages/7e/f7/1ee3982c6a94a6ccbbbc7a975971841aa5683c935cef45081a5ac1299ed2/BigJob-0.50d.tar.gz/BigJob-0.50d/tests/cloud/aws_test_sagabj.py#line.11) 😱.

#### "Legitimate" usage

There are some packages that attempt to use long-lived IAM keys for "legitimate" uses. I put legitimate in quotes here, 
as there are much better ways to allow public access to specific AWS resources that don't involve shared IAM keys.

The majority of these "legitimate" usages involve uploading temporary files to S3.

One example comes from [Sym](https://inspector.pypi.io/project/sym_flow_cli/5.2.0/packages/8f/ad/e458b02baad88d06e7e2d3f8fff41579785f79ae0552bf5d32b43c9e3774/sym_flow_cli-5.2.0-py3-none-any.whl/sym/flow/cli/helpers/constants.py#line.8), an access management company. 
They include some [write-only IAM credentials](https://inspector.pypi.io/project/sym_flow_cli/5.2.0/packages/8f/ad/e458b02baad88d06e7e2d3f8fff41579785f79ae0552bf5d32b43c9e3774/sym_flow_cli-5.2.0-py3-none-any.whl/sym/flow/cli/helpers/constants.py#line.8) and  
apparently use it because their API is [unable to generate temporary signed URLs yet](https://inspector.pypi.io/project/sym_flow_cli/5.2.0/packages/8f/ad/e458b02baad88d06e7e2d3f8fff41579785f79ae0552bf5d32b43c9e3774/sym_flow_cli-5.2.0-py3-none-any.whl/sym/flow/cli/helpers/boto.py#line.32).

Another example in the same vein comes from [mootoo](https://inspector.pypi.io/project/motoo/0.9879/packages/f5/a9/8f182b92cd6d9207ae36b65f0074e38b43a38a83907e5409958584ad8172/motoo-0.9879-py3-none-any.whl/motoo/wit_util.py#line.767).

QuantPanda is a funny example of this. In version 0.0.22 to 0.0.25 the AWS key [was hardcoded](https://inspector.pypi.io/project/QuantPanda/0.0.25/packages/0f/12/a59411004f74a23be4e13246ee868cfcbd40651ab6130766641735363c31/QuantPanda-0.0.25.tar.gz/QuantPanda-0.0.25/QuantPanda/__init__.py#line.1229). 
However, after AWS flagged their key they switched from hard-coding the key [to fetching it from a Gist 🙈](https://inspector.pypi.io/project/QuantPanda/0.0.26/packages/3e/85/9db2f6612e441e45a9ffdb0816e085fd4d3259ec834781774c61e808bc5e/QuantPanda-0.0.26.tar.gz/QuantPanda-0.0.26/QuantPanda/__init__.py#line.1228):

```python
aws_cred_df = pd.read_csv(r'https://gist.githubusercontent.com/ashishongari/eaf6cdede399ad0b2f0696d13982b374/raw/144b2034d49a4c28bbfbd478732de1f35de76b50/aws_cred_df.csv')
aws_access_key_id, aws_secret_access_key = aws_cred_df['aws_access_key_id'].iloc[0], aws_cred_df['aws_secret_access_key'].iloc[0]
```

```
$ curl https://gist.githubusercontent.com/ashishongari/eaf6cdede399ad0b2f0696d13982b374/raw/144b2034d49a4c28bbfbd478732de1f35de76b50/aws_cred_df.csv
aws_access_key_id,aws_secret_access_key
AKIA5LQDGW3AUXC4RDHM,2U0GQ8PQKvwSkiSwBOJrYZRmGpGlHfQtFkoG5EWs
```

I guess some people _really_ don't want to use short-lived credentials?

## Conclusions

I found a lot more keys than I was expecting. Why? I think there's a conflux of different reasons that have led to the 
large number of keys published to PyPi:

1. Testing against AWS is hard. It is often simpler to just test against AWS themselves than set up moto or localstack. 
2. It's easy to accidentally commit files when publishing releases. Python tooling could add an "are you sure" prompt 
   if anything you're publishing has not been fully committed to git.
3. Python allows multiple individual downloads for a given release. Combined with point 2, this makes it easy to publish
   a "correct" release, make some changes and publish a sneakily incorrect one without realising.
4. Python is used heavily for data-science and ML. A lot of the packages I found where around this domain, and perhaps
   best practices around AWS key management are not clear to those practitioners?

