
# Part 3: Consul Integration

The setup is composed of:
`api-gw->service-hello` -> 
`service-hello-proxy` -> 
`service-response-proxy` ->
`service-response`

**Run following command**
```bash
cd ./3-consul-service-mesh-simple

terraform init
terraform apply -var-file=variables.hcl
```

Copy the env section from terraform output and execute in terminal
```bash
# Sample only
export SSH_HELLO_SERVICE="ssh -i "minion-key.pem" ubuntu@<54.152.176.160>"
export SSH_RESPONSE_SERVICE_0="ssh -i "minion-key.pem" ubuntu@44.212.58.112"
export SSH_RESPONSE_SERVICE_1="ssh -i "minion-key.pem" ubuntu@3.86.29.88"

export HELLO_SERVICE=54.152.176.160
export RESPONSE_SERVICE_0=44.212.58.112
export RESPONSE_SERVICE_1=3.86.29.88
```

