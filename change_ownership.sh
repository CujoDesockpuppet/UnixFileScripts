#!/bin/bash

# Script to globally change owners and groups within a specified directory,
# based on a matching source owner/group combination, with interactive options.
# Compatibility: AIX and Linux (uses standard Bourne shell features and commands)

echo "--- Global Ownership and Group Change Script with Safety Menu ---"

# --- 1. ROOT USER CHECK & CONFIGURATION ---

if [ "$EUID" -ne 0 ]; then
    echo -e "\n **ERROR:** This script must be run as the root user."
    echo "Please run this script using './change_ownership.sh on AIX' or 'sudo ./change_ownership.sh on Linux'"
    exit 1
fi

LOG_FILE="./ownership_change_$(date +%Y%m%d_%H%M%S).log"
OWNERSHIP_SPEC=""
FILE_COUNT=0 # Global variable to store the accurate count of files found

# --- AIX COMPATIBILITY FIX: Temporary File Setup ---
# Using a unique filename based on the process ID ($$) since 'mktemp' is not portable.
TEMP_PATH="/tmp/ownership_paths_$$"

# Function to clean up the temporary file on exit/error
cleanup() {
    rm -f "$TEMP_PATH"
}
# Set trap to run cleanup function when the script exits normally or receives signals
trap cleanup EXIT INT TERM

# --- 2. OS DETECTION AND FIND PARAMETER SETUP ---

OS_NAME=$(uname)
FIND_OWNER_PARAM="-user" 
FIND_GROUP_PARAM="-group" 

if [[ "$OS_NAME" == "Linux" ]]; then
    FIND_OWNER_PARAM="-owner"
fi

echo "Detected OS: $OS_NAME. Using find parameters: $FIND_OWNER_PARAM and $FIND_GROUP_PARAM." | tee -a "$LOG_FILE"

# --- 3. GET USER INPUT ---

# Get the target directory
read -r -p "Enter the **target directory** (e.g., /opt/data/): " TARGET_DIR

# Check if the directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist or is not a directory." | tee -a "$LOG_FILE"
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
    echo "Error: All fields must be entered." | tee -a "$LOG_FILE"
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
    echo -e "\n--- Performing Test Listing on $(date) ---" | tee -a "$LOG_FILE"
    echo "**Soft links (symlinks) will be automatically skipped.**" | tee -a "$LOG_FILE"
    echo "Files found that match $SOURCE_OWNER:$SOURCE_GROUP will be listed below (pushed to $LOG_FILE):" | tee -a "$LOG_FILE"
    echo "Find Command: find \"$TARGET_DIR\" ! -type l $FIND_OWNER_PARAM \"$SOURCE_OWNER\" $FIND_GROUP_PARAM \"$SOURCE_GROUP\" -print" | tee -a "$LOG_FILE"
    echo "--------------------------------------------------------" | tee -a "$LOG_FILE"
    
    # 1. Ensure the temporary file is empty before use
    >"$TEMP_PATH"
    
    # Execute find. Errors (stderr) go to screen and log. Successful paths (stdout) go to the pipe.
    # The while read loop filters the output to only count valid paths, writing them to TEMP_PATH.
    find "$TARGET_DIR" ! -type l "$FIND_OWNER_PARAM" "$SOURCE_OWNER" "$FIND_GROUP_PARAM" "$SOURCE_GROUP" -print 2>&1 | tee -a "$LOG_FILE" | while read -r PATH_LINE; do
        # Only count the line if it starts with the target directory, indicating a successful path listing.
        if [[ "$PATH_LINE" = "$TARGET_DIR"* ]]; then
            echo "$PATH_LINE" >> "$TEMP_PATH"
        fi
    done
    FIND_STATUS=${PIPESTATUS[0]} # Get status of 'find' (the first command in the pipe)

    # 2. Get the final, reliable count from the temporary file
    FILE_COUNT=$(wc -l < "$TEMP_PATH" | tr -d '[:space:]')
    
    # 3. Handle results
    
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo -e "\n**FOUND FILES (First 5 of $FILE_COUNT total):**" | tee -a "$LOG_FILE"
        head -n 5 "$TEMP_PATH" | tee -a "$LOG_FILE"
        if [ "$FILE_COUNT" -gt 5 ]; then
            echo "[... $FILE_COUNT total items. Full list in log file.]" | tee -a "$LOG_FILE"
        fi
        echo "--------------------------------------------------------" | tee -a "$LOG_FILE"

        # Log the full list
        echo -e "\n[FULL LIST OF $FILE_COUNT ITEMS]" >> "$LOG_FILE"
        cat "$TEMP_PATH" >> "$LOG_FILE"

        echo "Listing complete. **$FILE_COUNT** files/directories found. Check '$LOG_FILE' for the full list." | tee -a "$LOG_FILE"
        return 0
    else
        # If file count is 0, check for find fatal error status first
        if [ "$FIND_STATUS" -ne 0 ]; then
             echo "ERROR: Find command returned a non-zero exit status ($FIND_STATUS) and found 0 files. Aborting." | tee -a "$LOG_FILE"
             return 1
        fi
        
        # If no files found and no fatal find error (status 0)
        echo -e "\n**No files or directories found** matching owner $SOURCE_OWNER and group $SOURCE_GROUP (Soft links skipped). Nothing to change." | tee -a "$LOG_FILE"
        return 10 # Custom exit code for "No files found"
    fi
}

# Function to perform the actual ownership change
perform_change() {
    
    # Check if the listing phase (option 3) already determined a count of 0.
    if [ "$CHOICE" -eq 3 ] && [ "$FILE_COUNT" -eq 0 ]; then
        echo -e "\nSkipping ownership change: No files were found in the listing phase." | tee -a "$LOG_FILE"
        return 0
    fi
    
    echo -e "\n--- Applying Ownership Changes ---" | tee -a "$LOG_FILE"
    
    # For option 2 (Execute ONLY), we must run a separate count/check.
    if [ "$CHOICE" -ne 3 ]; then
        # Check count without logging output to screen/main log
        TEMP_COUNT=$(find "$TARGET_DIR" ! -type l "$FIND_OWNER_PARAM" "$SOURCE_OWNER" "$FIND_GROUP_PARAM" "$SOURCE_GROUP" -print 2>/dev/null | wc -l | tr -d '[:space:]')
        if [ "$TEMP_COUNT" -eq 0 ]; then
            echo -e "\n**No files or directories found** matching owner $SOURCE_OWNER and group $SOURCE_GROUP (Soft links skipped). Ownership change skipped." | tee -a "$LOG_FILE"
            return 0
        fi
        CONFIRMATION_COUNT=$TEMP_COUNT
    else
        CONFIRMATION_COUNT=$FILE_COUNT
    fi

    read -r -p "Are you sure you want to change ownership of **$CONFIRMATION_COUNT** items to $OWNERSHIP_SPEC in $TARGET_DIR (y/N)? " CONFIRMATION
    
    if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
        echo "Ownership change cancelled by user." | tee -a "$LOG_FILE"
        return 1
    fi

    START_TIME=$(date +%s)
    
    # Execute the change
    find "$TARGET_DIR" ! -type l "$FIND_OWNER_PARAM" "$SOURCE_OWNER" "$FIND_GROUP_PARAM" "$SOURCE_GROUP" -exec chown "$OWNERSHIP_SPEC" {} + 2>&1 | tee -a "$LOG_FILE"
    
    # Check the exit status of the first command in the pipeline (find) using PIPESTATUS
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "\nOwnership change of **$CONFIRMATION_COUNT** items **completed successfully** on $(date) in $DURATION seconds." | tee -a "$LOG_FILE"
        echo "Files/dirs previously owned by $SOURCE_OWNER:$SOURCE_GROUP are now owned by $TARGET_OWNER:$TARGET_GROUP." | tee -a "$LOG_FILE"
    else
        echo -e "\n**FATAL ERROR:** An error occurred during the ownership change. Check the log '$LOG_FILE'." | tee -a "$LOG_FILE"
        echo "This could be due to a faulty find command, a critical permissions error, or non-existent user/group. The chown command did not execute successfully." | tee -a "$LOG_FILE"
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
        LISTING_STATUS=$?
        
        # Only proceed to change if listing succeeded (0) and files were found (not 10)
        if [ "$LISTING_STATUS" -eq 0 ]; then
            perform_change
        elif [ "$LISTING_STATUS" -eq 10 ]; then
            echo "Execution finished: No files found to change."
            exit 0 # Exit successfully since no changes were needed
        else
            echo "Execution cancelled due to errors in the test listing phase." | tee -a "$LOG_FILE"
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice. Operation cancelled." | tee -a "$LOG_FILE"
        exit 1
        ;;
esac

echo -e "\nScript execution finished. See '$LOG_FILE' for full details."
exit 0