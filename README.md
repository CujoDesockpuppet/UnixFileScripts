Directory Size & Hierarchy Scanner
A bash script that recursively scans a specified directory, calculates the size of each subdirectory, and displays the results in a clear, hierarchical format. It's designed to be compatible with both Linux and AIX environments.

🚀 Features
Recursive Scanning: Finds all subdirectories within a given path.

Directory Sizing: Uses du to calculate the size of each directory in megabytes.

Hierarchical Display: Indents the output to visually represent the directory structure.

OS Compatibility Check: Verifies if the script is running on Linux or AIX.

Input Validation: Checks if the user-provided directory exists before proceeding.

🛠️ Installation
Prerequisites
This script requires a Unix-like environment with a bash shell and standard command-line utilities.

bash

find

du

awk

cut

Steps
Clone the repository:

git clone https://github.com/CujoDesockpuppet/UnixFileScripts.git
cd your-repository

Make the script executable:

chmod +x ./fssizehierarchy.sh

💻 Usage
Run the script from your terminal. It will prompt you to enter the directory you wish to scan.

./fssizehierarchy.sh

Example output:

Running on Linux. Proceeding with script.
Please enter the directory to scan: /home/user/my_project

Host = my_server  Top Level Directory Structure = /home/user/my_project
Directory Structure = my_project
-------------     --------
        1.50      ./src
        0.04        ./src/components
        1.45        ./src/styles
       12.78      ./node_modules

🤝 Contributing
Contributions are welcome! If you'd like to improve this script, please follow these steps:

Fork the repository.

Create a new branch (git checkout -b feature/your-feature).

Make your changes and commit them (git commit -m 'Add your new feature').

Push to the branch (git push origin feature/your-feature).

Open a pull request.

📜 License
This project is licensed under the [Your License Name] License - see the LICENSE.md file for details.

📧 Contact
Author: The Kevin

Project Link: https://github.com/CujoDesockpuppet/UnixFileScripts.git
