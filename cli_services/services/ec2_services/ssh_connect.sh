#!/bin/bash
source utility/colors.sh
source utility/select_region.sh

# Temporary file paths
tmp_path="/usr/src/app/cli_services/tmp/"
array_of_object="arrayOfObject.json"
obejct_selected="object.json"
SELECTED_OPTION_OBJECT_PATH=${tmp_path}${obejct_selected}

select_region
# Read the selected region from the JSON file
if [[ -f "$SELECTED_OPTION_OBJECT_PATH" ]]; then
  selected_region=$(jq -r '.Name' "$SELECTED_OPTION_OBJECT_PATH") && rm "$SELECTED_OPTION_OBJECT_PATH"
else
  echo "Failed to select a region. Exiting."
  exit 1
fi

echo -e "\nAccessing Running EC2 instances in region: $selected_region"

# Step 2: Get the list of running EC2 instances in the selected region
RUNNING_INSTANCES_JSON=$(aws ec2 describe-instances --region "$selected_region" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value}" \
  --output json | jq 'sort_by(.Name)')

if [ $? -eq 0 ]; then
  # Check if JSON data contains instances
  if [ "$(echo "$RUNNING_INSTANCES_JSON" | jq 'length')" -gt 0 ]; then
    echo "$RUNNING_INSTANCES_JSON" | jq .
    echo "$RUNNING_INSTANCES_JSON" >"${tmp_path}${array_of_object}"
  else
    echo "No running EC2 instances found in region: $selected_region."
    exit 1
  fi
else
  echo "Failed to retrieve EC2 instance data from region: $selected_region."
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
