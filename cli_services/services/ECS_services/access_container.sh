#!/bin/bash
# tempory file were interactiveUI/select.js will write the selected option
tmp_file_path="/usr/src/app/cli_services/tmp/node_inquirer_select.txt"

get_selected_option(){
  if [[ -f "$tmp_file_path" ]]; then
    SELECTED_OPTION=$(cat "$tmp_file_path")
    rm "$tmp_file_path"
    echo "$SELECTED_OPTION"
  else
    echo "error: File $tmp_file_path does not exist."
  fi
}

echo -e "\n"
REGION=$(aws configure get region)
echo "Accessing ECS Containers for $REGION"

# Get the list of clusters in JSON format
CLUSTERS_JSON=$(aws ecs list-clusters)
# Pretty print the JSON
echo "$CLUSTERS_JSON" | jq .






# PART 1: Extract the clusterArns as an array using 

# Extract the clusterArns as an array using jq
CLUSTER_ARNS=($(echo $CLUSTERS_JSON | jq -r '.clusterArns[]'))

# Return if no clusters are found
if [ -z "$CLUSTER_ARNS" ]; then
  echo "No clusters found."
  exit 1
fi

# CLUSTER_ARNS_Choices="${CLUSTER_ARNS[@]}"
# Run the Node.js script with the desired arguments
echo -e "\n"

node interactiveUI/select.js --choices "${CLUSTER_ARNS[@]}" -q "Select the cluster to access:"
SELECTED_CLUSTER=$(get_selected_option)
# # Check if the file exists
# if [[ -f "$tmp_file_path" ]]; then
#   SELECTED_CLUSTER=$(cat "$tmp_file_path")
#   rm "$tmp_file_path"
# else
#   echo "File $tmp_file_path does not exist."
# fi

SELECTED_CLUSTER_NAME=$(aws ecs describe-clusters --clusters "$SELECTED_CLUSTER" --query 'clusters[0].clusterName' --output text)





# Terminal Coloring based on the environment
shopt -s nocasematch
if [[ $SELECTED_CLUSTER_NAME == *pro* ]]; then
  terminal_color=1
  env="Production"
elif [[ $SELECTED_CLUSTER_NAME == *dev* ]]; then
  terminal_color=2
  env="Development"
else
  terminal_color=3
  env="Other"
fi
shopt -u nocasematch


tput setaf $terminal_color
echo -e "\n$(tput bold)Accesing... $SELECTED_CLUSTER_NAME$(tput sgr0)"
echo -e "\n\n$(tput bold)$(tput setaf $terminal_color)ENVIRONMENT: $env$(tput sgr0)\n\n"








# PART 2: Get the list of services in the selected cluster

TASKS_JSON=$(aws ecs list-tasks --cluster "$SELECTED_CLUSTER")
echo "$TASKS_JSON" | jq .
TASK_ARNS=($(echo $TASKS_JSON | jq -r '.taskArns[]'))

# Return if no tasks are found
if [ -z "$TASK_ARNS" ]; then
  echo "No tasks were found."
  exit 1
fi

# TASK_ARNS=("any" "${TASK_ARNS[@]}")

echo -e "\n"
# Run the intercative UI to selecte the desired task
node interactiveUI/select.js --choices "any" "${TASK_ARNS[@]}" -q "Select the task to access:"
SELECTED_TASk=$(get_selected_option)
if [[ "$SELECTED_TASk" =~ ^error ]]; then
  echo $SELECTED_TASk
  exit 1
fi


if [[ "$SELECTED_TASk" == "any" ]]; then
  echo -e "\nAccessing first accessible task in the selected cluster..."
  ACCESSING_TASKS=("${TASK_ARNS[@]}")
else
  echo -e "\nAccesing selected Task"
  ACCESSING_TASKS=($SELECTED_TASk)
  echo -e "\n ${ACCESSING_TASKS[@]}"
fi










# PART 3: Get the container names in to which wants to connect

# Declare an associative array to hold container names for each task
ALL_CONTAINER_NAMES=()

# Loop through each task ARN
for TASK_ARN in "${ACCESSING_TASKS[@]}"; do
    # Describe the task to get detailed information including container details
    TASK_DESCRIPTION=$(aws ecs describe-tasks --cluster $SELECTED_CLUSTER_NAME --tasks "$TASK_ARN")

    # Extract the container names using jq
    CONTAINER_NAMES=$(echo $TASK_DESCRIPTION | jq -r '.tasks[0].containers[].name')

    # Store the container names in the associative array
    for CONTAINER_NAME in $CONTAINER_NAMES; do
        ALL_CONTAINER_NAMES+=("$CONTAINER_NAME")
    done
done

echo -e "\n"
node interactiveUI/select.js --choices "${ALL_CONTAINER_NAMES[@]}" -q "Select the container name to be accessed:"
SELECTED_CONTAINER_NAME=$(get_selected_option)
if [[ "$SELECTED_CONTAINER_NAME" =~ ^error ]]; then
  echo $SELECTED_CONTAINER_NAME
  exit 1
fi







# PART 4: check access to the tasks
if [ ${#ACCESSING_TASKS[@]} -gt 1 ]; then
  for TASK_ARN in "${ACCESSING_TASKS[@]}"; do
    echo "Checking access to task: $TASK_ARN"
    # Attempt to execute a simple command as a connection test
    if aws ecs execute-command \
      --region "$REGION" \
      --cluster "$SELECTED_CLUSTER_NAME" \
      --task "$TASK_ARN" \
      --container "$SELECTED_CONTAINER_NAME" \
      --command "/bin/echo Testing access" \
      --interactive > /dev/null 2>&1; then
        
      echo -e "Access to container in task $TASK_ARN: SUCCESS\n\n"
      # Set task_num to the current TASK_ARN and exit the loop
      CONNECTING_TASK=$TASK_ARN
      break
    else
        echo -e "Access to container in task $TASK_ARN: FAILED\n\n"
    fi
  done
else
  CONNECTING_TASK=${ACCESSING_TASKS[0]}
fi




# PART 4: Connect to the selected task
if [ -n "$CONNECTING_TASK" ]; then
  aws ecs execute-command \
    --region "$REGION" \
    --cluster "$SELECTED_CLUSTER_NAME" \
    --task "$CONNECTING_TASK" \
    --container "$SELECTED_CONTAINER_NAME" \
    --command "/bin/sh" \
    --interactive
else
  echo "No successful connection found. $task_number"
fi