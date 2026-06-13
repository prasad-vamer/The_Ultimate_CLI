#!/bin/bash
# Provision a self-hosted WireGuard VPN on a single, minimum-spec EC2 instance.
#
# What it builds (a full-tunnel "exit node" — also reaches private VPC resources):
#   - t4g.nano instance (cheapest ARM burstable) running Amazon Linux 2023
#   - Elastic IP so the VPN endpoint address is stable
#   - Security group opening only UDP 51820 (WireGuard); management is via SSM, no SSH
#   - IAM instance profile (SSM core + permission to publish the client config)
#   - WireGuard installed/configured via user-data; the ready-to-use client config
#     is pushed to SSM Parameter Store and pulled back down to ./wireguard-client.conf
#
# Tear down THIS deployment later with: ./wireguard_teardown.sh <name>
#
# Multiple independent VPNs are supported via a deployment name. Every resource
# is named after it, so each name is a fully separate VPN you can destroy alone.
#
# Usage:
#   ./wireguard_provision.sh [name] [region]
#   - no name   -> defaults to "vpn" (the original single-VPN deployment)
#   - name only -> prompts for region (default Mumbai / ap-south-1)
# Examples:
#   ./wireguard_provision.sh              # the default "vpn" deployment
#   ./wireguard_provision.sh home         # a separate "home" VPN
#   ./wireguard_provision.sh work us-east-1

set -euo pipefail

# ---------------------------------------------------------------------------
# Deployment name -> every resource is derived from it, so distinct names are
# fully independent VPNs. Default "vpn" reproduces the original resource names.
# ---------------------------------------------------------------------------
DEFAULT_DEPLOY="vpn"
DEPLOY="${1:-}"
if [[ -z "$DEPLOY" ]]; then
  read -r -p "Deployment name [${DEFAULT_DEPLOY}]: " DEPLOY
  DEPLOY="${DEPLOY:-$DEFAULT_DEPLOY}"
fi
# Restrict to a safe charset valid across tags, IAM names, SG names and SSM paths
if [[ ! "$DEPLOY" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Invalid deployment name '$DEPLOY'. Use letters, digits and hyphens only."
  exit 1
fi

# ---------------------------------------------------------------------------
# Configuration (all resource identifiers derived from $DEPLOY)
# ---------------------------------------------------------------------------
DEFAULT_REGION="ap-south-1" # Mumbai
INSTANCE_TYPE="t4g.nano"    # minimum spec: 2 vCPU burst, 0.5 GiB, ARM (~US$3/mo)
WG_PORT="51820"
NAME_TAG="wireguard-${DEPLOY}"
SG_NAME="wireguard-${DEPLOY}-sg"
ROLE_NAME="wireguard-${DEPLOY}-role"
PROFILE_NAME="wireguard-${DEPLOY}-profile"
SSM_PARAM="/wireguard/${DEPLOY}-client"
OUT_FILE="wireguard-${DEPLOY}-client.conf"

# ---------------------------------------------------------------------------
# Pick the region (2nd arg, or prompt)
# ---------------------------------------------------------------------------
REGION="${2:-}"
if [[ -z "$REGION" ]]; then
  read -r -p "Region to deploy the VPN [${DEFAULT_REGION}]: " REGION
  REGION="${REGION:-$DEFAULT_REGION}"
fi
echo "Deploying WireGuard VPN '${DEPLOY}' to: $REGION"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SSM_PARAM_ARN="arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter${SSM_PARAM}"

# Guard: refuse to create a duplicate instance for a name that already exists in
# this region (re-running would orphan a billable instance + Elastic IP).
EXISTING="$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
if [[ -n "$EXISTING" ]]; then
  echo "A VPN named '${DEPLOY}' already exists in ${REGION} (instance: ${EXISTING})."
  echo "Tear it down first (./wireguard_teardown.sh ${DEPLOY}) or use a different name."
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate the default VPC + a subnet to launch into
# ---------------------------------------------------------------------------
VPC_ID="$(aws ec2 describe-vpcs --region "$REGION" \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "No default VPC in $REGION. Create one (aws ec2 create-default-vpc) or edit this script to pass an explicit subnet."
  exit 1
fi

SUBNET_ID="$(aws ec2 describe-subnets --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)"
echo "Using VPC $VPC_ID, subnet $SUBNET_ID"

# ---------------------------------------------------------------------------
# IAM: instance profile so the box can be managed via SSM and publish the
# generated client config to Parameter Store
# ---------------------------------------------------------------------------
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Creating IAM role $ROLE_NAME ..."
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }' >/dev/null

  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

  aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name wg-ssm-put \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Action\": \"ssm:PutParameter\",
          \"Resource\": \"${SSM_PARAM_ARN}\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [\"kms:Encrypt\", \"kms:GenerateDataKey\"],
          \"Resource\": \"*\"
        }
      ]
    }"

  aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME"
  echo "Waiting for IAM instance profile to propagate ..."
  sleep 15
else
  echo "IAM role $ROLE_NAME already exists, reusing."
fi

# ---------------------------------------------------------------------------
# Security group: only UDP 51820 inbound (WireGuard). No SSH — use SSM.
# ---------------------------------------------------------------------------
SG_ID="$(aws ec2 describe-security-groups --region "$REGION" \
  --filters Name=group-name,Values="$SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)"

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  echo "Creating security group $SG_NAME ..."
  SG_ID="$(aws ec2 create-security-group --region "$REGION" \
    --group-name "$SG_NAME" --description "WireGuard VPN inbound" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${NAME_TAG}}]" \
    --query 'GroupId' --output text)"
  aws ec2 authorize-security-group-ingress --region "$REGION" \
    --group-id "$SG_ID" --protocol udp --port "$WG_PORT" --cidr 0.0.0.0/0 >/dev/null
fi
echo "Security group: $SG_ID"

# ---------------------------------------------------------------------------
# Allocate the Elastic IP first so we can bake the endpoint into the client config
# ---------------------------------------------------------------------------
ALLOC_ID="$(aws ec2 allocate-address --region "$REGION" --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${NAME_TAG}}]" \
  --query 'AllocationId' --output text)"
EIP="$(aws ec2 describe-addresses --region "$REGION" --allocation-ids "$ALLOC_ID" \
  --query 'Addresses[0].PublicIp' --output text)"
echo "Elastic IP: $EIP ($ALLOC_ID)"

# ---------------------------------------------------------------------------
# Resolve the latest Amazon Linux 2023 arm64 AMI (ships aws-cli + ssm-agent)
# ---------------------------------------------------------------------------
AMI_ID="$(aws ssm get-parameters --region "$REGION" \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query 'Parameters[0].Value' --output text)"
echo "AMI: $AMI_ID"

# ---------------------------------------------------------------------------
# Render user-data (placeholders -> real values) and launch
# ---------------------------------------------------------------------------
USER_DATA="$(mktemp)"
trap 'rm -f "$USER_DATA"' EXIT

cat > "$USER_DATA" <<'CLOUDINIT'
#!/bin/bash
set -euxo pipefail
exec > /var/log/wg-userdata.log 2>&1

REGION="__REGION__"
EIP="__EIP__"
PARAM="__PARAM__"
PORT="__PORT__"
SERVER_WG_IP="10.8.0.1"
CLIENT_WG_IP="10.8.0.2"

# iptables-nft is required by wg-quick's PostUp NAT rules — NOT installed on AL2023 by default
dnf -y install wireguard-tools qrencode iptables-nft

echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

WAN_IF="$(ip route | awk '/default/ {print $5; exit}')"

umask 077
SERVER_PRIV="$(wg genkey)"
SERVER_PUB="$(echo "$SERVER_PRIV" | wg pubkey)"
CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(echo "$CLIENT_PRIV" | wg pubkey)"

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${SERVER_WG_IP}/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_WG_IP}/32
EOF

cat > /etc/wireguard/client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_WG_IP}/24
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${EIP}:${PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Publish the client config FIRST, so even if the service fails to start the
# config is still retrievable (and we don't get blinded by `set -e` aborting).
aws ssm put-parameter --region "$REGION" --name "$PARAM" --type SecureString \
  --overwrite --value file:///etc/wireguard/client.conf

systemctl enable --now wg-quick@wg0
CLOUDINIT

sed -i.bak \
  -e "s|__REGION__|${REGION}|g" \
  -e "s|__EIP__|${EIP}|g" \
  -e "s|__PARAM__|${SSM_PARAM}|g" \
  -e "s|__PORT__|${WG_PORT}|g" \
  "$USER_DATA"

echo "Launching $INSTANCE_TYPE ..."
INSTANCE_ID="$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile "Name=${PROFILE_NAME}" \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --user-data "file://${USER_DATA}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME_TAG}}]" \
  --query 'Instances[0].InstanceId' --output text)"
echo "Instance: $INSTANCE_ID — waiting for it to enter 'running' ..."

aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
aws ec2 associate-address --region "$REGION" --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" >/dev/null
echo "Elastic IP associated."

# ---------------------------------------------------------------------------
# Wait for user-data to finish and publish the client config to SSM
# ---------------------------------------------------------------------------
echo "Waiting for WireGuard to bootstrap (this can take ~2 minutes) ..."
TMP_CONF="$(mktemp)"
for i in $(seq 1 40); do
  # Write to a temp first so a failed poll never truncates a good OUT_FILE
  if aws ssm get-parameter --region "$REGION" --name "$SSM_PARAM" --with-decryption \
       --query 'Parameter.Value' --output text > "$TMP_CONF" 2>/dev/null && [[ -s "$TMP_CONF" ]]; then
    mv "$TMP_CONF" "$OUT_FILE"
    echo ""
    echo "================================================================"
    echo " WireGuard VPN '${DEPLOY}' is up. Client config -> $OUT_FILE"
    echo " Endpoint: ${EIP}:${WG_PORT}"
    echo "================================================================"
    echo " Import it into the WireGuard app, or on Linux/macOS:"
    echo "   sudo wg-quick up ./$OUT_FILE"
    echo " For a phone QR code:"
    echo "   qrencode -t ansiutf8 < $OUT_FILE"
    echo " Tear this VPN down later with:"
    echo "   ./wireguard_teardown.sh ${DEPLOY}"
    echo "================================================================"
    exit 0
  fi
  sleep 6
done
rm -f "$TMP_CONF"

echo "Timed out waiting for the client config in SSM ($SSM_PARAM)."
echo "The instance may still be finishing. Check /var/log/wg-userdata.log via:"
echo "  aws ssm start-session --region $REGION --target $INSTANCE_ID"
exit 1
