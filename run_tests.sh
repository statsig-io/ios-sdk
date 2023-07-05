#!/bin/bash

MAX_RETRIES=5
retry=0

cd ".swiftpm/xcode"

while [ $retry -lt $MAX_RETRIES ]; do
    xcodebuild test \
        -destination "platform=iOS Simulator,name=iPhone SE (2nd generation)" \
        -scheme Statsig \
        -workspace package.xcworkspace \
        | xcbeautify
    exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        break
    else
        echo "Tests failed with exit code $exit_code. Retrying..."
        retry=$((retry+1))
    fi
done

if [ $retry -eq $MAX_RETRIES ]; then
    echo "Maximum number of retries reached. Exiting..."
    exit 1
else
    exit 0
fi

