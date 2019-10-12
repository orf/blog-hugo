---
title: "Testing my dotfiles with Github actions"
date: 2019-10-12T19:01:55+01:00
---

I went through a phase that involved reinstalling MacOS way, way too 
often. At a certain point I got fed up with installing things over 
and over again and decided to version my dotfiles.
And so https://github.com/orf/dotfiles was born.

This reolved around a `bootstrap.sh` script that clones your dotfiles 
repository and does some git tricks to check out the contents to your 
home directory and keep the actual git repository under `~/.dotfiles`.
While this wasn't an original piece of work (thanks Stack Overflow!), I 
did modify it to do [a sparse checkout](https://stackoverflow.com/questions/4114887/is-it-possible-to-do-a-sparse-checkout-without-checking-out-the-whole-repository), 
making it ignore the `README.md` in the repository (nobody want's a `README.md` 
file in your home directory).

This worked fantastically, until I needed to reinstall my machine again. 
At that point I found a few issues with the shell script, made some fixes 
and moved on with my life. However this isn't ideal. You should have 
confidence that the `bootstrap.sh` will actually work, and continue to 
work!

### Enter Github actions

I spent some time last week setting up a Github actions workflow for my 
dotfiles. This is the complete workflow:

```yaml
on: [push]

name: CI

jobs:
  build_and_test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@master
      - name: Run bootstrap
        shell: bash
        run: |
          brew untap caskroom/versions
          ./bootstrap.sh
        env:
          REPO: ${{github.workspace}}
          DOTFILES_REF: ${{github.sha}}
          HOMEBREW_BUNDLE_BREW_SKIP: "node"
```

The bootstrap script clones the latest master to your home directory. 
This is ideal when bootstrapping a new machine, it's not what you want 
when you are running a CI job. So I modified the script to pull from the 
local checkout being tested (that's the `REPO` environment variable).

The script also needs a reference to check out due to the sparse checkout 
method I mentioned above, so the `DOTFILES_REF` variable makes the 
script check out the current commit being tested.

The MacOS environment isn't signed into the Mac App Store which means 
that the [`mas` dependencies](https://github.com/mas-cli/mas) would 
fail to install. I added a simple if condition to my `.Brewfile` (which 
 is i just a Ruby file) to handle that if the `CI` environment variable is set:

```ruby
# Github actions cannot install these.
if unless ENV.has_key?('CI') then
    brew "mas"
    mas '1Password', id:1333542190
    # etc
end
```

### A few thoughts on Github Actions

#### Speed

Gitlab actions are really quick to start. Unlike Travis MacOS builds start instantly.

#### HCL vs Yaml

Github actions are really, really awesome. When they where first 
introduced they used a rather weird HCL (i.e Terraform) syntax:

```hcl
action "terraform-init" {
  uses = "hashicorp/terraform-github-actions/init@v<latest version>"
  needs = "terraform-fmt"
  secrets = ["GITHUB_TOKEN"]
  env = {
    TF_ACTION_WORKING_DIR = "."
  }
}
```

This kind of threw me off at first - it's a bit weird and unclear. I think they understood that because they 
have since  moved to a YAML structure:

```yaml
jobs:
  on-pull-request:
    name: On Pull Request
    runs-on: ubuntu-latest
    - name: Terraform Init
      uses: hashicorp/terraform-github-actions/init@v0.4.0
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        TF_ACTION_WORKING_DIR: '.'
        AWS_ACCESS_KEY_ID:  ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY:  ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Coming from Gitlab-CI I much prefer this.
