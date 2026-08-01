#!/bin/bash
#
# Lints the package against .swiftlint.yml.
#
#   scripts/lint.sh          # report violations
#   scripts/lint.sh --fix    # rewrite what SwiftLint can correct, then report
#
# SwiftLint is a developer tool, not a package dependency: keeping it out of
# Package.swift is what lets NotiWindow stay dependency-free for consumers.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: swiftlint not found on PATH." >&2
    echo "       Install it with:  brew install swiftlint" >&2
    echo "       (or 'mint install realm/SwiftLint' if you prefer Mint)" >&2
    exit 127
fi

if [[ "${1:-}" == "--fix" ]]; then
    swiftlint --fix --quiet
fi

exec swiftlint lint --strict --quiet
