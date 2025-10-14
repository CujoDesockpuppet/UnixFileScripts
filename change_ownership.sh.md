Global Ownership Change Script (change_ownership.sh)
This robust shell script is designed to safely and globally update the owner and group of files and directories within a specified target path. It functions by first identifying objects that match a specific source owner and group combination, and then applying the new ownership to only those matching objects.

The script prioritizes safety by requiring a mandatory test listing phase before execution and provides a clear, detailed log of all actions.

1. Compatibility
This script is designed for maximum compatibility across various Unix-like operating systems:

Linux (Modern and POSIX-compatible systems)

AIX (Includes specific logic for temporary file handling)

Most other Unix variants

2. Prerequisites
Root Access: The script must be executed as the root user ($EUID check).

Essential Utilities: Requires bash, find, chown, tee, and wc.

3. Usage
Save the script: Save the code as change_ownership.sh.

Set permissions: Make the script executable:

chmod +x change_ownership.sh

Run as root: Execute the script using sudo or by switching to the root user:

sudo ./change_ownership.sh

4. Interactive Prompts
The script will guide you through four main inputs:

Input

Description

Example

Target Directory

The top-level path where the changes will occur. (e.g., /var/www/html)

/opt/data/app

Source OWNER

The current owner to match against.

olduser

Source GROUP

The current group to match against.

oldgroup

Target (new) OWNER

The new owner to assign to matching files.

newuser

Target (new) GROUP

The new group to assign to matching files.

newgroup

5. Execution Modes
After providing the ownership details, you must select an execution mode from the menu:

Option

Mode

Action Performed

1

Test Listing ONLY

Runs the find command and writes all matched paths to the log file. No actual ownership changes are made.

2

Test and Execute

(Recommended) Performs the test listing first, displays the count, prompts for final confirmation, and then applies chown to the listed files.

3

Cancel

Exits the script immediately without making any changes.

6. Safety and Logging Features
Logging
All output, including the files found and any execution errors, is appended to a time-stamped log file in the current directory, named in the format:
ownership_change_YYYYMMDD_HHMMSS.log

Core Safety Checks
Root Requirement: Ensures the script has the necessary permissions to change ownership.

Directory Validation: Checks that the provided target directory exists before proceeding.

Symlink Exclusion: The find command explicitly uses ! -type l to skip soft links (symlinks), preventing unintended changes to files outside the target directory structure.

Graceful Exit: If the Test Listing phase finds zero matching files, the script prints an informative success message and exits immediately (exit 0), preventing unnecessary execution flow.

Confirmation: When running the "Test and Execute" option, a final confirmation prompt is required before the chown operation is run.
