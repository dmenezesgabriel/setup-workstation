# Wait enough (forever) until a long-time boot
set timeout -1

spawn curl -v -L -o ~/alpine/alpine.iso -C - $env(ALPINE_ISO_URL)
expect "left intact"

spawn rm -f ~/.ssh/qemukey ~/.ssh/qemukey.pub
sleep 5
spawn ssh-keygen -b 2048 -t rsa -N "" -f ~/.ssh/qemukey

expect "\[SHA256\]"

set qemukey [exec cat ~/.ssh/qemukey.pub]
set answerfile [exec cat ./answerfile.sh]

send "echo '$env(~/.ssh/qemukey.pub)'"

#
# install the system
#

# spawn rm -f alpine.img
# spawn qemu-img create -f qcow2 alpine.img $env(DISK_SIZE)

# sleep 5
# spawn qemu-system-x86_64 -m 512 -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1  -cdrom ~/alpine/alpine.iso -nographic alpine.qcow2

# set qemuID $spawn_id

# expect "login:"
# send "root\r"
