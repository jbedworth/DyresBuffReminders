"""List CurseForge's Forever game versions. Python 3, standard library only.

Read-only: one GET to the same versions endpoint the uploader verifies against.
Run it locally to find CURSEFORGE_GAME_VERSION_ID; with --classic, it lists
the Classic Era (1.15.x) versions and their type IDs instead. The token comes from the
CF_API_TOKEN environment variable or a hidden prompt; it is sent only in the
X-Api-Token header and is never printed or written anywhere.
"""

import argparse
import getpass
import os
import sys
import urllib.request
from pathlib import Path

# The Windows embeddable Python's ._pth file omits the script folder from the
# import path, so add it explicitly for the sibling uploader module.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import publish_curseforge as publisher  # noqa: E402


def forever_versions(versions):
    """Return Forever (type 88568) entries as sorted (id, name) pairs."""
    if not isinstance(versions, list):
        raise publisher.PublishError("CurseForge versions response must be an array")
    found = []
    for entry in versions:
        if (isinstance(entry, dict) and type(entry.get("id")) is int
                and type(entry.get("gameVersionTypeID")) is int
                and entry["gameVersionTypeID"] == publisher.FOREVER_TYPE_ID
                and isinstance(entry.get("name"), str)):
            found.append((entry["id"], entry["name"]))
    return sorted(found)


def classic_versions(versions):
    """Return Classic Era (1.15.x) entries as sorted (type, id, name) triples."""
    if not isinstance(versions, list):
        raise publisher.PublishError("CurseForge versions response must be an array")
    found = []
    for entry in versions:
        if (isinstance(entry, dict) and type(entry.get("id")) is int
                and type(entry.get("gameVersionTypeID")) is int
                and isinstance(entry.get("name"), str) and entry["name"].startswith("1.15.")):
            found.append((entry["gameVersionTypeID"], entry["id"], entry["name"]))
    return sorted(found)


def read_token():
    token = os.environ.get("CF_API_TOKEN") or getpass.getpass("CurseForge API token (hidden): ")
    token = token.strip()
    if not token:
        raise publisher.PublishError("A CurseForge API token is required")
    if any(ord(char) < 33 or ord(char) > 126 for char in token):
        raise publisher.PublishError("CF_API_TOKEN has an invalid header format")
    return token


def fetch_versions(token, opener=None):
    opener = opener or publisher.make_opener()
    headers = {"X-Api-Token": token, "Accept": "application/json"}
    return publisher.request_json(opener, urllib.request.Request(publisher.VERSIONS_URL, headers=headers))


def list_versions(token, opener=None):
    return forever_versions(fetch_versions(token, opener))


def list_classic_versions(token, opener=None):
    return classic_versions(fetch_versions(token, opener))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--classic", action="store_true", help="list Classic Era (1.15.x) versions")
    args = parser.parse_args(argv)
    if args.classic:
        try:
            classic = list_classic_versions(read_token())
        except publisher.PublishError as error:
            print("CurseForge version lookup failed: " + str(error), file=sys.stderr)
            return 1
        if not classic:
            print("No Classic Era (1.15.x) game versions were returned.")
            return 1
        print("Classic Era game versions (1.15.x):")
        for type_id, version_id, name in classic:
            marker = "  <- Era 1.15.9" if name == "1.15.9" else ""
            print(f"  type={type_id}  id={version_id}  name={name}{marker}")
        return 0
    try:
        versions = list_versions(read_token())
    except publisher.PublishError as error:
        print("CurseForge version lookup failed: " + str(error), file=sys.stderr)
        return 1
    if not versions:
        print(f"No Forever (type {publisher.FOREVER_TYPE_ID}) game versions were returned.")
        return 1
    print(f"Forever game versions (type {publisher.FOREVER_TYPE_ID}):")
    for version_id, name in versions:
        marker = "  <- CURSEFORGE_GAME_VERSION_ID" if name == "1.60.1" else ""
        print(f"  id={version_id}  name={name}{marker}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
