## OVERVIEW

This is the environment preparation you need to do before you can deploy any nodes. It includes:
* Azure Setup
* Operation VM Setup


## SETUP CHECKLIST

Since there are a number of prerequisites that need to be met and then a certain order of running everything, a checklist has been collated that you may find useful.
* Azure Setup
> - [ ] Service Principle 
> - [ ] Resource group for the environment, within this resource group
>> - [ ] Azure Container Registry: the container registry to host images. It should be configured with Service Principle above.
>> - [ ] Azure Kubernetes Cluster: the kubernetes cluster which will be used for all deployments. It should be configured with Service Principle above.
>> - [ ] Azure Storage Account: the storage account to host nodes' files
>> - [ ] Azure Kubernetes Cluster for CENM*: the kubernetes cluster for CENM. This is optional cause you can join any other existing network anywhere. And this CENM could be set up without k8s and could be located at other resource group as well.
>> - [ ] Operation VM*: the VM for operating the environment. This is optional as well. The VM could be located anywhere as long as it could access all the services.
* Operation VM Setup
> - [ ] Helm2
> - [ ] Azure CLI
> - [ ] kubectl
> - [ ] docker
> - [ ] this repository
>> - [ ] helm/files/cordapps - the CorDapps you want to deploy on nodes
>> - [ ] helm/files/network - the networkRootTrustStore.jks of the network
>> - [ ] helm/values/templates/values-template.yml - update this file if needed
>> - [ ] helm/variables.sh - update this file according to your setting


---

## Azure Setup
### Azure Kubernetes Service (AKS)

This is the main Kubernetes cluster that we will be using. Setting up the AKS will also set up a NodePool resource group. The NodePool should also have a few public IP addresses configured as Front End IP addresses for the AKS cluster.

A good guide to follow for setting up AKS: [Quickstart: Deploy an Azure Kubernetes Service cluster using the Azure CLI](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough).

Worth reading the ACR section at the same time to combine the knowledge and setup process.

### Azure Container Registry (ACR)

The ACR provides the Docker images for the AKS to use. Please make sure that the AKS can connect to the ACR using appropriate Service Principals. See: [Azure Container Registry authentication with service principals](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-service-principal). 

Guide for setting up ACR: [Tutorial: Deploy and use Azure Container Registry](https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-acr).

Guide for connecting ACR and AKS: [Authenticate with Azure Container Registry from Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration).

Worth reading the AKS section at the same time to combine the knowledge and setup process.

### Azure Service Principals

Service Principals is Azures way of delegating permissions between different services within Azure. There should be at least one Service Principal for AKS which can access ACR to pull the Docker images from there.

Here is a guide to get your started on SPs: [Service principals with Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal).

### Azure Storage Account

In addition to that there should be a storage account that will host the persistent volumes (File storage).

Guide on setting up Storage Accounts: [Create an Azure Storage account](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal).

## Operation VM Setup

### Helm2
see https://v2.helm.sh/docs/install/

### Azure CLI
see https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

### kubectl
see https://kubernetes.io/docs/tasks/tools/install-kubectl/

### docker
see https://docs.docker.com/engine/install/

### repo
#### variables.sh
- Node Variables 
    - PREFIX # serve as primary key for this set of deployment. It will be used in deployment naming and tagging. 
    - X500NAME # the X500NAME the node uses to register on network
    - APIVERSION # the sprintboot application version to deploy
- Environment Variables
    - NAMESPACE # helm namespace
    - ENV # environment tag, used in kubernetes deployment labeling
    - CERT_NS # namespace for cert-manager and nginx-ingress controller deployment
- Azure Info
    - ACR_ADDRESS # Address of ACR
    - ACR_USERNAME # ACR username
    - ACR_PASSWORD # ACR password
    - NODEPOOL_RG # the nodepool resource group of AKS
    - ASA_NAME  # Azure Storage Account Name
    - ASA_KEY # Azure Storage Account Key
- Network Info
    - IM_ADDRESS # Identity Manager URL
    - NM_ADDRESS # Network Map URL
    - NETWORK_TRUSTSTORE_PASSWORD # passoword of network truststore

Fin.
