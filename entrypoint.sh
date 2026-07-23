#!/bin/bash

# Ensure tmp directory exists
mkdir -p /usr/src/app/cli_services/tmp

# Base of the caller's mounted directory (see the "${PWD}/.the_ultimate_cli"
# volume in compose.yml). Any subfolder scripts need can be built from
# $MOUNT_DIR without redefining this path.
export MOUNT_DIR="/${AWS_PROFILE}_mount"

# User-facing results (log downloads, generated configs, etc.) go here
# instead of accumulating inside the repo.
export OUTPUT_DIR="${MOUNT_DIR}/outputs"
mkdir -p "$OUTPUT_DIR"

# Create credentials directory if not present
mkdir -p /root/.aws

# Create sample config file if not present
if [ ! -f "/root/.aws/config" ]; then
  echo "Creating sample AWS config file..."
  cat > /root/.aws/config << 'EOF'
[default]
region = <Region>
output = json

[profile my-profile]
region = <Region>
output = yml
EOF
fi

# Create sample credentials file if not present
if [ ! -f "/root/.aws/credentials" ]; then
  echo "Creating sample AWS credentials file..."
  cat > /root/.aws/credentials << 'EOF'
[default]
# This is the default profile
aws_access_key_id = <AWS ACCESS KEY>
aws_secret_access_key = <AWS SECRET KEY>

[my-profile]
aws_access_key_id = <AWS ACCESS KEY>
aws_secret_access_key = <AWS SECRET KEY>
EOF
  echo "⚠️  Please update with your actual AWS credentials."
fi

# Install node modules for interactiveUI if not present
if [ ! -d "/usr/src/app/cli_services/interactiveUI/node_modules" ]; then
  echo "Installing node modules for interactiveUI..."
  cd /usr/src/app/cli_services/interactiveUI
  npm install --silent
  cd /usr/src/app/cli_services
fi

# Run the command passed to the container (not exec'd, so cleanup below
# still runs afterwards)
"$@"
EXIT_CODE=$?

# Remove any subfolder under the mounted directory (e.g. outputs/) that
# ended up empty this run, so the host folder doesn't accumulate clutter
# across sessions. Never touches $MOUNT_DIR itself (the bind mount point)
# or non-empty folders.
find "$MOUNT_DIR" -mindepth 1 -depth -type d -empty -delete 2>/dev/null

exit $EXIT_CODE
