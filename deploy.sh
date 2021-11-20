#!/bin/bash

mkdir -p /etc/letsencrypt /data/elastic/data /data/elastic/logs 
chmod 777 /etc/letsencrypt /data/elastic/data /data/elastic/logs 

cd ${DEPLOY_DIR}

docker login -u ${CI_REGISTRY_USER} -p ${CI_JOB_TOKEN} ${CI_REGISTRY}
docker pull ${CI_REGISTRY_IMAGE}/curator:${CI_PIPELINE_ID}
ls -la /files
envsubst < docker-compose.tpl > docker-compose.yaml
docker-compose down || true
sleep 15
docker-compose up -d

cd
rm -rf ${DEPLOY_DIR}
