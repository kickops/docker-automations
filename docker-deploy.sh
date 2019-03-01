#!/bin/bash
#Author - Kicky
#Version - 1.0
#
#######################################################################################################
# Utility to deploy the tosca-o service along with the required postgres instance. The linking and the#
# internal communication will be handled all together by this utility.                                #
# Both the containers will be started and ports exposed                                               #
#######################################################################################################

WORK_DIR='/var/tmp/tosca-o/build'
SDIR='/opt/toscao/compose'
VERSION="1.1"
TAG=`docker images  | grep toscao | awk '{print $2}' | sort -rn | head -1`
IMAGE=toscao:$TAG

#Color schemas
Color_Off='\033[0m'       # Text Reset
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow

ISARGS=`echo $*`


#fetch user preferences
while [ "$1" != "" ]; 
do
   case $1 in
    -p | --port )
        shift
        if [[ "$1" != "" && "$1" != "-i" && "$1" != "-s" && "$1" != "-v" && "$1" != "-h" ]];
           then
             PORT="$1"
        else
           echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>]"
           echo -e $Yellow"port number missing after the -p argument"$Color_Off
           exit
        fi
        ;;
    -r | --remote )
        shift
        if [[ "$1" != "" && "$1" != "-p" && "$1" != "-s" && "$1" != "-v" && "$1" != "-h"  && "$1" != "-i" ]];
          then
            REMHOST="$1"
        else
           echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>] [-r <remote-host>]"
           echo -e $Yellow"Remote hostname missing after the -r argument"$Color_Off
           exit
        fi
        ;;
    -i | --image )
        shift
        if [[ "$1" != "" && "$1" != "-p" && "$1" != "-s" && "$1" != "-v" && "$1" != "-h" ]];
           then
             IMAGE="$1"
        else
           echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>]"
           echo -e $Yellow"image name missing after the -i argument"$Color_Off
           exit
        fi
        ;;
    -v | --version )
        echo "docker-deploy Version: $VERSION"
        exit
        ;;
    -s | --service )
        shift
        if [[ "$1" != "" && "$1" != "-p" && "$1" != "-i" && "$1" != "-v" && "$1" != "-h" ]];
           then
             SERVICE="$1"
        else
           echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>]"
           echo -e $Yellow"service name missing after the -s argument"$Color_Off
           exit
        fi
        ;;
    -h | --help ) 
         echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>(optional)] [-r <remote-host>(optional)]"
         echo "   -p | --port -  port on the host to which the tosca-o container has to be mapped"
         echo "   -s | --service -  Any user defined name in which the services will be spawned"
         echo "                     Example: <service>-toscao , <service>-postgres"
         echo "   -i | --image -  <image:tag> of the tosca-o service to be run (Default - latest version of tosca-o image)"
         echo "   -r | --remote - hostname|ip addr of the server where container has to be deployed "
         echo "   -v | --version -  prints out version information for this script"
         echo "   -h | --help -  displays this message"
         exit
      ;;
    * ) 
         echo "Invalid option: $1"
         echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>(optional)]"
         echo "   -p | --port - port on the host to which the tosca-o container has to be mapped"
         echo "   -s | --service - Any user defined name in which the services will be spawned"
         echo "                    Example: <service>-toscao , <service>-postgres"
         echo "   -i | --image - <image:tag> of the tosca-o service to be run (Default - latest version of tosca-o image)"
         echo "   -v | --version - prints out version information for this script"
         echo "   -r | --remote - hostname|ip addr of the server where container has to be deployed "
         echo "   -h | --help - displays help message for this utility"
        exit
       ;;
  esac
  shift
done


copy_contents()
{
mkdir -p $WORK_DIR/$SERVICE
cat $SDIR/docker-compose.yml| sed "s/<service>/$SERVICE/g" | sed "s/<port>/$PORT/g" | sed "s/<image>/$IMAGE/g" > $WORK_DIR/$SERVICE/docker-compose.yml
cat $SDIR/db-variables.conf | sed "s/<service>/$SERVICE/g" > $WORK_DIR/$SERVICE/db-variables.conf
}

remote_deploy()
{
ssh $REMHOST -C "docker load -i /var/opt/tosca-o/build/toscao-tar.gz >/dev/null" && \
ssh $REMHOST docker images | grep none > /dev/null
if [[ `echo $?` -eq 0 ]]; then
  remimg=`ssh $REMHOST -C docker images | grep none | head -1 | awk '{print $3}'`
else
  remimg=`ssh $REMHOST -C docker images toscao | sort -rn|head -1 | awk '{print $3}'` 
fi 
ssh $REMHOST "docker tag $remimg toscao:$TAG" && \
ssh $REMHOST  "docker-compose -f $WORK_DIR/$SERVICE/docker-compose.yml up -d" && echo -e $Green"Succesfully deployed the stack"$Color_Off
}


validate_contents()
{
ping -c1 $REMHOST > /dev/null
if [[ `echo $?` != 0 ]];then
  echo -e $Red"The remote host is not reachable. Please check the IP and try again"$Color_Off
  exit 2
fi
##validate service name in remote machine##
ssh $REMHOST "docker ps -a |grep $SERVICE- > /dev/null"
if [[ `echo $?` -eq 0 ]];then 
  echo -e $Red"The Service name is already used in the remote machine"$Color_Off && exit
fi

ssh $REMHOST "netstat -an | grep -w $PORT | grep LISTEN > /dev/null"
    if [[ `echo $?` -eq 0 ]]; then
       echo -e $Red"Error: This port is already taken in the remote machine"$Color_Off && exit
    fi
}

transfer_contents()
{
## Copy the toscao image "
ssh $REMHOST  "mkdir -p /var/opt/tosca-o/build/"
echo -e "Copying the toscao image $Green........"$Color_Off
scp /var/opt/tosca-o/build/toscao-tar.gz $REMHOST:/var/opt/tosca-o/build/  > /dev/null
echo -e "Copying the deployables  $Green........"$Color_Off
ssh $REMHOST  "mkdir -p $WORK_DIR/$SERVICE"
scp -r $WORK_DIR/$SERVICE $REMHOST:$WORK_DIR/ >/dev/null
remote_deploy
}

run_deploy()
{
cd $WORK_DIR/$SERVICE/ && docker-compose up -d && \
echo -e "INFO : The compose config files are located at '$WORK_DIR/$SERVICE'"
echo -e "INFO : After making changes to tosca-o container , it can be restarted using 'docker-compose restart $SERVICE-tosca-o'"
echo -e $Green"Succesfully deployed the stack"$Color_Off
}

if [[ $ISARGS = *-r* ]] || [[ $ISARGS = *--remote* ]]; then
    if [[ $ISARGS = *-p*-s* ]] || [[ $ISARGS = *-s*-p* ]] ; then
      validate_contents
      copy_contents
      transfer_contents
    else
       echo "Usage: docker-deploy [-r <remote-host>] [-p <port>] [-s <service>] [-i <image>(optional)]"
       echo -e  $Red"MISSING ARGUMENTS: port number and service name are mandatory"$Color_Off
    fi

else
  if [[ $ISARGS = *-p*-s* ]] || [[ $ISARGS = *-s*-p* ]] ; then
netstat -an | grep -w $PORT | grep LISTEN > /dev/null
    if [[ `echo $?` -eq 0 ]]; then
       echo -e $Red"Error: This port is already taken"$Color_Off && exit
    fi
docker ps -a |grep $SERVICE- > /dev/null
if [[ `echo $?` -eq 0 ]];then
  echo -e $Red"The Service name is already used in the remote machine"$Color_Off && exit
fi
copy_contents
run_deploy

  else
    echo
    echo "Usage: docker-deploy [-p <port>] [-s <service>] [-i <image>(optional)]"
    echo -e  $Red"MISSING ARGUMENTS: port number and service name are mandatory"$Color_Off
  exit
  fi
fi

