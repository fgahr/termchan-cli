# termchan-cli -- A Minimalistic Client for Termchan

## About

This is a small wrapper around the various curl commands to interact with a
[termchan](https://github.com/fgahr/termchan) server.

## Installation

Clone this repository, create a symlink to `main.sh`, e.g. via

```
ln -s $PWD/main.sh ~/.local/bin/tccli
```

This will make the program available under the name `tccli` which this README
will assume. However, choose any name you like.

## Configuration

For its operation, `tccli` needs to know the server and port to connect to, as
well as optionally a user name for your posts. To achieve this, you can export
the variables `TERMCHAN_SERVER`, `TERMCHAN_PORT`, and `TERMCHAN_NAME`.

In order to simplify usage, `tccli` can store this information in the file
`~/.config/termchan-cli/settings.sh` where the variables are named `server`,
`port`, and `name`. Usual shell syntax applies, e.g.

```text
## ~/.config/termchan-cli/settings.sh
# termchan server name or IP
server=localhost
# port on which the server is listening
port=8088
# Name can be empty to post anonymously
name=
```

When not otherwise defined, the script will ask for this information
interactively.

## Usage

```text
$ tccli help
Usage: tccli command [opt]

Available commands:
 h|help                        print this help message
 w|welcome                     print the server's welcome message
 v|view          [board[/id]]  view a board or a thread
 r|reply         [board/id]    reply to a thread (interactive)
 c|create-thread [board]       create a new thread (interactive)
```

### View a Thread or Board

```text
# View a thread
$ tccli view b/2
...
# View a board
$ tccli v g
...
```

### Reply to a Thread

```text
$ tccli reply g/78
... [prompt for post content]
```

### Create a Thread

```text
$ tccli create b
... [prompts for topic and content]
```
