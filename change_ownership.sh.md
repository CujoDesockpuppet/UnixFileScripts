Global Ownership and Group Change Script Documentation
This script, change_ownership.sh, is a robust Bourne shell script designed to recursively find files and directories within a specified path that currently match a source owner/group combination and change their ownership to a new target owner/group. It incorporates critical safety checks, interactive input, and a tiered execution menu.

🚀 Key Features
Global Recursive Change: Uses the find and chown commands to modify ownership for all matching files and directories under a specified target directory.

Source Matching: Changes are only applied to files and directories that currently possess the specified source owner and group.

Mandatory Root Check: The script strictly enforces execution with root privileges, ensuring the necessary authority to modify file ownership.

Safety Menu: Provides a critical selection menu with options for Test Listing Only, Execute Changes Only, or Both, allowing for verification before applying irreversible changes.

Detailed Logging: A unique, timestamped log file (ownership_change_YYYYMMDD_HHMMSS.log) is created to record the paths of all files found during the test listing phase.

Cross-Platform Compatibility: Designed to work on both AIX and Linux systems using standard shell features.

📋 Prerequisites
Operating System: Linux or AIX.

Permissions: You must have root user privileges to run this script successfully, as ownership changes require elevated access.

🛠️ Usage
1. Execution
Execute the script from the command line, ensuring you use the appropriate method for root access:

Environment

Command

Linux

sudo ./change_ownership.sh

AIX

./change_ownership.sh (Requires being logged in as root)

2. Interactive Prompts
The script will guide you through the necessary inputs:

Target Directory: The starting path for the recursive operation (e.g., /var/www/html).

Source OWNER & Source GROUP: The existing owner and group combination to look for and match.

Target (new) OWNER & Target (new) GROUP: The desired new owner and group to be applied to the matching files (e.g., www-data and app-users).

3. Execution Mode Selection
After providing the details, select one of the following options from the Execution Menu:

Choice

Mode

Action Taken

1

Test Listing ONLY

Lists all matching file paths to the terminal and the log file. No ownership changes are performed.

2

Execute Changes ONLY

Skips the listing and proceeds directly to apply the ownership changes after a final confirmation.

3

Both

Performs the test listing first, and then executes the ownership change after a confirmation prompt.

4

Cancel

Exits the script immediately.

⚙️ Technical Logic
A. Root User Check
The script immediately verifies the user ID:

if [ "$EUID" -ne 0 ]; then
    # Error message and exit
    exit 1
fi

B. Ownership Specification
The target owner and group are combined into a single variable for the chown command:

OWNERSHIP_SPEC="${TARGET_OWNER}:${TARGET_GROUP}"

C. Core Change Command
The core logic uses the efficient -exec ... {} + structure to minimize the number of chown processes executed, speeding up large operations:

find "$TARGET_DIR" -owner "$SOURCE_OWNER" -group "$SOURCE_GROUP" -exec chown "$OWNERSHIP_SPEC" {} + 2>&1

2>&1: Redirects both standard output and standard error (including permissions denied errors) to the console.

The find command locates all files and directories beneath $TARGET_DIR that match both the -owner and -group criteria.