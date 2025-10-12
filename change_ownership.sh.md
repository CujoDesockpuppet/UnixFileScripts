Certainly\! Here is the documentation for your ownership change script in Markdown format.

# Global Ownership and Group Change Script

This script, `change_ownership.sh`, is designed to recursively find files and directories within a specified path that match a **source** owner/group combination and change their ownership to a new **target** owner/group. It features interactive input, a mandatory root check, and a safety menu for testing before execution.

-----

## 🚀 Key Features

  * **Global Recursive Change:** Uses `find` and `chown` to modify ownership for all matching files and directories under a specified path.
  * **Source Matching:** Only changes files/directories that currently match the specified **source** owner and group.
  * **Root Check:** Ensures the script is run with root privileges, as file ownership changes typically require superuser access.
  * **Interactive Menu:** Provides options to perform a test listing, execute changes, or both, offering a safety measure before mass changes.
  * **Logging:** A log file (`ownership_change_YYYYMMDD_HHMMSS.log`) is created to record the paths of files that match the criteria during the test listing.
  * **Cross-Platform:** Designed for compatibility with both **AIX** and **Linux** environments using standard Bourne shell (`/bin/bash`) features and commands.

-----

## 📋 Prerequisites

  * **Operating System:** Linux or AIX.
  * **Shell:** A POSIX-compatible shell (the script uses `/bin/bash` features).
  * **Permissions:** **Root user** privileges (`sudo` or direct root login) are required to execute the script and perform ownership changes.

-----

## 🛠️ Usage

### 1\. Execute the Script

The script **must** be run as the root user.

| Environment | Command |
| :--- | :--- |
| **Linux** | `sudo ./change_ownership.sh` |
| **AIX** | `./change_ownership.sh` (if logged in as root) |

### 2\. Follow Interactive Prompts

The script will prompt you for the following information:

1.  **Target Directory:** The root directory where the recursive search and change will begin (e.g., `/opt/app/data`).
2.  **Source OWNER & Source GROUP:** The current (old) owner and group combination you want to match.
3.  **Target (new) OWNER & Target (new) GROUP:** The new owner and group to be applied to the matching files.

### 3\. Execution Menu

After providing the details, you must select an execution mode:

| Choice | Mode | Description |
| :---: | :--- | :--- |
| **1** | **Test Listing ONLY** | Runs the `find` command and outputs the path of every file/directory that matches the source owner/group to the terminal and the log file. **No changes are made.** |
| **2** | **Execute Changes ONLY** | Skips the listing and proceeds directly to the `chown` command. A final confirmation prompt will appear before changes are applied. |
| **3** | **Both** | Performs the test listing first, then prompts for confirmation and executes the ownership change. |
| **4** | **Cancel** | Exits the script without performing any actions. |

-----

## 📜 Technical Details

### Core Logic

The primary functionality relies on the `find` command to locate specific files:

```bash
find "$TARGET_DIR" -owner "$SOURCE_OWNER" -group "$SOURCE_GROUP"
```

The action taken on the found files depends on the chosen mode:

  * **Listing:** The command uses `-print` (or pipes the output to `tee`) to list the paths.
  * **Execution:** The command uses an efficient `chown` execution method:
    ```bash
    find ... -exec chown "$OWNERSHIP_SPEC" {} +
    ```
    The `-exec ... {} +` structure is generally faster than using `-exec ... \;` because it executes the `chown` command once with a batch of found files, rather than once per file.

### Logging

A unique log file is created in the current directory with a timestamp:
`./ownership_change_YYYYMMDD_HHMMSS.log`

All files and directories found during the **Test Listing** phase are redirected to this log file via the `tee -a` command, which both prints the output to the screen and appends it to the log.

### Error Handling

  * **Root Check:** Exits with an error if `$EUID` is not `0`.
  * **Directory Check:** Exits if the specified target directory does not exist.
  * **Input Check:** Exits if any required input fields are left blank.
  * **Execution Errors:** Provides on-screen warnings if the `find` or `chown` commands return a non-zero exit status ($? -ne 0).