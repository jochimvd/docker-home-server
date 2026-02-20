# CrowdSec & Traefik: Troubleshooting False Positives

This guide outlines the workflow for identifying, lifting, and permanently whitelisting false positive bans in the CrowdSec/Traefik stack.

## 1. Identifying a False Positive

When a user reports they are blocked, follow these steps to confirm it's a CrowdSec ban and find the cause.

### Check Ban Status

Verify if the IP is banned and get the Alert ID:

```bash
docker exec crowdsec cscli decisions list -i <IP_ADDRESS>
```

### Inspect the Alert

Find out _why_ they were banned (e.g., `http-probing`, `http-backdoor-attempts`):

```bash
docker exec crowdsec cscli alerts list
docker exec crowdsec cscli alerts inspect <ALERT_ID>
```

Look at the **Context** section to see the specific `target_uri`, `method`, and `status` that triggered the ban.

### Cross-Reference with Traefik Logs

Confirm the behavior in the Traefik access logs:

```bash
# On the host:
grep "<IP_ADDRESS>" /opt/docker-stacks/traefik/data/logs/access.log | tail -n 20
```

## 2. Lifting the Ban (Immediate Fix)

To give the user immediate access while you work on a permanent fix:

```bash
docker exec crowdsec cscli decisions delete -i <IP_ADDRESS>
```

## 3. Creating a Permanent Whitelist (Prevention)

If the behavior is legitimate but triggering a scenario, create a custom whitelist parser.

### Location

Custom whitelist parsers should be placed in:
`/opt/docker-stacks/traefik/data/crowdsec/config/parsers/s02-enrich/`

### Template: `custom-whitelist.yaml`

Check if a whitelist for the service already exists (e.g., `plex-custom-whitelist.yaml`) and update it, or create a new one if it doesn't. Use this structure:

```yaml
name: jvdme/<service>-custom-whitelist
description: "Comprehensive Whitelist for <service> to prevent false positives"
filter: "evt.Meta.service == 'http' && evt.Parsed.traefik_router_name == '<service>@<provider>'"
whitelist:
  reason: "<Service> General False Positive Prevention"
  expression:
    # Example: Whitelist specific status codes on a path
    - evt.Meta.http_status in ['200', '404'] && evt.Meta.http_verb == 'GET' && evt.Meta.http_path startsWith '/some/path'
```

### Apply Changes

After creating or modifying a parser, reload CrowdSec:

```bash
docker kill -s HUP crowdsec
```

### Verify Loading

Check that your custom parser appears in the list and is "enabled,local":

```bash
docker exec crowdsec cscli parsers list
```

## 4. Testing your Whitelist (Advanced)

If you want to be 100% sure your whitelist works without waiting for a ban, use `cscli explain`.

Copy a log line from the Traefik access log that _should_ be whitelisted and run:

```bash
docker exec crowdsec cscli explain --type traefik --log "PASTE_LOG_LINE_HERE"
```

Look for the `s02-enrich` section in the output. It will show if your custom parser was triggered and if the event was whitelisted.

---

**Server Note:** The stack is deployed at `/opt/docker-stacks/traefik`. Access via `ssh port`.
