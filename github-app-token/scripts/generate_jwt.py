#!/usr/bin/env python3
"""Generate a JWT for GitHub App authentication.

Reads from environment variables:
  GITHUB_APP_ID       - The GitHub App's numeric ID
  GITHUB_APP_PEM_FILE - Path to the PEM-encoded private key file

Prints the signed JWT to stdout.
"""

import json
import os
import sys
import time
import base64

try:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    USE_CRYPTOGRAPHY = True
except ImportError:
    import subprocess

    USE_CRYPTOGRAPHY = False


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def sign_with_cryptography(unsigned: str, pem_contents: str) -> str:
    """Sign using the cryptography library. Handles both PKCS#1 and PKCS#8 PEM formats."""
    private_key = serialization.load_pem_private_key(pem_contents.encode(), password=None)
    signature = private_key.sign(unsigned.encode(), padding.PKCS1v15(), hashes.SHA256())
    return b64url(signature)


def sign_with_openssl(unsigned: str, pem_file: str) -> str:
    """Sign using the openssl CLI. Reads the key from the file path directly."""
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", pem_file, "-binary"],
        input=unsigned.encode(),
        capture_output=True,
    )
    if result.returncode != 0:
        print(f"error: openssl signing failed: {result.stderr.decode()}", file=sys.stderr)
        sys.exit(1)
    return b64url(result.stdout)


def main():
    app_id = os.environ.get("GITHUB_APP_ID")
    pem_file = os.environ.get("GITHUB_APP_PEM_FILE")

    if not app_id:
        print("error: GITHUB_APP_ID is not set", file=sys.stderr)
        sys.exit(1)
    if not pem_file:
        print("error: GITHUB_APP_PEM_FILE is not set", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(pem_file):
        print(f"error: PEM file not found: {pem_file}", file=sys.stderr)
        sys.exit(1)

    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    payload = b64url(
        json.dumps({"iat": now - 60, "exp": now + 600, "iss": app_id}).encode()
    )
    unsigned = f"{header}.{payload}"

    if USE_CRYPTOGRAPHY:
        with open(pem_file, "r") as f:
            pem_contents = f.read()
        signature = sign_with_cryptography(unsigned, pem_contents)
    else:
        signature = sign_with_openssl(unsigned, pem_file)

    print(f"{unsigned}.{signature}")


if __name__ == "__main__":
    main()
