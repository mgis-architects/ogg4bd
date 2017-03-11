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
# Confluent setup
##################################################################################

function confluentProps() {

    local l_function_name=confluentProps
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    cat > $l_tmp_script << EOFcp

    cd ${ogg4bdHome}/dirprm
    
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
# gg.log.level=DEBUG
gg.log.level=INFO
gg.report.time=30sec
# /usr/share/java/kafka-connect-hdfs/ has everything in it
gg.classpath=dirprm/:${ogg4bdHome}/ggjava/resources/lib/*:/usr/share/java/kafka/*:/u01/kafka-connect/bin/ogg-kafka-connect-1.0.jar:/usr/share/java/kafka-connect-hdfs/*
javawriter.bootoptions=-Xmx2048m -Xms512m -Djava.class.path=.:./ggjava/ggjava.jar:./dirprm
EOFcp1

EOFcp

    sudo su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}

}


function confluentProperties() {

    local l_function_name=confluentProperties
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    cat > $l_tmp_script << EOFcprop

cd ${ogg4bdHome}/dirprm

cat > confluent.properties << EOFcprop1
bootstrap.servers=${bootstrapServers}
schema.registry.url=${schemaRegistry}
#
value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
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

    cd ${ogg4bdHome}/dirprm
    
    cat > irconflt.prm << EOFrk1
SPECIALRUN
END RUNTIME
EXTFILE ${ogg4bdHome}/dirdat/initld
--
TARGETDB LIBFILE libggjava.so SET property=dirprm/conflt.props
SOURCECHARSET AL32UTF8
REPORTCOUNT EVERY 1 MINUTES, RATE
GROUPTRANSOPS 10000
MAP ${pdbName}.ade.*, TARGET bd.*;
EOFrk1

# cd ${ogg4bdHome}
# ./replicat paramfile dirprm/irconflt.prm reportfile dirrpt/irconflt.rpt
    
EOFrk

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
}


function rconflt1() {

    local l_function_name=rconflt1
    local l_tmp_script=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.${l_function_name}.log
    
    
    cat > $l_tmp_script << EOFrk

    cd ${ogg4bdHome}/dirprm

    cat > rconflt1.prm << EOFrk1
REPLICAT rconflt1
-- Command to add REPLICAT
-- add replicat rconflt1, exttrail ${ogg4bdHome}/dirdat/ss
TARGETDB LIBFILE libggjava.so SET property=${ogg4bdHome}/dirprm/conf.props
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
    eval `grep ogg4bdHome $INI_FILE`

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
    if [ -z $ogg4bdHome ]; then
        l_str+="ogg4bdHome not found in $INI_FILE; "
    fi
    if ! [ -z $l_str ]; then
        fatalError "ogg4bd-testsuite(): $l_str"
    fi

    # function calls
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

