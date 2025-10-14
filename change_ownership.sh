#!/bin/bash

# Script to globally change owners and groups within a specified directory,
# based on a matching source owner/group combination, with interactive options.
# Compatibility: AIX, Linux (POSIX-compatible find), and most Unix variants.

echo "--- Global Ownership and Group Change Script with Safety Menu ---"

# --- 1. ROOT USER CHECK & CONFIGURATION ---

if [ "$EUID" -ne 0 ]; then
    echo -e "\n **ERROR:** This script must be run as the root user."
    echo "Please run this script using './change_ownership.sh on AIX/Linux' or 'sudo ./change_ownership.sh on Linux'"
    exit 1
fi

LOG_FILE="./ownership_change_$(date +%Y%m%d_%H%M%S).log"
OWNERSHIP_SPEC=""
FILE_COUNT=0 

# --- UNIVERSAL FIND PARAMETERS ---
FIND_OWNER_PARAM="-user" 
FIND_GROUP_PARAM="-group" 

# --- AIX COMPATIBILITY FIX: Temporary File Setup ---
# Using a unique filename based on the process ID ($$) since 'mktemp' is not portable on AIX.
TEMP_PATH="/tmp/ownership_paths_$$"

# Function to clean up the temporary file on exit/error
cleanup() {
    rm -f "$TEMP_PATH"
}
# Set trap to run cleanup function when the script exits normally or receives signals
trap cleanup EXIT INT TERM

# --- 2. GET USER INPUT ---

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

# --- 3. EXECUTION MENU (REVISED) ---

echo -e "\n--- Execution Mode Selection ---"
echo "1) **Test Listing ONLY**: Find files/dirs and list their paths to the log file ($LOG_FILE)."
echo "2) **Test and Execute**: List files/dirs to log, and then apply the ownership change."
echo "3) **Cancel**"
read -r -p "Enter your choice (1-3): " CHOICE

if [[ "$CHOICE" == "3" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

# --- 4. FUNCTIONS ---

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
        return 0 # Success: Files found
    else
        # If file count is 0, check for find fatal error status first
        if [ "$FIND_STATUS" -ne 0 ]; then
              echo "ERROR: Find command returned a non-zero exit status ($FIND_STATUS) and found 0 files. Aborting." | tee -a "$LOG_FILE"
              return 1 # Error: Fatal Find error
        fi
        
        # --- NO RECORDS FOUND: GRACEFUL EXIT (CHANGE IMPLEMENTED HERE) ---
        echo -e "\n--------------------------------------------------------" | tee -a "$LOG_FILE"
        echo -e "✅ **Operation Complete:** **No files or directories were found**" | tee -a "$LOG_FILE"
        echo "matching owner **$SOURCE_OWNER** and group **$SOURCE_GROUP**." | tee -a "$LOG_FILE"
        echo "Nothing to change. Exiting gracefully." | tee -a "$LOG_FILE"
        echo "--------------------------------------------------------" | tee -a "$LOG_FILE"
        
        # Clean up temporary file and exit the script entirely
        cleanup
        exit 0 # Exit the entire script gracefully
    fi
}

# Function to perform the actual ownership change
perform_change() {
    
    # Check if the listing phase (option 2) already determined a count of 0.
    # Note: Since perform_listing now exits the script if FILE_COUNT is 0, 
    # this check is mostly a safeguard but remains structurally sound.
    if [ "$FILE_COUNT" -eq 0 ]; then
        echo -e "\nSkipping ownership change: No files were found in the listing phase." | tee -a "$LOG_FILE"
        return 0
    fi
    
    echo -e "\n--- Applying Ownership Changes ---" | tee -a "$LOG_FILE"
    
    CONFIRMATION_COUNT=$FILE_COUNT

    read -r -p "Are you sure you want to change ownership of **$CONFIRMATION_COUNT** items to $OWNERSHIP_SPEC in $TARGET_DIR (y/N)? " CONFIRMATION
    
    if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
        echo "Ownership change cancelled by user." | tee -a "$LOG_FILE"
        return 1
    fi

    START_TIME=$(date +%s)
    
    # Execute the change using the universal variables
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

# --- 5. EXECUTION FLOW (REVISED) ---

case "$CHOICE" in
    1) # Test Listing ONLY
        # If perform_listing finds 0 records, it now handles the exit itself.
        perform_listing
        ;;
    2) # Test and Execute
        perform_listing
        LISTING_STATUS=$?
        
        # Note: If perform_listing exits gracefully with 0 files, the script will not reach here.
        if [ "$LISTING_STATUS" -eq 0 ]; then
            perform_change
        else
            # Only reached if perform_listing failed (status 1) due to a fatal find error.
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