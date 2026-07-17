#!/bin/bash

# Import colors
source utility/colors.sh

# Temporary files to remember the last used log group / stream name
TMP_PATH="/usr/src/app/cli_services/tmp/"
LAST_LOG_GROUP_FILE="${TMP_PATH}last_log_group.txt"
LAST_LOG_STREAM_FILE="${TMP_PATH}last_log_stream.txt"

# Prompt user for log group, stream, and optional filter pattern
if [ -f "$LAST_LOG_GROUP_FILE" ]; then
  LAST_LOG_GROUP_NAME=$(cat "$LAST_LOG_GROUP_FILE")
  echo -en "Enter Log Group Name (${BOLD_YELLOW}default${RESET}: ${CYAN}${LAST_LOG_GROUP_NAME}${RESET}): "
  read LOG_GROUP_NAME
  [ -z "$LOG_GROUP_NAME" ] && LOG_GROUP_NAME="$LAST_LOG_GROUP_NAME"
else
  read -p "Enter Log Group Name: " LOG_GROUP_NAME
fi

if [ -f "$LAST_LOG_STREAM_FILE" ]; then
  LAST_LOG_STREAM_NAME=$(cat "$LAST_LOG_STREAM_FILE")
  echo -en "Enter Log Stream Name (${BOLD_YELLOW}default${RESET}: ${CYAN}${LAST_LOG_STREAM_NAME}${RESET}): "
  read LOG_STREAM_NAME
  [ -z "$LOG_STREAM_NAME" ] && LOG_STREAM_NAME="$LAST_LOG_STREAM_NAME"
else
  read -p "Enter Log Stream Name: " LOG_STREAM_NAME
fi

read -p "Enter Filter Pattern (optional, e.g. { \$.message = \"Redirected to*\" }): " FILTER_PATTERN

# Save for next run
mkdir -p "$TMP_PATH"
echo "$LOG_GROUP_NAME" >"$LAST_LOG_GROUP_FILE"
echo "$LOG_STREAM_NAME" >"$LAST_LOG_STREAM_FILE"

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
