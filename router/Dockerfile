FROM mongo:4.2.8-bionic

RUN apt-get update && apt-get install -y netcat

ENV CONFIG_SERVER_NAME 'config-server'
ENV SHARD_NAME_PREFIX 'shard'
ENV SHARD_NODES_1 ''
ENV SHARD_NODES_2 ''
ENV SHARD_NODES_3 ''

ADD /startup.sh /
ADD /config.sh /

EXPOSE 27017

CMD [ "/startup.sh" ]

