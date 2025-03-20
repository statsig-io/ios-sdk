#!/bin/bash

# To test a single spec, run:
# ./run_tests.sh -only-testing StatsigTests/YourSpec

cd ".swiftpm/xcode"

xcodebuild test \
    -destination "platform=iOS Simulator,name=iPhone SE (3rd generation)" \
    -scheme Statsig \
    -workspace package.xcworkspace \
    "$@" \
    | xcbeautify && exit ${PIPESTATUS[0]}
