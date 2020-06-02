NETWORK="$1"
if [ -z "$NETWORK" ]; then
    NETWORK="testnet"
fi
HOST="0.0.0.0" PORT="4200" yarn build:"$NETWORK"
EXPLORER_HOST="0.0.0.0" EXPLORER_PORT="4200" pm2 start /home/mlh_workshop/core-explorer/express-server.js --name explorer
