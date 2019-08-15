#!/bin/bash
#
# Test DMAs using 'dmatest' kernel module.
# The kernel module must be loaded or built-in for these tests to pass.
#
set -e

TIMEOUT=2000 # in ms, -1 for infinite
ITERATIONS=1
THREADS_PER_CHAN=1
TEST_BUF_SIZE=32
TRANSFER_SIZE=16
VERBOSE=Y
DMESG_BUF_LEN=50 # about 10x what we should need, but room for other messages

# should fail immediately if dmatest isn't available
echo $TIMEOUT > /sys/module/dmatest/parameters/timeout
echo $ITERATIONS > /sys/module/dmatest/parameters/iterations
echo $THREADS_PER_CHAN > /sys/module/dmatest/parameters/threads_per_chan
echo $TEST_BUF_SIZE > /sys/module/dmatest/parameters/test_buf_size
echo $TRANSFER_SIZE > /sys/module/dmatest/parameters/transfer_size
echo $VERBOSE > /sys/module/dmatest/parameters/verbose

function dma_check_failures()
{
    # summary contains the string "N failures" for some value N
    local summary=$1
    local last=""
    for s in $summary; do
        if [ "$s" == "failures" ]; then
            [ "$last" == "0" ] && return || return 1
        fi
        last=$s
    done
    return 1 # no summary line (empty string)?
}

function dma_test()
{
    local chan=$1
    echo "$chan" > /sys/module/dmatest/parameters/channel
    local dmesg_a=$(dmesg | tail -n $DMESG_BUF_LEN)
    # start the test (returns immediately)
    echo 1 > /sys/module/dmatest/parameters/run
    # wait for test completion
    cat /sys/module/dmatest/parameters/wait
    local dmesg_b=$(dmesg | tail -n $DMESG_BUF_LEN)
    # get only new lines in dmesg - ignore lines unrelated to dmatest and those
    # that fell out of buffer range (from earlier tests)
    local dmesg_new=$(diff <(echo "$dmesg_a") <(echo "$dmesg_b") -U 0 |
                      grep "dmatest" | grep -E "^\+\[" | cut -c2-)
    if ! dma_check_failures "$(echo "$dmesg_new" | grep "summary")"; then
        echo "dmatest failed for channel: $chan" >&2
        echo "$dmesg_new" >&2
        return 1
    fi
}

for c in /sys/class/dma/*; do
    dma_test "$(basename "$c")"
done
