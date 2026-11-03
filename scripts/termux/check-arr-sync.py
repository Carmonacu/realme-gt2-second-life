#!/usr/bin/env python3
"""Diagnostic: Prowlarr vs Radarr/Sonarr indexer counts (run inside proot Ubuntu)."""
import json
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

BASE = Path("/data/data/com.termux/files/home/media-arr/config")
PORTS = {"prowlarr": 9696, "radarr": 7878, "sonarr": 8989}


def api_key(app: str) -> str | None:
    p = BASE / app / "config.xml"
    if not p.exists():
        return None
    el = ET.parse(p).getroot().find("ApiKey")
    return el.text if el is not None else None


def get(app: str, path: str):
    k = api_key(app)
    if not k:
        print(f"MISSING config for {app}")
        return None
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORTS[app]}{path}",
        headers={"X-Api-Key": k},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def main() -> None:
    prowlarr_indexers = get("prowlarr", "/api/v1/indexer") or []
    apps = get("prowlarr", "/api/v1/applications") or []
    profiles = get("prowlarr", "/api/v1/appprofile") or []
    radarr_indexers = get("radarr", "/api/v3/indexer") or []
    sonarr_indexers = get("sonarr", "/api/v3/indexer") or []

    print("=== Prowlarr app profiles ===")
    for p in profiles:
        print(f"  id={p['id']} name={p.get('name')}")

    print("=== Prowlarr applications (fields) ===")
    for a in apps:
        print(f"  --- {a['name']} id={a['id']} syncLevel={a.get('syncLevel')} ---")
        for f in a.get("fields", []):
            name = f.get("name", "")
            val = f.get("value")
            if "key" in name.lower() or "password" in name.lower() or name == "apiKey":
                val = "(redacted)" if val else None
            print(f"    {name}={val!r}")

    print("=== Prowlarr indexers ===")
    for i in prowlarr_indexers:
        print(
            f"  {i['name']}: enable={i['enable']} id={i['id']} "
            f"appProfileId={i.get('appProfileId')} tags={i.get('tags', [])}"
        )

    print("=== Radarr indexers ===")
    for i in radarr_indexers:
        print(f"  {i['name']}: enable={i.get('enable')} id={i['id']}")

    print("=== Sonarr indexers ===")
    for i in sonarr_indexers:
        print(f"  {i['name']}: enable={i.get('enable')} id={i['id']}")

    print(
        f"COUNTS prowlarr={len(prowlarr_indexers)} radarr={len(radarr_indexers)} "
        f"sonarr={len(sonarr_indexers)}"
    )

    health = get("radarr", "/api/v3/health") or []
    if health:
        print("=== Radarr health ===")
        for h in health:
            print(f"  [{h.get('type')}] {h.get('message')}")
    else:
        print("=== Radarr health === (ok or empty)")


def post_prowlarr(path: str, body: dict):
    k = api_key("prowlarr")
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORTS['prowlarr']}{path}",
        data=data,
        headers={"X-Api-Key": k, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def sync_apps() -> None:
    apps = get("prowlarr", "/api/v1/applications") or []
    for a in apps:
        print(f"Trigger sync: {a['name']} (id={a['id']})")
        try:
            cmd = post_prowlarr(
                "/api/v1/command",
                {"name": "ApplicationIndexerSync", "appId": a["id"]},
            )
            print(f"  command id={cmd.get('id')} status={cmd.get('status')}")
        except Exception as e:
            print(f"  ERROR: {e}")


def put_prowlarr(path: str, body: dict):
    k = api_key("prowlarr")
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORTS['prowlarr']}{path}",
        data=data,
        headers={"X-Api-Key": k, "Content-Type": "application/json"},
        method="PUT",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def clear_app_sync_tags() -> None:
    """Prowlarr skips indexers when app tags do not intersect indexer tags."""
    apps = get("prowlarr", "/api/v1/applications") or []
    for a in apps:
        if not a.get("tags"):
            print(f"Skip {a['name']}: app tags already empty")
            continue
        print(f"Clear app tags on {a['name']}: was {a.get('tags')}")
        a["tags"] = []
        put_prowlarr(f"/api/v1/applications/{a['id']}", a)
    sync_apps()


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--sync":
        sync_apps()
        print("--- after sync ---")
    elif len(sys.argv) > 1 and sys.argv[1] == "--fix-app-tags":
        clear_app_sync_tags()
        print("--- after fix ---")
    main()
