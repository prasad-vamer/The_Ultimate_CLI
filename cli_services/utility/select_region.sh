#!/bin/bash
source utility/colors.sh

select_region() {
  # Temporary file paths
  local tmp_path="/usr/src/app/cli_services/tmp/"

  local array_of_object="arrayOfObject.json"
  local obejct_selected="object.json"
  local SELECTED_OPTION_OBJECT_PATH=${tmp_path}${obejct_selected}

  DEFAULT_REGION=$(aws configure get region)
  echo -e "\nThe current configured default region is: ${BLUE}$DEFAULT_REGION${RESET}"
  read -p "Do you want to use the default region? (Y/n): " use_default_region

  case "${use_default_region,,}" in
  y | yes)
    JSON_CONTENT=$(echo '{"Name": "'$DEFAULT_REGION'"}')
    echo "$JSON_CONTENT" >"${SELECTED_OPTION_OBJECT_PATH}"
    ;;
  n | no)
    local ALL_REGIONS=$(aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output json)

    # Save the regions to a temporary file for selection
    echo "$ALL_REGIONS" >"${tmp_path}${array_of_object}"

    # Use Node.js script to allow user to select a region interactively
    node interactiveUI/keyValueArrayOfObjectJsonSelect.js -k Name -v Name -f "${array_of_object}" -o "${obejct_selected}"
    # Clean up the temporary file
    rm "${tmp_path}${array_of_object}"
    ;;
  *)
    echo "Invalid input. Please enter 'y/yes' or 'n/no'. Exiting."
    exit 1
    ;;
  esac
}
