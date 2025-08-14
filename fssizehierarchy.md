

## **Script Documentation: fssizehierarchy.sh**

---

This script, fssizehierarchy.sh, is designed to recursively scan a specified directory, calculate the size of each subdirectory, and present the output in a hierarchical, tree-like format. It's a read-only script that's compatible with both Linux and AIX operating systems.

### **Purpose**

The primary goal of this script is to provide a clear, easy-to-read overview of disk space usage within a given directory structure. It helps users quickly identify large directories and understand the size distribution within a file system.

### **How it works**

1. **OS Detection**: The script first checks the operating system (uname) to confirm if it's running on Linux or AIX.  
2. **Logging**: All output from the script, including prompts, warnings, and the final size hierarchy, is saved to a timestamped log file in the user's home directory. The log file is also simultaneously displayed on the console.  
3. **User Input**: The user is prompted to enter a directory path to scan. If no path is provided, the script defaults to the user's **HOME** directory.  
4. **Path Validation**: The script validates the user-provided path, ensuring it exists and is a valid directory. It also performs some path normalization, like adding a leading slash if one is missing and removing any trailing slashes.  
5. **Scanning and Formatting**: The script uses the find command to locate all subdirectories. For each directory found, it calculates its size in MB using du \-sm. It then formats the output to display the size and the full path with an indentation that represents the directory's depth, creating a clear hierarchy.  
6. **Cleanup**: At the end of the script, the user is given the option to keep or delete the generated log file.

### **Usage and Warnings**

* **Permissions**: It is highly recommended to run this script as the root user to avoid permission issues, which could prevent the script from accessing and scanning certain directories.  
* **Performance**: Be aware that scanning very large file systems (e.g., /sap\_stage, /CP/interface) can be time-consuming. To optimize performance, it's best to specify a directory as deep as possible in the file system hierarchy.  
* **Example**: To scan a specific directory like /sap\_stage/kfries, you would enter that path when prompted. The script would then focus its scan on that directory and its subdirectories.

### **Code Reference**

Bash

\#\!/bin/bash  
\# Author: The Kevin   
\# Find all directories recursively, then for each directory  
\# print out with sizes and in a hierarchy.

\# Because you may use globally mounted directories,   
\# I want to make sure the user sees whether it's AIX or Linux.

OS\_NAME=$(uname)  
if \[\[ "$OS\_NAME" \== "LINUX" \]\]; then  
  echo "Running on Linux. Proceeding with script."  
\#   exit 0  
fi  
if \[\[ "$OS\_NAME" \== "AIX" \]\]; then  
  echo "Running on AIX. Proceeding with script."  
\#   exit 0  
fi

\# Define the log file name  
\# Use a timestamp to ensure the file is unique  
LOG\_FILE="$HOME/fssizehierarchy\_$(date \+%Y%m%d\_%H%M%S).log"

\# Redirect all script output to the log file and stdout  
exec \> \>(tee "$LOG\_FILE") 2\>&1

\# Obligatory usage warnings  
  echo "--------------------------------------------------------------------------"   
  echo "This is a read-only script, you may want to be root user when running"  
  echo "to eliminate permissions issues on the files and directories scanned."  
  echo "--------------------------------------------------------------------------"  
  echo "Directory input defaults to user's HOME directory, so be careful as root"  
  echo "Please note that this could take a lot of time on huge filesystems"  
  echo "such as /sap\_stage/xxx or /CP/interface/ so qualify the name as much as possible."  
  echo "EG: /sap\_state/kfries or /CP/interface/HUP/fake/directory/ "  
  echo "--------------------------------------------------------------------------"

\# Prompt the user for a directory path and store it in a variable  
read \-p "Please enter the directory to scan: " scan\_dir

\# If the scan\_dir variable is empty, set it to the current directory  
if \[\[ \-z "$scan\_dir" \]\]; then    
    scan\_dir="$HOME"  
fi

\# Add a leading slash if it's not present.  
if \[\[ \! "$scan\_dir" \== /\* \]\]; then  
  scan\_dir="/$scan\_dir"  
fi

\# Strip a trailing slash if it's present.  
scan\_dir="${scan\_dir%/}"

\# Check if the entered directory exists and is a directory  
if \[\[ \! \-d "$scan\_dir" \]\]; then  
  echo "Error: Directory '$scan\_dir' does not exist or is not a directory. Exiting."  
  exit 1  
fi

\# Store the full path of the scan directory for later use  
full\_scan\_dir="$scan\_dir"

\# Change to the user-specified directory  
cd "$scan\_dir" || exit 1

\# Initialize a variable to keep track of the current top-level directory  
current\_toplevel\_dir=""

find . \-type d \-print | while read dir; do  
  \# Determine the top-level directory for the current path.  
  \# We use \`sed\` to remove the leading \`./\` and then \`cut\` to get the first component.  
  toplevel\_dir=$(echo "$dir" | sed 's/^\\.\\///' | cut \-d'/' \-f1)

  \# Check if the top-level directory has changed  
  if \[\[ "$toplevel\_dir" \!= "$current\_toplevel\_dir" \]\]; then  
    \# Print the headings if a new top-level directory is encountered  
    printf "\\n"  
    printf "Host \= %s  Top Level Directory Structure \= %s\\n" "$HOSTNAME" "$full\_scan\_dir"  
    printf "%-25s %s\\n" "Directory Structure \=" "$toplevel\_dir"     
    printf "%-13s %s\\n" "-------------" "  \--------"  
    \# Update the current top-level directory  
    current\_toplevel\_dir="$toplevel\_dir"  
  fi

  \# Get the directory size in MB. Use 'du \-sm' for KB on AIX.  
  size=$(du \-sm "$dir" | awk '{print $1}')  
    
  \# Check if the size is a non-zero value.  
  if \[\[ "$size" \!= "0.00" \]\]; then  
    \# Construct the full path manually, as 'readlink' is not available.  
    \# We append the relative path from 'find' to the user's base directory.  
    \# We use 'sed' to remove the './' prefix if it exists to avoid double slashes.  
    relative\_path=$(echo "$dir" | sed 's/^\\.\\///')  
    full\_path="${full\_scan\_dir}/${relative\_path}"

    \# Determine the depth of the directory  
    \# We now base the depth on the manually constructed full path  
    depth=$(echo "$full\_path" | awk \-F'/' '{print NF-1}')  
      
    \# Calculate the indentation based on the base directory's depth.  
    base\_depth=$(echo "$full\_scan\_dir" | awk \-F'/' '{print NF-1}')  
    indentation=$(( (depth \- base\_depth) \* 2 ))  
      
    \# Use printf to create the indentation  
    indent\_spaces=$(printf "%\*s" "$indentation" "")

    \# Format the output with right-aligned decimal numbers and the full path  
    printf "%13.2f\\t%s%s\\n" "$size" "$indent\_spaces" "$full\_path"  
  fi  
done

\# Inform the user that the output has been logged  
echo "--------------------------------------------------------------------------"  
echo "Script finished. All output has been logged to: $LOG\_FILE"  
echo "--------------------------------------------------------------------------"  
\# Prompt the user to keep or delete the log file  
echo \-e "\\033\[7mPlease choose to keep or remove the current log file.\\033\[0m"  
read \-p "Do you want to keep the log file '$LOG\_FILE'? (y/n): " keep\_log   
\# Check the user's response and act accordingly  
if \[\[ "$keep\_log" \=\~ ^\[Nn\]$ \]\]; then   
  rm "$LOG\_FILE"    
  echo "Log file deleted."  
else    
  echo "Log file kept."  
fi  
