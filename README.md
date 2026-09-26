# Pairing config (template)

Your team's settings for [pairing-setup](https://github.com/johantre/pairing-setup):
which relay you use, who may join your sessions, and which machines may
host them. pairing-setup holds the tools; this repo holds the data that's
specific to your team. Keeping them apart lets you update the tools with a
plain `git pull`, without your team's details ever ending up in the public
tool repo.

> [!IMPORTANT]
> **Make your copy private.** This template is public, but a filled-in copy
> tells anyone who reads it where your relay is and who is on your team.
> Public keys themselves aren't secret, but there's no reason to publish
> that map.

## Get your own copy

1. On GitHub, click **Use this template → Create a new repository**.
2. Pick your team's account or organisation, name it (e.g.
   `pairing-config`), and choose **Private**.
3. Clone it next to pairing-setup, so the installers find it without
   extra options:
   ```
   your-folder/
   ├── pairing-setup/     ← the tools (public)
   └── pairing-config/    ← your copy of this (private)
   ```
   Somewhere else works too; pass `--config <path>` to the installers
   (`-Config <path>` on Windows).

## What's in it

| File | Filled in by | Contains | Decides |
|---|---|---|---|
| [`relay.conf`](relay.conf) | whoever runs the relay, once | the relay's address and its SSH server key | which relay everyone uses, and how they recognise the real one |
| [`relay_authorized_hosts`](relay_authorized_hosts) | each new host, via a pull request | the host machines' relay login keys | who may **start** sessions on the relay |
| [`team_authorized_keys`](team_authorized_keys) | each participant, via a pull request | the participants' SSH public keys | who may **join** a session |
| [`join`](join), [`join.ps1`](join.ps1) | — (ready to use) | the command participants join with | — |

Only public keys and an address go in here — nothing that lets someone log
in. Still: private repo, reviewed pull requests. Who can merge into this
repo decides who gets into your sessions.

One copy of this repo is one relay with one join list: everyone in
`team_authorized_keys` can join any session on that relay once they have
its token. Fine for people who trust each other; a group that must be
kept apart gets its own relay and its own copy (see
[One relay per group that trusts each other](https://github.com/johantre/pairing-setup/blob/main/docs/relay.md#one-relay-per-group-that-trusts-each-other)).

## Joining a session

Participants need nothing but a clone of your team's copy of this repo and
an SSH client (built into macOS, Linux and Windows 10+). From its folder:

| | macOS / Linux / WSL | Windows (PowerShell) |
|---|---|---|
| **First time** — create your key, pin the relay, show the line for your pull request | `./join` | `.\join.ps1` |
| **Each session** — with the token the host shared | `./join <token>` | `.\join.ps1 <token>` |
| **Or** paste the host's whole command | `./join "ssh <token>@<host> -p <port>"` | `.\join.ps1 "ssh <token>@<host> -p <port>"` |

Every run checks what's missing and skips what's already done, then
connects with the right key, host and port. It only touches your own
`~/.ssh`, and refuses a command that points to another relay than the one
in `relay.conf`. More in
[What `join` does](https://github.com/johantre/pairing-setup/blob/main/docs/join.md).

## In what order

The full walkthrough is in [pairing-setup's README](https://github.com/johantre/pairing-setup#1-set-up-for-your-team-once);
in short:

1. **Create your private copy** of this repo (above).
2. **Set up the relay** and fill in `relay.conf`. The relay starts closed:
   `relay_authorized_hosts` is still empty, so nobody can host yet.
   (Or, knowingly, use `upterm`'s public relay — see
   [Using the public relay instead](https://github.com/johantre/pairing-setup/blob/main/docs/relay.md#using-the-public-relay-instead)
   for the values; then `relay_authorized_hosts` isn't used.)
3. **Install each host.** The installer prints the machine's relay login
   key; add it to `relay_authorized_hosts` in a pull request, after which
   the relay admin applies the list.
4. **Add participants** to `team_authorized_keys`, also via pull requests.
   Hosts pull and re-run the installer to pick them up.
