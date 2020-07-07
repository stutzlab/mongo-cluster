FROM mongo:4.2.8-bionic

RUN apt-get update && apt-get install -y netcat

ENV SHARD_NAME ''
ENV SHARD_NODES ''

ADD /startup.sh /
ADD /config.sh /

EXPOSE 27017

CMD [ "/startup.sh" ]

