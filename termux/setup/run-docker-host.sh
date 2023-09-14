while ! ssh -p 2222 -q -i ~/.ssh/qemukey -o ConnectTimeout=10 \
      root@localhost exit; do
    echo "VM is not ready yet, waiting..."
    sleep 10
done

ssh -p 2222 -i ~/.ssh/qemukey root@localhost service docker stop

sleep 3

ssh -p 2222 -i ~/.ssh/qemukey root@localhost dockerd -H tcp://0.0.0.0:2375 --iptables=false
