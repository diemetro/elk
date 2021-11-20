version: '3.7'
services:

  traefik:
    image: "traefik:v2.2"
    command:
      - "--log.level=DEBUG"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=admin@scancity.ru"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--accesslog=true"
    networks:
      - elk
    ports:
      - "80:80"
      - "8080:8080"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/etc/letsencrypt:/letsencrypt"
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.14.2
    configs:
      - source: elastic_config
        target: /usr/share/elasticsearch/config/elasticsearch.yml
    environment:
      ES_JAVA_OPTS: "-Xmx1024m -Xms1024m"
      ELASTIC_PASSWORD: demlfluaf
      discovery.type: single-node
    volumes:
      - /data/elastic/data:/usr/share/elasticsearch/data
      - /data/elastic/logs:/usr/share/elasticsearch/logs
    networks:
      - elk
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"

  logstash:
    image: docker.elastic.co/logstash/logstash:7.14.2
    configs:
      - source: logstash_config
        target: /usr/share/logstash/config/logstash.yml
      - source: logstash_pipeline
        target: /usr/share/logstash/pipeline/logstash.conf
    environment:
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"
    ports:
      - 12202:12202/udp
    networks:
      - elk
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"

  kibana:
    image: docker.elastic.co/kibana/kibana:7.14.2
    configs:
      - source: kibana_config
        target: /usr/share/kibana/config/kibana.yml
    ports:
      - 5601:5601
    networks:
      - elk
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 10s
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.kibana.rule=Host(`log.it.scancity.ru`)"
        - "traefik.http.services.kibana.loadbalancer.server.port=5601"
        - "traefik.http.routers.kibana.entrypoints=websecure"
        - "traefik.http.routers.kibana.tls.certresolver=myresolver"
        - "traefik.docker.network=elk"
    logging:
      driver: "json-file"
      options:
        max-size: "5m"

  curator:
    image: ${CI_REGISTRY_IMAGE}/curator:${CI_PIPELINE_ID}
    environment:
      ELASTICSEARCH_HOST: elasticsearch
      CRON: 0 0 * * *
      CONFIG_FILE: /usr/share/curator/config/curator.yml
      COMMAND: /usr/share/curator/config/delete_log_files_curator.yml
      UNIT_COUNT: 2
    networks:
      - elk
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"

configs:
  elastic_config:
    file: ./elasticsearch/config/elasticsearch.yml
  logstash_config:
    file: ./logstash/config/logstash.yml
  logstash_pipeline:
    file: ./logstash/pipeline/logstash.conf
  kibana_config:
    file: ./kibana/config/kibana.yml

networks:
  elk:
    driver: overlay
    external: true
