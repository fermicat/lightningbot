sudo apt-get update
sudo apt-get -y dist-upgrade
sudo apt-get -y upgrade
sudo apt-get -y autoremove
echo "\033[32m >>>>>>>>>>>>>>>>>>>> system and apps Updated to the latest version!\033[0m"

if [ -f /var/run/reboot-required ]; then
    sudo shutdown -r +1 'The system will be restarted after 1 minutes, please re-run this script.' 
fi
