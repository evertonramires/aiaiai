# aiaiai

Ask your own LLM for the shell command you meant to type.

```
$ aiaiai how to mv all subfolders of /ORGANIZED into current folder
mv /ORGANIZED/*/ .
Moves every immediate subdirectory of /ORGANIZED into the working directory.
run it? [y/N/e(dit)]
```

One Python file, standard library only, no dependencies. Talks to any
OpenAI-compatible endpoint: a local LM Studio or Ollama, your own gateway, the
OpenAI API itself.

## Requirements

- **Python 3.11 or newer.** Nothing else - no pip, no dependencies, standard
  library only. Ubuntu 22.04+, Fedora 36+, Debian 12+ and a Homebrew Python on
  macOS all qualify. `python3 -V` tells you what you have.
- **Linux or macOS.** On Windows use WSL.
- **An OpenAI-compatible endpoint.** Any one of:
  - [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai) running on
    your own machine, free, no account
  - an [OpenAI API key](https://platform.openai.com/api-keys), paid per use
  - your own gateway, or anything else speaking `/v1/chat/completions`

## Install

```sh
git clone https://github.com/<you>/aiaiai.git
cd aiaiai
./install.sh
```

That links `aiaiai` (and the short alias `ai`) into `~/.local/bin`, checks your
Python, then asks you where to send questions, which model to use, any API key,
and what it should do with the answer. It offers to test the connection before
you leave.

To reconfigure later, run `aiaiai --setup`. To edit by hand,
`$EDITOR "$(aiaiai --where)"`. The config file is written `0600` since it can
hold an API key.

Install elsewhere with `./install.sh /usr/local/bin`. `NO_SETUP=1` skips the
questions, `NO_SHORT_ALIAS=1` skips the `ai` link.

`install.sh` links the tool under two names: `aiaiai` and the short alias `ai`.
They are the same program, so use whichever you like:

```sh
ai how to mv all subfolders of /ORGANIZED into current folder
```

If `ai` is already taken on your system the installer says so and leaves it
alone; `NO_SHORT_ALIAS=1 ./install.sh` skips it outright.

## Output modes

The config file sets the default; a flag overrides it for one call.

| mode | flag | what happens |
|---|---|---|
| `command` | `-c` | prints only the command, nothing else |
| `explain` | `-e` | prints the command, plus one or two lines of explanation |
| `confirm` | `-r` | prints it and asks `y / N / e(dit)` before running (default) |
| `auto` | `-y` | runs it immediately |

The command always goes to **stdout** and everything else to **stderr**, so
substitution works:

```sh
$(ai -c list every png here)
ai -c archive this folder | tee last-command.sh
```

In `auto` mode a command matching a destructive pattern (`rm -rf`, `mkfs`,
`dd of=/dev/…`, `kubectl delete`, `git push --force`, piping curl into a shell,
…) still stops for confirmation. `--force` turns that off.

## Configuration

`~/.config/aiaiai/config.toml` (`aiaiai --where` prints the path in use):

```toml
# the trailing /v1 is optional, both forms work
base_url = "http://localhost:1234/v1"
model    = "local-model"
api_key  = "not-required"

mode  = "confirm"        # command | explain | confirm | auto
shell = "auto"           # "auto" follows $SHELL

context = true           # send the cwd listing so the model uses real names
max_context_entries = 40

tools = true             # tell the model which commands are on your PATH
extra_tools = []         # probe for these too

temperature = 0.2
timeout = 120
```

Environment variables win over the file: `AIAIAI_BASE_URL`, `AIAIAI_MODEL`,
`AIAIAI_API_KEY`, `AIAIAI_MODE`, `AIAIAI_SHELL`.

## Context sent to the model

So it answers for *your* machine rather than a generic one:

- the working directory, and a listing of it
- a listing of up to three absolute directory paths mentioned in the request, so
  `aiaiai move the reports in /srv/data somewhere` sees what is really there
- your distribution and version - `Ubuntu 24.04.4 LTS`, `macOS 15.1` - plus
  whether the userland is GNU or BSD, which decides half of `sed` and `find`
- your shell
- which commands actually exist on your `PATH`, from a fixed probe list, so it
  suggests `rg` only if you have `rg`, and `apt` rather than `dnf`

The probe is a PATH lookup of about fifty well-known tools, not your package
list: bounded, fast, and it does not tell the model what software you have
installed beyond those. Add your own with `extra_tools = ["terraform", "just"]`,
or turn it off with `tools = false`.

`--no-context` or `context = false` drops the listings and the tool probe.

Anything piped into aiaiai is appended to the request, truncated at 4000 chars:

```sh
git status | aiaiai -e what should I clean up here
```

## Flags

```
-c --command      print only the command
-e --explain      command plus explanation
-r --run          ask before running
-y --yes --auto   run without asking
-m --model NAME   override the model for this call
   --url URL      override the base url
   --config PATH  use another config file
   --no-context   skip the directory listing
   --force        no extra prompt on dangerous commands in auto mode
   --setup        interactive configuration (re-run any time)
   --init         write an example config
   --where        print the config path
-h --help         usage
-V --version      version
```

If the request starts with a dash, put `--` first:
`aiaiai -- -rf, what does that mean in rm`.

## Notes

Commands run in a subprocess, so `cd` cannot change the shell you are sitting
in. For that, wrap it:

```sh
aiaiai-here() { eval "$(command aiaiai -c "$@")" }
```
