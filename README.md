# aiaiai

Ask your own AI for the command you meant to type, without leaving the terminal.

```console
$ ai how to mv all subfolders of /ORGANIZED into current folder
mv /ORGANIZED/*/ .
Moves every immediate subdirectory of /ORGANIZED into the working directory.
run it? [y/N/e(dit)]
```

One file, no dependencies, works with any OpenAI-compatible API - a local
[Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai), an OpenAI key,
or your own gateway. Nothing is sent anywhere except the endpoint you choose.

## Install

**Linux and macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/evertonramires/aiaiai/main/install.sh | sh
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/evertonramires/aiaiai/main/install.ps1 | iex
```

The installer finds Python (and offers to install it if it is missing), puts
`aiaiai` and the short alias `ai` on your PATH, then asks you four questions:
which AI to use, which model, an API key if the service needs one, and what it
should do with the commands it writes. It offers to test the connection before
you go.

If your PATH needed changing it prints one line to copy, paste, and you are
done. Otherwise you can use it immediately.

<details>
<summary>Prefer to read the script first? (a good habit)</summary>

```sh
git clone https://github.com/evertonramires/aiaiai.git
cd aiaiai
less aiaiai        # it is one readable file
./install.sh
```

`NO_SETUP=1` skips the questions, `NO_SHORT_ALIAS=1` skips the `ai` alias, and
`NO_PATH_EDIT=1` leaves your shell config alone. On Windows the equivalents are
`$env:AIAIAI_NO_SETUP`, `$env:AIAIAI_NO_SHORT_ALIAS` and `$env:AIAIAI_DIR`.
</details>

## Use it

```sh
ai find every file bigger than 1G under /var
ai why is my disk full
git status | ai what should I clean up here
```

`ai` and `aiaiai` are the same program. Pick whichever you like.

### What it does with the answer

The setup picked a default for you; a flag overrides it for one call.

| mode | flag | what happens |
|---|---|---|
| `command` | `-c` | prints only the command, runs nothing |
| `explain` | `-e` | prints the command with a short explanation |
| `confirm` | `-r` | prints it, then asks `y / N / e(dit)` before running |
| `auto` | `-y` | runs it immediately |

Press `e` at the prompt to edit the command before it runs.

The command goes to **stdout** and everything else to **stderr**, so it composes:

```sh
$(ai -c list every png here)
ai -c archive this folder | tee last-command.sh
```

### It will not quietly wreck your machine

In `auto` mode a command that matches a destructive pattern - `rm -rf`,
`Remove-Item -Recurse -Force`, `mkfs`, `dd of=/dev/…`, `kubectl delete`,
`git push --force`, piping the internet into a shell - still stops and asks.
`--force` turns that off.

It is a safety net, not a guarantee. Read what you run.

## Configure

Run `ai --setup` any time to change anything. To edit by hand:

```sh
$EDITOR "$(ai --where)"
```

```toml
base_url = "http://localhost:11434/v1"   # any OpenAI-compatible endpoint
model    = "llama3.2"
api_key  = "not-required"

mode  = "confirm"   # command | explain | confirm | auto
shell = "auto"      # "auto" follows $SHELL, or PowerShell on Windows

timeout = 90        # seconds to wait for the model before giving up

context = true      # send the directory listing so it uses real names
max_context_entries = 40
tools = true        # tell it which commands exist on your PATH
extra_tools = []    # probe for these too

temperature = 0.2
```

The file lives in `~/.config/aiaiai/config.toml`
(`%APPDATA%\aiaiai\config.toml` on Windows) and is written `0600`, since it can
hold an API key. Environment variables win over the file: `AIAIAI_BASE_URL`,
`AIAIAI_MODEL`, `AIAIAI_API_KEY`, `AIAIAI_MODE`, `AIAIAI_SHELL`.

## What it tells the model

So the answer fits your machine rather than a generic one:

- the working directory and a listing of it
- a listing of up to three absolute paths named in your request, so
  `ai move the reports in /srv/data somewhere` sees what is really there
- your distribution and version - `Ubuntu 24.04.1 LTS`, `macOS 15.1`,
  `Windows 11` - and whether the userland is GNU, BSD or PowerShell, which
  decides half of `sed`, `find` and friends
- your shell
- which commands exist on your PATH, from a fixed probe of about fifty
  well-known tools, so it suggests `rg` only if you have `rg`, and `apt` rather
  than `dnf`

That probe is a PATH lookup of a known list, not an inventory of your installed
software. Add your own with `extra_tools = ["terraform", "just"]`, or switch it
off with `tools = false`. `--no-context` drops the listings and the probe for
one call.

## Options

```
-c --command      print only the command
-e --explain      command plus a short explanation
-r --run          ask before running
-y --yes --auto   run without asking
-m --model NAME   override the model for this call
   --url URL      override the base url
   --timeout SECS override how long to wait for an answer
   --config PATH  use another config file
   --no-context   skip the directory listing and tool probe
   --force        no extra prompt on dangerous commands in auto mode
   --setup        interactive configuration, re-runnable any time
   --init         write a default config
   --where        print the config path
-h --help         usage
-V --version      version
```

If your request starts with a dash, put `--` first:
`ai -- -rf, what does that mean in rm`.

## Requirements

- **Python 3.11+**. The installer checks, and offers to install it for you.
- **Linux, macOS or Windows.** PowerShell is supported natively: on Windows it
  writes PowerShell, and it will use `pwsh` anywhere if you set `shell = "pwsh"`.
- **An OpenAI-compatible endpoint.** Ollama and LM Studio are free and run on
  your own machine; an OpenAI key works too.

## Trouble

| what you see | what to do |
|---|---|
| `command not found: ai` | open a new terminal, or run the line the installer printed |
| `cannot reach ...` | is your AI running? `ai --setup` to change the address |
| `HTTP 401` | the API key is wrong - `ai --setup` |
| `HTTP 404` | the model name or url is wrong - `ai --setup` |
| `did not answer within 90s` | raise `timeout`, or use a smaller model |
| it suggests nonsense | a bigger model helps a lot here |

## Uninstall

```sh
rm ~/.local/bin/aiaiai ~/.local/bin/ai
rm -rf ~/.config/aiaiai
```

On Windows, delete `%LOCALAPPDATA%\Programs\aiaiai` and `%APPDATA%\aiaiai`, and
remove that first path from your user PATH.

## License

[AGPL-3.0-or-later](LICENSE). Free software: use it, change it, share it. If you
run a modified version as a network service, publish your changes.
