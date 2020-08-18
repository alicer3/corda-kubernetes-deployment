#!/bin/bash

######################## NODE VARIBLES START ########################
PREFIX="node-5"
X500NAME="O=Node5,L=London,C=GB"
APIVERSION="2"
######################## NODE VARIBLES END ########################

######################## ENV VARIBLES START ########################
NAMESPACE="coadjute-dev" #namespace
ENV="dev" #env
CERT_NS="cert-manager" #namespace for cert-manager and nginx-ingress controller deployment

# Azure Info
ACR_ADDRESS="acrcoadjute.azurecr.io" #acraddress
ACR_USERNAME="acrcoadjute" #acrusername
ACR_PASSWORD="deuSCh40M1ACAtJuoL/bQPIWaN1lU196" #acrpassword
NODEPOOL_RG="MC_ps-rg-coadjute-dev_aks-coadjute_uksouth" #nodepoolrg
ASA_NAME="storageaccountcoadjute" #storageAccountName
ASA_KEY="x/s5jAWvl0W/23ho6EihOGDtGK5iYxd5Ieon4u82KJ+tVWCSGv0vINxvwwyct1Y9XsbNkKk1MtqEJq78l9Jp3Q==" #storageAccountKey

# Network Info
IM_ADDRESS="http://20.49.235.0:10000" #identityManagerURL
NM_ADDRESS="http://20.49.233.34:10000" #networkMapURL
NETWORK_TRUSTSTORE_PASSWORD="trust-store-password" #networkTruststorePass
######################## ENV VARIBLES END ########################