#!/usr/bin/env bash

# Shell Startup Performance Benchmark Tool
# Measures zsh startup time and provides detailed analysis

set -euo pipefail

RUNS=${1:-10}
BENCHMARK_DIR="${HOME}/.shell-benchmark"
RESULTS_FILE="${BENCHMARK_DIR}/results-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${BENCHMARK_DIR}"

echo "🚀 Shell Startup Benchmark Tool"
echo "================================"
echo "Runs: ${RUNS}"
echo "Results: ${RESULTS_FILE}"
echo

# Warm up
echo "🔥 Warming up..."
for i in {1..3}; do
    /usr/bin/time -p zsh -i -c exit 2>/dev/null || true
done

echo "📊 Running benchmark..."

# Benchmark current setup
total_time=0
times=()

for i in $(seq 1 $RUNS); do
    printf "Run %2d/%d: " $i $RUNS

    # Measure startup time
    if time_output=$(/usr/bin/time -p zsh -i -c exit 2>&1); then
        shell_status=0
    else
        shell_status=$?
    fi

    real_time=$(printf '%s\n' "$time_output" | awk '/^real/ { print $2; exit }')
    if [[ -z "$real_time" ]]; then
        echo "failed to parse startup time"
        printf '%s\n' "$time_output" >&2
        exit 1
    fi

    times+=($real_time)
    total_time=$(echo "$total_time + $real_time" | bc -l)

    if [[ $shell_status -eq 0 ]]; then
        printf "%.3fs\n" $real_time
    else
        printf "%.3fs (zsh exited %d)\n" $real_time "$shell_status"
    fi
done

# Calculate statistics
avg_time=$(echo "scale=3; $total_time / $RUNS" | bc -l)
min_time=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
max_time=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)

# Calculate median
sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
mid=$((RUNS / 2))
if (( RUNS % 2 == 0 )); then
    median_time=$(echo "scale=3; (${sorted_times[$((mid-1))]} + ${sorted_times[$mid]}) / 2" | bc -l)
else
    median_time=${sorted_times[$mid]}
fi

# Results
echo
echo "📈 Results Summary"
echo "=================="
printf "Average: %.3fs\n" $avg_time
printf "Median:  %.3fs\n" $median_time
printf "Min:     %.3fs\n" $min_time
printf "Max:     %.3fs\n" $max_time
echo

# Save detailed results
{
    echo "# Shell Startup Benchmark - $(date)"
    echo "## Configuration"
    echo "Runs: $RUNS"
    echo "Shell: $(zsh --version)"
    echo "OS: $(uname -a)"
    echo
    echo "## Raw Times"
    for i in "${!times[@]}"; do
        printf "Run %2d: %.3fs\n" $((i+1)) ${times[$i]}
    done
    echo
    echo "## Statistics"
    printf "Average: %.3fs\n" $avg_time
    printf "Median:  %.3fs\n" $median_time
    printf "Min:     %.3fs\n" $min_time
    printf "Max:     %.3fs\n" $max_time
} > "$RESULTS_FILE"

# Performance classification
if (( $(echo "$avg_time < 0.1" | bc -l) )); then
    status="🟢 Excellent (< 0.1s)"
elif (( $(echo "$avg_time < 0.3" | bc -l) )); then
    status="🟡 Good (< 0.3s)"
elif (( $(echo "$avg_time < 0.5" | bc -l) )); then
    status="🟠 Acceptable (< 0.5s)"
else
    status="🔴 Slow (> 0.5s)"
fi

echo "⭐ Performance: $status"
echo "📝 Detailed results saved to: $RESULTS_FILE"
