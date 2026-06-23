#!/bin/bash

export LANG=en_UK.UTF-8

SCRIPT_DIR=$(dirname $0)
SOURCE_DIR="$SCRIPT_DIR/.."

PASSTHROUGH_ARGS=$*

# Check for NodeJS
NODE_VERSION=$(node -v)
if [ -z "$NODE_VERSION" ]
then
  echo "Error: Node.js is not available."
  exit 1
fi
echo "Node.js version $NODE_VERSION"

# packages.py requires certificates to ping the artifactory servers.
PYTHON_VERSION_MAJOR=$(python3 -Ec "import platform; print(platform.python_version_tuple()[0])")
PYTHON_VERSION_MINOR=$(python3 -Ec "import platform; print(platform.python_version_tuple()[1])")
"/Applications/Python $PYTHON_VERSION_MAJOR.$PYTHON_VERSION_MINOR/Install Certificates.command"

# run packages.py to update third parties
python3 -E "$SOURCE_DIR/jenkins/packages.py" update "$SOURCE_DIR/jenkins"

if [ $? -ne 0 ]; then
  echo "Error: Failed to update packages."
  exit 1
fi

# Detect the platform
OS=$(uname)
if [ $OS = "Linux" ]
then
  POST_ENGINE="$SOURCE_DIR/jenkins/packages/post/centos/7/post"
elif [ $OS = "Darwin" ]
then
  POST_ENGINE="$SOURCE_DIR/jenkins/packages/post/osx/10.15/post"
else
  POST_ENGINE="$SOURCE_DIR/jenkins/packages/post/vc142/x64/post.exe"
fi

# Give the post executable all permissions
chmod 777 $POST_ENGINE

TEST_DIR="$SOURCE_DIR/tests"

TEST_SCRIPT="$TEST_DIR/run-tests.js"
LIB_TEST_CASES="$TEST_DIR/test_cases"
LIB_DATA_DIR="$TEST_DIR"
LIB_POST_DIR="$TEST_DIR/.."
IGNORE_FILES="$TEST_DIR/ignore_all.json;$TEST_DIR/ignore_single.json"

# Run tests
node $TEST_SCRIPT $LIB_TEST_CASES --postEngine=$POST_ENGINE --problemsOnly --dataDir=$LIB_DATA_DIR --postDir=$LIB_POST_DIR --ignore=$IGNORE_FILES $PASSTHROUGH_ARGS
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "Error: Failed to run post library tests."
  exit $EXIT_CODE
fi
