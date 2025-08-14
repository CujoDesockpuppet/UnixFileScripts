# File System Size Hierarchy Script

## Overview

This script, `fssizehierarchy.sh`, is a Bash utility designed to recursively scan a specified directory, determine the size of all subdirectories, and present the information in a hierarchical format. It is a read-only script, so it does not modify any files or directories. The script's output is logged to a unique file in the user's home directory while also being displayed on the screen.

---

## Features

- **OS Detection**: Automatically detects if it's running on **Linux** or **AIX** and informs the user.
- **Logging**: All script output is redirected to a timestamped log file (`fssizehierarchy_YYYYMMDD_HHMMSS.log`) in the user's home directory.
- **User Prompts and Warnings**:
    - Warns the user that running as the **root** user is recommended to avoid permission issues.
    - Cautions that the process can be time-consuming on large file systems.
    - Prompts the user to enter a directory path to scan.
- **Input Handling**:
    - If no directory is entered, it defaults to the user's home directory (`$HOME`).
    - Automatically adds a leading slash (`/`) if one is missing.
    - Removes any trailing slashes to ensure a consistent path format.
- **Error Handling**:
    - Checks if the specified directory exists and is a valid directory.
    - If an error occurs, it prompts the user to decide whether to keep or delete the log file.
    - The prompt to keep or delete the log file has a 30-second timeout, after which the log is automatically deleted.

---

## Usage

1.  **Save the script**: Save the provided code into a file named `fssizehierarchy.sh`.
2.  **Make it executable**: Open a terminal and run the following command:
    ```bash
    chmod +x fssizehierarchy.sh
    ```
3.  **Run the script**: Execute the script from the terminal.
    ```bash
    ./fssizehierarchy.sh
    ```
4.  **Enter the directory**: When prompted, enter the full path of the directory you wish to scan. For example:
    ```
    Please enter the directory to scan: /var/log
    ```
    If you just press **Enter**, the script will default to your home directory.

---

## Code

```bash
#!/bin/bash
# Author: The Kevin
# Find all directories recursively, then for each directory
# print out with sizes and in a hierarchy.

# Because you may use globally mounted directories,
# I want to make sure the user sees whether it's AIX or Linux.

OS_NAME=$(uname)
if [[ "$OS_NAME" == "LINUX" ]]; then
  echo "Running on Linux. Proceeding with script."
#   exit 0
fi
if [[ "$OS_NAME" == "AIX" ]]; then
  echo "Running on AIX. Proceeding with script."
#   exit 0
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
"fssizehierarchy.sh" 146 lines, 5451 characters
  # The -t 30 flag sets a 30-second timeout.
  read -t 30 -p "Do you want to keep the log file '$LOG_FILE'? (y/n): " keep_log

  # Check the exit status of the read command to see if it timed out
  if [[ $? -gt 128 ]]; then
    echo -e "\nTimeout reached. Log file will be deleted."
    rm "$LOG_FILE"
    exit 0
  fi

  # Convert the input to lowercase for easier comparison
  keep_log=${keep_log,,}

  # Check for a valid response (y or n)
  if [[ "$keep_log" == "y" ]]; then
    echo "Log file kept."
    break # Exit the loop on a valid response
  elif [[ "$keep_log" == "n" ]]; then
    rm "$LOG_FILE"
    echo "Log file deleted."
    break # Exit the loop on a valid response
  else
    echo "Invalid input. Please answer with 'y' or 'n'."
  fi
done

exit 0
