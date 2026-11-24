#!/usr/bin/env python3
"""Build-time Android source packaging preparation; adapted from the working Desktop bundler. No runtime or database changes."""
from __future__ import annotations

import collections
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
from urllib.parse import urlparse

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = ROOT / "config" / "modules.lock.json"
OUT = ROOT / "build" / "web"
TEXT_EXT = {".html", ".htm", ".js", ".mjs", ".css", ".json", ".webmanifest", ".svg"}
BINARY_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".ico", ".bmp", ".woff", ".woff2", ".ttf", ".otf", ".pdf"}
SKIP_DIRS = {".git", ".github", "node_modules", "sql", "docs", "windows-workstation",
             "android-local-app", "android-online-app", "native-mobile-v2", "android-bundled-source-prep", "tests", "__pycache__", ".venv"}
SKIP_FILES = {".env", ".env.local", ".env.production", "package-lock.json", "yarn.lock"}
HTTP_RE = re.compile(r"https?://[a-zA-Z0-9.-]+", re.I)


def git(*args: str) -> None:
    subprocess.run(["git", *args], check=True, stdout=subprocess.DEVNULL)


# Desktop-only reconciliation for the two Sales Support customer screens.
# The normal Dashboard loader skips navigation if frame.dataset.module
# already matches the button clicked. Add Customer and Customer Map used to
# replace frame.src without updating that marker, so returning to Your
# Customer looked like a no-op. Keep the source Cloud/PWA repositories intact.
SALES_SUPPORT_ROUTE_MARKERS = {
    "supabase-sales-support-add-customer.js": (
        "workspace.hidden=false;frame.src=target.href;markActive();",
        "workspace.hidden=false;frame.dataset.module=ROUTE;frame.src=target.href;markActive();",
    ),
    "supabase-sales-support-customer-map.js": (
        "workspace.hidden=false;frame.src=URL;markActive();",
        "workspace.hidden=false;frame.dataset.module=ROUTE;frame.src=URL;markActive();",
    ),
}


def patch_desktop_sales_support_navigation(repo: str, relative: str, data: str) -> str:
    if repo != "big-brother-dashboard" or relative not in SALES_SUPPORT_ROUTE_MARKERS:
        return data
    before, after = SALES_SUPPORT_ROUTE_MARKERS[relative]
    if data.count(before) == 1:
        # Historical pinned dashboard versions still need the Desktop patch.
        return data.replace(before, after, 1)
    # Newer Cloud/PWA Dashboard revisions include this exact fix natively,
    # with the route marker and deferred-switch token updated on separate
    # lines. Accept the already-correct code instead of failing bundling.
    target = "target.href" if "add-customer" in relative else "URL"
    if (data.count("frame.dataset.module=ROUTE;") == 1
        and data.count("frame.dataset.bbSwitchToken=") >= 1
        and data.count(f"frame.src={target};") == 1):
        return data
    raise RuntimeError(
        f"Desktop Sales Support route patch missing or changed: {repo}/{relative}"
    )


# Notification Center's Telegram Manager tool URLs are constructed at
# runtime from a host-only TOOL_ORIGIN constant (without a trailing slash).
# The generic static GitHub Pages URL rewrite intentionally cannot match it.
# In the installed Desktop, all admin tools live at app.bigbrother.test,
# while access to GitHub Pages is blocked. Keep the exact tool allow-list,
# origin gate, scripts and Cloud/PWA repository untouched.
def patch_desktop_telegram_tool_origin(repo: str, relative: str, data: str) -> str:
    if repo != "big-brother-notification-center" or relative != "app.js":
        return data
    original = "const TOOL_ORIGIN = 'https://angsokhey11-cloud.github.io';"
    local = "const TOOL_ORIGIN = 'https://app.bigbrother.test';"
    if data.count(original) != 1:
        raise RuntimeError(
            "Telegram Manager approved-tool origin marker changed; "
            "refusing to package potentially broken Desktop tool routing"
        )
    return data.replace(original, local, 1)


def bundle() -> None:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    owner = lock["owner"]
    names = {m["name"] for m in lock["modules"]}
    old = lock["sourceHost"]
    new = lock["desktopHost"]
    assert old.startswith("https://") and new == "https://app.bigbrother.test/"
    assert len(names) == len(lock["modules"])
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    hosts = collections.Counter()
    files = 0
    bytes_count = 0
    base = re.escape(new)
    root_pattern = re.compile(r"(" + base + r"(" + "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True)) + r")/)(?=[\x22\x27\s?#<])")
    with tempfile.TemporaryDirectory(prefix="bb-android-source-modules-") as root_tmp:
        tmp = pathlib.Path(root_tmp)
        for item in lock["modules"]:
            name, sha = item["name"], item["sha"]
            if not re.fullmatch(r"[a-zA-Z0-9_.-]+", name):
                raise ValueError("Unsafe repository name")
            if not re.fullmatch(r"[0-9a-f]{40}", sha):
                raise ValueError(f"Unpinned repository: {name}")
            source = tmp / name
            source.mkdir()
            git("-C", str(source), "init", "-q")
            git("-C", str(source), "remote", "add", "origin", f"https://github.com/{owner}/{name}.git")
            git("-C", str(source), "fetch", "--quiet", "--depth=1", "origin", sha)
            git("-C", str(source), "checkout", "--quiet", "--detach", "FETCH_HEAD")
            for entry in source.rglob("*"):
                if not entry.is_file() or entry.is_symlink():
                    continue
                rel = entry.relative_to(source)
                if any(segment in SKIP_DIRS or segment.startswith(".") for segment in rel.parts[:-1]):
                    continue
                if entry.name in SKIP_FILES or entry.name.startswith("."):
                    continue
                if any(word in entry.name.lower() for word in ("service-role", "private-key", "secret-key", "credentials")):
                    continue
                suffix = entry.suffix.lower()
                if suffix not in TEXT_EXT | BINARY_EXT:
                    continue
                if entry.stat().st_size > 20 * 1024 * 1024:
                    raise ValueError(f"Unexpectedly large web asset: {name}/{rel}")
                target = OUT / name / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                if suffix in TEXT_EXT:
                    try:
                        data = entry.read_text(encoding="utf-8")
                    except UnicodeDecodeError as exc:
                        raise ValueError(f"Non-UTF8 web source: {name}/{rel}") from exc
                    # Rewrite only first-party GitHub Pages URLs. Preserve backend/API origins.
                    data = re.sub(re.escape(old), new, data, flags=re.I)
                    data = re.sub(re.escape(old.removeprefix("https:")), new, data, flags=re.I)
                    # WebView2 static host mapping need not serve a directory index.
                    data = root_pattern.sub(lambda m: m.group(1) + "index.html", data)
                    data = patch_desktop_sales_support_navigation(
                        name, rel.as_posix(), data
                    )
                    data = patch_desktop_telegram_tool_origin(
                        name, rel.as_posix(), data
                    )
                    for url in HTTP_RE.findall(data):
                        host = urlparse(url).netloc.lower()
                        if host not in ("app.bigbrother.test", "angsokhey11-cloud.github.io"):
                            hosts[host] += 1
                    target.write_text(data, encoding="utf-8", newline="\n")
                else:
                    shutil.copy2(entry, target)
                files += 1
                bytes_count += target.stat().st_size
            # Repositories stay under the temporary build directory until
            # context-manager cleanup, which handles read-only Git objects on Windows.
            print(f"Bundled {name} @ {sha[:12]}", flush=True)

    for required in ("big-brother-dashboard/mobile.html",
                     "big-brother-dashboard/mobile.js",
                     "big-brother-dashboard/index.html",
                     "big-brother-dashboard/legacy-dashboard-v3.40.html",
                     "big-brother-invoice-generator/index.html",
                     "big-brother-ar/index.html",
                     "big-brother-sales-support/index.html"):
        if not (OUT / required).is_file():
            raise RuntimeError(f"Required frontend file missing: {required}")
    digest = hashlib.sha256()
    for entry in sorted(p for p in OUT.rglob("*") if p.is_file()):
        digest.update(str(entry.relative_to(OUT)).encode("utf-8"))
        digest.update(hashlib.sha256(entry.read_bytes()).digest())
    report = {
        "moduleCount": len(lock["modules"]), "fileCount": files,
        "assetBytes": bytes_count, "assetHash": digest.hexdigest(),
        "remainingExternalHosts": dict(sorted(hosts.items())),
        "sourceRevisions": {m["name"]: m["sha"] for m in lock["modules"]},
    }
    (ROOT / "build" / "bundle-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Bundled {files} assets from {len(lock['modules'])} pinned repositories ({bytes_count:,} bytes).", flush=True)
    print("External-dependency audit: build/bundle-report.json", flush=True)


if __name__ == "__main__":
    bundle()
