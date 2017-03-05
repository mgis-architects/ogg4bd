#!/bin/bash
#########################################################################################
## OGG for Big Data
#########################################################################################
# Installs Oracle Goldengate for Big Data 12.2.0.1.4 on an existing Oracle database 
# built via https://github.com/mgis-architects/terraform/tree/master/azure/oracledb
# This script only supports Azure currently, mainly due to the disk persistence method
#
# USAGE:
#
#    sudo ogg4bd-buildOnExistingDBserver.sh ~/ogg4bd-build.ini
#
# USEFUL LINKS: 
# 
# docs:    http://docs.oracle.com/goldengate/bd123010/gg-bd/index.html
# install: http://docs.oracle.com/goldengate/bd123010/gg-bd/GBDIG/toc.htm
# useful:
#          https://blogs.oracle.com/dataintegration/entry/goldengate_for_big_data_121
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-1-hdfs/
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-2-flume
#          https://www.pythian.com/blog/goldengate-12-2-big-data-adapters-part-3-kafka/
#          https://java.net/downloads/oracledi/GoldenGate/Oracle%20GoldenGate%20Adapter%20for%20Kafka%20Connect/OGG_Kafka_Connect.pdf
#
#########################################################################################

g_prog=ogg4bd-buildOnExistingDBserver
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

function installRPMs()
{
    INSTALL_RPM_LOG=$LOG_DIR/yum.${g_prog}_install.log.$$

    STR=""
    STR="$STR java-1.8.0-openjdk.x86_64"
    
    yum makecache fast
    
    echo "installRPMs(): to see progress tail $INSTALL_RPM_LOG"
    if ! yum -y install $STR > $INSTALL_RPM_LOG
    then
        fatalError "installRPMs(): failed; see $INSTALL_RPM_LOG"
    fi
}


function oracleProfile() 
{
    cat >> /home/oracle/.bash_profile << EOForacleProfile
    export JAVA_HOME=/usr/lib/jvm
    export LD_LIBRARY_PATH=\$JAVA_HOME/jre/lib/amd64/server:$LD_LIBRARY_PATH
    #export PATH=$PATH:/u01/app/oracle/product/12.3.0/ogg4bd
EOForacleProfile
}

function mountMedia() {

    if [ -f /mnt/software/ogg4bd12301/V839824-01.zip ]; then
    
        log "mountMedia(): Filesystem already mounted"
        
    else
    
        umount /mnt/software
    
        mkdir -p /mnt/software
        
        eval `grep mediaStorageAccountKey $INI_FILE`
        eval `grep mediaStorageAccount $INI_FILE`
        eval `grep mediaStorageAccountURL $INI_FILE`

        l_str=""
        if [ -z $mediaStorageAccountKey ]; then
            l_str+="mediaStorageAccountKey not found in $INI_FILE; "
        fi
        if [ -z $mediaStorageAccount ]; then
            l_str+="mediaStorageAccount not found in $INI_FILE; "
        fi
        if [ -z $mediaStorageAccountURL ]; then
            l_str+="mediaStorageAccountURL not found in $INI_FILE; "
        fi
        if ! [ -z $l_str ]; then
            fatalError "mountMedia(): $l_str"
        fi

        cat > /etc/cifspw << EOF1
username=${mediaStorageAccount}
password=${mediaStorageAccountKey}
EOF1

        cat >> /etc/fstab << EOF2
//${mediaStorageAccountURL}     /mnt/software   cifs    credentials=/etc/cifspw,vers=3.0,gid=54321      0       0
EOF2

        mount -a
        
        if [ ! -f /mnt/software/ogg4bd12301/V839824-01.zip ]; then
            fatalError "installGridHome(): media missing /mnt/software/ogg4bd12301/V839824-01.zip"
        fi

    fi
    
}

installOgg4bd122011()
{
    local l_installdir=/u01/app/oracle/product/12.2.0.1.1/ogg4bd
    local l_media=/mnt/software/ogg4bd12201/122011_ggs_Adapters_Linux_x64.zip
    local l_tmp_script=$LOG_DIR/$g_prog.installOgg4bd122011.$$.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.installOgg4bd122011.log
    
    if [ ! -f ${l_media} ]; then
        fatalError "installGridHome(): media missing ${l_media}"
    fi

    cat > $l_tmp_script << EOFogg4bd122

    mkdir -p ${l_installdir}
    
    cd ${l_installdir}
    
    unzip ${l_media}
    
    tar -xf ggs_Adapters_Linux_x64.tar
    
    rm -f ggs_Adapters_Linux_x64.tar
    
    ./ggsci  << EOFggsci122a
       CREATE SUBDIRS 
EOFggsci122a

    echo "PORT ${ogg4bdMgrPort}" > ${l_installdir}/dirprm/mgr.prm
    
    ./ggsci  << EOFggsci122b
        START MGR 
EOFggsci122b

    sleep 3
    
    ./ggsci  << EOFggsci122c
        INFO MGR 
EOFggsci122c

EOFogg4bd122

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}

}

installOgg4bd122014()
{
    local l_installdir=/u01/app/oracle/product/12.2.0.1.4/ogg4bd
    local l_media=/mnt/software/ogg4bd12201/p24816159_122014_Linux-x86-64.zip
    local l_tmp_script=$LOG_DIR/$g_prog.installOgg4bd122014.$$.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.installOgg4bd122014.log
    
    if [ ! -f ${l_media} ]; then
        fatalError "installGridHome(): media missing ${l_media}"
    fi

    cat > $l_tmp_script << EOFogg4bd122014

    mkdir -p ${l_installdir}
    
    cd ${l_installdir}
    
    unzip ${l_media}
    
    tar -xf ggs_Adapters_Linux_x64.tar
    
    rm -f ggs_Adapters_Linux_x64.tar
    
    ./ggsci  << EOFggsci123a
       CREATE SUBDIRS 
EOFggsci123a

    echo "PORT ${ogg4bdMgrPort}" > ${l_installdir}/dirprm/mgr.prm
    
    ./ggsci  << EOFggsci123b
        START MGR 
EOFggsci123b

    sleep 3
    
    ./ggsci  << EOFggsci123c
        INFO MGR 
EOFggsci123c

EOFogg4bd122014

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}

}

installOgg4bd12301()
{
    local l_installdir=/u01/app/oracle/product/12.3.0/ogg4bd
    local l_media=/mnt/software/ogg4bd12301/V839824-01.zip
    local l_tmp_script=$LOG_DIR/$g_prog.installOgg4bd12301.$$.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.installOgg4bd12301.log
    
    if [ ! -f ${l_media} ]; then
        fatalError "installGridHome(): media missing ${l_media}"
    fi

    cat > $l_tmp_script << EOFogg4bd12301

    mkdir -p ${l_installdir}
    
    cd ${l_installdir}
    
    unzip ${l_media}
    
    tar -xf ggs_Adapters_Linux_x64.tar
    
    rm -f ggs_Adapters_Linux_x64.tar
    
    ./ggsci  << EOFggsci123a
       CREATE SUBDIRS 
EOFggsci123a

    echo "PORT ${ogg4bdMgrPort}" > ${l_installdir}/dirprm/mgr.prm
    
    ./ggsci  << EOFggsci123b
        START MGR 
EOFggsci123b

    sleep 3
    
    ./ggsci  << EOFggsci123c
        INFO MGR 
EOFggsci123c

EOFogg4bd12301

    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}

}


function installKakfaConnect()
{
    local l_tmp_script=$LOG_DIR/$g_prog.installKafkaConnect.$$.sh
    local l_log=$LOG_DIR/$g_prog.installKafkaConnect.$$.log

    yum -y install wget
    
    cat > $l_tmp_script << EOFkch
    wget -O /tmp/OGG_KafkaConnectHandlerFormatter1.0.tar https://java.net/projects/oracledi/downloads/download/GoldenGate/Oracle%20GoldenGate%20Adapter%20for%20Kafka%20Connect/OGG_KafkaConnectHandlerFormatter1.0.tar
    cd /u01
    tar xf /tmp/OGG_KafkaConnectHandlerFormatter1.0.tar
EOFkch

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

    eval `grep ogg4bdMgrPort $INI_FILE`

    l_str=""
    if [ -z $ogg4bdMgrPort ]; then
        l_str+="ogg4bdMgrPort not found in $INI_FILE; "
    fi
    if ! [ -z $l_str ]; then
        fatalError "installSimpleSchema(): $l_str"
    fi
    
    # function calls
    installRPMs
    oracleProfile
    mountMedia
    # installOgg4bd122011
    installOgg4bd122014
    # installOgg4bd12301
    installKakfaConnect
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

