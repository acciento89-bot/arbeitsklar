#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qa_tmp="$(mktemp -d)"
trap 'rm -rf "$qa_tmp"' EXIT
cp "$repo_root/ci/roster-smoke.swift" "$qa_tmp/main.swift"
export DEVELOPER_DIR=/Applications/Xcode-27.1-RC.app/Contents/Developer
xcrun swiftc "$repo_root/ArbeitsKlar/Models/ShiftTemplate.swift" "$repo_root/ArbeitsKlar/Models/ScheduledShift.swift" "$repo_root/ArbeitsKlar/Models/ShiftCycle.swift" "$repo_root/ArbeitsKlar/Services/ShiftCyclePlanner.swift" "$repo_root/ArbeitsKlar/Models/ShiftRoster.swift" "$repo_root/ArbeitsKlar/Services/ShiftRosterStorage.swift" "$qa_tmp/main.swift" -o "$qa_tmp/roster-smoke"
"$qa_tmp/roster-smoke"
