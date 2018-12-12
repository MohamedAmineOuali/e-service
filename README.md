
  
Microservices Dockerization Tutorial  
=======  

### How to Run it
Very simple 
* clone the project 
* run `docker-compose up --scale product-service=1`
(CHECK THE FINAL SECTION FOR MORE)


## Prerequisite  

After following this the tutorial on how to create Micro-services by Ms "Lilia Sfaxi" which can be found on her website. We end up with 4 maven modules: 
* product-service  
* config-service  
* discovery-service  
* proxy-service  
  
## Requirements  
- docker  
- docker composer  
- Internet :p   
## Structure of the repository  
Each module has its on respective directory and we have a maven parent module that inculdes the 4 of them. The parent pom file is located in the root directory of the repository.  
In addition, the Dockerfile defines multi-stage images build (refer to the following section) and the docker-compose.yml which defines the containers to be instantiated. 
Finally we used the file "wait-for-it.sh" which is cloned from the following project "https://github.com/vishnubob/wait-for-it". We will explain later it's utility.  
## Dockerising the Microservices  
### Dockerfile

```Dockerfile  
FROM maven:3.6.0-jdk-8-alpine AS build  
WORKDIR /usr/config-service  
COPY config-service/pom.xml .  
COPY config-service/src ./src  
WORKDIR /usr/product-service  
COPY product-service/pom.xml .  
COPY product-service/src ./src  
WORKDIR /usr/discovery-service  
COPY discovery-service/pom.xml .  
COPY discovery-service/src ./src  
WORKDIR /usr/proxy-service  
COPY proxy-service/pom.xml .  
COPY proxy-service/src ./src  
WORKDIR /usr  
COPY pom.xml .  
RUN mvn package -DskipTests  
  
  
FROM openjdk:8-jre-alpine AS product-service  
COPY --from=build /usr/product-service/target/product-service-0.0.1-SNAPSHOT.jar /usr/app/EXPOSE 8080  
RUN apk add --no-cache bash  
ADD wait-for-it.sh /wait-for-it.sh  
  
FROM openjdk:8-jre-alpine AS config-service  
COPY --from=build /usr/config-service/target/config-service-0.0.1-SNAPSHOT.jar /usr/app/COPY config-service/src/main/resources/myConfig /usr/src/app/src/main/resources/myConfig  
EXPOSE 8888  
  
FROM openjdk:8-jre-alpine AS discovery-service  
COPY --from=build /usr/discovery-service/target/discovery-service-0.0.1-SNAPSHOT.jar /usr/app/EXPOSE 8761  
RUN apk add --no-cache bash  
ADD wait-for-it.sh /wait-for-it.sh  
  
  
FROM openjdk:8-jre-alpine AS proxy-service  
COPY --from=build /usr/proxy-service/target/proxy-service-0.0.1-SNAPSHOT.jar /usr/app/EXPOSE 9999  
RUN apk add --no-cache bash  
ADD wait-for-it.sh /wait-for-it.sh  
```  
=> The AS keyword is used to identify the stage image.

In this dockefile we used the multi-stage feature provided by docker. Using this feature we create 5 different images defined in the same file.   
```Dockerfile  
FROM maven:3.6.0-jdk-8-alpine AS build  
WORKDIR /usr/config-service  
COPY config-service/pom.xml .  
COPY config-service/src ./src  
WORKDIR /usr/product-service  
COPY product-service/pom.xml .  
COPY product-service/src ./src  
WORKDIR /usr/discovery-service  
COPY discovery-service/pom.xml .  
COPY discovery-service/src ./src  
WORKDIR /usr/proxy-service  
COPY proxy-service/pom.xml .  
COPY proxy-service/src ./src  
WORKDIR /usr  
COPY pom.xml .  
RUN mvn package -DskipTests  
```  
* First, we build the maven modules using temporary image (which will be delete in the end)  
   * We copy all the modules 
   * We build the parent pom using the command 'RUN mvn package -DskipTests'   
   * This will generate the 4 packages of the 4 module.  

```Dockerfile  
FROM openjdk:8-jre-alpine AS proxy-service  
COPY --from=build /usr/proxy-service/target/proxy-service-0.0.1-SNAPSHOT.jar /usr/app/EXPOSE 9999  
RUN apk add --no-cache bash  
ADD wait-for-it.sh /wait-for-it.sh  
```  
* Second, we create 4 persistent images that will include each a specific "jar" package.  
   * we copy the jar package from the build image to the specific image  
   * we expose the right port for each one  
   * we install bash shell for each image  
   * we copy the script wait-for-it.sh from the host to the image.  

### wait-for-it.sh  
Due to the tight relation between the programs, a synchronization is needed to ensure that everything is working. This will be ensured by the following script.
For example the config-service should be started before all the others because they get their configuration form it. The same thing is applied to discovery-service which should start just after config-service. Docker doesn't have a mechanism to ensure that a server is running before starting a specific container. But, it has the ability to start a container before another. This doesn't not imply that the server (spring-boot application in our case) has started.

Many solutions are proposed to solve this problem one of them is to estimate the duration between the start of the container and the end of the server initialization and use some plugins to start the next container after that duration.
This method is heuristic and it could result in some problem, like an execution in an environment that will be different. 

Another more efficient method is to use the wait-for-it.sh. This script is simple: you give it a host and a port and it keeps sending requests until a valid response is giving back which mean that the server which we are trying to reach has started. This script also takes as an argument: a command to run if the server has been reached (started). In our case, the command will start the spring-boot project.

### docker-compose.yml
In this file we have 4 section one for each service. It's worth mentioning that we are using the version "3.4" of docker-compose specified in the `docker-compose.yml` file. This version enable us to create containers from stage images that are defined in a dockerfile. So the dockerfile will run only one time and then each stage mentioned in the `docker-compose.yml` will be used to create the corresponding container.

config-service
 ```YAML
  config-service:
    build:
      context: .
      target: config-service
    container_name: config-service
    ports: 
     - "8888:8888"
    command: java -jar /usr/app/config-service-0.0.1-SNAPSHOT.jar
    environment:
        SPRING_APPLICATION_JSON: '{"spring": {"cloud": {"config": { "server":{"git":{"uri":"https://github.com/MohamedAmineOuali/e-service_config"}}}}}}'
```

discovery-service:
  ```YAML
  discovery-service:
    build:
      context: .
      target: discovery-service
    container_name: discovery-service
    ports: 
     - "8761:8761"
    depends_on:
      - config-service
    entrypoint: /wait-for-it.sh config-service:8888 -t 0 --
    command: java -jar /usr/app/discovery-service-0.0.1-SNAPSHOT.jar
    environment:
        SPRING_APPLICATION_JSON: '{"spring":{"cloud":{"config":{"uri":"http://config-service:8888"}}}}' 
```

proxy-service:
 ```YAML
 proxy-service:
    build:
      context: .
      target: proxy-service
    container_name: proxy-service
    ports: 
     - "9999:9999"
    depends_on:
      - discovery-service
    entrypoint: /wait-for-it.sh discovery-service:8761 -t 0 --
    command: java -jar /usr/app/proxy-service-0.0.1-SNAPSHOT.jar
    environment:
        SPRING_APPLICATION_JSON: '{"spring":{"cloud":{"config":{"uri":"http://config-service:8888"}}}}' 
```

product-service:
 ```YAML
  product-service:
    build:
      context: .
      target: product-service
    ports: 
     - "8080-8083:8080"
    depends_on:
      - discovery-service
    entrypoint: /wait-for-it.sh discovery-service:8761 -t 0 --
    command: java -jar /usr/app/product-service-0.0.1-SNAPSHOT.jar
    environment:
        SPRING_APPLICATION_JSON: '{"spring":{"cloud":{"config":{"uri":"http://config-service:8888"}}}}' 
```

All the tags used are explained in the docker documentation 
* For the build: we specify the context in the current directory so that Dockerfile (in the current directory) will be used. The target specifies the stage image id that will be used to start the container. As mentioned before the Dockerfile will run only once.
* We then specify the mapped port with ports tag
	* For the product-service, we give it a range of ports to choose from. This will help us instantiate more than one container as product-service. It will also be useful if one of the specified ports is occupied by another app. This will not cause any problem giving that we are using the discovery service.
* Some containers start depending on the config-service or discovery-service. This is specified by `depends_on` tag. But this is not sufficient, as we also need to wait for the server to start. 
* Most of the service specify an entrypoint and use wait-for-it.sh in order to wait for the config-server to start or the discovery-service for other containers
* The command tag specifies what application to start for each container using the package jar generated.
* Finally, some spring boot parameters are overridden using the environment variable `SPRING_APPLICATION_JSON`. This prevent changing the application.properties of each spring boot application. Only the parameters specified in the environment variable are overridden.
	* We override the local git repository in the config-service config with the remote-repository where all config files of the services are located.
	* We override the hostname of the config-service in all the other services.

### How to Run it
* clone the project 
* run `docker-compose up --scale product-service=n`
	* n is the number of product-service that we are instantiating
	* The current maximum number is 3 if the ports range 8080-8083 is free 
	* If you need more, you can change the ports' range or even delete this because we don't need to expose the product-service to the host if we are using the proxy.
## Contributors

| [<img src="https://avatars1.githubusercontent.com/u/20454717?s=460&v=4" width="100px;"/><br /><sub><b>Mohmaed Amine Ouali</b></sub>](https://github.com/MohamedAmineOuali)<br /> | [<img src="https://avatars0.githubusercontent.com/u/31276718?s=460&v=4" width="100px;"/><br /><sub><b>Souleima Zghab</b></sub>](https://github.com/sZghab)<br />
| :---: | :---: | 
