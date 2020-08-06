FROM azul/zulu-openjdk-debian:8
RUN mkdir -p /opt/webserver
COPY api.jar /opt/webserver/api.jar
EXPOSE 8080
WORKDIR /opt/webserver
ENTRYPOINT ["java", "-jar", "api.jar"]