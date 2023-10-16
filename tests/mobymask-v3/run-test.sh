#!/usr/bin/env bash
set -e
if [ -n "$CERC_SCRIPT_DEBUG" ]; then
  set -x
fi

echo "$(date +"%Y-%m-%d %T"): Running stack-orchestrator Mobymask-v3 stack test"
# Bit of a hack, test the most recent package
TEST_TARGET_SO=$( ls -t1 ./package/laconic-so* | head -1 )
# Set a new unique repo dir
export CERC_REPO_BASE_DIR=$(mktemp -d stack-orchestrator-mobymask-v3-test.XXXXXXXXXX)
echo "$(date +"%Y-%m-%d %T"): Testing this package: $TEST_TARGET_SO"
echo "$(date +"%Y-%m-%d %T"): Test version command"
reported_version_string=$( $TEST_TARGET_SO version )
echo "$(date +"%Y-%m-%d %T"): Version reported is: ${reported_version_string}"
echo "$(date +"%Y-%m-%d %T"): Cloning repositories into: $CERC_REPO_BASE_DIR"
$TEST_TARGET_SO --stack mobymask-v3 setup-repositories --pull --include github.com/cerc-io/mobymask-ui
echo "$(date +"%Y-%m-%d %T"): Building containers"
$TEST_TARGET_SO --stack --stack mobymask-v3 build-containers --include cerc/mobymask-ui
echo "$(date +"%Y-%m-%d %T"): Starting stack"
$TEST_TARGET_SO laconic-so --stack mobymask-v3 deploy --cluster mobymask_v3 --include mobymask-app-v3 --env-file <PATH_TO_ENV_FILE> up
echo "$(date +"%Y-%m-%d %T"): Stack started"
# Verify that the fixturenet is up and running
$TEST_TARGET_SO --stack mobymask-v3 deploy --cluster mobymask_v3 --include mobymask-app-v3 ps




$TEST_TARGET_SO --stack mobymask-v3 deploy --cluster mobymask_v3 --include mobymask-app-v3 down --delete-volumes
echo "$(date +"%Y-%m-%d %T"): Removing cloned repositories"
rm -rf $CERC_REPO_BASE_DIR
echo "$(date +"%Y-%m-%d %T"): Test finished"
exit $test_result
