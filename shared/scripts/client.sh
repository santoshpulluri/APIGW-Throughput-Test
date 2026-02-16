#!/bin/bash

set -e

CONFIGDIR=/ops/shared/config
#CONSULVERSION=1.21.0
#ENVOYVERSION=1.33.2
#CONSULVERSION=1.18.2
#ENVOYVERSION=1.27.7
#CONSULVERSION=1.15.3
#ENVOYVERSION=1.29.12
CONSULVERSION=1.22.2
ENVOYVERSION=1.35.3

CONSULCONFIGDIR=/etc/consul.d
HOME_DIR=ubuntu

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`)
CLOUD=$1
RETRY_JOIN=$2

# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

sudo apt-get install -y software-properties-common
sudo add-apt-repository universe && sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean

# Install HashiCorp Apt Repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install HashiStack Packages
# sudo apt-get update && sudo apt-get -y install \
	# consul=$CONSULVERSION* \
	# nomad=$NOMADVERSION* \
	# vault=$VAULTVERSION* \
	# consul-template=$CONSULTEMPLATEVERSION*

echo "Installing consul and envoy"
# Install Consul only
sudo apt-get update && sudo apt-get -y install consul-enterprise=$CONSULVERSION* hashicorp-envoy=$ENVOYVERSION*

echo "Setup consul config"
# Consul
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/consul_client.hcl
sudo cp $CONFIGDIR/consul_client.hcl $CONSULCONFIGDIR/consul.hcl

sudo cp $CONFIGDIR/acl_client.hcl $CONSULCONFIGDIR/acl.hcl

# install license file
sudo tee $CONSULCONFIGDIR/license.hclic <<EOF
02MV4UU43BK5HGYYTOJZWFQMTMNNEWU33JLJCFS6CNKRKXOTT2NN2E4V2JGJGUGMDZJUZFU3KMKRETCTSHJV2FSVCJPFHEIWJQJ5CESNKONJTXUSLJO5UVSM2WPJSEOOLULJMEUZTBK5IWST3JJJUVSMSKNRNGURJTJ5JTC3C2IRHGWTCUIJUFURCFORHHU2ZSJZUTC2COI5KTEWTKJF4U42SBPBNFIVLJJRBUU4DCNZHDAWKXPBZVSWCSOBRDENLGMFLVC2KPNFEXCSLJO5UWCWCOPJSFOVTGMRDWY5C2KNETMSLKJF3U22SZORGUIRLUJVCEMVKNKRGTMTLKJE3E2RDDOVHVIQLYJZCFKNKOPJITGV3JJFZUS3SOGBMVQSRQLAZVE4DCK5KWST3JJF4U2RCJGJGFIQLYJRKEC6CWIRAXOT3KIF3U62SBO5LWSSLTJFWVMNDDI5WHSWKYKJYGEMRVMZSEO3DULJJUSNSJNJEXOTLKM52E2VCJORGXURSVJVCECNSNIRATMTKEIJQUS2LXNFSEOVTZMJLWY5KZLBJHAYRSGVTGIR3MORNFGSJWJFVES52NNJTXITKUJF2E26SGKVGUIQJWJVCECNSNIRBGCSLJO5UWGSCKOZNEQVTKMRBUSNSJNVHHMYTOJYYWEQ2JONEW2WTTLFLWI6SJNJYDOSLNGF3FUSCWONNFQTLJJ5WHG2K2GI4TEWSYJJ2VSVZVNJNFGMLXMIZHQ4CZGNVWSTCDJJXGERZZNFMVO53UMRWWY6TBK5FHAYSHNQYGKUZRPFRDGVRQMFLTK3SMLBHGUWKXPBWES3BRHFTFCPJ5FZ2E45RWKZYHOOKFJVJUITSSMJWUI5ZTJZ2VE3DJNVEDI2KGOMZE65KSLF3DCRL2GZEFAYLTKRIXI2RPJY2UON3EORDUWVLFORKDQN3QIZXWEK3XOY3DG4TKONTTOODFK5IDQOLYIFYDCZCBNNRWCNDEKYYDGMZYKB3W2VTMMF3EUUBUOBFHQSKJHFCDMVKGJRKWCVSQNJVVOSTUMNCDM4DBNQ3G6T3GI5XEWMT2KBFUUUTNI5EFMM3FLJ3XCRTFFNXTO2ZPOMVUCVCONBIFUZ2TF5FVMWLHF5FSW3CHKB3UYN3KIJ4ESN2HJ5QWWNSVMFUWCSDPMVVTAUSUN43TERCRHU6Q
EOF
sudo chmod a+r $CONSULCONFIGDIR/license.hclic

sudo systemctl enable consul.service&& sleep 1
sudo systemctl start consul.service && sleep 10

echo "installing fake_service"
# installing the nikolasjakson fake service
curl -LO "https://github.com/nicholasjackson/fake-service/releases/download/v0.26.2/fake_service_linux_amd64.zip"
unzip fake_service_linux_amd64.zip
sudo mv fake-service /usr/local/bin/fake_service
sudo chmod a+x /usr/local/bin/fake_service
