# CORDA KUBERNETES DEPLOYMENT

This repository (https://github.com/alicer3/corda-kubernetes-deployment) helps you with full set deployment in Kubernetes, including CE nodes, Postgres DB and Sprintboot Application.

This is meant to build Corda Managed Service Dev/QA environment for Coadjute.

This repository is based on <https://github.com/corda/corda-kubernetes-deployment>

## Contents
- [Setup Checklist](#SETUP-CHECKLIST): a setup checklist to get the environment ready
- [Short Operation Guide](#SHORT-OPERATION-GUIDE): a quickstart guide for operation
- [Operation Guide](#OPERATION-GUIDE): a more comprehensive guide for operation
- [Explanations](#EXPLANATION): explanation on the file structures and key scripts
- [Todos](#TO-DOS): the to-dos
- [Feedbacks](#Feedback): any feedback welcome
---

## SETUP CHECKLIST

Since there are a number of prerequisites that need to be met and then a certain order of running everything, a checklist has been collated that you may find useful.

Please see [PREPARATION.md](PREPARATION.md) for the checklist.

**Note!**
It is strongly recommended you follow the CHECKLIST, to not skip an important step, especially the first time you set up this deployment,

---
## SHORT OPERATION GUIDE (see [OPERATION](#OPERATION-GUIDE) for a full guide)

### Before any actual deployments
Finish all the setup and configuration in [ONE-TIME SETUP](#ONE-TIME-SETUP)

### Deploy a new node
1. update `variables.sh`
2. run `prepareAzure.sh`
3. run `helm_compile.sh`
4. (optional) run `sanity_check.sh` to check on the deployment status

### Delete an existing node
1. run `delete-all.sh`
2. select option 1 (delete kubernetes deployment) or option 2 (delete Azure resource) or option 3 (both)

### Re-Deploy an existing node
1. run `cp files/values/<PREFIX>.yaml ./values.yaml`
2. if Azure resource deleted, recreate
3. run `./helm_compile.sh`
4. (optional) run `sanity_check.sh` to check on the deployment status

---

## OPERATION GUIDE

The operation side consists of few aspects. 
- [one-time setup](#ONE-TIME-SETUP): environment configuration, docker image preparation for later deployment and Ingress Controller (shared by the whole environment) deployment
- [per node deployment](#PER-NODE-DEPLOYMENT): deploy a node, its database and upper layer sprintboot application in different scenarios
- [deletion](#DELETION): how to delete the deployments
- [per node modification](): this is not implemented yet, but it means partial re-deployment. eg. re-deploy the corda node without touching the DB and sprintboot application
- [useful commands](#USERFUL-COMMANDS): useful commands

### ONE-TIME SETUP
#### Environment Initialisation 
- `az login`, make sure at this point that if you have many subscriptions, that the one you want to use has isDefault=true, if not use "az account list" and "az account set -s <subscription id>" to fix it
- `az aks get-credentials --resource-group <Resource Group Name> --name <AKS Name>` # get the info based on the Azure preparation 
- `kubectl create namespace <name>` # for dev, the namespace would be "coadjute-dev"; for QA, it will be "coadjute-qa". It should be consistent with `variables.sh`.
- `kubectl config set-context --current --namespace <name>` # set kubectl context

#### BINARIES

This deployment is targeting an Enterprise deployment, which should include a Corda Node and Postgres Database.

In order to execute the following scripts correctly, you will have to have access to the Corda Enterprise binaries.

The files should be downloaded first and placed in the following folder: ``docker-images/bin``

You can use the helper script ``download_binaries.sh`` to download binaries for you, as long as you have the necessary login details available for the R3 Artifactory.

#### Docker Image
Before building docker images, you need to make sure you have all the binaries ready. See [BINARIES](#BINARIES) for more details.
- `cd docker-images`
- CE image:
    - run `build_docker_images.sh`
    - run `push_docker_images.sh`
- Sprintboot image:
    - run `handle_sprintboot_image.sh`

#### Ingress Controller
The Ingress Controller deployment is shared by all the sprintboot application deployment in the namespace.
- run `./helm/env-prep/env-prep.sh`
- choose option 1

#### Elastic + Kibana
The Elastic + Kibana deployment is shared by all the node deployments in the namespace. Filebeat will be deployed as a sidecar along with nodes, and feeding logs to ElasticSearch, and finally visualized by Kibana.
- run `./helm/env-prep/env-prep.sh`
- choose option 2

### PER NODE DEPLOYMENT
- `cd helm`
- for new node deployment
    - update the node variables in `variables.sh`
    - run `./values/prepareAzure.sh`
    - run `./helm_compile.sh`
- for an existing node deployment
    - check in `files/certificates/node/<PREFIX>` to see whether the node certificates exist
    - check in `files/values/` to see whether `<PREFIX>.yaml` exists
    - check whether the Azure resources (file shares and public IPs) still there
    - run `cp files/values/<PREFIX>.yaml ./values.yaml`
    - run `./helm_compile.sh`
- Sanity Check
    - `cd helm`
    - run `./sanity-check.sh`

### DELETION
- `cd helm`
- run `./delete-all.sh`. And choice the option that suits the needs

### USEFUL COMMANDS

- Check deployment status with: ``kubectl get pods``, expect to see 'Running' if the pods are working normally
- Check logs of running components with: ``kubectl logs -f <pod>``
- If the pods are not running correctly, investigate why with command: ``kubectl decribe <pod>``
- Investigate Corda Node log by gaining a shell into the running pod with: ``(prefix with 'winpty' on Windows) kubectl exec -it <pod> bash``, then cd to folder /opt/corda/workspace/logs and look at most recent node log file

---
## EXPLANATION
Explanation on main components
- Docker images: All Docker images are pushed to Azure Container Registry for later deployment.
    - CE images are node images without cordapp installation used for CE node deployment
    - springboot images are image with sprintboot application inside. Thus a new springboot image needs to be built and pushed whenever a new version of sprintboot application is published. `APIVERSION` is used to identify sprintboot application version.
- Helm
    - files
        - certificates: keeps a copy of node certificates so that the node could be deleted and deployed again
        - conf: the node configuration template
        - cordapps: the place to upload the cordapps you want to deploy
        - network: the place for network truststore and network parameters
        - values: keeps a copy of values.yaml for each node to facilitate re-deployment
    - initial_registration: handles node initial registration 
    - output: the output of `template` folder
    - template: the helm charts for all deployments
    - values: generate `values.yaml` for later deployments and create Azure resources
        - prepareAzure.sh: use the values in `variables.sh` to fill in `values-template.yml` to create `values.yaml` and create Azure resources
    - delete-all.sh: handle deployment and Azure resource deletion
    - helm_compile.sh: use `values.yaml` to compile helm charts and execute the actual deployments
    - ingress_setup.sh: deployment ingress controller shared by the all namespace
    

---

## TO-DOS
- optimization for operation
    - partial re-deployment of node
        - redeploy node only with new cordapps
        - redeploy sprintboot application only
        - redeploy node and database
        - redeploy node and sprintboot application
        - redeploy all deployments
    - batch deployment of nodes
- Log expose: how to expose the logs in real time fashion
- View privilege account for DB

---
## Feedback

Any suggestions / issues are welcome in the issues section.

Fin.
