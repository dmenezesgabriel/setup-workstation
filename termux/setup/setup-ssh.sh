# https://joeprevite.com/ssh-termux-from-computer/
echo "Update repositories"
pkg update -y && pkg upgrade -y
echo "install openssh"
pkg install openssh
echo "Setup password with passwd"
echo "Find your username with whoami"
echo "Find the host by running ipconfig"
echo "Use sshd to start tha ssh server"
echo "ssh <username>@<host> -p8022"
