#!/bin/sh
# Times loading and searching 1,000, 5,000 and 10,000 generated Notes with
# MacJot's own code (ticket 40), against 50 ms per keystroke and 1 s to load.
# Run by hand; not part of test.sh. Other counts: scripts/benchmark-search.sh 20000
# The Notes go to a temporary folder, never the Notes Folder, and are removed afterwards.
set -e
cd "$(dirname "$0")/.."
swift build -c release --product JotBenchmark
JOT_BENCHMARK_DIR="$(mktemp -d -t jot-benchmark)"
export JOT_BENCHMARK_DIR
trap 'rm -rf "$JOT_BENCHMARK_DIR"' EXIT
trap 'exit 130' INT TERM
echo "$(sysctl -n hw.model), $(sysctl -n machdep.cpu.brand_string), $(sysctl -n hw.memsize | awk '{ print $1 / 1073741824 " GB" }'), macOS $(sw_vers -productVersion)"
"$(swift build -c release --show-bin-path)/JotBenchmark" "$@"
