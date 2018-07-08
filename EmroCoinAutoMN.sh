#/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
BLUE='\033[01;34m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
ORANGE='\033[01;33m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
MAX=9

COINGITHUB=https://github.com/EmroCoin/emro/releases/download/emro/EMROd-MN.zip
SENTINELGITHUB=NOSENTINEL
COINSRCDIR=EmroSRC
# P2Pport and RPCport can be found in chainparams.cpp -> CMainParams()
COINPORT=10060
COINRPCPORT=
COINDAEMON=EMROd
# COINCORE can be found in util.cpp -> GetDefaultDataDir()
COINCORE=.Emro
COINCONFIG=Emro.conf
key=""

checkForUbuntuVersion() {
   echo "[1/${MAX}] Checking Ubuntu version..."
    if [[ `cat /etc/issue.net`  == *16.04* ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running Ubuntu 16.04.X. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

updateAndUpgrade() {
    echo
    echo "[2/${MAX}] Runing update and upgrade. Please wait..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -y > /dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
    echo -e "${GREEN}* Completed${NONE}";
}

setupSwap() {
    echo -e "${BOLD}"
    read -e -p "Add swap space? (To setup Swapfile, choose Y.) [Y/n] :" add_swap
    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        swap_size="3G"
    else
        echo -e "${NONE}[3/${MAX}] Swap space not created."
    fi

    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        echo && echo -e "${NONE}[3/${MAX}] Adding swap space...${YELLOW}"
        sudo fallocate -l $swap_size /swapfile
        sleep 2
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo -e "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    fi
}

installFail2Ban() {
    echo -e "${BOLD}"
    read -e -p "Install Fail2Ban? (This is just a safety program, optional.) [Y/n] :" install_F2B
    if [[ ("$install_F2B" == "y" || "$install_F2B" == "Y" || "$install_F2B" == "") ]]; then
        echo -e "[4/${MAX}] Installing fail2ban. Please wait..."
        sudo apt-get -y install fail2ban > /dev/null 2>&1
        sudo systemctl enable fail2ban > /dev/null 2>&1
        sudo systemctl start fail2ban > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    else
        echo -e "${NONE}[4/${MAX}] Fail2Ban not installed."
    fi
}

installFirewall() {
    echo -e "${BOLD}"
    read -e -p "Install Firewall? (This is just for safety, optional.) [Y/n] :" install_FW
    if [[ ("$install_FW" == "y" || "$install_FW" == "Y" || "$install_FW" == "") ]]; then
        echo -e "[5/${MAX}] Installing UFW. Please wait..."
        sudo apt-get -y install ufw > /dev/null 2>&1
        sudo ufw default deny incoming > /dev/null 2>&1
        sudo ufw default allow outgoing > /dev/null 2>&1
        sudo ufw allow ssh > /dev/null 2>&1
        sudo ufw limit ssh/tcp > /dev/null 2>&1
        sudo ufw allow $COINPORT/tcp > /dev/null 2>&1
        sudo ufw logging on > /dev/null 2>&1
        echo "y" | sudo ufw enable > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    else
        echo -e "${NONE}[5/${MAX}] Firewall not installed."
    fi
}

installDependencies() {
    echo
    echo -e "[6/${MAX}] Installing dependecies. Please wait..."
    sudo apt-get install git nano unzip rpl wget python-virtualenv -qq -y > /dev/null 2>&1
    sudo apt-get install build-essential libtool automake autoconf -qq -y > /dev/null 2>&1
    sudo apt-get install autotools-dev autoconf pkg-config libssl-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libgmp3-dev libevent-dev bsdmainutils libboost-all-dev -qq -y > /dev/null 2>&1
    sudo apt-get install software-properties-common python-software-properties -qq -y > /dev/null 2>&1
    sudo add-apt-repository ppa:bitcoin/bitcoin -y > /dev/null 2>&1
    sudo apt-get update -qq -y > /dev/null 2>&1
    sudo apt-get install libdb4.8-dev libdb4.8++-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libminiupnpc-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libzmq5 -qq -y > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}

installWallet() {
    echo
    echo -e "[7/${MAX}] Installing wallet. Please wait..."
	sudo mkdir -p /root/$COINSRCDIR
	cd /root/$COINSRCDIR
	sudo wget $COINGITHUB
	sudo unzip -o EMROd-MN.zip
	sudo cp EMROd /usr/local/bin/
	sudo chmod 754 /usr/local/bin/EMROd
	cd
	echo -e "${NONE}${GREEN}* Completed${NONE}";
}

configureWallet() {
    echo
    echo -e "[8/${MAX}] Configuring wallet. Please wait..."
    sudo mkdir -p /root/$COINCORE
    sudo touch /root/$COINCORE/$COINCONFIG
    sleep 10

    mnip=$(curl --silent ipinfo.io/ip)
    rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rpcpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    mnkey=$key

    sleep 10

    echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcallowip=127.0.0.1\nlisten=1\nserver=1\ndaemon=1\nstaking=0\nport=${COINPORT}\nmaxconnections=64\nexternalip=${mnip}:${COINPORT}\nmasternodeaddr=${mnip}:${COINPORT}\nmasternode=1\nmasternodeprivkey=${mnkey}" > /root/$COINCORE/$COINCONFIG
    sudo cat /root/$COINSRCDIR/nodes.txt >> /root/.Emro/Emro.conf
	echo -e "${NONE}${GREEN}* Completed${NONE}";
}


startWallet() {
    echo
    echo -e "[9/${MAX}] Starting wallet daemon..."
    sudo $COINDAEMON > /dev/null 2>&1
    sleep 5
    echo -e "${GREEN}* Completed${NONE}";
}

clear
cd

echo
echo -e "${ORANGE}           MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM           ${NONE}"
echo -e "${ORANGE}       MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM       ${NONE}"
echo -e "${ORANGE}    MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM    ${NONE}"
echo -e "${ORANGE}  MMMMMMMMMMM                                                      MMMMMMMMMMM  ${NONE}"
echo -e "${ORANGE} MMMMMMMMMM                                                          MMMMMMMMMM ${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMM                                                      MMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMM                                                      MMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMM                                                      MMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMMMM                                                      MMMMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE}MMMMMMMMMMM                                                          MMMMMMMMMMM${NONE}"
echo -e "${ORANGE} MMMMMMMMMM                                                          MMMMMMMMMM ${NONE}"
echo -e "${ORANGE}  MMMMMMMMMMM                                                      MMMMMMMMMMM  ${NONE}"
echo -e "${ORANGE}    MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM    ${NONE}"
echo -e "${ORANGE}       MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM       ${NONE}"
echo -e "${ORANGE}           MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM           ${NONE}"


echo -e "${BOLD}"
read -p "This script will setup your Emro Coin Masternode. Do you wish to continue? (y/n)?" response
echo -e "${NONE}"

if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h) : " key
    if [[ "$key" == "" ]]; then
        echo "WARNING: No private key entered, exiting!!!"
        echo && exit
    fi
    checkForUbuntuVersion
    updateAndUpgrade
    setupSwap
    installFail2Ban
    installFirewall
    installDependencies
    installWallet
    configureWallet
    startWallet
    echo
    echo -e "${BOLD}The VPS side of your masternode has been installed. You can start your Masternode on your Cold wallet.${NONE}"
    echo
    echo -e "${BOLD}Thank you for your support of Emro Coin.${NONE}"
    echo
else
    echo && echo "Installation cancelled" && echo
fi
