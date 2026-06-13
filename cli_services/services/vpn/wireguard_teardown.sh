#!/bin/bash
# Tear down ONE named WireGuard VPN deployment (provisioned by wireguard_provision.sh).
# Terminates the instance, releases the Elastic IP, deletes the security group,
# the SSM parameter, and the IAM role/instance profile — scoped to one name.
#
# Usage:
#   ./wireguard_teardown.sh [name] [region]
#   - no name   -> defaults to "vpn" (the original single-VPN deployment)
#   - name only -> prompts for region (default Mumbai / ap-south-1)
# Examples:
#   ./wireguard_teardown.sh              # tear down the default "vpn" deployment
#   ./wireguard_teardown.sh home         # tear down only the "home" VPN
#   ./wireguard_teardown.sh work us-east-1

set -euo pipefail

DEFAULT_DEPLOY="vpn"
DEFAULT_REGION="ap-south-1"

DEPLOY="${1:-}"
if [[ -z "$DEPLOY" ]]; then
  read -r -p "Deployment name to tear down [${DEFAULT_DEPLOY}]: " DEPLOY
  DEPLOY="${DEPLOY:-$DEFAULT_DEPLOY}"
fi
if [[ ! "$DEPLOY" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Invalid deployment name '$DEPLOY'. Use letters, digits and hyphens only."
  exit 1
fi

# All identifiers derived from $DEPLOY (must match wireguard_provision.sh)
NAME_TAG="wireguard-${DEPLOY}"
SG_NAME="wireguard-${DEPLOY}-sg"
ROLE_NAME="wireguard-${DEPLOY}-role"
PROFILE_NAME="wireguard-${DEPLOY}-profile"
SSM_PARAM="/wireguard/${DEPLOY}-client"

REGION="${2:-}"
if [[ -z "$REGION" ]]; then
  read -r -p "Region to tear down the VPN from [${DEFAULT_REGION}]: " REGION
  REGION="${REGION:-$DEFAULT_REGION}"
fi
echo "Tearing down WireGuard VPN '${DEPLOY}' in: $REGION"

# --- Terminate the instance(s) tagged wireguard-vpn ---------------------------
INSTANCE_IDS="$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

if [[ -n "$INSTANCE_IDS" ]]; then
  echo "Terminating instance(s): $INSTANCE_IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS >/dev/null
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INSTANCE_IDS
  echo "Instance(s) terminated."
else
  echo "No running instance found."
fi

# --- Release the Elastic IP ---------------------------------------------------
ALLOC_IDS="$(aws ec2 describe-addresses --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME_TAG}" \
  --query 'Addresses[].AllocationId' --output text)"
for a in $ALLOC_IDS; do
  echo "Releasing Elastic IP allocation $a"
  aws ec2 release-address --region "$REGION" --allocation-id "$a"
done

# --- Delete the security group ------------------------------------------------
SG_ID="$(aws ec2 describe-security-groups --region "$REGION" \
  --filters Name=group-name,Values="$SG_NAME" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)"
if [[ "$SG_ID" != "None" && -n "$SG_ID" ]]; then
  echo "Deleting security group $SG_ID"
  aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID"
fi

# --- Delete the SSM parameter -------------------------------------------------
aws ssm delete-parameter --region "$REGION" --name "$SSM_PARAM" >/dev/null 2>&1 \
  && echo "Deleted SSM parameter $SSM_PARAM" || true

# --- Delete IAM instance profile + role (global, not region-scoped) -----------
if aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null 2>&1; then
  aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME" 2>/dev/null || true
  aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME"
  echo "Deleted instance profile $PROFILE_NAME"
fi
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name wg-ssm-put 2>/dev/null || true
  aws iam detach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true
  aws iam delete-role --role-name "$ROLE_NAME"
  echo "Deleted IAM role $ROLE_NAME"
fi

echo "Teardown complete."
