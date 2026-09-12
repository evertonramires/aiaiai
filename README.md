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

## Install

```sh
git clone https://github.com/<you>/aiaiai.git
cd aiaiai && ./install.sh   # symlinks aiaiai + ai into ~/.local/bin
aiaiai --init               # writes ~/.config/aiaiai/config.toml
$EDITOR "$(aiaiai --where)" # point base_url and model at your endpoint
```

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

temperature = 0.2
timeout = 120
```

Environment variables win over the file: `AIAIAI_BASE_URL`, `AIAIAI_MODEL`,
`AIAIAI_API_KEY`, `AIAIAI_MODE`, `AIAIAI_SHELL`.

## Context sent to the model

The working directory, OS, shell name, a listing of the cwd, and a listing of up
to three absolute directory paths mentioned in the request (so
`aiaiai move the reports in /srv/data somewhere` can see what is actually in
`/srv/data`). `--no-context` or `context = false` sends only cwd, OS and shell.

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
