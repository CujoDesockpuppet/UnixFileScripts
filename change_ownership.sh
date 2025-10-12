#!/bin/bash

# Script to globally change owners and groups within a specified directory,
# based on a matching source owner/group combination, with interactive options.
# Compatibility: AIX and Linux (uses standard Bourne shell features and commands)

echo "--- Global Ownership and Group Change Script with Safety Menu ---"

#  1. ROOT USER CHECK
if [ "$EUID" -ne 0 ]; then
    echo -e "\n **ERROR:** This script must be run as the root user."
    echo "Please run this script using 'sudo ./change_ownership.sh on linux'"
echo "Please run this script using './change_ownership.sh on AIX'"
echo "Alternatively on Linux you can run this way:"
echo "'sudo ./change_ownership.sh on linux'"
    exit 1
fi
# ----------------------

# --- 2. CONFIGURATION ---
LOG_FILE="./ownership_change_$(date +%Y%m%d_%H%M%S).log"
OWNERSHIP_SPEC=""

# --- 3. GET USER INPUT ---

# Get the target directory
read -r -p "Enter the **target directory** (e.g., /opt/data/): " TARGET_DIR

# Check if the directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist or is not a directory."
    exit 1
fi

# Get the source (current) owner and group to match
echo -e "\n--- Current (Source) Owner/Group to Match ---"
read -r -p "Enter the **source OWNER** to match: " SOURCE_OWNER
read -r -p "Enter the **source GROUP** to match: " SOURCE_GROUP

# Get the target (new) owner and group
echo -e "\n--- New (Target) Owner/Group ---"
read -r -p "Enter the **target (new) OWNER**: " TARGET_OWNER
read -r -p "Enter the **target (new) GROUP**: " TARGET_GROUP

OWNERSHIP_SPEC="${TARGET_OWNER}:${TARGET_GROUP}"

# Check for empty input (basic validation)
if [ -z "$TARGET_DIR" ] || [ -z "$SOURCE_OWNER" ] || [ -z "$SOURCE_GROUP" ] || [ -z "$TARGET_OWNER" ] || [ -z "$TARGET_GROUP" ]; then
    echo "Error: All fields must be entered."
    exit 1
fi

# --- 4. EXECUTION MENU ---

echo -e "\n--- Execution Mode Selection ---"
echo "1) **Test Listing ONLY**: Find files/dirs and list their paths to the log file ($LOG_FILE)."
echo "2) **Execute Changes ONLY**: Skip listing and apply the ownership change directly."
echo "3) **Both**: List files/dirs to log and then apply the ownership change."
echo "4) **Cancel**"
read -r -p "Enter your choice (1-4): " CHOICE

if [[ "$CHOICE" == "4" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

# --- 5. FUNCTIONS ---

# Function to perform the test listing
perform_listing() {
    echo -e "\n--- Performing Test Listing ---" | tee -a "$LOG_FILE"
    echo "Files found that match $SOURCE_OWNER:$SOURCE_GROUP will be listed below (pushed to $LOG_FILE):" | tee -a "$LOG_FILE"
    echo "--------------------------------------------------------" | tee -a "$LOG_FILE"

    # The find command lists the files that would be changed, using -print for compatibility
    find "$TARGET_DIR" -owner "$SOURCE_OWNER" -group "$SOURCE_GROUP" -print | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------------" | tee -a "$LOG_FILE"
        echo "Listing complete. Check '$LOG_FILE' for the full list." | tee -a "$LOG_FILE"
    else
        echo "ERROR during listing. Check permissions or find command usage." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to perform the actual ownership change
perform_change() {
    echo -e "\n--- Applying Ownership Changes ---"
    read -r -p "Are you sure you want to change ownership to $OWNERSHIP_SPEC in $TARGET_DIR (y/N)? " CONFIRMATION
   
    if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
        echo "Ownership change cancelled."
        return 1
    fi

    START_TIME=$(date +%s)
   
    # The core logic: find files and change ownership
    # -exec chown ... {} + executes the change efficiently.
    find "$TARGET_DIR" -owner "$SOURCE_OWNER" -group "$SOURCE_GROUP" -exec chown "$OWNERSHIP_SPEC" {} + 2>&1
   
    if [ $? -eq 0 ]; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "\nOwnership change **completed successfully** in $DURATION seconds."
        echo "Files/dirs previously owned by $SOURCE_OWNER:$SOURCE_GROUP are now owned by $TARGET_OWNER:$TARGET_GROUP."
    else
        echo -e "\n**ERROR:** An error occurred during the ownership change."
        echo "Please check the output above for specific errors (e.g., permission denied)."
        return 1
    fi
}

# --- 6. EXECUTION FLOW ---

case "$CHOICE" in
    1) # Test Listing ONLY
        perform_listing
        ;;
    2) # Execute Changes ONLY
        perform_change
        ;;
    3) # Both
        perform_listing
        perform_change
        ;;
    *)
        echo "Invalid choice. Operation cancelled."
        exit 1
        ;;
esac

echo -e "\nScript execution finished."
exit 0