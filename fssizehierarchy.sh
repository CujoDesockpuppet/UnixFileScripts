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

# Prompt the user for a directory path and store it in a variable
read -p "Please enter the directory to scan: " scan_dir

# Check if the entered directory exists and is a directory
if [[ ! -d "$scan_dir" ]]; then
  echo "Error: Directory '$scan_dir' does not exist or is not a directory. Exiting."
  exit 1
fi

# Change to the user-specified directory
cd "$scan_dir" || exit 1

# Initialize a variable to keep track of the current top-level directory
current_toplevel_dir=""

find . -type d -print | while read dir; do
  # Determine the top-level directory for the current path
  toplevel_dir=$(echo "$dir" | cut -d'/' -f2)

  # Check if the top-level directory has changed
  if [[ "$toplevel_dir" != "$current_toplevel_dir" ]]; then
    # Print the headings if a new top-level directory is encountered
    printf "\n"
    printf "Host = %s  Top Level Directory Structure = %s\n" "$HOSTNAME" "$scan_dir"
   # printf "%-25s %s\n" "Host =" "$HOSTNAME"
     printf "%-25s %s\n" "Directory Structure =" "$toplevel_dir"   
# printf "%-13s %s\n" "Size(MB)     " "   Path"
    printf "%-13s %s\n" "-------------" "   --------"
    # Update the current top-level directory
    current_toplevel_dir="$toplevel_dir"
  fi

  # Get the directory size in MB. Use 'du -sm' for KB on AIX.
  size=$(du -sm "$dir" | awk '{print $1}')
  
  # Check if the size is a non-zero value.
  if [[ "$size" != "0.00" ]]; then
    # Determine the depth of the directory
    depth=$(echo "$dir" | awk -F'/' '{print NF-1}')
    
    # Calculate the number of spaces for indentation. A simple rule is to
    # add 2 spaces for each level of depth beyond the top level.
    indentation=$(( (depth - 1) * 2 ))
    
    # Use printf to create the indentation
    indent_spaces=$(printf "%*s" "$indentation" "")

    # Format the output with right-aligned decimal numbers and indentation
    printf "%13.2f\t%s%s\n" "$size" "$indent_spaces" "$dir"
  fi
done