#!/bin/bash

# Prompt user for log group, stream, and optional filter pattern
read -p "Enter Log Group Name: " LOG_GROUP_NAME
read -p "Enter Log Stream Name: " LOG_STREAM_NAME
read -p "Enter Filter Pattern (optional, e.g. { \$.message = \"Redirected to*\" }): " FILTER_PATTERN

# Output filename
OUTPUT_FILE="logs_${LOG_STREAM_NAME//\//_}.txt"

echo "Downloading logs from:"
echo "  Log Group : $LOG_GROUP_NAME"
echo "  Log Stream: $LOG_STREAM_NAME"
[ -n "$FILTER_PATTERN" ] && echo "  Filter    : $FILTER_PATTERN"
echo "  Output    : $OUTPUT_FILE"
echo

# Initialize
>"$OUTPUT_FILE"
NEXT_TOKEN=""

if [ -n "$FILTER_PATTERN" ]; then
  # filter-log-events supports --filter-pattern; paginate until nextToken disappears
  while :; do
    if [ -z "$NEXT_TOKEN" ]; then
      RESPONSE=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-names "$LOG_STREAM_NAME" \
        --filter-pattern "$FILTER_PATTERN" \
        --limit 10000 \
        --output json)
    else
      RESPONSE=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-names "$LOG_STREAM_NAME" \
        --filter-pattern "$FILTER_PATTERN" \
        --limit 10000 \
        --next-token "$NEXT_TOKEN" \
        --output json)
    fi

    echo "$RESPONSE" | jq -r '.events[].message' >>"$OUTPUT_FILE"

    NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // empty')
    [ -z "$NEXT_TOKEN" ] && break
  done
else
  PREV_TOKEN="init"

  # Loop until nextForwardToken stops changing
  while [ "$NEXT_TOKEN" != "$PREV_TOKEN" ]; do
    if [ -z "$NEXT_TOKEN" ]; then
      RESPONSE=$(aws logs get-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-name "$LOG_STREAM_NAME" \
        --limit 10000 \
        --start-from-head \
        --output json)
    else
      RESPONSE=$(aws logs get-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-name "$LOG_STREAM_NAME" \
        --limit 10000 \
        --start-from-head \
        --next-token "$NEXT_TOKEN" \
        --output json)
    fi

    # Append messages to file
    echo "$RESPONSE" | jq -r '.events[].message' >>"$OUTPUT_FILE"

    PREV_TOKEN="$NEXT_TOKEN"
    NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextForwardToken')
  done
fi

echo "✅ Completed. Logs saved to: $OUTPUT_FILE"
