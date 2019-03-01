#!/bin/bash

##Author: Kicky


if [ -z "$1" ]; then
    echo  "Usage: docker-destroy <service>"
    exit 1
fi


if [ $1 == -h ] || [ $1 == --help ];then
         echo "Usage: docker-destroy <service>"
         echo "       note: multiple services can be provided as space separated arguments"
         echo "       ex: docker-destroy <service1> <service2>"
else
for i in $@
do if [ -d /var/tmp/tosca-o/build/$i ]
     then
       cd /var/tmp/tosca-o/build/$i && echo -e "\nTeardown of service $i is being performed..."  && docker-compose down
   else
     echo "Service $i is not available"
   fi
done
fi

