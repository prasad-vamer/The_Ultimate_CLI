#!/bin/bash

# Temporary file paths
tmp_path="/usr/src/app/cli_services/tmp/"
array_of_object="arrayOfObject.json"
obejct_selected="object.json"
SELECTED_OPTION_OBJECT_PATH=${tmp_path}${obejct_selected}

# Step 1: Prompt user to use default region or choose a region
DEFAULT_REGION=$(aws configure get region)
echo -e "\nThe current configured default region is: $DEFAULT_REGION"
read -p "Do you want to use the default region? (y/yes||n/no): " use_default_region

# Use case statement for robust input handling
case "${use_default_region,,}" in
y | yes)
  REGION=$DEFAULT_REGION
  echo "Using the default region: $REGION"
  ;;
n | no)
  echo "Retrieving list of AWS regions..."

  # Get the list of all AWS regions
  ALL_REGIONS=$(aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output json)

  echo $ALL_REGIONS

  # Save the regions to a temporary file for selection
  echo "$ALL_REGIONS" >"${tmp_path}${array_of_object}"

  # Use Node.js script to allow user to select a region interactively
  node interactiveUI/keyValueArrayOfObjectJsonSelect.js -k Name -v Name -f "${array_of_object}" -o "${obejct_selected}"

  # Clean up the temporary file
  rm "${tmp_path}${array_of_object}"

  # Read the selected region from the JSON file
  if [ -f "$SELECTED_OPTION_OBJECT_PATH" ]; then
    REGION=$(cat "$SELECTED_OPTION_OBJECT_PATH" | jq -r '.Name')
    rm "$SELECTED_OPTION_OBJECT_PATH"
  else
    echo "Failed to select a region. Exiting."
    exit 1

  fi
  ;;
*)
  echo "Invalid input. Please enter 'y/yes' or 'n/no'. Exiting."
  exit 1
  ;;
esac

echo -e "\nAccessing Running EC2 instances in region: $REGION"

# Step 2: Get the list of running EC2 instances in the selected region
RUNNING_INSTANCES_JSON=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value}" \
  --output json | jq 'sort_by(.Name)')

if [ $? -eq 0 ]; then
  # Check if JSON data contains instances
  if [ "$(echo "$RUNNING_INSTANCES_JSON" | jq 'length')" -gt 0 ]; then
    echo "$RUNNING_INSTANCES_JSON" | jq .
    echo "$RUNNING_INSTANCES_JSON" >"${tmp_path}${array_of_object}"
  else
    echo "No running EC2 instances found in region: $REGION."
    exit 1
  fi
else
  echo "Failed to retrieve EC2 instance data from region: $REGION."
  exit 1
fi

# Step 3: Run the Node.js script to select an EC2 instance interactively
node interactiveUI/keyValueArrayOfObjectJsonSelect.js -k Name -v InstanceId -f "${array_of_object}" -o "${obejct_selected}"

# Clean up the temporary instance list file
rm "${tmp_path}${array_of_object}"

# Step 4: Read the selected instance information
if [ -f "$SELECTED_OPTION_OBJECT_PATH" ]; then
  SELECTED_OBJECT=$(cat "$SELECTED_OPTION_OBJECT_PATH")

  ACCESS_Instance_Id=$(echo "$SELECTED_OBJECT" | jq -r '.InstanceId')
  Access_Name=$(echo "$SELECTED_OBJECT" | jq -r '.Name')
else
  echo "File $SELECTED_OPTION_OBJECT_PATH does not exist. Exiting."
  exit 1
fi

rm "$SELECTED_OPTION_OBJECT_PATH"

# Step 5: SSH into the selected instance
echo -e "\nAccessing EC2 instance: $Access_Name ($ACCESS_Instance_Id)"

aws ssm start-session --target "$ACCESS_Instance_Id"
