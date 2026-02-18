#!/bin/bash

TOTAL_REQUESTS=10000
CONCURRENCY_LIST=(50 100 150 200 250 300 350 400 450 500 750 1000)

ENDPOINTS=(
  "${HELLO_URL:-http://43.205.107.26:8443/hello}"
  "${HELLOBELLO_URL:-http://43.205.107.26:8443/hellobello}"
  "${RESPONSE_URL:-http://65.2.32.238:6060/response}"
)

NAMES=("hello" "hellobello" "response")

for idx in "${!ENDPOINTS[@]}"; do
  echo "Benchmarking ${NAMES[$idx]} endpoint: ${ENDPOINTS[$idx]}"
  echo "-------------------------------------------------------------"
  printf "%-12s %-15s %-15s %-12s %-12s %-12s %-14s\n" "Concurrency" "Total Requests" "Throughput(RPS)" "Avg Latency" "P95 Latency" "P99 Latency" "Success Rate%"
  for c in "${CONCURRENCY_LIST[@]}"; do
    result=$(hey -n $TOTAL_REQUESTS -c $c -m GET "${ENDPOINTS[$idx]}" 2>&1)
    avg_latency=$(echo "$result" | grep "Average:" | awk '{print $2}')
    p95_latency=$(echo "$result" | grep '95%% in' | awk '{print $3}')
    p99_latency=$(echo "$result" | grep '99%% in' | awk '{print $3}')
    reqs_sec=$(echo "$result" | grep "Requests/sec:" | awk '{print $2}')
    total=$(echo "$result" | grep "Requests:" | awk '{print $2}')
    success=$(echo "$result" | grep "Status code distribution:" -A 1 | tail -n 1 | awk '{print $2}')
    if [[ -z "$success" ]]; then
      success_rate="0.00"
    else
      success_rate=$(awk "BEGIN {printf \"%.2f\", ($success/$TOTAL_REQUESTS)*100}")
    fi
    printf "%-12s %-15s %-15s %-12s %-12s %-12s %-14s\n" "$c" "$TOTAL_REQUESTS" "$reqs_sec" "$avg_latency" "$p95_latency" "$p99_latency" "$success_rate"
  done
  echo "-------------------------------------------------------------"
  echo

done
