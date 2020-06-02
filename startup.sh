#!/bin/bash -l
/home/mlh_workshop/ark-deployer/bridgechain.sh start-core --network "testnet" &>> /home/mlh_workshop/core.log &
/home/mlh_workshop/ark-deployer/bridgechain.sh start-explorer --network "testnet" &>> /home/mlh_workshop/explorer.log &
