#!/bin/bash
# Compiles the app's real models + view models against an in-memory FirebaseService and runs the scenario tests.
# Needs only the Swift toolchain (Command Line Tools) on a Mac - no Xcode, no Firebase.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
SRC=ProperDisciplineApp
swiftc -swift-version 5 -o "$OUT/harness" \
  $SRC/Models/*.swift \
  $SRC/ViewModels/CalendarViewModel.swift $SRC/ViewModels/TaskViewModel.swift \
  $SRC/ViewModels/AuthViewModel.swift $SRC/ViewModels/NestViewModel.swift \
  Tests/LogicHarness/StubFirebaseService.swift Tests/LogicHarness/main.swift 2>&1 | grep -v "warning:" || true
for tz in America/New_York Asia/Kolkata Pacific/Auckland UTC; do
  echo "=== TZ=$tz"
  TZ=$tz "$OUT/harness"
done
