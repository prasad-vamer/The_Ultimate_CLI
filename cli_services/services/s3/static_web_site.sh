#!/bin/bash

# Exit on any error
set -e

# Ensure bucket name is passed
if [ -z "$1" ]; then
  echo "Usage: $0 <s3-bucket-name> [--lock | ip1 ip2 ...]"
  echo "  No extra args     → public (anyone can read)"
  echo "  --lock            → IP-restricted to default IP only"
  echo "  ip1 ip2 ...       → IP-restricted to default IP plus listed IPs"
  exit 1
fi

BUCKET_NAME=$1
REGION="ap-northeast-1"
DEFAULT_SOURCE_IP="153.142.38.216"

# Parse optional IP restriction args (shift off bucket name)
shift
RESTRICT=false
ALLOWED_IPS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --lock|-l)
      RESTRICT=true
      ;;
    *)
      RESTRICT=true
      ALLOWED_IPS+=("$1")
      ;;
  esac
  shift
done

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $REGION

echo "Enabling static website hosting"
aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document error.html

echo "Cleaning bucket contents if any"
aws s3 rm s3://$BUCKET_NAME --recursive || true

echo "Syncing /table_definition to the bucket"
aws s3 sync /table_definition s3://$BUCKET_NAME

echo "Enabling public access"
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration '{
    "BlockPublicAcls": false,
    "IgnorePublicAcls": false,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
  }'

echo "Confirming public access block settings"
aws s3api get-public-access-block --bucket $BUCKET_NAME

if [ "$RESTRICT" = true ]; then
  # Build unique IP list: default + any user-supplied IPs
  UNIQUE_IPS=("$DEFAULT_SOURCE_IP")
  for ip in "${ALLOWED_IPS[@]}"; do
    duplicate=false
    for existing in "${UNIQUE_IPS[@]}"; do
      if [ "$ip" = "$existing" ]; then
        duplicate=true
        break
      fi
    done
    if [ "$duplicate" = false ]; then
      UNIQUE_IPS+=("$ip")
    fi
  done

  # Build JSON array for aws:SourceIp
  IP_JSON=""
  for ip in "${UNIQUE_IPS[@]}"; do
    if [ -n "$IP_JSON" ]; then
      IP_JSON="$IP_JSON,"
    fi
    IP_JSON="$IP_JSON\"$ip\""
  done

  echo "Setting bucket policy (IP-restricted: ${UNIQUE_IPS[*]})"
  POLICY="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"RestrictedReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\",
      \"Condition\": {
        \"IpAddress\": {
          \"aws:SourceIp\": [$IP_JSON]
        }
      }
    }
  ]
}"
else
  echo "Setting bucket policy (public — no IP restriction)"
  POLICY="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"PublicReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
    }
  ]
}"
fi

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$POLICY"

echo ""
echo "✅ Static website is available at:"
echo "http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
if [ "$RESTRICT" = true ]; then
  echo "   Access restricted to: ${UNIQUE_IPS[*]}"
else
  echo "   Access: public (no IP restriction)"
fi
