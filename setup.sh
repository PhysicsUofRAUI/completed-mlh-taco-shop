############################
#   ARK Deployer Install   #
############################

####################################
##       Install Instructions     ##
##                                ##
##  adduser bridgechain           ##
##  usermod -aG sudo bridgechain  ##
##  su bridgechain                ##
##  cd ~                          ##
##  bash setup-deployer.sh        ##
##                                ##
####################################

if [ "$EID" == "0" ]; then
    echo "Deployer installation must not be run as root!"
    exit 1
fi

## Update and Install Initial Packages
sudo apt-get update && sudo apt-get install -y jq git curl software-properties-common

## Install NodeJS & NPM
curl -sL https://deb.nodesource.com/setup_11.x | sudo bash -
sudo apt-get update && sudo apt-get install -y nodejs

## Install Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install -y yarn

## Config
rm -rf "$HOME/.deployer/ark/"
mkdir -p "$HOME/.deployer/ark/"
CONFIG_PATH="$HOME/.deployer/ark/config.json"
cat > "$CONFIG_PATH" <<- EOF
{
  "coreIp": "127.0.0.1",
  "p2pPort": 4002,
  "apiPort": 4003,
  "webhookPort": 4004,
  "jsonRpcPort": 8080,
  "explorerIp": "0.0.0.0",
  "explorerPort": 4200,
  "chainName": "ark",
  "token": "ARK",
  "cliAlias": "TOKEN",
  "databaseHost": "localhost",
  "databasePort": "5432",
  "databaseName": "core_bridgechain",
  "symbol": "a\$",
  "mainnetPeers": [
    "157.245.90.17"
  ],
  "devnetPeers": [
    "157.245.90.17"
  ],
  "mainnetPrefix": "A",
  "devnetPrefix": "D",
  "testnetPrefix": "A",
  "fees": {
    "static": {
      "transfer": 10000000,
      "vote": 100000000,
      "secondSignature": 500000000,
      "delegateRegistration": 2500000000,
      "multiSignature": 500000000,
      "ipfs": 500000000,
      "multiPayment": 10000000,
      "delegateResignation": 2500000000
    },
    "dynamic": {
      "enabled": false,
      "minFeePool": 3000,
      "minFeeBroadcast": 3000,
      "addonBytes": {
        "transfer": 100,
        "secondSignature": 250,
        "delegateRegistration": 400000,
        "vote": 100,
        "multiSignature": 500,
        "ipfs": 250,
        "multiPayment": 500,
        "delegateResignation": 400000
      }
    }
  },
  "forgers": 51,
  "blocktime": 8,
  "transactionsPerBlock": 150,
  "totalPremine": 12500000000000000,
  "rewardHeightStart": 1,
  "rewardPerBlock": 200000000,
  "vendorFieldLength": 255,
  "bridgechainPath": "\$HOME/core-bridgechain",
  "explorerPath": "\$HOME/core-explorer",
  "gitCoreCommit": true,
  "gitCoreOrigin": "https://github.com/PhysicsUofRAUI/core",
  "gitExplorerCommit": true,
  "gitExplorerOrigin": "",
  "licenseName": null,
  "licenseEmail": null
}
EOF
BRIDGECHAIN_PATH=$(jq -r '.bridgechainPath' "$CONFIG_PATH")

## Install with Dependencies
rm -rf "$HOME/ark-deployer"
git clone https://github.com/ArkEcosystem/deployer.git -b master "$HOME/ark-deployer"
cd "$HOME/ark-deployer"
./bridgechain.sh install-core --config "$CONFIG_PATH" --autoinstall-deps --non-interactive
if [ "$?" != "0" ]; then
  echo "Core install failed"
  exit
fi

./bridgechain.sh install-explorer --config "$CONFIG_PATH" --skip-deps --non-interactive
if [ "$?" != "0" ]; then
  echo "Explorer install failed"
  exit
fi


## Setup startup and login scripts

if [ -f "$HOME/.bash_profile" ]; then
    echo 'export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.yarn/bin:$PATH"' >> "$HOME/.bash_profile"
elif [ -f "$HOME/.bashrc" ]; then
    echo 'export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.yarn/bin:$PATH"' >> "$HOME/.bashrc"
fi
if [ -f "$HOME/.profile" ]; then
    echo 'export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.yarn/bin:$PATH"' >> "$HOME/.profile"
fi

NETWORK=""
while [ -z "$NETWORK" ]; do
    echo "Which network do you want to run?"
    echo "  1) mainnet"
    echo "  2) devnet"
    echo "  3) testnet"
    echo ""

    read -p "Enter option: " OPTION
    if [[ "$OPTION" != "1" && "$OPTION" != "2" && "$OPTION" != "3" ]]; then
        echo "Invalid option"
        echo ""
    else
        case $OPTION in
            "1")
                NETWORK="mainnet"
            ;;
            "2")
                NETWORK="devnet"
            ;;
            "3")
                NETWORK="testnet"
            ;;
        esac
    fi
done

if [ "$NETWORK" == "mainnet" ]; then
    cp "$HOME/.bridgechain/mainnet/ark/delegates.json" "$HOME/.config/ark-core/mainnet/"
elif [ "$NETWORK" == "devnet" ]; then
    cp "$HOME/.bridgechain/devnet/ark/delegates.json" "$HOME/.config/ark-core/devnet/"
fi

cat > "$HOME/startup.sh" <<- EOF
#!/bin/bash -l
$HOME/ark-deployer/bridgechain.sh start-core --network "$NETWORK" &>> $HOME/core.log &
$HOME/ark-deployer/bridgechain.sh start-explorer --network "$NETWORK" &>> $HOME/explorer.log &
EOF
chmod u+x "$HOME/startup.sh"

echo '@reboot sleep 15; env USER=$LOGNAME $HOME/startup.sh' >> "$HOME/cron.sh"
crontab "$HOME/cron.sh"
rm "$HOME/cron.sh"

$HOME/ark-deployer/bridgechain.sh passphrases

API_PORT=$(jq -r '.apiPort' "$CONFIG_PATH")
P2P_PORT=$(jq -r '.p2pPort' "$CONFIG_PATH")
EXPLORER_PORT=$(jq -r '.explorerPort' "$CONFIG_PATH")

IP=$($HOME/ark-deployer/bridgechain.sh get-ip)

echo 'Rebooting Machine - check back in a few minutes on the below:'
echo "  Core P2P API: http://$IP:$P2P_PORT/"
echo "  Core Public API: http://$IP:$API_PORT/"
echo "  Explorer: http://$IP:$EXPLORER_PORT/"
sudo reboot
