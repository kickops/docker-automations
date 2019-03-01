#!/bin/bash

#Version: 1.0
#Author : Karthik
#Date:    24 Jun 18 
#

#Color schemas
Color_Off='\033[0m'       # Text Reset
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow


restartdb()
{
psql -U postgres -d postgres -c "DROP DATABASE $USER;" && psql -U postgres -d postgres -c "CREATE DATABASE $USER;" && echo -e $Green"Restart successful"$Color_Off
}

killmain()
{
mainpid=`ps -ef | grep -i main.py | grep $USER | grep -v grep | awk '{print $2}'`
if test -n "$mainpid"; then
  kill -9 $mainpid
fi
}


main()
{
  ps -ef | grep -i main.py | grep $USER | grep -v grep > /dev/null
  mainexit=$?
  if [[ $mainexit -eq 0 ]];then
    echo -e "The tosca-o main.py is still running. Can i go ahead and kill it before resetting DB? (Y)es, (N)o:\c"
    read ANSWER
    if [[ $ANSWER == "Y" ]] || [[ $ANSWER == "y" ]]; then
      killmain
      restartdb
    else 
      exit
    fi
  else
    restartdb
  fi
}

#LOGIC
main
