#!/usr/bin/env bash
# Sign the official DigiByte Electrum release artifacts.
#
# This script intentionally does not sign every file in dist/. The artifact
# list below is the release contract, which prevents old, debug, or backup
# files from being published accidentally.

set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"
SIGNATURE_DIR="${SIGNATURE_DIR:-$DIST_DIR/sigs}"
PUBLIC_KEY_FILE="${PUBLIC_KEY_FILE:-$PROJECT_ROOT/pubkeys/digibyte_electrum_release.asc}"
RELEASE_SIGNING_KEY="${RELEASE_SIGNING_KEY:-AFDCF9A5EB44818016F2CC5F87A504ECA52604EB}"
SIGNER_NAME="${SIGNER_NAME:-digibyte_electrum_release}"

usage() {
    cat <<'EOF'
Usage: contrib/sign_release.sh ARTIFACT_VERSION

Sign the official DigiByte Electrum artifacts in dist/.
The argument is the client version used in filenames, not the GitHub release
label. For release tag 4.8.2-pre2, use artifact version 4.8.2.

Environment overrides:
  DIST_DIR              Artifact directory (default: PROJECT_ROOT/dist)
  SIGNATURE_DIR         Signature output directory (default: DIST_DIR/sigs)
  PUBLIC_KEY_FILE       Public key used for verification
  RELEASE_SIGNING_KEY   Full GPG fingerprint used for signing
  SIGNER_NAME           Suffix used in detached signature filenames

Example:
  contrib/sign_release.sh 4.8.2
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

VERSION="${1:-}"
[[ -n "$VERSION" ]] || { usage >&2; exit 2; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]] \
    || fail "invalid version: $VERSION"

command -v gpg >/dev/null 2>&1 || fail "gpg is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

[[ -d "$DIST_DIR" ]] || fail "artifact directory does not exist: $DIST_DIR"
[[ -f "$PUBLIC_KEY_FILE" ]] || fail "public key does not exist: $PUBLIC_KEY_FILE"
[[ "$SIGNER_NAME" =~ ^[A-Za-z0-9_.-]+$ ]] || fail "invalid signer name: $SIGNER_NAME"

ARTIFACTS=(
    "electrum-digibyte-${VERSION}-x86_64.AppImage"
    "electrum-digibyte-${VERSION}.exe"
    "electrum-digibyte-${VERSION}-portable.exe"
    "electrum-digibyte-${VERSION}-setup.exe"
    "wallet-${VERSION}-arm64-v8a-release.apk"
    "wallet-${VERSION}-armeabi-v7a-release.apk"
    "wallet-${VERSION}-x86_64-release.apk"
)

for artifact in "${ARTIFACTS[@]}"; do
    case "$artifact" in
        *debug*|*release-unsigned*|*.previous*)
            fail "unsafe artifact name in release manifest: $artifact"
            ;;
    esac
    [[ -f "$DIST_DIR/$artifact" ]] || fail "missing release artifact: $DIST_DIR/$artifact"
done

mkdir -p "$SIGNATURE_DIR"

# Confirm that the requested signing identity is available locally. The full
# fingerprint avoids selecting an unrelated key with a similar user ID.
KEY_FINGERPRINT="$(gpg --batch --with-colons --list-keys "$RELEASE_SIGNING_KEY" \
    | awk -F: '$1 == "fpr" { print toupper($10); exit }')"
[[ "$KEY_FINGERPRINT" == "${RELEASE_SIGNING_KEY^^}" ]] \
    || fail "requested signing key is not available by the expected fingerprint"

echo "Signing ${#ARTIFACTS[@]} DigiByte Electrum artifacts"
echo "Signer fingerprint: ${RELEASE_SIGNING_KEY^^}"

for artifact in "${ARTIFACTS[@]}"; do
    signature="$SIGNATURE_DIR/${artifact}.${SIGNER_NAME}.asc"
    echo "Signing $artifact"
    gpg --batch --yes --armor --detach-sign \
        --local-user "$RELEASE_SIGNING_KEY" \
        --output "$signature" \
        "$DIST_DIR/$artifact"
done

# Verify with a fresh keyring so success does not depend on unrelated local
# keys. This imports only the repository's published public key.
VERIFY_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dgb-electrum-gpg.XXXXXX")"
cleanup() {
    rm -rf "$VERIFY_HOME"
}
trap cleanup EXIT
chmod 700 "$VERIFY_HOME"
gpg --batch --homedir "$VERIFY_HOME" --import "$PUBLIC_KEY_FILE" >/dev/null

for artifact in "${ARTIFACTS[@]}"; do
    signature="$SIGNATURE_DIR/${artifact}.${SIGNER_NAME}.asc"
    echo "Verifying $artifact"
    gpg --batch --homedir "$VERIFY_HOME" --verify "$signature" "$DIST_DIR/$artifact" \
        >/dev/null
done

CHECKSUM_FILE="$DIST_DIR/SHA256SUMS-${VERSION}.txt"
(
    cd "$DIST_DIR"
    sha256sum "${ARTIFACTS[@]}"
) > "$CHECKSUM_FILE"

echo ""
echo "All signatures verified successfully."
echo "Signatures: $SIGNATURE_DIR"
echo "Checksums:  $CHECKSUM_FILE"
