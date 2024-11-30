#!/bin/bash

# Script to retrieve unallocated Elastic IPs for all AWS regions
echo "Retrieving unallocated Elastic IPs for all regions"

# Get the list of all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# Iterate through each region
for region in $regions; do
  echo "Fetching for Region: $region"

  # Get the list of unallocated Elastic IPs in the current region
  unallocated_ips=$(aws ec2 describe-addresses --region "$region" --query "Addresses[?AssociationId == null].[PublicIp, AllocationId]" --output json)

  # Check if there are any unallocated IPs
  if [[ "$unallocated_ips" != "[]" ]]; then
    echo "Unallocated Elastic IPs in Region: $region"
    # Display unallocated IPs in table format for readability
    aws ec2 describe-addresses --region "$region" --query "Addresses[?AssociationId == null].[PublicIp, AllocationId]" --output table
    echo
  fi
done

echo "Completed retrieval of unallocated Elastic IPs."
