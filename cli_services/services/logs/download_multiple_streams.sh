#!/bin/bash

# Import colors
source utility/colors.sh

# Temporary file to remember the last used log group name (shared with the
# other logs/ scripts)
TMP_PATH="/usr/src/app/cli_services/tmp/"
LAST_LOG_GROUP_FILE="${TMP_PATH}last_log_group.txt"

# Prompt for the single Log Group Name
if [ -f "$LAST_LOG_GROUP_FILE" ]; then
  LAST_LOG_GROUP_NAME=$(cat "$LAST_LOG_GROUP_FILE")
  echo -en "Enter Log Group Name (${BOLD_YELLOW}default${RESET}: ${CYAN}${LAST_LOG_GROUP_NAME}${RESET}): "
  read LOG_GROUP_NAME
  [ -z "$LOG_GROUP_NAME" ] && LOG_GROUP_NAME="$LAST_LOG_GROUP_NAME"
else
  read -p "Enter Log Group Name: " LOG_GROUP_NAME
fi

# Prompt for the single Filter Pattern (applied to every stream below)
read -p "Enter Filter Pattern (optional, e.g. { \$.message = \"Redirected to*\" }): " FILTER_PATTERN

# Prompt for multiple Log Stream Names, one per line, blank line to finish
echo -e "Enter Log Stream Names, one per line. Leave blank and press Enter to finish:"
LOG_STREAMS=()
while true; do
  read -p "  Stream: " STREAM_NAME
  [ -z "$STREAM_NAME" ] && break
  LOG_STREAMS+=("$STREAM_NAME")
done

if [ ${#LOG_STREAMS[@]} -eq 0 ]; then
  echo "No log streams entered. Exiting."
  exit 1
fi

# Save log group for next run
mkdir -p "$TMP_PATH"
echo "$LOG_GROUP_NAME" >"$LAST_LOG_GROUP_FILE"

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

echo
echo -e "${BOLD_CYAN}Downloading ${#LOG_STREAMS[@]} stream(s) from group '${LOG_GROUP_NAME}'${RESET}"
echo

# Iteratively call download_single_stream.sh once per stream, feeding its
# interactive prompts (Log Group, Log Stream, Filter Pattern) via stdin.
for STREAM in "${LOG_STREAMS[@]}"; do
  echo -e "${BOLD_YELLOW}==> ${STREAM}${RESET}"
  printf '%s\n%s\n%s\n' "$LOG_GROUP_NAME" "$STREAM" "$FILTER_PATTERN" | bash "${SCRIPT_DIR}/download_single_stream.sh"
  echo
done

echo -e "${BOLD_GREEN}✅ All streams processed.${RESET}"
