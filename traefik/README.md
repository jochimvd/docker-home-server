To prevent false positive crowdsec bans I created this rule in `data/crowdsec/config/parsers/s02-enrich`:

```yaml
name: custom/plex-whitelist
description: "Whitelist false positives from Plex clients"
filter: "evt.Meta.service == 'http' && evt.Meta.log_type in ['http_access-log', 'http_error-log']"
whitelist:
  reason: "Whitelist false positives from Plex clients"
  expression:
    - evt.Parsed.traefik_router_name == 'plex@file' && evt.Meta.http_status == '403' && evt.Meta.http_verb in ['POST', 'GET']
    - evt.Parsed.traefik_router_name == 'overseerr@docker' && evt.Meta.http_status == '403' && evt.Meta.http_verb in ['POST', 'GET']
```
