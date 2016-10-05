# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM       registry.access.redhat.com/rhel7/rhel
MAINTAINER Sonatype <cloud-ops@sonatype.com>
LABEL vendor=Sonatype \
  com.sonatype.license="Apache License, Version 2.0"

ENV NEXUS_DATA /nexus-data
ENV NEXUS_HOME /opt/sonatype/nexus
ENV NEXUS_VERSION 3.0.2-02

ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 102
ENV JAVA_VERSION_BUILD 14

# Download Oracle JRE and localinstall with yum, yum install tar, yum clean
RUN curl --remote-name --fail --silent --location --retry 3 \
  --header "Cookie: oraclelicense=accept-securebackup-cookie; " \
  http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm \
  && yum localinstall -y jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm \
  && rm jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm \
  && yum install -y tar  \
  && yum clean all

# install nexus
RUN mkdir -p ${NEXUS_HOME} \
  && curl --fail --silent --location --retry 3 \
    https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz \
  | gunzip \
  | tar x -C ${NEXUS_HOME} --strip-components=1 nexus-${NEXUS_VERSION} \
  && chown -R root:root ${NEXUS_HOME}

## configure nexus runtime env
RUN sed \
    -e "s|karaf.home=.|karaf.home=${NEXUS_HOME}|g" \
    -e "s|karaf.base=.|karaf.base=${NEXUS_HOME}|g" \
    -e "s|karaf.etc=etc|karaf.etc=${NEXUS_HOME}/etc|g" \
    -e "s|java.util.logging.config.file=etc|java.util.logging.config.file=${NEXUS_HOME}/etc|g" \
    -e "s|karaf.data=data|karaf.data=${NEXUS_DATA}|g" \
    -e "s|java.io.tmpdir=data/tmp|java.io.tmpdir=${NEXUS_DATA}/tmp|g" \
    -i ${NEXUS_HOME}/bin/nexus.vmoptions

RUN useradd -r -u 200 -m -c "nexus role account" -d ${NEXUS_DATA} -s /bin/false nexus

COPY scripts/fix-permissions.sh /usr/local/bin/

RUN chmod 755 /usr/local/bin/fix-permissions.sh \
  && /usr/local/bin/fix-permissions.sh /opt/sonatype

VOLUME ${NEXUS_DATA}

USER nexus
WORKDIR $NEXUS_HOME

ENV JAVA_MAX_MEM 1200m
ENV JAVA_MIN_MEM 1200m

EXPOSE 8081

CMD bin/nexus run
