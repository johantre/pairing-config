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

Only public keys and an address go in here — nothing that lets someone log
in. Still: private repo, reviewed pull requests. Who can merge into this
repo decides who gets into your sessions.

## In what order

The full walkthrough is in [pairing-setup's README](https://github.com/johantre/pairing-setup#setup-in-four-steps);
in short:

1. **Create your private copy** of this repo (above).
2. **Set up the relay** and fill in `relay.conf`. The relay starts closed:
   `relay_authorized_hosts` is still empty, so nobody can host yet.
3. **Install each host.** The installer prints the machine's relay login
   key; add it to `relay_authorized_hosts` in a pull request, after which
   the relay admin applies the list.
4. **Add participants** to `team_authorized_keys`, also via pull requests.
   Hosts pull and re-run the installer to pick them up.
