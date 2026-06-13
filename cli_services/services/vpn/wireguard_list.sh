#!/bin/bash
# List WireGuard VPN deployments created by wireguard_provision.sh, with a rough
# running-cost estimate, and (optionally) real billed cost via Cost Explorer
# — including past/destroyed deployments.
#
# All deployments are discovered by the shared tag convention: Name=wireguard-*
#
# Usage:
#   ./wireguard_list.sh [region|all] [--cost]
#   - no region   -> prompts (default Mumbai / ap-south-1); type "all" to scan every region
#   - --cost      -> also query Cost Explorer for actual $ per deployment (see caveats)
# Examples:
#   ./wireguard_list.sh                 # inventory + estimate, Mumbai
#   ./wireguard_list.sh all             # inventory + estimate, every region
#   ./wireguard_list.sh ap-south-1 --cost
#   ./wireguard_list.sh all --cost

set -euo pipefail

DEFAULT_REGION="ap-south-1"
TAG_GLOB="wireguard-*"

# Rough on-demand rates (USD) for the cost ESTIMATE only — adjust if needed.
# t4g.nano compute is ~$0.0042-0.0047/hr depending on region; EBS 8GB gp3 ~$0.64/mo;
# an UNASSOCIATED Elastic IP is ~$0.005/hr. Data-transfer (egress) is NOT included.
RATE_INSTANCE_HR="0.0046"
RATE_IDLE_EIP_HR="0.005"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
WANT_COST="no"
ARGS=()
for a in "$@"; do
  if [[ "$a" == "--cost" ]]; then WANT_COST="yes"; else ARGS+=("$a"); fi
done

REGION_ARG="${ARGS[0]:-}"
if [[ -z "$REGION_ARG" ]]; then
  read -r -p "Region to list (or 'all') [${DEFAULT_REGION}]: " REGION_ARG
  REGION_ARG="${REGION_ARG:-$DEFAULT_REGION}"
fi

if [[ "$REGION_ARG" == "all" ]]; then
  REGIONS="$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)"
else
  REGIONS="$REGION_ARG"
fi

NOW_EPOCH="$(date -u +%s)"

# ---------------------------------------------------------------------------
# Inventory + running-cost estimate
# ---------------------------------------------------------------------------
echo ""
echo "WireGuard deployments (tag Name=${TAG_GLOB})"
echo "============================================================================================"
printf "%-12s %-13s %-19s %-11s %-15s %-16s\n" "DEPLOY" "INSTANCE" "TYPE" "STATE" "PUBLIC IP" "EST. COST (USD)"
echo "--------------------------------------------------------------------------------------------"

FOUND_ANY="no"
for R in $REGIONS; do
  # [name, instanceId, type, state, launchTime, publicIp]
  INSTANCES="$(aws ec2 describe-instances --region "$R" \
    --filters "Name=tag:Name,Values=${TAG_GLOB}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,InstanceType,State.Name,LaunchTime,PublicIpAddress]' \
    --output text 2>/dev/null || true)"

  [[ -z "$INSTANCES" ]] && continue
  FOUND_ANY="yes"
  echo ">> region: $R"

  while IFS=$'\t' read -r NAME IID ITYPE STATE LAUNCH PUBIP; do
    [[ -z "${NAME:-}" ]] && continue
    DEPLOY="${NAME#wireguard-}"
    EST="-"
    if [[ "$STATE" == "running" && -n "$LAUNCH" && "$LAUNCH" != "None" ]]; then
      LAUNCH_EPOCH="$(date -u -d "$LAUNCH" +%s 2>/dev/null || echo "")"
      if [[ -n "$LAUNCH_EPOCH" ]]; then
        HOURS=$(( (NOW_EPOCH - LAUNCH_EPOCH) / 3600 ))
        EST="$(awk -v h="$HOURS" -v r="$RATE_INSTANCE_HR" 'BEGIN{printf "~%.2f (%dh)", h*r, h}')"
      fi
    fi
    printf "%-12s %-13s %-19s %-11s %-15s %-16s\n" \
      "$DEPLOY" "$IID" "$ITYPE" "$STATE" "${PUBIP:-none}" "$EST"
  done <<< "$INSTANCES"

  # Idle (unassociated) Elastic IPs — these bill even with no instance
  IDLE_EIPS="$(aws ec2 describe-addresses --region "$R" \
    --filters "Name=tag:Name,Values=${TAG_GLOB}" \
    --query 'Addresses[?AssociationId==`null`].[Tags[?Key==`Name`]|[0].Value,PublicIp]' \
    --output text 2>/dev/null || true)"
  if [[ -n "$IDLE_EIPS" ]]; then
    while IFS=$'\t' read -r ENAME EIP; do
      [[ -z "${ENAME:-}" ]] && continue
      EST="$(awk -v r="$RATE_IDLE_EIP_HR" 'BEGIN{printf "~%.2f/day idle", r*24}')"
      printf "%-12s %-13s %-19s %-11s %-15s %-16s\n" \
        "${ENAME#wireguard-}" "(eip)" "elastic-ip" "UNATTACHED" "$EIP" "$EST"
    done <<< "$IDLE_EIPS"
  fi
done

[[ "$FOUND_ANY" == "no" ]] && echo "(no deployments found)"
echo "============================================================================================"
echo "EST. COST = rough compute estimate only (rate \$${RATE_INSTANCE_HR}/hr). Excludes data transfer."
echo "Use --cost for actual billed dollars via Cost Explorer."

# ---------------------------------------------------------------------------
# Actual billed cost via Cost Explorer (opt-in)
# ---------------------------------------------------------------------------
if [[ "$WANT_COST" == "yes" ]]; then
  echo ""
  echo "Actual billed cost per deployment (Cost Explorer)"
  echo "============================================================"
  echo "Note: requires the 'Name' cost-allocation tag to be ACTIVATED in Billing,"
  echo "data lags ~24h, and each query costs \$0.01. Includes past/destroyed names."

  # From the 1st of last month through today (CE End is exclusive -> +1 day).
  START="$(date -u -d "$(date -u +%Y-%m-01) -1 month" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-01)"
  END="$(date -u -d "+1 day" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"
  echo "Period: ${START} -> ${END} (monthly)"
  echo "------------------------------------------------------------"

  # CE is a global service reached via us-east-1. Group by the Name tag.
  CE_JSON="$(aws ce get-cost-and-usage --region us-east-1 \
    --time-period "Start=${START},End=${END}" \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --group-by Type=TAG,Key=Name \
    --output json 2>/dev/null || true)"

  if [[ -z "$CE_JSON" ]]; then
    echo "Cost Explorer query failed — CE may not be enabled, or you lack ce:GetCostAndUsage."
  else
    ROWS="$(echo "$CE_JSON" | jq -r '
      .ResultsByTime[] as $t
      | $t.Groups[]
      | select(.Keys[0] | test("Name\\$wireguard-"))
      | [ ($t.TimePeriod.Start),
          (.Keys[0] | sub("^Name\\$";"") | sub("^wireguard-";"")),
          (.Metrics.UnblendedCost.Amount) ]
      | @tsv' 2>/dev/null || true)"
    if [[ -z "$ROWS" ]]; then
      echo "No wireguard-* costs found. Likely the 'Name' tag isn't activated as a"
      echo "cost-allocation tag yet (Billing console -> Cost allocation tags -> activate 'Name')."
      echo "Activation only attributes cost from that point forward."
    else
      printf "%-12s %-12s %-12s\n" "MONTH" "DEPLOY" "COST (USD)"
      echo "$ROWS" | while IFS=$'\t' read -r MONTH DEP AMT; do
        printf "%-12s %-12s %-12s\n" "$MONTH" "$DEP" "$(awk -v a="$AMT" 'BEGIN{printf "%.2f", a}')"
      done
    fi
  fi
  echo "============================================================"
fi
