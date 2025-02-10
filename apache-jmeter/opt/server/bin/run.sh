#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

jvmArgs="-XshowSettings:vm -XX:+UseContainerSupport -XX:InitialRAMPercentage=${JAVA_RAM_PERCENTAGE} -XX:MinRAMPercentage=${JAVA_RAM_PERCENTAGE} -XX:MaxRAMPercentage=${JAVA_RAM_PERCENTAGE}"
localIP=$(ifconfig eth0 | awk '$1~/inet$/ {split($2,ip,":");print ip[2]}')
jmeterArgs=" -Djava.rmi.server.hostname=${localIP} -Dserver.rmi.ssl.disable=true -Djmeter.logfile=/var/log/jmeter.log -Dprometheus.ip=0.0.0.0"
# Word-Split is expected behavior for $jvmArgs, $jmeterArgs and $*. Disable shellcheck.
# shellcheck disable=SC2086,SC2048
exec java ${jvmArgs} -jar /opt/server/bin/ApacheJMeter.jar ${jmeterArgs} ${*:-${CMD}}
