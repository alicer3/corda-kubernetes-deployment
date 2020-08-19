# CORDA KUBERNETES DEPLOYMENT

This repository (https://github.com/alicer3/corda-kubernetes-deployment) helps you with full set deployment in Kubernetes, including CE nodes, Postgres DB and Sprintboot Application.

This is meant to build Corda Managed Service Dev/QA environment for Coadjute.

This repository is based on <https://github.com/corda/corda-kubernetes-deployment>


---

## SETUP CHECKLIST

Since there are a number of prerequisites that need to be met and then a certain order of running everything, a checklist has been collated that you may find useful.

Please see [PREPARATION.md](PREPARATION.md) for the checklist.

**Note!**
It is strongly recommended you follow the CHECKLIST, to not skip an important step, especially the first time you set up this deployment,

---

## OPERATION

The operation side consists of few aspects. 
- one-time setup: environment configuration, docker image preparation for later deployment and Ingress Controller (shared by the whole environment) deployment
- per node deployment: deploy a node, its database and upper layer sprintboot application in different scenarios
- deletion: how to delete the deployments
- per node modification: 

### ONE-TIME SETUP
#### Environment Initialisation 
- `az login`, make sure at this point that if you have many subscriptions, that the one you want to use has isDefault=true, if not use "az account list" and "az account set -s <subscription id>" to fix it
- `az aks get-credentials --resource-group <Resource Group Name> --name <AKS Name>` # get the info based on the Azure preparation 
- `kubectl create namespace <name>` # for dev, the namespace would be "coadjute-dev"; for QA, it will be "coadjute-qa". It should be consistent with `variables.sh`.
- `kubectl config set-context --current --namespace <name>` # set kubectl context

#### Docker Image
Before building docker images, you need to make sure you have all the binaries ready.
- `cd docker-images`
- CE image:
    - run `build_docker_images.sh`
    - run `push_docker_images.sh`
- Sprintboot image:
    - run `handle_sprintboot_image.sh`

#### Ingress Controller
The Ingress Controller deployment is shared by all the sprintboot application deployment in the namespace.
- run `./helm/ingress-setup.sh`

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

### Sanity Check
- `cd helm`
- run `./sanity-check.sh`

### DELETION
- `cd helm`
- run `./delete-all.sh`. And choice the option that suits the needs

---
## EXPLANATION
Explanation on main components
- Docker images: All Docker images are pushed to Azure Container Registry for later deployment.
    - CE images are node images without cordapp installation used for CE node deployment
    - sprintboot images are image with sprintboot application inside. Thus a new sprintboot image needs to be built and pushed whenever a new version of sprintboot application is published. `APIVERSION` is used to identify sprintboot application version.

    
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
---
## APPENDIX
### BINARIES

This deployment is targeting an Enterprise deployment, which should include a Corda Node and Postgres Database.

In order to execute the following scripts correctly, you will have to have access to the Corda Enterprise binaries.

The files should be downloaded first and placed in the following folder: ``docker-images/bin``

You can use the helper script ``download_binaries.sh`` to download binaries for you, as long as you have the necessary login details available for the R3 Artifactory.

---

## CONFIGURATION

You must completely fill out the [helm/values.yaml](helm/values.yaml) file according to your configuration.
For more details on how it should be filled out, follow the [CHECKLIST.md](CHECKLIST.md) document.

---

## SHORT USAGE GUIDE (see [SETUP CHECKLIST](#setup-checklist) for a full guide)

This is a brief view of the steps you will take, for the full set of steps, please review [CHECKLIST.md](CHECKLIST.md).

1. Customize the Helm ``values.yaml`` file according to your deployment (this step is used by initial-registration and Helm compile, very important to fill in correctly and completely)
2. Execute ``one-time-setup.sh`` which will do the following (you can also step through the steps on your own, just follow what the one-time-setup.sh would have done):
	1. Build the docker images and push them to the Container Registry
	2. Generate the Corda Firewall PKI certificates
	3. Execute initial registration step (which should copy certificates to the correct locations under ``helm/files``)
3. Build Helm templates and install them onto the Kubernetes Cluster (by way of executing either ``deploy.sh`` or ``helm/helm_compile.sh``)
4. Ensure that the deployment has been successful (log in to the pods and check that they are working correctly, please see below link for information on how to do that)

---

## DOCUMENTATION

For more details and instructions it is strongly recommended to visit the following page on the Corda Solutions docs site: 
<https://solutions.corda.net/deployment/kubernetes/intro.html>

For additional documentation please find it here [Documentation](DOCUMENTATION.md).

It also contains a helpful [Cost calculation](COST_CALCULATION.md) for evaluating **production** costs.
(you can test this out in a much more affordable setup, in a test cluster you can run it with just 2x(Standard DS2 v2 (2 vcpus, 7 GiB memory)) worker nodes)

---

### KEY CONCEPTS & TOOLS

You may want to familiarize yourself with the key concepts of a production grade deployment and the tools being used in this deployment.

You can find the information in [Key Concepts](KEY_CONCEPTS.md).

---

## ROADMAP

To see the intended direction that this deployment should take, please have a look at the [Roadmap](ROADMAP.md)

---

## Contributing

The Corda Kubernetes Deployment is an open-source project and contributions are welcome as seen here: [Contributing](CONTRIBUTING.md)

The contributors can be found here: [Contributors](CONTRIBUTORS.md)

---

## Feedback

Any suggestions / issues are welcome in the issues section: <https://github.com/corda/corda-kubernetes-deployment/issues/new>

Fin.
