#!/usr/bin/env bash
#
#  Purpose: Initialize the template load for testing purposes
#  Usage:
#    install.sh



###############################
## ARGUMENT INPUT            ##
###############################

usage() { echo "Usage: install.sh " 1>&2; exit 1; }

if [ -f ./.envrc ]; then source ./.envrc; fi

if [ ! -z $1 ]; then INITIALS=$1; fi
if [ -z $INITIALS ]; then
  $INITIALS="tsp"
fi

if [ -z $AZURE_SUBSCRIPTION ]; then
  tput setaf 1; echo 'ERROR: AZURE_SUBSCRIPTION not provided' ; tput sgr0
  usage;
fi

if [ -z $AZURE_LOCATION ]; then
  tput setaf 1; echo 'ERROR: AZURE_LOCATION not provided' ; tput sgr0
  usage;
fi

if [ -z $PREFIX ]; then
  PREFIX="arm"
fi


###############################
## FUNCTIONS                 ##
###############################
function CreateResourceGroup() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LOCATION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (LOCATION) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az group show --name $1)
  if [ "$_result"  == "" ]
    then
      UNIQUE=$(shuf -i 100-999 -n 1)
      OUTPUT=$(az group create --name $1 \
        --location $2 \
        --tags RANDOM=$UNIQUE environment="dev" contact=$INITIALS \
        -ojsonc)
    else
      tput setaf 3;  echo "Resource Group $1 already exists."; tput sgr0
      UNIQUE=$(az group show --name $1 --query tags.RANDOM -otsv)
    fi
}
function CreateServicePrincipal() {
    # Required Argument $1 = PRINCIPAL_NAME

    if [ -z $1 ]; then
        tput setaf 1; echo 'ERROR: Argument $1 (PRINCIPAL_NAME) not received'; tput sgr0
        exit 1;
    fi

    local _result=$(az ad sp list --display-name $1 --query [].appId -otsv)
    if [ "$_result"  == "" ]
    then
      CLIENT_SECRET=$(az ad sp create-for-rbac \
        --name $PrincipalName \
        --skip-assignment \
        --query password -otsv)
      CLIENT_ID=$(az ad sp list \
        --display-name $PrincipalName \
        --query [].appId -otsv)

      echo "export CLIENT_ID=${CLIENT_ID}" >> .envrc
      echo "export CLIENT_SECRET=${CLIENT_SECRET}" >> .envrc
    else
        tput setaf 3;  echo "Service Principal $1 already exists."; tput sgr0
        if [ -z $CLIENT_ID ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_ID not provided' ; tput sgr0
          exit 1;
        fi
        if [ -z $CLIENT_SECRET ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_SECRET not provided' ; tput sgr0
          exit 1;
        fi
    fi
}
function CreateSSHKeys() {
  # Required Argument $1 = SSH_USER
  if [ -d ./.ssh ]
  then 
    tput setaf 3;  echo "SSH Keys for User $1: "; tput sgr0
  else 
    mkdir .ssh && cd .ssh
    ssh-keygen -t rsa -b 2048 -C $1 -f id_rsa && cd ..
  fi 

 #read -r _result < ./.ssh/id_rsa.pub
 _result=`cat ./.ssh/id_rsa.pub`
 echo $_result
}


###############################
## Azure Intialize           ##
###############################

tput setaf 2; echo 'Logging in and setting subscription...' ; tput sgr0
az account set --subscription ${AZURE_SUBSCRIPTION}

tput setaf 2; echo 'Creating Resource Group...' ; tput sgr0
RESOURCE_GROUP="$PREFIX-cluster"
CreateResourceGroup $RESOURCE_GROUP $AZURE_LOCATION

tput setaf 2; echo 'Creating Service Principal...' ; tput sgr0
PrincipalName="$PREFIX-Principal"
CreateServicePrincipal $PrincipalName

tput setaf 2; echo 'Creating SSH Keys...' ; tput sgr0
AZURE_USER=$(az account show --query user.name -otsv) 
LINUX_USER=(${AZURE_USER//@/ })
CreateSSHKeys $AZURE_USER

tput setaf 2; echo 'Deploying ARM Template...' ; tput sgr0
az group deployment create --template-file azuredeploy.json  \
    --resource-group $RESOURCE_GROUP \
    --parameters azuredeploy.parameters.json \
    --parameters servicePrincipalClientId=$CLIENT_ID --parameters servicePrincipalClientSecret=$CLIENT_SECRET \
    --parameters initials=$INITIALS --parameters random=$UNIQUE \
    --parameters linuxAdminUsername=$LINUX_USER
