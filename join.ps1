<#
.SYNOPSIS
  Joins a pairing session on this team's relay, from native Windows
  (PowerShell, no WSL needed). On macOS, Linux or WSL, use ./join instead.

.DESCRIPTION
  Every run checks what's missing and skips what's already done: your
  client key, the relay's pinned server key, and whether your key is on the
  team list. Then it joins. Nothing is installed; it only touches your own
  $HOME\.ssh.

.EXAMPLE
  .\join.ps1
  Set up only: key, relay pin, team-list check.

.EXAMPLE
  .\join.ps1 <token>
  Set up what's missing, then join.

.EXAMPLE
  .\join.ps1 "ssh <token>@<relay-host> -p <port>"
  Same, pasting the command the host shared.
#>

$ErrorActionPreference = "Stop"

$Dir = $PSScriptRoot
$SshDir = Join-Path $HOME ".ssh"
$Key = Join-Path $SshDir "upterm_client_key"
$KnownHosts = Join-Path $SshDir "known_hosts"

function Say($msg)  { Write-Host $msg }
function Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Err($msg)  { Write-Host $msg -ForegroundColor Red }

if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
  Err "No ssh.exe found. Enable Windows' built-in OpenSSH client:"
  Err "  Settings > System > Optional features > Add a feature > OpenSSH Client"
  exit 1
}

# --- the team's relay ---------------------------------------------------------
$conf = @{}
foreach ($line in Get-Content (Join-Path $Dir "relay.conf")) {
  if ($line -match '^\s*(\w+)="(.*)"\s*$') { $conf[$Matches[1]] = $Matches[2] }
}
$RelayHost = $conf["RELAY_HOST"]; $RelayPort = $conf["RELAY_PORT"]; $ServerKey = $conf["RELAY_SERVER_KEY"]
if (-not $RelayHost -or -not $RelayPort -or -not $ServerKey) {
  Err "relay.conf isn't filled in yet - ask whoever runs your relay."
  exit 1
}
# known_hosts writes port 22 as a bare host name, any other port as [host]:port.
if ($RelayPort -eq "22") { $KhName = $RelayHost } else { $KhName = "[$RelayHost]:$RelayPort" }

# --- what to join: a bare token, or the pasted ssh command --------------------
$Token = ""
if ($args.Count -gt 0) {
  $words = ($args -join " ") -split '\s+' | Where-Object { $_ -ne "" }
  $cmdHost = ""; $cmdPort = ""; $prev = ""
  foreach ($w in $words) {
    if ($w -eq "ssh" -or $w -eq "-p") { }
    elseif ($w -like "*@*") { $at = $w.LastIndexOf("@"); $Token = $w.Substring(0, $at); $cmdHost = $w.Substring($at + 1) }
    elseif ($prev -eq "-p") { $cmdPort = $w }
    elseif (-not $Token) { $Token = $w }
    $prev = $w
  }
  if ($cmdHost -and $cmdHost -ne $RelayHost) {
    Err "That command points to $cmdHost, but your team's relay (relay.conf) is $RelayHost."
    Err "Only join sessions on your own relay."
    exit 1
  }
  if ($cmdPort -and $cmdPort -ne $RelayPort) {
    Err "That command uses port $cmdPort, but your team's relay (relay.conf) uses $RelayPort."
    exit 1
  }
  if (-not $Token) { Err "Couldn't find a session token in: $($args -join ' ')"; exit 1 }
}

# --- 1. your client key -------------------------------------------------------
New-Item -ItemType Directory -Force $SshDir | Out-Null
if (Test-Path $Key) {
  Say "OK  Client key: $Key"
} else {
  # Through Start-Process on purpose: it hands ssh-keygen one raw command
  # line, so -N "" arrives as an empty passphrase in every PowerShell
  # version (passing "" directly gets dropped or mangled depending on it).
  $argLine = "-t ed25519 -N `"`" -f `"$Key`" -C `"$env:USERNAME@$env:COMPUTERNAME`" -q"
  $p = Start-Process ssh-keygen.exe -ArgumentList $argLine -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0 -or -not (Test-Path $Key)) { Err "ssh-keygen failed to create $Key"; exit 1 }
  Say "OK  Created client key: $Key"
}

# --- 2. the relay's server key, pinned ------------------------------------------
# Without it, the first connection is a blind yes/no prompt that looks the
# same whether you reach the real relay or an impersonator.
if (-not (Test-Path $KnownHosts)) { New-Item -ItemType File $KnownHosts | Out-Null }
$known = @(& ssh-keygen.exe -F $KhName -f $KnownHosts 2>$null | Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { $f = $_ -split '\s+'; "$($f[1]) $($f[2])" })
if ($known -contains $ServerKey) {
  Say "OK  Relay server key pinned for $KhName"
} elseif ($known.Count -gt 0) {
  Err "Your known_hosts already has a DIFFERENT key for $KhName than relay.conf."
  Err "Either the relay was redeployed with a new key (check with its admin, and pull"
  Err "pairing-config), or something is impersonating it. Once you know it's the"
  Err "former, remove the old entry and run this again:"
  Err "  ssh-keygen -R '$KhName'"
  exit 1
} else {
  Add-Content -Encoding ascii $KnownHosts "$KhName $ServerKey"
  Say "OK  Pinned relay server key for $KhName"
}

# --- 3. are you on the team list? ---------------------------------------------
# Going by this checkout of pairing-config; the host's installed copy is what
# actually counts, so this is a hint, not a gate.
$pub = (Get-Content "$Key.pub" -Raw).Trim()
$blob = ($pub -split '\s+')[1]
if ((Get-Content (Join-Path $Dir "team_authorized_keys") -Raw) -match [regex]::Escape($blob)) {
  Say "OK  Your key is in team_authorized_keys"
} else {
  Warn "Your key isn't in team_authorized_keys (in this checkout) yet."
  Warn "Add this line to team_authorized_keys in a pull request:"
  Say ""
  Say "  $pub"
  Say ""
  Warn "Already merged? Run 'git pull' here. Hosts need to pull and re-run their"
  Warn "installer too before their sessions let you in."
}

if (-not $Token) { Say ""; Say "Set up. To join a session: .\join.ps1 <token>"; exit 0 }

# --- 4. join ------------------------------------------------------------------
Say ""
Say "Joining session on ${RelayHost}:$RelayPort ..."
# IdentitiesOnly: offer only the client key - an ssh-agent full of other keys
# otherwise runs into "Too many authentication failures" first.
& ssh.exe -i $Key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -p $RelayPort "$Token@$RelayHost"
$rc = $LASTEXITCODE
if ($rc -eq 255) {
  Say ""
  Warn "Couldn't join. If ssh said 'Permission denied (publickey)': your key isn't in"
  Warn "the host's installed team list yet (PR merged? host pulled and re-ran the"
  Warn "installer?), or the session has ended. Otherwise: is the token right, and"
  Warn "is the session still running?"
}
exit $rc
