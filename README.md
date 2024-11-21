# fr
Find/replace for busy people.

## Overview

fr is a commandline utility for interactive find/replace across multiple file types for
an entire project (frontend, backend, utility scripts, etc).

It can pick up structured comments in the matched files and recursively find/replace
lines across your entire project allowing a developer to leave a comment when they
spot a misspelled variable or something that needs to be renamed and run the tool to
fix the issue once they have time.

It also allows the user to selectively exclude specific lines from the list of changes
interactively and presents a preview before writing to the filesystem.

fr is written in elixir and leverages the Erlang virtual machine's awesome concurrency to
stream files in parallel making it very fast and memory efficient even on large batches.

## Basic Usage

fr searches files based on file extensions and an optional root directory all given on the
commandline.

```bash
fr -e ex,exs,py,html --find search --replace update src
```

If the optional `--find` and `--replace` switches are not given, fr will search for lines
containing structured "findtags" of the form: `[[fr]]label::find::replace[[fr]]` in any
matched files, and then present the user with a list of these findtags to choose from.

If the findtag does not have the `replace` section e.g. `[[fr]]rename::my_func[[fr]]`, then
the user will be prompted to provide the string to replace `find` with. This allows a
developer to leave a comment for a rename even if they don't know what they want to
change it to yet.

Once a findtag is selected or lines have been matched with `--find` and `--replace`, the
user can interactively remove lines from the list of changes and view a preview of
all replacements before writing the changes to disk.

If a findtag was used, then the line with the findtag comment will also be removed.
This means that inline comments cannot be used to declare findtags or the entire
line will be removed. However, since findtags are not dependent on the semantics
of the language, they can be added to any filetype.
For example, in JSON, which doesn't support comments, this works:

```json
{
  "fr-comment": "[[fr]]rename::dependencies::devDependencies[[fr]]",
  "dependencies": {
    "prettier": "^3.3.2",
  }
}
```

### fr --check

The `--check` flag lists all findtags found in the matched files.
For example, `fr -e ex,exs src --check` will print a list of any findtags
found in `.ex` or `.exs` files underneath the `src` directory recursively.

This switch also returns a system exit code of 1 if findtags are found or 0
if no findtags were found. This can be used in a CI workflow to ensure all
findtags are resolved before merging.

## Motivation

Why make this? IDEs and LSPs have really good semantic renaming capabilities, right?

I'm a full stack developer, so I work on projects in several different languages across frontend,
backend, infrastructure, and system code. My personal projects have multiple servers written
in Python and Elixir with frontends written in multiple template languages (jinja, heex) as well as
pure HTML and Javascript, so when I need to rename something, my LSP is not good enough. I need
to be able to rename identifiers across many different file types. Additionally, I often find myself
renaming concepts as opposed to variables (e.g. user -> visitor), and this usually involves string literals in
xml or json files as well as indentifiers in multiple languages.

I have been using sed for this task for a few years, but I'm too stupid for sed, and I'm tired
of borking projects and running `git reset --hard`, so I wrote something that a monkey could use.

## Installation

Currently, fr only supports building from source, so [elixir](https://elixir-lang.org/install.html)
is required.

Once elixir is installed:

```bash
git clone https://github.com/GrammAcc/fr
cd fr
MIX_ENV=prod mix escript.build
```

This will create a standalone binary named `fr` in the project's root directory.

Run `./fr --version` to confirm the tool was built correctly.

This binary can be moved anywhere in the system and executed with its full
path, but it is recommended to add it to your shell's $PATH.

```bash
mkdir ~/fr_build
mv ./fr ~/fr_build
export PATH=~/fr_build/:$PATH
```
