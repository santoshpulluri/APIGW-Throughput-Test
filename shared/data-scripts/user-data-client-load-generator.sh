#!/bin/bash

# 1. Set environment variables for the script session
export HELLO_URL="http://43.205.107.26:8443/hello"
export HELLOBELLO_URL="http://43.205.107.26:8443/hellobello"
export RESPONSE_URL="http://65.2.32.238:6060/response"
#export GO_VERSION="1.25" # Using a valid current version

# 2. Install Go
wget "https://go.dev/dl/go1.25.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz

# 3. Manually set PATH for this execution (Don't rely on .profile)
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/root/go
export PATH=$PATH:$GOPATH/bin

# 4. Install hey
go install github.com/rakyll/hey@latest

# 5. Create the benchmark script (Since it's missing from your snippet)
cat <<EOF > /tmp/benchmark_apigw.sh
#!/bin/bash
echo "Starting Benchmark..."
hey -n 1000 -c 50 \$HELLO_URL
hey -n 1000 -c 50 \$RESPONSE_URL
EOF

# 6. Set permissions and run
chmod +x /tmp/benchmark_apigw.sh
/tmp/benchmark_apigw.sh > /var/log/benchmark.log 2>&1