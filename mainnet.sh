# @dev change from testnet to mainnet
#!/bin/bash

sudo systemctl stop lnd
sudo systemctl stop bitcoind
# edit the .conf files
sudo sed -i".bak" "/testnet/d" /mnt/hdd/bitcoin/bitcoin.conf
sudo sed -i".bak" "/bitcoin.testnet/d" /mnt/hdd/lnd/lnd.conf
echo "bitcoin.mainnet=1" >> /mnt/hdd/lnd/lnd.conf

sudo shutdown -r +1 'The system will be restarted in 1 minutes.' 