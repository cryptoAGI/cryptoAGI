# pythai.net — portal wiring (Hostinger ⇄ VPS)

**Goal:** pythai.net (Hostinger, web2 DNS delivery portal) shows a **live/deploy admin breakdown**
of every system, while staying **independent of the VPS** — Hostinger serves static files; the VPS
never exposes admin ports to the web.

## The pattern: VPS pushes, Hostinger serves

```
  VPS (systems live here)                         Hostinger (pythai.net)
  ─────────────────────────                       ────────────────────────
  pythai-status.sh  ── probes each subdomain ──►  status.json  ─┐
     (cron, every ~60s)                                          ├─►  index.html renders it
  systems.json  (source of truth) ───────────────────────────► ─┘    (fetch every 60s)
                        push over SFTP/rsync (VPS → Hostinger)
```

- The VPS runs **`pythai-status.sh`** on a timer → writes **`status.json`** (live/deploy state).
- The VPS **pushes** `status.json` (+ `systems.json`, `index.html`) to Hostinger's docroot over
  SFTP/rsync. pythai.net stays a pure static site — no inbound VPS ports, no CORS, no coupling.
- **`index.html`** (the landing) fetches `status.json` client-side every 60s and renders the grid.
  Falls back to `systems.json` (no live state) if the feed hasn't been published yet.

### On the VPS (cron)
```bash
*/1 * * * *  /path/pythai/pythai-status.sh && \
             rsync -az /path/pythai/{status.json,systems.json,index.html} \
                   user@hostinger:~/public_html/portal/
# (SFTP/lftp works too; key-based auth. Only OUTBOUND from the VPS.)
```

### Files in this module (local PYTHAI)
| File | Role |
|------|------|
| `systems.json` | source of truth — every system: subdomain, machine, summary, repos, deploy target |
| `pythai-status.sh` | VPS probe → writes `status.json` (live/deploy admin breakdown) |
| `status.json` | generated live feed (probed just now: 3 live · RAGE auth · 2 coming) |
| `index.html` | modernized landing — grouped menu, live systems grid, **bankon.eth** wallet |
| `mirror/` | mirror of the current pythai.net (Zyro/Hostinger Astro output) for layout/skin reference |

## Skinning & the builder
The current pythai.net is built with **Hostinger's Zyro AI drag-and-drop builder** (kept). This
module is the **template + live-data layer** to skin into it: reuse `mirror/index.html` +
`mirror/layout.css` for layout, drop in `index.html`'s systems grid + menu + wallet as the dynamic
block, and re-skin the tokens at the top of `index.html` (`:root{ --brand … }`).

## Live status right now (probed)
- **bankon.pythai.net** — LIVE (200)
- **rage.pythai.net** — AUTH-gated (403; up, expected)
- **mindx.pythai.net** — LIVE (200) · has `/openapi.json`, `/docs`, `/health` public; `/api`,
  `/status`, `/endpoints` are 401. **300+ endpoints → catalogue from the OpenAPI spec; add the
  x402 paygate (per-request payment) from OVERLORD.**
- **agenticplace.pythai.net** — LIVE (200)
- **cryptoagi.pythai.net** — not created yet
- **deltaverse.pythai.net** — not created yet (deploy target on the OTHER machine)

## Open items (need your machines / access)
- **Publish step** — the VPS→Hostinger `rsync`/SFTP push needs the Hostinger login/SSH (currently
  manual login; a **Hostinger MCP tool module** for VPS + Apache hosting is planned on the OTHER
  machine — wire it here when ready).
- **mindX MCP tool** — lives on the other machine; when connected it can drive the VPS directly. For
  now the portal reads mindX purely via its public subdomain (no admin coupling).
- **cryptoagi / deltaverse subdomains** — create in Hostinger DNS when those systems deploy.
- **wallet** — `bankon.eth` shown; wire live balance/ENS resolution when a read endpoint is chosen.
