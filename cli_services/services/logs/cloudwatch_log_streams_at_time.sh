#!/bin/bash

#!/bin/bash
#
# Script Name: find_log_streams_by_time.sh
#
# Description:
#   This script finds AWS CloudWatch log streams that contain log events
#   spanning a given timestamp. It helps you quickly identify which streams
#   to inspect when searching for logs around a specific time.
#
# Features:
#   - Accepts log group name, timestamp, and optional timezone.
#   - Defaults to Asia/Tokyo (JST) if no timezone is specified.
#   - Displays results in a colored table with:
#       • Log Stream Name
#       • First Event Time
#       • Last Event Time
#       • Creation Time
#   - All times are displayed in the chosen timezone with its abbreviation.
#
# Requirements:
#   - AWS CLI installed and configured with proper IAM permissions
#   - jq installed for JSON parsing
#   - utility/colors.sh script available for terminal color formatting
#
# Usage:
#   ./find_log_streams_by_time.sh
#
#   The script will prompt for:
#     - Log Group Name
#     - Date/Time (e.g., 2025-09-29 11:40:33)
#     - Timezone (default = Asia/Tokyo)
#
# Example:
#   $ ./find_log_streams_by_time.sh
#   Enter Log Group Name: MyApp-LogGroup
#   Enter date/time (e.g., 2025-09-29 11:40:33): 2025-09-29 11:40:33
#   Enter timezone (default: Asia/Tokyo): 
#
#   => Displays all streams in MyApp-LogGroup that had events spanning that time,
#      showing first/last/created timestamps in JST.
#
# Notes:
#   - Timestamps are compared using firstEventTimestamp and lastEventTimestamp.
#   - If no streams are returned, no log stream covered that timestamp.
#   - Creation time may be later than first event time in some cases due to
#     CloudWatch internals (but both are shown for clarity).
#

# Import colors
source utility/colors.sh

# Temporary file to remember the last used log group name
TMP_PATH="/usr/src/app/cli_services/tmp/"
LAST_LOG_GROUP_FILE="${TMP_PATH}last_log_group.txt"

# Prompt user for log group, datetime, and timezone
if [ -f "$LAST_LOG_GROUP_FILE" ]; then
  LAST_LOG_GROUP_NAME=$(cat "$LAST_LOG_GROUP_FILE")
  echo -en "Enter Log Group Name (${BOLD_YELLOW}default${RESET}: ${CYAN}${LAST_LOG_GROUP_NAME}${RESET}): "
  read LOG_GROUP_NAME
  if [ -z "$LOG_GROUP_NAME" ]; then
    LOG_GROUP_NAME="$LAST_LOG_GROUP_NAME"
  fi
else
  read -p "Enter Log Group Name: " LOG_GROUP_NAME
fi

# Save for next run
mkdir -p "$TMP_PATH"
echo "$LOG_GROUP_NAME" >"$LAST_LOG_GROUP_FILE"

read -p "Enter date/time (e.g., 2025-09-29 11:40:33): " INPUT_TIME
read -p "Enter timezone (default: Asia/Tokyo): " TIMEZONE

# Default to JST if nothing entered
if [ -z "$TIMEZONE" ]; then
  TIMEZONE="Asia/Tokyo"
fi

# Convert input to epoch (ms)
TARGET_EPOCH=$(TZ="$TIMEZONE" date -d "$INPUT_TIME" +%s)000

# Get TZ abbreviation for header
TZ_ABBR=$(TZ="$TIMEZONE" date +%Z)

echo -e "Finding log streams in group '${BOLD_CYAN}$LOG_GROUP_NAME${RESET}' that span: ${YELLOW}$INPUT_TIME${RESET} (${CYAN}$TIMEZONE / $TZ_ABBR${RESET})"
echo

# Header
printf "${BOLD_CYAN}%-70s | %-22s | %-22s | %-22s${RESET}\n" "LogStreamName" "First Event ($TZ_ABBR)" "Last Event ($TZ_ABBR)" "Created ($TZ_ABBR)"
printf -- "${BOLD_WHITE}-----------------------------------------------------------------------+------------------------+------------------------+------------------------${RESET}\n"

# Get matching log streams
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP_NAME" \
  --query "logStreams[?firstEventTimestamp <= \`${TARGET_EPOCH}\` && lastEventTimestamp >= \`${TARGET_EPOCH}\`].[logStreamName,firstEventTimestamp,lastEventTimestamp,creationTime]" \
  --output json |
jq -r '.[] | @tsv' | while IFS=$'\t' read -r stream first last created; do
  first_human=$(TZ="$TIMEZONE" date -d "@$((first/1000))" +"%Y-%m-%d %H:%M:%S")
  last_human=$(TZ="$TIMEZONE" date -d "@$((last/1000))" +"%Y-%m-%d %H:%M:%S")
  created_human=$(TZ="$TIMEZONE" date -d "@$((created/1000))" +"%Y-%m-%d %H:%M:%S")

  printf "${BLUE}%-70s${RESET} | ${GREEN}%-22s${RESET} | ${YELLOW}%-22s${RESET} | ${MAGENTA}%-22s${RESET}\n" "$stream" "$first_human" "$last_human" "$created_human"
done
