#!/bin/bash

# tempory file were interactiveUI/select.js will write the selected option

tmp_path="/usr/src/app/cli_services/tmp/"
array_of_object="arrayOfObject.json"
obejct_selected="object.json"
SELECTED_OPTION_OBJECT_PATH=${tmp_path}${obejct_selected}

# 1. OutPut the CURRENT REGION
echo -e "\n"
REGION=$(aws configure get region)
echo "Accessing Running EC2 instances in $REGION"



# 2. Get the list of running instances in JSON format
RUNNING_INSTANCES_JSON=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
--query "Reservations[].Instances[].{InstanceId:InstanceId,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value}" \
--output json | jq 'sort_by(.Name)')

if [ $? -eq 0 ]; then
  # Check if json_data is not empty and contains at least one object
  if [ "$(echo $RUNNING_INSTANCES_JSON | jq 'length')" -gt 0 ]; then
    echo "$RUNNING_INSTANCES_JSON" | jq .
    # Write the JSON data to the file
    echo "$RUNNING_INSTANCES_JSON" > "${tmp_path}${array_of_object}"
  else
    echo "No running EC2 instances found."
  fi
else
  echo "Failed to retrieve EC2 instance data."
fi


# 3. Run the Node.js script to select the instance interactively
node interactiveUI/keyValueArrayOfObjectJsonSelect.js -k Name -v InstanceId -f "${array_of_object}" -o "${obejct_selected}"

# remove the tempory Instance List file
rm "${tmp_path}${array_of_object}"



# 4. Read the selected instance information object from the JSON file
# Check if the JSON file exists
if [ -f "$SELECTED_OPTION_OBJECT_PATH" ]; then    
  # Extract values from the JSON file using jq
  SELECTED_OBJECT=$(cat "$SELECTED_OPTION_OBJECT_PATH")

  ACCESS_Instance_Id=$(echo "$SELECTED_OBJECT" | jq -r '.InstanceId')
  Access_Name=$(echo "$SELECTED_OBJECT" | jq -r '.Name')
  # public_ip=$(echo "$SELECTED_OBJECT" | jq -r '.PublicIP')
else
  echo "File $SELECTED_OPTION_OBJECT_PATH does not exist."
  exit 1
fi

rm "$SELECTED_OPTION_OBJECT_PATH"



# 5. SSH into the selected instance
echo -e "\n Accessing EC2 instance: $Access_Name ($ACCESS_Instance_Id)"

aws ssm start-session --target $ACCESS_Instance_Id
