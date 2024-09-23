#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: MIT

import sys
import json
import os
import requests
import base64
import hashlib
import argparse

DEFAULT_OWNER = "freifunk-rhein-neckar"
DEFAULT_REPO = "site-ffrn"

def parse_arguments():
    parser = argparse.ArgumentParser(description='Load and print attestation from a GitHub API.')
    parser.add_argument('-o', '--owner', help='Owner of the repository', required=False, default=DEFAULT_OWNER)
    parser.add_argument('-r', '--repo', help='Repository name', required=False, default=DEFAULT_REPO)
    parser.add_argument('file_path', help='Path to the attestation file')
    return parser.parse_args()

def get_file_sha256(file_path):
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        while True:
            data = f.read(65536)
            if not data:
                break
            sha256.update(data)
    return sha256.hexdigest()

def load_attestation_from_gh_api(owner, repo, file_sha256):
    url = f"https://api.github.com/repos/{owner}/{repo}/attestations/sha256:{file_sha256}"
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        print(f"Failed to load attestation from {url}")
        sys.exit(1)

    print("Got attestation from GitHub API")

    return response.json()

def print_attestation(data):
    dsse_envelope = data.get("attestations", [{}])[0].get("bundle", {}).get("dsseEnvelope", {})
    if "payload" not in dsse_envelope:
        print("No payload in attestation")
        sys.exit(1)

    decoded_dsse_payload = base64.b64decode(dsse_envelope["payload"])

    dsse_object = json.loads(decoded_dsse_payload)
    ci_filename = dsse_object["subject"][0]["name"]
    ci_hashes = dsse_object["subject"][0]["digest"]
    print(f"Artifact: {ci_filename}")
    for hash in ci_hashes.keys():
        print(f"  {hash}: {ci_hashes[hash]}")

    predicate = dsse_object["predicate"]
    build_definition = predicate["buildDefinition"]
    run_details = predicate["runDetails"]

    build_commit = build_definition["resolvedDependencies"][0]["digest"]["gitCommit"]
    print(f"  Commit: {build_commit}")
    print(f"  Run: {run_details["metadata"]["invocationId"]}")


if __name__ == "__main__":
    # Command: load-attestation.py [-o <owner> -r <repo>] <file-path>
    args = parse_arguments()

    print(f"Fetching attestation for {args.file_path} from {args.owner}/{args.repo}")
    file_hash = get_file_sha256(args.file_path)
    attestation = load_attestation_from_gh_api(args.owner, args.repo, file_hash)
    print_attestation(attestation)
