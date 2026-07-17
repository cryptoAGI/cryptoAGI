# PYTHAI portal

The pythai.net landing + live/deploy admin breakdown of every PYTHAI system.

- `index.html` — the modernized landing (grouped menu · live systems grid · PARSEC/bankon.eth wallet · deployment roadmap). Skinnable via the `:root{}` tokens.
- `systems.json` — source of truth: every subdomain system, the PARSEC wallet, the deployment sequence.
- `pythai-status.sh` — run on the VPS → writes `status.json` (the live feed the portal renders).
- `status.json` — a sample live feed.
- `mirror/` — mirror of the current pythai.net (Zyro/Hostinger build) for layout/skin reference.
- `WIRING.md` — how Hostinger (pythai.net) wires to the VPS (VPS pushes status.json; site stays static).

Serve locally: `python3 -m http.server 8899` → http://127.0.0.1:8899/pythai/
