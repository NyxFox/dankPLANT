#!/bin/bash
# Make all shell scripts executable
# Run this before committing to git

find debian -name "*.sh" -type f -exec chmod +x {} \;
chmod +x install.sh

echo "All shell scripts are now executable:"
find debian -name "*.sh" -type f -exec ls -l {} \;
ls -l install.sh
