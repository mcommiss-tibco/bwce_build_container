#!/bin/bash

# Start Xvfb in the background on display :99.
# -ac: Disables access control, allowing connections from any client (useful in Docker).
# -screen 0 1280x1024x24: Defines a virtual screen with resolution 1280x1024 and 24-bit color depth.
#                        Adjust resolution as needed for your application.
Xvfb :99 -ac -screen 0 1280x1024x24 &

# Wait for Xvfb to start up and be ready to accept connections.
# A simple sleep is often sufficient for most cases.
# For more robust applications, you might want to check for a specific X server socket file
# or use `xdpyinfo` to ensure the display is truly up before proceeding.
sleep 3

# Execute the command passed to the Docker container.
# `exec "$@"` ensures that signals (like SIGTERM for graceful shutdown)
# are correctly passed to your application.
exec "$@"