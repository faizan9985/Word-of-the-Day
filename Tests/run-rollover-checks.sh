#!/bin/sh
# Run the real date helpers and view model against deterministic service/storage doubles.
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /private/tmp/word-rollover-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library \
    -module-cache-path "$check_dir/module-cache" \
    Shared/WordEntry.swift \
    WordOfTheDayApp/Services/WordAPIService.swift \
    WordOfTheDayApp/ViewModels/WordViewModel.swift \
    Tests/RolloverChecks.swift \
    -o "$check_dir/checks"
"$check_dir/checks"
