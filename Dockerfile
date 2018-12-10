FROM maven:3.6.0-jdk-8-alpine AS build
WORKDIR /usr/config-service
COPY config-service/pom.xml .
COPY config-service/src ./src
RUN mvn package -DskipTests
WORKDIR /usr/product-service
COPY product-service/pom.xml .
COPY product-service/src ./src
RUN mvn package -DskipTests
WORKDIR /usr/discovery-service
COPY discovery-service/pom.xml .
COPY discovery-service/src ./src
RUN mvn package -DskipTests
WORKDIR /usr/proxy-service
COPY proxy-service/pom.xml .
COPY proxy-service/src ./src
RUN mvn package -DskipTests



FROM openjdk:8-jre-alpine  AS product-service
COPY --from=build /usr/product-service/target/product-service-0.0.1-SNAPSHOT.jar /usr/app/
EXPOSE 8080
RUN apk add --no-cache bash
ADD wait-for-it.sh /wait-for-it.sh
CMD ["java","-jar","/usr/app/product-service-0.0.1-SNAPSHOT.jar","--spring.profiles.active=docker"]


FROM openjdk:8-jre-alpine  AS config-service
COPY --from=build /usr/config-service/target/config-service-0.0.1-SNAPSHOT.jar /usr/app/
COPY config-service/src/main/resources/myConfig /usr/src/app/src/main/resources/myConfig
EXPOSE 8888
CMD ["java","-jar","/usr/app/config-service-0.0.1-SNAPSHOT.jar","--spring.profiles.active=docker"]


FROM openjdk:8-jre-alpine AS discovery-service
COPY --from=build /usr/discovery-service/target/discovery-service-0.0.1-SNAPSHOT.jar /usr/app/
EXPOSE 8761
RUN apk add --no-cache bash
ADD wait-for-it.sh /wait-for-it.sh
CMD ["java","-jar","/usr/app/discovery-service-0.0.1-SNAPSHOT.jar","--spring.profiles.active=docker"]



FROM openjdk:8-jre-alpine  AS proxy-service
COPY --from=build /usr/proxy-service/target/proxy-service-0.0.1-SNAPSHOT.jar /usr/app/
EXPOSE 9999
RUN apk add --no-cache bash
ADD wait-for-it.sh /wait-for-it.sh
CMD ["java","-jar","/usr/app/proxy-service-0.0.1-SNAPSHOT.jar","--spring.profiles.active=docker"]
