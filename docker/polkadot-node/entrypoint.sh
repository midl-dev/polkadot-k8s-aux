#!/bin/bash

set -e
set -x

if [ ! -z "$CHAIN" ]; then
    chain_param="--chain \"$CHAIN\""
fi

eval /usr/bin/polkadot --wasm-execution Compiled \
         --unsafe-ws-external \
         --unsafe-rpc-external \
         --rpc-methods=Unsafe \
         --rpc-cors=all \
         --unsafe-pruning \
         --pruning=1000 \
         $chain_param
