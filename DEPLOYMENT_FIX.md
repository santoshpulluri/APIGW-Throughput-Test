# Consul Service Registration Fix

## Problem Identified
Your Consul setup was configured to use Enterprise partitions (AP1 and AP2), but:
1. The partition-specific client config files were missing (`consul_client_ap1.hcl`, `consul_client_ap2.hcl`)
2. The partitions were never created on the Consul server
3. Services couldn't register because the partitions didn't exist

## What Was Fixed

### 1. Created Partition Client Configurations
- **Created**: `shared/config/consul_client_ap1.hcl` for hello-service and apigw-service
- **Created**: `shared/config/consul_client_ap2.hcl` for response-service

### 2. Updated Server Bootstrap Script
- Modified `shared/data-scripts/user-data-server.sh` to:
  - Wait for Consul to be fully ready
  - Create partition AP1
  - Create partition AP2
  - Handle errors gracefully if partitions already exist

### 3. Enhanced Outputs
- Added debugging commands to `outputs.tf` for easier troubleshooting

## How to Redeploy

### Option 1: Full Redeployment (Recommended)
```bash
# Destroy the current infrastructure
terraform destroy -auto-approve

# Reapply with fixes
terraform apply -auto-approve
```

### Option 2: Manual Fix on Running Infrastructure
If you prefer not to destroy everything:

#### Step 1: SSH to Consul Server
```bash
ssh -i "minion-key.pem" ubuntu@<CONSUL_PUBLIC_IP>
```

#### Step 2: Create Partitions Manually
```bash
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
consul partition create -name AP1 -description "Application Partition 1"
consul partition create -name AP2 -description "Application Partition 2"

# Verify partitions were created
consul partition list
```

#### Step 3: Fix Client Configurations
For each hello-service instance:
```bash
ssh -i "minion-key.pem" ubuntu@<HELLO_SERVICE_IP>

# Create the partition config
sudo tee /etc/consul.d/consul.hcl <<EOF
ui = true
log_level = "TRACE"
data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
retry_join = ["<CONSUL_PRIVATE_IP>"]
partition = "AP1"
license_path = "/etc/consul.d/license.hclic"
ports {
  grpc = 8502
}
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}
EOF

# Restart Consul
sudo systemctl restart consul

# Wait a bit
sleep 10

# Re-register the service
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
cd /ops/shared/config
consul services register -partition=AP1 hello-service.json
consul services register -partition=AP1 hello-service-proxy.hcl
```

For each response-service instance (similar process with partition AP2):
```bash
ssh -i "minion-key.pem" ubuntu@<RESPONSE_SERVICE_IP>

# Create the partition config
sudo tee /etc/consul.d/consul.hcl <<EOF
ui = true
log_level = "TRACE"
data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
retry_join = ["<CONSUL_PRIVATE_IP>"]
partition = "AP2"
license_path = "/etc/consul.d/license.hclic"
ports {
  grpc = 8502
}
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}
EOF

# Restart Consul
sudo systemctl restart consul

# Wait a bit
sleep 10

# Re-register the service
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
cd /ops/shared/config
consul services register -partition=AP2 response-service.json
consul services register -partition=AP2 response-service-proxy.hcl
```

## Verification

### 1. Check Partitions Exist
```bash
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
consul partition list
```

Expected output:
```
default
AP1
AP2
```

### 2. Check Services in Each Partition
```bash
# Check AP1 services (should show service-hello)
consul catalog services -partition=AP1

# Check AP2 services (should show service-response)
consul catalog services -partition=AP2
```

### 3. Check Consul UI
Navigate to: `http://<CONSUL_PUBLIC_IP>:8500`
- Use token: `e95b599e-166e-7d80-08ad-aee76e7ddf19`
- You should see partitions in the UI dropdown
- Services should appear under their respective partitions

### 4. Check Service Logs
On any service instance:
```bash
# Check if service started
tail -100 /var/log/user-data.log

# Check application logs
tail -100 /var/log/fake_service.log

# Check Envoy proxy logs
tail -100 /var/log/envoy.log

# Check Consul agent logs
sudo journalctl -u consul -n 100
```

## Common Issues

### Services Still Not Showing
1. Check if partitions exist: `consul partition list`
2. Check Consul agent is connected to the right partition: `consul members`
3. Check service registration errors in logs: `tail /var/log/user-data.log`

### Permission Denied Errors
Make sure you're setting the token:
```bash
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
```

### Consul Agent Not Starting
Check logs:
```bash
sudo journalctl -u consul -f
```

Common issue: partition files not found or incorrect configuration.

## Next Steps
After services are registered:
1. Test API Gateway: `curl http://<APIGW_IP>:8443/hello`
2. Check service mesh connectivity
3. Verify Envoy proxies are running: `curl http://<SERVICE_IP>:19000/ready`
