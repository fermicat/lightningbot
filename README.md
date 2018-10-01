# lightningbot

## Basic set up
make sure you install the Linux system into Raspberry Pi or other portable hardware.
make sure you connect a drive at least 500 GB (1 TB recommended) to the Raspberry Pi

```
git clone https://github.com/quantumcatwang/lightningbot.git
sudo ./update-linux.sh
```

Wait until the block complete syncing.

Use the lnd API for creating wallet. Input the RPC username, RPC password, write down your private seed, and the latest version of bitcoin core & lnd is recommended.

For API of lnd: https://api.lightning.community/

## Switch to mainnet
 Disclaimer 
 ```
 This script may contain errors that may result in loss of user's bitcoin.
 Users should read the script and verify it.
 It would be good to run testnet and check the command line by line.
 The integration of bitcoin core and lnd should be verify by users.
 REMENBER: Bitcoin is still experimental.
 Lightning network is more experimental.
 ```



It is recommended that sync the full block at first at your local PC.
If you run the testnet at first, when switching to mainnet, run: (If you run the mainnet directly, skip it)
```
sudo ./mainnet.sh
```
After restart, run
```
scp -r {block_path}\blocks username@raspberry_ip:/mnt/hdd/bitcoin/
scp -r {block_path}\chainstate username@raspberry_ip:/mnt/hdd/bitcoin/
```
or use WinScp


