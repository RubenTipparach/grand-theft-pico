#!/bin/bash
# Launch Picotron with Grand Theft Picotron (with console output)

# Path to Picotron executable inside the app bundle
PICOTRON_EXE="/Applications/Picotron.app/Contents/MacOS/picotron"

if [ -f "$PICOTRON_EXE" ]; then
    # Run directly to get console output
    "$PICOTRON_EXE" "$@"
else
    echo "Picotron not found at $PICOTRON_EXE"
    echo "Please update the path in this script"
    exit 1
fi
