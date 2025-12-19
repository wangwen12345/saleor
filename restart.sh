#!/bin/bash
#删除
#docker rm  `docker ps -a|grep saleor|awk '{ print $1}'`
docker stop `docker ps |grep saleor|awk '{ print $1}'`
docker start `docker ps -a|grep saleor|awk '{ print $1}'`
