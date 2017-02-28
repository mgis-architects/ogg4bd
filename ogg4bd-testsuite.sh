#!/bin/bash
#########################################################################################
## OGG4BD Test Suite
#########################################################################################
# Configures Oracle Goldengate for big data to receive trail files from OGG
# and write to Confluent/Kafka queues
# Pre-req: https://github.com/mgis-architects/ogg-testsuite.sh
# This script only supports Azure currently, mainly due to the disk persistence method
#
# USAGE:
#
#    sudo ogg4bd-testsuite.sh ~/ogg4bd-testsuite.ini
#
# USEFUL LINKS: 
# 
# docs:    http://docs.oracle.com/goldengate/bd123010/gg-bd/index.html
# install: http://docs.oracle.com/goldengate/bd123010/gg-bd/GBDIG/toc.htm
# useful:
#          https://blogs.oracle.com/dataintegration/entry/goldengate_for_big_data_121
#          http://www.ateam-oracle.com/oracle-goldengate-big-data-adapter-apache-kafka-producer/
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-1-hdfs/
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-2-flume
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-3-kafka/
#          https://gist.github.com/rmoff/ae6b8d78000650477b0d35a494682e29
#          https://java.net/downloads/oracledi/GoldenGate/Oracle%20GoldenGate%20Adapter%20for%20Kafka%20Connect/OGG_Kafka_Connect.pdf
#
# https://docs.oracle.com/goldengate/bd123010/gg-bd/GADBD/GUID-1C21BC19-B3E9-462C-809C-9440CAB3A427.htm#GADBD372
# The Kafka client JARs must match the version of Kafka that the Kafka Handler is connecting to. 
#

#########################################################################################

g_prog=ogg4bd-testsuite
RETVAL=0

######################################################
## defined script variables
######################################################
STAGE_DIR=/tmp/$g_prog/stage
LOG_DIR=/var/log/$g_prog
LOG_FILE=$LOG_DIR/${prog}.log.$(date +%Y%m%d_%H%M%S_%N)
INI_FILE=$LOG_DIR/${g_prog}.ini

THISDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCR=$(basename "${BASH_SOURCE[0]}")
THIS_SCRIPT=$THISDIR/$SCR

oggHome=/u01/app/oracle/product/12.2.1/ogg
ogg4bdHome=/u01/app/oracle/product/12.3.0/ogg4bd



######################################################
## log()
##
##   parameter 1 - text to log
##
##   1. write parameter #1 to current logfile
##
######################################################
function log ()
{
    if [[ -e $LOG_DIR ]]; then
        echo "$(date +%Y/%m/%d_%H:%M:%S.%N) $1" >> $LOG_FILE
    fi
}

######################################################
## fatalError()
##
##   parameter 1 - text to log
##
##   1.  log a fatal error and exit
##
######################################################
function fatalError ()
{
    MSG=$1
    log "FATAL: $MSG"
    echo "ERROR: $MSG"
    exit -1
}

##################################################################################
# Leaving in here as may be useful
##################################################################################
# function installDocker()
# {
#     sudo yum -y install yum-utils
#     sudo yum-config-manager --add-repo https://docs.docker.com/engine/installation/linux/repo_files/centos/docker.repo
#     sudo yum makecache fast
#     sudo yum list docker-engine.x86_64  --showduplicates |sort -r
#     sudo yum -y install docker-engine-selinux-1.12.6-1.el7.centos
#     sudo yum -y install docker-engine-1.12.6-1.el7.centos
#     sudo systemctl start docker
#     sudo systemctl status docker
# }
#
# function createTopics() {
#     sudo docker run --net=host --rm confluentinc/cp-kafka:3.1.2 kafka-topics --create --topic sstopic --partitions 3 --replication-factor 3 --if-not-exists --zookeeper 10.135.50.4:22181
#     sudo docker run --net=host --rm confluentinc/cp-kafka:3.1.2 kafka-topics --describe --topic sstopic --zookeeper 10.135.50.4:22181
# }
# 
# function customKafkaProducer() {
# 
#     local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.customKafkaProducer.sh
#     local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.customKafkaProducer.log
#     
#     cat > $l_tmp_script << EOFckp
# 
# cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm
# 
# cat > custom_kafka_producer.properties << EOFckp1
# bootstrap.servers=${bootstrapServers}
# acks=1
# compression.type=gzip
# reconnect.backoff.ms=1000
# value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
# key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
# # 100KB per partition
# batch.size=102400
# linger.ms=10000
# EOFckp1
# 
# EOFckp
# 
#     su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
# 
# }
# 
# function kafkaProps() {
# 
#     local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.kafkaProps.sh
#     local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.kafkaProps.log
#     
#     cat > $l_tmp_script << EOFkp
# 
#     cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm
#     
#     cat > kafka.props << EOFkp1
# 
# gg.handlerlist = kafkahandler
# gg.handler.kafkahandler.type=kafka
# gg.handler.kafkahandler.KafkaProducerConfigFile=custom_kafka_producer.properties
# gg.handler.kafkahandler.TopicName=${topic1}
# gg.handler.kafkahandler.format=avro_op
# gg.handler.kafkahandler.SchemaTopicName=${schemaTopic1}
# gg.handler.kafkahandler.BlockingSend=false
# gg.handler.kafkahandler.includeTokens=false
# gg.handler.kafkahandler.mode=tx
# #gg.handler.kafkahandler.maxGroupSize=100, 1Mb
# #gg.handler.kafkahandler.minGroupSize=50, 500Kb
# goldengate.userexit.timestamp=utc
# goldengate.userexit.writers=javawriter
# javawriter.stats.display=TRUE
# javawriter.stats.full=TRUE
# gg.log=log4j
# gg.log.level=INFO
# gg.report.time=30sec
# gg.classpath=dirprm/:/usr/share/java/kafka/*
# #Sample gg.classpath for HDP
# #gg.classpath=/etc/kafka/conf:/usr/hdp/current/kafka-broker/libs/*
# javawriter.bootoptions=-Xmx512m -Xms32m -Djava.class.path=ggjava/ggjava.jar
# EOFkp1
# 
# EOFkp
# 
#     su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
# }
# 
# function irkafka() {
# 
#     local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.irkafka.sh
#     local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.irkafka.log
#     
#     cat > $l_tmp_script << EOFrk
# 
#     cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm
#     
#     cat > irkafka.prm << EOFrk1
# SPECIALRUN
# END RUNTIME
# EXTFILE /u01/oggbd/dirdat/initld
# --
# TARGETDB LIBFILE libggjava.so SET property=dirprm/kafka.props
# REPORTCOUNT EVERY 1 MINUTES, RATE
# GROUPTRANSOPS 10000
# MAP ade.*, TARGET bd.*;
# EOFrk1
# 
# cd /u01/app/oracle/product/12.3.0/ogg4bd
# ./replicat paramfile dirprm/irkafka.prm reportfile dirrpt/irkafka.rpt
#     
# EOFrk
# 
#     su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
# }
# 
# function rkafka() {
# 
#     local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.rkafka.sh
#     local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.rkafka.log
#     
#     cat > $l_tmp_script << EOFrk
# 
#     cat > rkafka.prm << EOFrk1
# REPLICAT rkafka
# -- Command to add REPLICAT
# -- add replicat rkafka, exttrail AdapterExamples/trail/tr
# TARGETDB LIBFILE libggjava.so SET property=dirprm/kafka.props
# REPORTCOUNT EVERY 1 MINUTES, RATE
# GROUPTRANSOPS 10000
# MAP ade.*, TARGET bd.*;
# EOFrk1
#     
# EOFrk
# 
#     su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
# }


##################################################################################
# Confluent setup
##################################################################################

function installConfluent() 
{

    # http://docs.confluent.io/3.1.2/installation.html
    # lot of effort to get a kafka client... 
    # will be installed here... /usr/share/java/kafka

    sudo rpm --import http://packages.confluent.io/rpm/3.1/archive.key
    sudo su - -c "cat > /etc/yum.repos.d/confluent.repo << EOFrepo    
[Confluent.dist]
name=Confluent repository (dist)
baseurl=http://packages.confluent.io/rpm/3.1/7
gpgcheck=1
gpgkey=http://packages.confluent.io/rpm/3.1/archive.key
enabled=1

[Confluent]
name=Confluent repository
baseurl=http://packages.confluent.io/rpm/3.1
gpgcheck=1
gpgkey=http://packages.confluent.io/rpm/3.1/archive.key
enabled=1

EOFrepo
"
    sudo yum clean all
    sudo yum -y install confluent-platform-2.11
}


function confluentProps() {

    local l_function_name=confluentProps
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    cat > $l_tmp_script << EOFcp

    cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm
    
    cat > conflt.props << EOFcp1
gg.handlerlist=confluent
gg.handler.confluent.type=oracle.goldengate.kafkaconnect.KafkaConnectHandler
gg.handler.confluent.kafkaProducerConfigFile=confluent.properties
gg.handler.confluent.mode=tx
gg.handler.confluent.sourceRecordGeneratorClass=oracle.goldengate.kafkaconnect.DefaultSourceRecordGenerator
gg.handler.confluent.format=oracle.goldengate.kafkaconnect.formatter.KafkaConnectFormatter
gg.handler.confluent.format.insertOpKey=I
gg.handler.confluent.format.updateOpKey=U
gg.handler.confluent.format.deleteOpKey=D
gg.handler.confluent.format.treatAllColumnsAsStrings=false
gg.handler.confluent.format.iso8601Format=false
gg.handler.confluent.format.pkUpdateHandling=abend
goldengate.userexit.timestamp=utc
goldengate.userexit.writers=javawriter
javawriter.stats.display=TRUE
javawriter.stats.full=TRUE
gg.log=log4j
gg.log.level=INFO
gg.report.time=30sec
# /usr/share/java/kafka-connect-hdfs/ has everything in it
gg.classpath=dirprm/:/u01/app/oracle/product/12.3.0/ogg4bd/ggjava/resources/lib/*:/usr/share/java/kafka/*:/u01/kafka-connect/bin/ogg-kafka-connect-1.0.jar:/usr/share/java/kafka-connect-hdfs/*
javawriter.bootoptions=-Xmx512m -Xms32m -Djava.class.path=.:./ggjava/ggjava.jar:./dirprm
EOFcp1

EOFcp

    sudo su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}

}


function confluentProperties() {

    local l_function_name=confluentProperties
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    cat > $l_tmp_script << EOFcprop

cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm

cat > confluent.properties << EOFcprop1
bootstrap.servers=${bootstrapServers}
# value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
# key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
value.serializer=io.confluent.kafka.serializers.KafkaAvroSerializer
key.serializer=io.confluent.kafka.serializers.KafkaAvroSerializer
schema.registry.url=${schemaRegistry}
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter=org.apache.kafka.connect.json.JsonConverter
EOFcprop1

EOFcprop

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
}

function irconflt() {

    local l_function_name=irconflt
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    cat > $l_tmp_script << EOFrk

    cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm
    
    cat > irconflt.prm << EOFrk1
SPECIALRUN
END RUNTIME
EXTFILE /u01/app/oracle/product/12.3.0/ogg4bd/dirdat/initld
--
TARGETDB LIBFILE libggjava.so SET property=dirprm/conflt.props
SOURCECHARSET AL32UTF8
REPORTCOUNT EVERY 1 MINUTES, RATE
GROUPTRANSOPS 10000
MAP ${pdbName}.ade.*, TARGET bd.*;
EOFrk1

cd /u01/app/oracle/product/12.3.0/ogg4bd
./replicat paramfile dirprm/irconflt.prm reportfile dirrpt/irconflt.rpt
    
EOFrk

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
}


function rconflt1() {

    local l_function_name=rconflt1
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    
    cat > $l_tmp_script << EOFrk

    cd /u01/app/oracle/product/12.3.0/ogg4bd/dirprm

    cat > rconflt1.prm << EOFrk1
REPLICAT rconflt1
-- Command to add REPLICAT
-- add replicat rconflt1, exttrail /u01/app/oracle/product/12.3.0/ogg4bd/dirdat/ss
TARGETDB LIBFILE libggjava.so SET property=/u01/app/oracle/product/12.3.0/ogg4bd/dirprm/conf.props
REPORTCOUNT EVERY 1 MINUTES, RATE
GROUPTRANSOPS 10000
MAP ${pdbName}.ade.*, TARGET bd.*;
EOFrk1

EOFrk

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
}

function run()
{
    eval `grep platformEnvironment $INI_FILE`
    if [ -z $platformEnvironment ]; then    
        fatalError "$g_prog.run(): Unknown environment, check platformEnvironment setting in iniFile"
    elif [ $platformEnvironment != "AZURE" ]; then    
        fatalError "$g_prog.run(): platformEnvironment=AZURE is the only valid setting currently"
    fi
    
    eval `grep bootstrapServers $INI_FILE`
    eval `grep schemaRegistry $INI_FILE`
    eval `grep pdbName $INI_FILE`

    l_str=""
    if [ -z $bootstrapServers ]; then
        l_str+="bootstrapServers not found in $INI_FILE; "
    fi
    if [ -z $schemaRegistry ]; then
        l_str+="schemaRegistry not found in $INI_FILE; "
    fi
    if [ -z $pdbName ]; then
        l_str+="pdbName not found in $INI_FILE; "
    fi
    if ! [ -z $l_str ]; then
        fatalError "ogg4bd-testsuite(): $l_str"
    fi

    # function calls
    #installDocker
    # createTopics
    # customKafkaProducer
    # kafka.props
    # rkafka
    installConfluent
    confluentProps
    confluentProperties
    irconflt
    rconflt1
    
}


######################################################
## Main Entry Point
######################################################

log "$g_prog starting"
log "STAGE_DIR=$STAGE_DIR"
log "LOG_DIR=$LOG_DIR"
log "INI_FILE=$INI_FILE"
log "LOG_FILE=$LOG_FILE"
echo "$g_prog starting, LOG_FILE=$LOG_FILE"

if [[ $EUID -ne 0 ]]; then
    fatalError "$THIS_SCRIPT must be run as root"
    exit 1
fi

INI_FILE_PATH=$1

if [[ -z $INI_FILE_PATH ]]; then
    fatalError "${g_prog} called with null parameter, should be the path to the driving ini_file"
fi

if [[ ! -f $INI_FILE_PATH ]]; then
    fatalError "${g_prog} ini_file cannot be found"
fi

if ! mkdir -p $LOG_DIR; then
    fatalError "${g_prog} cant make $LOG_DIR"
fi

chmod 777 $LOG_DIR

cp $INI_FILE_PATH $INI_FILE

run

log "$g_prog ended cleanly"
exit $RETVAL

