FROM registry.ng.bluemix.net/ibmnode:latest

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 9.0.0
ENV TMPDIR /tmp/
ENV JBOSS_HOME /opt/wildfly
ENV PATH /opt/wildfly/bin:/usr/local/java/jdk1.8.0_66/bin:$PATH

RUN apt-get -y install wget

RUN chmod 777 /opt

RUN echo "Creating directory structures"

RUN mkdir /usr/local/java

#Give the absolute path to copy e.g /opt/foo.txt
#COPY  foo.txt /opt/foo.txt

WORKDIR /opt
RUN wget  http://downloads.jboss.org/keycloak/1.7.0.Final/keycloak-demo-1.7.0.Final.tar.gz && tar -zxvf keycloak-demo-1.7.0.Final.tar.gz && mv keycloak-demo-1.7.0.Final/keycloak wildfly && rm keycloak-demo-1.7.0.Final.tar.gz 

RUN ls -l 

WORKDIR /tmp
RUN wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u66-b17/jdk-8u66-linux-x64.tar.gz"  && tar -zxvf jdk-8u66-linux-x64.tar.gz -C /usr/local/java/ && rm jdk-8u66-linux-x64.tar.gz

WORKDIR /usr/local/java
RUN ls -l 

WORKDIR /opt
RUN ls -l 

RUN echo "JAVA_HOME=/usr/local/java/jdk1.8.0_66" >> /etc/profile
RUN echo "JRE_HOME=$JAVA_HOME/jre" >> /etc/profile
RUN echo "PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin" >> /etc/profile
RUN echo "export JAVA_HOME" >> /etc/profile 
RUN echo "export PATH" >> /etc/profile
RUN update-alternatives --install "/usr/bin/java" "java" "/usr/local/java/jdk1.8.0_66/jre/bin/java" 1

RUN update-alternatives --set java /usr/local/java/jdk1.8.0_66/jre/bin/java

RUN chmod 777 -R /usr/local/java

RUN chmod 777 /etc/profile

RUN chmod 777 -R /opt/wildfly

RUN . /etc/profile

RUN java -version

COPY postgresql.jar /opt/wildfly/standalone/deployments
#COPY standalone.xml /opt/wildfly/standalone/configuration

WORKDIR /opt

RUN ls -l 

RUN chmod 777  /opt/wildfly/bin/add-user.sh

RUN chmod 777 /opt/wildfly/bin/add-user-keycloak.sh
RUN /opt/wildfly/bin/add-user-keycloak.sh -r master -u  admin -p m1n2a4@ijk

RUN chmod -R 777 /opt/wildfly

RUN /opt/wildfly/bin/add-user.sh admin m1n2a4@ijk --silent

#configuring SSL (IMPORTANT as other configs has to be manual)

RUN touch /opt/wildfly/standalone/configuration/https-users.properties

WORKDIR  /opt/wildfly/standalone/configuration
RUN keytool -genkeypair -alias bluemix.net -keyalg RSA -keysize 2048 -validity 365 -keystore wldfly.jks -keypass s1h2a3rd -storepass s1h2a3rd -dname "CN=bluemix,O=csc,C=us"

RUN sed -i '/<security-realms>/a <security-realm name="SSLRealm"><server-identities><ssl><keystore path="wldfly.jks" relative-to="jboss.server.config.dir" keystore-password="s1h2a3rd" alias="bluemix.net"/></ssl></server-identities></security-realm>' standalone.xml

RUN sed -i '/<server name="default-server">/a <https-listener name="default-https" socket-binding="https" security-realm="SSLRealm"/>' standalone.xml

RUN sed -i '/<management-interface security-realm="ManagementRealm" http-upgrade-enabled="true">/a <socket-binding http="management-https"/>' standalone.xml

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

# Expose the ports we're interested in
EXPOSE 8080
EXPOSE 9990
EXPOSE 9993
EXPOSE 8443

# This will boot WildFly in the standalone mode and bind to all interface
CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0","-bmanagement", "0.0.0.0"]
