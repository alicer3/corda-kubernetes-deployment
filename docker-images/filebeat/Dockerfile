FROM centos:latest
WORKDIR /usr/local
ADD filebeat-7.5.0-linux-x86_64.tar.gz .

RUN ln -s filebeat-7.5.0-linux-x86_64  filebeat \
 && cd filebeat       \
 && mkdir  config     \
 && chmod +x filebeat \
 && cp filebeat.yml config/

ENTRYPOINT ["/usr/local/filebeat/filebeat","-c","/usr/local/filebeat/config/filebeat.yml"]


# Install Filebeat
# RUN cd /usr/local && \
#     tar xvf filebeat-5.4.0-linux-x86_64.tar.gz && \
#     rm -f filebeat-5.4.0-linux-x86_64.tar.gz && \
#     ln -s /usr/local/filebeat-5.4.0-linux-x86_64 /usr/local/filebeat && \
#     chmod +x /usr/local/filebeat/filebeat && \
#     mkdir -p /etc/filebeat
#
# ENV PATHS /var/log/yum.log
# ENV ES_SERVER 172.23.5.255:9200
# ENV INDEX filebeat-test
# ENV INPUT_TYPE log
# ENV ES_USERNAME elastic
# ENV ES_PASSWORD changeme
#
# ADD ./filebeat.yml /etc/filebeat/
# ADD ./entrypoint.sh /usr/bin/
#
# ENTRYPOINT ["entrypoint.sh"]
#
# CMD ["/usr/local/filebeat/filebeat","-e","-c","/etc/filebeat/filebeat.yml"]