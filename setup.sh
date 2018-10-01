# @title the Script for Install Lnd + Bitcoin Full Node on Lightweight Client
# @author QuantumCat
# @dev 1. This script is designed for Debian / Ubantu / Mint / Raspbian. 
#         For Raspbian, use the dphys-swapfile method. For RedHat series, please manually 
#         check it or wait for our update.
#      2. c-lightning and other lightning client may be supported in the future update.
#      3. This require one drive with more than 500 GB (1 TB recommended) connected. Assume the 
#         user will not assign more than one drive.
#      4. The default versions installed are bitcoin core 0.16.3 and lnd 0.5-beta


#!/bin/bash

# use red to return failure or warning
function echo_red() {
    echo -e "\033[31m$1 \033[0m"
}

# use yellow to return choice
function echo_yellow() {
    echo -e "\033[33m$1 \033[0m"
}

# use green to return success
function echo_green() {
    echo -e "\033[32m$1 \033[0m"
}

# use sky blue to return process
function echo_blue() {
    echo -e "\033[36m$1 \033[0m"
}

# @dev the most easy way, but rely on https://ipinfo.io
# using curl to read the data from ipinfo.io to get local external IP
public_ip=$( curl ipinfo.io/ip )
router_address=$( ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}' )
btc_version=0.16.3
lnd_version=0.5-beta
OS_NAME=$( cat /etc/os-release | grep ^NAME | cut -d'"' -f2 )


function user_input {
    echo_yellow "Please input the RPC username and password for bitcoin core and Lnd..."
    read -p "Input username: " rpc_user
    read -s -p "Input password: (will not be shown) " rpc_passwd
    echo_blue "You need an lightning alias name to show on the network." 
    read -p "Input your LND node alias name: " lnd_alias
    echo_yellow "Please connect your hard drive to the device..."
    read -p "After connected, press any key to continue." temp_process
}


# prepare the necessary packages for the system
function prepare_required_package {
    echo_blue "Installing the required packages ..."
    sudo apt-get install -y autoconf automake build-essential git
    sudo apt-get install -y libtool libevent-dev 
    sudo apt-get install -y libgmp-dev libsqlite3-dev libssl-dev libzmq3-dev
    sudo apt-get install -y libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev 
    sudo apt-get install -y libboost-system-dev libboost-test-dev libboost-thread-dev  
    sudo apt-get install -y pkg-config python python3 python-pip python3-pip net-tools # pip for API @ python
    sudo apt-get install -y tmux    # for multi-test
    echo_green ">>>>>>>>>>>>>>>>>>>> Required packages installed!"
}

# config for ufw and fail2ban
function security {
    echo_blue "preparing basic security configuration..."
    sudo apt-get install ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow from "$router_address" to any port 22 comment 'allow SSH from local LAN'
    # sudo ufw allow from 192.168.1.0/24 to any port 50002 comment 'allow Electrum from local LAN'
    sudo ufw allow 9735 comment 'allow Lightning'
    sudo ufw allow 8333 comment 'allow Bitcoin mainnet'
    sudo ufw allow 18333 comment 'allow Bitcoin testnet'
    sudo ufw enable
    sudo systemctl enable ufw  # auto-run when boot
    sudo ufw status
    sudo apt-get install fail2ban
    echo_green ">>>>>>>>>>>>>>>>>>>> security configurated!"
}

# detecting if hdd is connecting
function hdd_detect {
    echo_blue "We are going to detect the hard drives..."
    echo_blue "Here is the details of attached drives:"
    lsblk -o UUID,NAME,FSTYPE,SIZE,LABEL,MODEL
    echo_yellow "Do you find one unmounted hdd with size > 500 GB?"
    read -p "Press any key to continue, or Ctrl+C to quit." temp_process

    # @dev If there are more than one drives with the size greater than 500 GB, it will return error
    hdd_name=$(lsblk -dlnb | awk '$4>500000000000' | awk '{print $1}')
    # In the lsblk list, -d (no sub holder), -n (no title), -b (present in byte)
    # print the lines whose 4th column > 500 GB, print the first blank (sda or xdva).
    hdd_path=/dev/$hdd_name

    echo_yellow "$hdd_name will be formatted."
    read -p "Press any key to continue, or Ctrl+C to quit." temp_process
}

# mount the hdd to /mnt/hdd
function hdd_mount {
    echo_blue "Formatting hard disk to ext4..."
    sudo mkfs.ext4 $hdd_path
    echo_green ">>>>>>>>>>>>>>>>>>>> Hard disk formatted!"

    # @dev sudo is required to read UUID from blkid
    UUID=$(sudo blkid -o value -s UUID $hdd_path)
    
    echo_blue "mount the hdd to /mnt/hdd ..."
    sudo mkdir /mnt/hhd
    # write the UUID information in /etc/fstab so as to configure it after re-start
    sudo echo "UUID=$UUID /mnt/hdd ext4 noexec,defaults 0 0" >> /etc/fstab
    
    if mount | grep "$hdd_path" > /dev/null;then
        :
    else
        sudo mount -a
    fi
    df /mnt/hdd
    echo_yellow "Do you see the mounting information for $hdd_path ?"
    read -p "Press any key to continue, or Ctrl+C to quit." temp_process

    sudo chmod -R 777 /mnt/hdd
    echo_green ">>>>>>>>>>>>>>>>>>>> Hard disk mounted!"
}

# config for swap on hdd 
# dphys-swapfile is for Raspbian
function swap_conf {
    echo_blue "Configuring the swap file on hdd..."
    swap_path=/mnt/hdd/swapfile

    # the swap configuration depends on different OS
    case "${OS_NAME}" in
		"Raspbian GNU/Linux")
            sudo apt-get install dphys-swapfile
            sudo dphys-swapfile swapoff
            sudo dphys-swapfile uninstall
            sudo sed -i".bak" "/CONF_SWAPFILE/d" /etc/dphys-swapfile
            sudo sed -i".bak" "/CONF_SWAPSIZE/d" /etc/dphys-swapfile
            echo "CONF_SWAPFILE=$swap_path" >> /etc/dphys-swapfile
            sudo dd if=/dev/zero of=$swap_path count=2048 bs=1M
            chmod 600 $swap_path
            sudo mkswap $swap_path
            sudo dphys-swapfile setup
            sudo dphys-swapfile swapon
		;;
		"Ubuntu" | "Linux Mint" | "Debian")
            sudo dd if=/dev/zero of=$swap_path count=2048 bs=1M
            sudo mkswap $swap_path
            chmod 600 $swap_path
            sudo swapon $swap_path
            sudo echo "$swap_path swap swap defaults 0 0" >> /etc/fstab
		;;
		*)
            echo_red "Operation system currently not support by this script."
            exit 1
		;;
	esac    
    
    echo_green ">>>>>>>>>>>>>>>>>>>> Swap file is created!"
}


# install bitcoin core
function install_bitcoin_core {
    echo_blue "Installing Bitcoin Core..."
    btc_verson=0.16.3
    rm -rf ~/bitcoin
    wget https://bitcoincore.org/bin/bitcoin-core-$btc_version/bitcoin-$btc_version-arm-linux-gnueabihf.tar.gz
    tar -xvf bitcoin-$btc_version-arm-linux-gnueabihf.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$btc_version/bin/*
}

# edit the file bitcoin.conf
function edit_bitcoin_conf {
    # For more about bitcoin core rpc API, please read the API document:
    # https://en.bitcoin.it/wiki/Running_Bitcoin#Command-line_arguments

    echo_blue "preparing the bicoin.conf file..."
    # mount ~/.bitcoin to hdd
    cd /mnt/hdd
    mkdir bitcoin
    cd ~
    ln -s /mnt/hdd/bitcoin ~/.bitcoin 
    cp ~/lightningbot/bitcoin.conf ~/.bitcoin/

    read -p "Are you going to run the mainnet? (y/n)" mainnet
    case $mainnet in
        [Yy]* ) echo "Run mainnet.";;
        [Nn]* ) echo "testnet=1" >> ~/.bitcoin/bitcoin.conf;;
            * ) echo "Please answer yes or no. (y/n)";;
    esac

    sudo sed -i".bak" "/rpcuser/d" /mnt/hdd/bitcoin/bitcoin.conf
    sudo sed -i".bak" "/rpcpassword/d" /mnt/hdd/bitcoin/bitcoin.conf
    echo "rpcuser=$rpc_user" >> ~/.bitcoin/bitcoin.conf
    echo "rpcpassword=$rpc_passwd" >> ~/.bitcoin/bitcoin.conf
    
    echo_green ">>>>>>>>>>>>>>>>>>>> bitcoin.conf is prepared!"
}

# install the lnd client
function install_lnd {
    lnd_version=0.5-beta
    echo_blue "Installing LND $lnd_version"
    cd ~
    mkdir -p download
    cd download
    wget "https://github.com/lightningnetwork/lnd/releases/download/v$lnd_version/lnd-linux-arm64-v$lnd_version.tar.gz"
    tar -xzf "lnd-linux-arm64-v$lnd_version.tar.gz"
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-arm64-v$lnd_version/*
    echo_green  ">>>>>>>>>>>>>>>>>>>> Lnd is installed!"
}

# edit the lnd.conf
function edit_lnd_conf {
    # For more about Lnd rpc API, please read the API document:
    # https://en.bitcoin.it/wiki/Running_Bitcoin#Command-line_arguments
    echo_blue "preparing the lnd.conf file..."
    # mount ~/.lnd to hdd
    cd /mnt/hdd
    mkdir lnd
    cd ~
    ln -s /mnt/hdd/lnd ~/.lnd
    cp ~/lightningbot/lnd.conf ~/.lnd/

    echo "alias=$lnd_alias" >> ~/.lnd/lnd.conf
    case $miannet in
        [Yy]* ) echo "bitcoin.mainnet=1" >> ~/.lnd/lnd.conf;;
        [Nn]* ) echo "bitcoin.testnet=1" >> ~/.lnd/lnd.conf;;
            * ) echo "Please answer yes or no. (y/n)";;
    esac

    read -p "Do you want autopilot? (y/n)" yn
    case $mainnet in
        [Yy]* ) echo "autopilot.active=1" >> ~/.lnd/lnd.conf;;
        [Nn]* ) echo "autopilot.active=0" >> ~/.lnd/lnd.conf;;
            * ) echo "Please answer yes or no. (y/n)";;
    esac
    
    echo_green ">>>>>>>>>>>>>>>>>>>> lnd.conf file is prepared!"
}

function auto_run {
    echo_blue "preparing for auto start units..."
    cd ~
    sudo cp ~/lightningbot/bitcoind.service /etc/systemd/system/
    sudo systemctl enable bitcoind.service
    sudo systemctl start bitcoind.service
    
    # use the API of ipinfo.io
    sudo cp ~/lightningbot/getpublicip.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/getpublicip.sh
    sudo cp ~/lightningbot/getpublicip.service /etc/systemd/system/
    sudo getpublicip.sh
    sudo systemctl enable getpublicip
    sudo systemctl start getpublicip
    sleep 1m
    echo_green "The public IP is:"
    cat /run/publicip

    sudo cp ~/lightningbot/lnd.service /etc/systemd/system/
    sudo systemctl enable lnd.service
    sudo systemctl start lnd.service

    echo_green ">>>>>>>>>>>>>>>>>>>> auto start setting have been completed."
}

# @dev the main program start here
# ************************************** MAIN PROGRAM ************************************ 

# Check if script is launched with sudo
# for root, id -u will return 0
if [ "$(id -u)" -ne 0 ]; then
    echo_red "Please run this script with sudo"
    exit 1
fi

echo_blue "This script is going to install bitcoin core $btc_version and lnd $lnd_version."
echo_blue "The configuration will be completed during the process."
echo_red "Please KEEP an off-line record of the username, password and secret key."
echo_red "Please KEEP an off-line record of the username, password and secret key."
echo_red "Please KEEP an off-line record of the username, password and secret key."
echo_red "If you loss your secret key, you loss the control of your bitcoin wallet"
echo_red "and NO ONE CAN RECOVER THAT!"
echo " "
echo_blue "***************************** Disclaimer ***********************************"
echo_red "* This script may contain errors that may result in loss of user's bitcoin."
echo_red "* Users should read the script and verify it."
echo_red "* It would be good to run testnet and check the command line by line."
echo_red "* The integration of bitcoin core and lnd should be verify by users."
echo_red "* REMENBER: Bitcoin is still experimental."
echo_red "* Lightning network is more experimental."
echo_blue "****************************************************************************"
echo " "
echo_yellow "Do you understand the above statement?"
read -p "(yes/no)" yn
    case $yn in
        [yes]* ) echo "You understand the above statement.";;
        [no]* ) echo "Stop install."; exit 1;;
            * ) echo "Please answer yes or no. (yes/no)";;
    esac
read -p "Press any key to continue or Ctrl+C to stop" temp_process

sudo chmod +x update-linux.sh
sudo ./update-linux.sh
user_input
prepare_required_package
security
hdd_detect
hdd_mount
swap_conf

install_bitcoin_core
edit_bitcoin_conf
install_lnd
edit_lnd_conf

auto_run

echo "If you run the mainnet directly, it is recommended that sync the full block at first at your local PC."
echo "If you run the testnet at first, when switching to mainnet, run:"
echo_blue "sudo ./mainnet.sh"
echo "Then run:"
echo_blue "scp -r {block_path}\blocks username@raspberry_ip:/mnt/hdd/bitcoin/"
echo_blue "scp -r {block_path}\chainstate username@raspberry_ip:/mnt/hdd/bitcoin/"
echo "or use WinScp"

echo_yellow "Plese RESTART after the set up your node, and wait for syncing."

