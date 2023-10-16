#!/usr/bin/env bash
set -e
if [ -n "$CERC_SCRIPT_DEBUG" ]; then
  set -x
fi

echo "$(date +"%Y-%m-%d %T"): Running stack-orchestrator Payments stack fixturenet test"
# Bit of a hack, test the most recent package
TEST_TARGET_SO=$( ls -t1 ./package/laconic-so* | head -1 )
# Set a new unique repo dir
export CERC_REPO_BASE_DIR=$(mktemp -d stack-orchestrator-fixturenet-payments-test.XXXXXXXXXX)
echo "$(date +"%Y-%m-%d %T"): Testing this package: $TEST_TARGET_SO"
echo "$(date +"%Y-%m-%d %T"): Test version command"
reported_version_string=$( $TEST_TARGET_SO version )
echo "$(date +"%Y-%m-%d %T"): Version reported is: ${reported_version_string}"
echo "$(date +"%Y-%m-%d %T"): Cloning repositories into: $CERC_REPO_BASE_DIR"
$TEST_TARGET_SO --stack fixturenet-payments setup-repositories --pull
echo "$(date +"%Y-%m-%d %T"): Building containers"
$TEST_TARGET_SO --stack fixturenet-payments build-containers
echo "$(date +"%Y-%m-%d %T"): Starting stack"
$TEST_TARGET_SO --stack fixturenet-payments deploy --cluster payments up
echo "$(date +"%Y-%m-%d %T"): Stack started"
# Verify that the fixturenet is up and running
$TEST_TARGET_SO --stack fixturenet-payments deploy --cluster payments ps

# get watcher payments channel id
timeout=600 # 10 minutes
echo "$(date +"%Y-%m-%d %T"): Waiting for watcher payment channel status 'Open'. Timeout set to $timeout seconds"
start_time=$(date +%s)
elapsed_time=0
while [ -z "$WATCHER_UPSTREAM_PAYMENT_CHANNEL" ]  && [ $elapsed_time -lt $timeout ]; do
  sleep 10
  echo "$(date +"%Y-%m-%d %T"): Waiting for channel..."
  WATCHER_UPSTREAM_PAYMENT_CHANNEL=$(docker logs $(docker ps -aq --filter name="mobymask-watcher-server") 2>&1 | \
    grep "payment channel created with id" | \
    grep -o '0x[0-9a-fA-F]\+') \
    || true
  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

echo "Watcher payment channel id: $WATCHER_UPSTREAM_PAYMENT_CHANNEL"

# check watcher payment channel status. Expected result: 'Open'
query="Status:"
watcher_query_result=$(docker exec payments-nitro-rpc-client-1 npm exec -c "nitro-rpc-client get-payment-channel $WATCHER_UPSTREAM_PAYMENT_CHANNEL -h ipld-eth-server -p 4005" | \
  grep "$query" | \
  grep -o "'.*'") \
  || true

# run ponder indexer for 180s and get ponder payments channel id
timeout=180
PONDER_UPSTREAM_PAYMENT_CHANNEL=$(docker exec -it payments-ponder-app-indexer-1 bash -c "DEBUG=laconic:payments timeout ${timeout}s pnpm start" | \
  grep "Using payment channel" | \
  grep -o '0x[0-9a-fA-F]\+') \
  || true

if [[ -z "$PONDER_UPSTREAM_PAYMENT_CHANNEL" ]]; then
  echo "Ponder payment channel id not found."
  ponder_query_result=0
else
  echo "Ponder payment channel id: $PONDER_UPSTREAM_PAYMENT_CHANNEL"
  # query ponder payment channel, Expected result: PaidSoFar is nonzero
  query="PaidSoFar"
  ponder_query_result=$(docker exec payments-nitro-rpc-client-1 npm exec -c "nitro-rpc-client get-payment-channel $PONDER_UPSTREAM_PAYMENT_CHANNEL -h ipld-eth-server -p 4005" | \
    grep "$query" | \
    grep -o '[0-9]\+') \
    || true
fi

if [[ "$watcher_query_result" == "'Open'" && "$ponder_query_result" -gt 0 ]]; then
  echo "Test passed"
  test_result=0
else
  echo "Test failed: watcher_query_result was $watcher_query_result and ponder_query_result was $ponder_query_result"
  echo "Logs from stack:"
  $TEST_TARGET_SO --stack fixturenet-payments deploy logs
  test_result=1
fi
$TEST_TARGET_SO --stack fixturenet-payments deploy --cluster payments down 30 --delete-volumes
echo "$(date +"%Y-%m-%d %T"): Removing cloned repositories"
rm -rf $CERC_REPO_BASE_DIR
echo "$(date +"%Y-%m-%d %T"): Test finished"
exit $test_result