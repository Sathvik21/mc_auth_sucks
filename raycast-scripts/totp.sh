#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title TOTP Code
# @raycast.mode silent
# @raycast.packageName Auth
#
# Copies a fresh TOTP (6-digit authenticator) code to the clipboard.
# Reads an otpauth:// URL out of the macOS login Keychain, extracts the
# secret, and runs it through oathtool. Nothing is stored in this file.
#
# Setup: see README.md in this repo.

set -euo pipefail

# Change this to whatever account name you used when you ran
# `security add-generic-password -a <name> -s totp -w '<otpauth-url>'`
KEYCHAIN_ACCOUNT="totp-seed"
KEYCHAIN_SERVICE="totp"

# Path to oathtool. Homebrew installs to /opt/homebrew/bin on Apple
# Silicon and /usr/local/bin on Intel — check `which oathtool` if this
# doesn't match your machine.
OATHTOOL="/opt/homebrew/bin/oathtool"
if [ ! -x "$OATHTOOL" ]; then
  OATHTOOL="$(command -v oathtool || true)"
fi
if [ -z "$OATHTOOL" ]; then
  echo "oathtool not found. Install with: brew install oath-toolkit" >&2
  exit 1
fi

url="$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)"
if [ -z "$url" ]; then
  echo "No keychain entry found for account '$KEYCHAIN_ACCOUNT' / service '$KEYCHAIN_SERVICE'." >&2
  exit 1
fi

secret="$(sed -n 's/.*[?&]secret=\([^&]*\).*/\1/p' <<<"$url")"
if [ -z "$secret" ]; then
  echo "Could not parse a 'secret=' parameter out of the stored value. Is it a valid otpauth:// URL?" >&2
  exit 1
fi

# If your provider's QR used non-default digits/period, uncomment and adjust:
# EXTRA_ARGS="--digits=8 --time-step-size=60s"
EXTRA_ARGS=""

code="$("$OATHTOOL" --totp -b ${EXTRA_ARGS} "$secret" | tr -d '\n')"

if [ -z "$code" ]; then
  echo "oathtool produced no output." >&2
  exit 1
fi

printf '%s' "$code" | pbcopy
echo "Copied: $code"
