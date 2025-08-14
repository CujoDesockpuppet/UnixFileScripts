#!/bin/bash
# Author: The Kevin 
# Find all directories recursively, then for each directory
# print out with sizes and in a hierarchy.

# Because you may use globally mounted directories, 
# I want to make sure the user sees whether it's AIX or Linux.

OS_NAME=$(uname)
if [[ "$OS_NAME" == "LINUX" ]]; then
  echo "Running on Linux. Proceeding with script."
#  exit 0
fi
if [[ "$OS_NAME" == "AIX" ]]; then
  echo "Running on AIX. Proceeding with script."
#  exit 0
fi

# Define the log file name
# Use a timestamp to ensure the file is unique
LOG_FILE="$HOME/fssizehierarchy_$(date +%Y%m%d_%H%M%S).log"

# Redirect all script output to the log file and stdout
exec > >(tee "$LOG_FILE") 2>&1

# Obligatory usage warnings
  echo "--------------------------------------------------------------------------" 
  echo "This is a read-only script, you may want to be root user when running"
  echo "to eliminate permissions issues on the files and directories scanned."
  echo "--------------------------------------------------------------------------"
  echo "Directory input defaults to user's HOME directory, so be careful as root"
  echo "Please note that this could take a lot of time on huge filesystems"
  echo "such as /sap_stage/xxx or /CP/interface/ so qualify the name as much as possible."
  echo "EG: /sap_state/kfries or /CP/interface/HUP/fake/directory/ "
  echo "--------------------------------------------------------------------------"

# Prompt the user for a directory path and store it in a variable
read -p "Please enter the directory to scan: " scan_dir

# If the scan_dir variable is empty, set it to the current directory
if [[ -z "$scan_dir" ]]; then  
   scan_dir="$HOME"
fi

# Add a leading slash if it's not present.
if [[ ! "$scan_dir" == /* ]]; then
  scan_dir="/$scan_dir"
fi

# Strip a trailing slash if it's present.
scan_dir="${scan_dir%/}"

# Check if the entered directory exists and is a directory
if [[ ! -d "$scan_dir" ]]; then
  echo "Error: Directory '$scan_dir' does not exist or is not a directory. Exiting."
  exit 1
fi

# Store the full path of the scan directory for later use
full_scan_dir="$scan_dir"

# Change to the user-specified directory
cd "$scan_dir" || exit 1

# Initialize a variable to keep track of the current top-level directory
current_toplevel_dir=""

find . -type d -print | while read dir; do
  # Determine the top-level directory for the current path.
  # We use `sed` to remove the leading `./` and then `cut` to get the first component.
  toplevel_dir=$(echo "$dir" | sed 's/^\.\///' | cut -d'/' -f1)

  # Check if the top-level directory has changed
  if [[ "$toplevel_dir" != "$current_toplevel_dir" ]]; then
    # Print the headings if a new top-level directory is encountered
    printf "\n"
    printf "Host = %s  Top Level Directory Structure = %s\n" "$HOSTNAME" "$full_scan_dir"
    printf "%-25s %s\n" "Directory Structure =" "$toplevel_dir"   
    printf "%-13s %s\n" "-------------" "  --------"
    # Update the current top-level directory
    current_toplevel_dir="$toplevel_dir"
  fi

  # Get the directory size in MB. Use 'du -sm' for KB on AIX.
  size=$(du -sm "$dir" | awk '{print $1}')
  
  # Check if the size is a non-zero value.
  if [[ "$size" != "0.00" ]]; then
    # Construct the full path manually, as 'readlink' is not available.
    # We append the relative path from 'find' to the user's base directory.
    # We use 'sed' to remove the './' prefix if it exists to avoid double slashes.
    relative_path=$(echo "$dir" | sed 's/^\.\///')
    full_path="${full_scan_dir}/${relative_path}"

    # Determine the depth of the directory
    # We now base the depth on the manually constructed full path
    depth=$(echo "$full_path" | awk -F'/' '{print NF-1}')
    
    # Calculate the indentation based on the base directory's depth.
    base_depth=$(echo "$full_scan_dir" | awk -F'/' '{print NF-1}')
    indentation=$(( (depth - base_depth) * 2 ))
    
    # Use printf to create the indentation
    indent_spaces=$(printf "%*s" "$indentation" "")

    # Format the output with right-aligned decimal numbers and the full path
    printf "%13.2f\t%s%s\n" "$size" "$indent_spaces" "$full_path"
  fi
done

# Inform the user that the output has been logged
echo "--------------------------------------------------------------------------"
echo "Script finished. All output has been logged to: $LOG_FILE"
echo "--------------------------------------------------------------------------"
# Prompt the user to keep or delete the log file
echo -e "\033[7mPlease choose to keep or remove the current log file.\033[0m"
read -p "Do you want to keep the log file '$LOG_FILE'? (y/n): " keep_log 
# Check the user's response and act accordingly
if [[ "$keep_log" =~ ^[Nn]$ ]]; then 
  rm "$LOG_FILE"  
  echo "Log file deleted."
else  
  echo "Log file kept."
fi
