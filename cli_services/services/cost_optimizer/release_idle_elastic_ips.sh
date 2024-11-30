#!/bin/bash

echo "Elastic IP Management Script"

# Prompt user for scope of operation: All regions or specific regions
read -p "Do you want to check all regions or specific regions? (all/specific): " region_choice

if [[ "$region_choice" == "all" ]]; then
  # Get the list of all AWS regions
  regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)
elif [[ "$region_choice" == "specific" ]]; then
  read -p "Enter the region(s) you want to check (comma-separated if multiple): " specific_regions
  IFS=',' read -r -a regions <<<"$specific_regions"
else
  echo "Invalid choice. Exiting."
  exit 1
fi

for region in ${regions[@]}; do
  echo "Checking region: $region"

  # Get the list of unallocated Elastic IPs in the current region
  unallocated_ips=$(aws ec2 describe-addresses --region "$region" --query "Addresses[?AssociationId == null].[PublicIp, AllocationId]" --output json)

  # Check if there are any unallocated IPs
  if [[ "$unallocated_ips" != "[]" ]]; then
    echo "Unallocated Elastic IPs in region: $region"
    aws ec2 describe-addresses --region "$region" --query "Addresses[?AssociationId == null].[PublicIp, AllocationId]" --output table

    # Ask if the user wants to release all or specific IPs in this region
    read -p "Do you want to release all unallocated IPs in $region or specific ones? (all/specific): " release_choice

    if [[ "$release_choice" == "all" ]]; then
      # Release all unallocated IPs
      echo $unallocated_ips | jq -c '.[]' | while read -r ip_allocation; do
        public_ip=$(echo $ip_allocation | jq -r '.[0]')
        allocation_id=$(echo $ip_allocation | jq -r '.[1]')
        echo "Releasing Elastic IP with Public IP: $public_ip and Allocation ID: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$region"
        echo "Elastic IP with Public IP: $public_ip released successfully."
        echo "------------------------------------------"
      done
    elif [[ "$release_choice" == "specific" ]]; then
      read -p "Enter the Public IP(s) you want to release (comma-separated if multiple): " specific_ips
      IFS=',' read -r -a ip_array <<<"$specific_ips"

      for public_ip in ${ip_array[@]}; do
        # Find allocation ID for the specified IP
        allocation_id=$(echo "$unallocated_ips" | jq -c '.[]' | jq -r "select(.[0] == \"$public_ip\") | .[1]")

        if [[ -n "$allocation_id" ]]; then
          echo "Releasing Elastic IP with Public IP: $public_ip and Allocation ID: $allocation_id"
          aws ec2 release-address --allocation-id "$allocation_id" --region "$region"
          echo "Elastic IP with Public IP: $public_ip released successfully."
          echo "------------------------------------------"
        else
          echo "Public IP: $public_ip is not unallocated in region: $region."
        fi
      done
    else
      echo "Invalid choice for release option. Skipping region $region."
    fi
  else
    echo "No unallocated Elastic IPs in region: $region."
  fi

  echo ""
done

echo "Completed Elastic IP management."
