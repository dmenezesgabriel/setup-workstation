## Kind K8s on Crostini VM

- Get system info:

```sh
cat /etc/os-release
```

Output:

```sh
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
NAME="Debian GNU/Linux"
VERSION_ID="12"
VERSION="12 (bookworm)"
VERSION_CODENAME=bookworm
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

- Install Kind

```sh
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

- Create Keyring dir

```sh
sudo mkdir -p -m 755 /etc/apt/keyrings
```

- Add kubectl repository

```sh
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

- Install kubectl

```sh
sudo apt-get update
sudo apt-get install -y kubectl
```

- Create a Kind cluster

```sh
kind create cluster --config cluster.yaml --image kindest/node:v1.27.3
```

- Verify cluster

```sh
kubectl cluster-info --context kind-kind
```

## References

- https://github.com/kubernetes-sigs/kind/issues/763#issuecomment-1859162319