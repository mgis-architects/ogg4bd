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
#    sudo ogg4bd-build.sh ~/ogg4bd-build.ini
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

g_prog=ogg4bd-build
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

function fixSwap()
{
    cat /etc/waagent.conf | while read LINE
    do
        if [ "$LINE" == "ResourceDisk.EnableSwap=n" ]; then
                LINE="ResourceDisk.EnableSwap=y"
        fi

        if [ "$LINE" == "ResourceDisk.SwapSizeMB=2048" ]; then
                LINE="ResourceDisk.SwapSizeMB=14000"
        fi
        echo $LINE
    done > /tmp/waagent.conf
    /bin/cp /tmp/waagent.conf /etc/waagent.conf
    systemctl restart waagent.service
}

function addGroups()
{
    local l_group_list=$LOG_DIR/groups.${g_prog}.lst.$$
    local l_found
    local l_user
    local l_x
    local l_gid
    local l_newgid
    local l_newgname

    cat > $l_group_list << EOFaddGroups
54321 oinstall
EOFaddGroups

    while read l_newgid l_newgname
    do    
    
        local l_found=0
        grep $l_newgid /etc/group | while IFS=: read l_gname l_x l_gid
        do
            if [ $l_gname != $l_newgname ]; then
                fatalError "addGroups(): gid $l_newgid exists with a different group name $l_gname"
            fi
        done
        
        log "addGroups(): /usr/sbin/groupadd -g $l_newgid $l_newgname"
        if ! /usr/sbin/groupadd -g $l_newgid $l_newgname; then 
            log "addGroups() failed on $l_newgid $l_newgname"
        fi
    
    done < $l_group_list   
}

function addUsers()
{

    if ! id -a oracle 2> /dev/null; then
        /usr/sbin/useradd -u 54321 -g oinstall oracle -p c6kTxMi2LR1l2
    else
        fatalError "addUsers(): user 54321/oracle already exists"
    fi
}

function addLimits()
{
    local l_mem

    cp /etc/security/limits.conf /etc/security/limits.conf.preDB
    
    # at least 90 percent of the current RAM
    let l_mem=`grep MemTotal /proc/meminfo | awk '{print $2}'`*91/100

    cat >> /etc/security/limits.conf << EOFaddLimits
oracle           soft    nproc     16384
oracle           hard    nproc     16384
oracle           soft    nofile    65536
oracle           hard    nofile    65536
oracle           soft    stack     10240
oracle           hard    stack     10240
oracle           soft    memlock  $l_mem
oracle           hard    memlock  $l_mem
EOFaddLimits
}

function addPam()
{

    cp /etc/pam.d/login /etc/pam.d/login.pre.$$
    
    cat >> /etc/pam.d/login << EOFaddPam
# Doc ID 1529864.1
session    required     pam_limits.so
EOFaddPam

}

function makeFolders()
{
    local l_error=0
    if ! mkdir -p /u01/app/oracle; then l_error=1; fi
    if ! chown oracle:oinstall /u01/app/oracle; then l_error=1; fi
    if ! chmod -R 775 /u01/; then l_error=1; fi
    if [ $l_error -eq 1 ]; then
        fatalError "makeFolders(): error creating folders"
    fi
}

function oracleProfile() 
{
    cat >> /home/oracle/.bashrc << EOForacleProfile1
    if [ -t 0 ]; then
       stty intr ^C
    fi
EOForacleProfile1

    cat >> /home/oracle/.bash_profile << EOForacleProfile2
    umask 022
    set -o vi
    export EDITOR=vi
    export TMP=/tmp
    export TMPDIR=/tmp
    export OGG_HOME=${ogg4bdHome}
    export JAVA_HOME=/usr/lib/jvm
    export LD_LIBRARY_PATH=\$JAVA_HOME/jre/lib/amd64/server:$LD_LIBRARY_PATH
    export PATH=$PATH:${ogg4bdHome}
EOForacleProfile2

    chown oracle:oinstall /home/oracle/.bashrc 
    chown oracle:oinstall /home/oracle/.bash_profile
}

createFilesystem()
{
    # createFilesystem /u01 $l_disk $diskSectors  
    # size is diskSectors-128 (offset)

    local p_filesystem=$1
    local p_disk=$2
    local p_sizeInSectors=$3
    local l_sectors
    local l_layoutFile=$LOG_DIR/sfdisk.${g_prog}_install.log.$$
    
    if [ -z $p_filesystem ] || [ -z $p_disk ] || [ -z $p_sizeInSectors ]; then
        fatalError "createFilesystem(): Expected usage mount,device,numsectors, got $p_filesystem,$p_disk,$p_sizeInSectors"
    fi
    
    let l_sectors=$p_sizeInSectors-128
    
    cat > $l_layoutFile << EOFsdcLayout
# partition table of /dev/sdc
unit: sectors

/dev/sdc1 : start=     128, size=  ${l_sectors}, Id= 83
/dev/sdc2 : start=        0, size=        0, Id= 0
/dev/sdc3 : start=        0, size=        0, Id= 0
/dev/sdc4 : start=        0, size=        0, Id= 0
EOFsdcLayout

    set -x # debug has been useful here

    if ! sfdisk $p_disk < $l_layoutFile; then fatalError "createFilesystem(): $p_disk does not exist"; fi
    
    sleep 4 # add a delay - experiencing occasional "cannot stat" for mkfs
    
    log "createFilesystem(): Dump partition table for $p_disk"
    fdisk -l 
    
    if ! mkfs.ext4 ${p_disk}1; then fatalError "createFilesystem(): mkfs.ext4 ${p_disk}1"; fi
    
    if ! mkdir -p $p_filesystem; then fatalError "createFilesystem(): mkdir $p_filesystem failed"; fi
    
    if ! chmod 755 $p_filesystem; then fatalError "createFilesystem(): chmod $p_filesystem failed"; fi
    
    if ! chown oracle:oinstall $p_filesystem; then fatalError "createFilesystem(): chown $p_filesystem failed"; fi
    
    if ! mount ${p_disk}1 $p_filesystem; then fatalError "createFilesystem(): mount $p_disk $p_filesytem failed"; fi

    log "createFilesystem(): Dump blkid"
    blkid
    
    if ! blkid | egrep ${p_disk}1 | awk '{printf "%s\t'${p_filesystem}' \t ext4 \t defaults \t 1 \t2\n", $2}' >> /etc/fstab; then fatalError "createFilesystem(): fstab update failed"; fi

    log "createFilesystem() fstab success: $(grep $p_disk /etc/fstab)"

    set +x    
}

function allocateStorage() 
{
    local l_disk
    local l_size
    local l_sectors
    local l_hasPartition

    for l_disk in /dev/sd? 
    do
         l_hasPartition=$(( $(fdisk -l $l_disk | wc -l) != 6 ? 1 : 0 ))
        # only use if it doesnt already have a blkid or udev UUID
        if [ $l_hasPartition -eq 0 ]; then
            let l_size=`fdisk -l $l_disk | grep 'Disk.*sectors' | awk '{print $5}'`/1024/1024/1024
            let l_sectors=`fdisk -l $l_disk | grep 'Disk.*sectors' | awk '{print $7}'`
            
            if [ $u01_Disk_Size_In_GB -eq $l_size ]; then
                log "allocateStorage(): Creating /u01 on $l_disk"
                createFilesystem /u01 $l_disk $l_sectors
            fi
        fi
    done   
}

function mountMedia() {

    if [ -f /mnt/software/ogg4bd12201/p24816159_122014_Linux-x86-64.zip ]; then
    
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

installOgg4bd()
{
    local l_installdir=${ogg4bdHome}
    local l_media=${ogg4bdMedia}
    local l_tmp_script=$LOG_DIR/$g_prog.installOgg4bd.$$.sh
    local l_log=$LOG_DIR/$g_prog.ogg4bdTestSuite.$$.installOgg4bd.log
    
    if [ ! -f ${l_media} ]; then
        fatalError "installGridHome(): media missing ${l_media}"
    fi

    cat > $l_tmp_script << EOFogg4bd

    mkdir -p ${l_installdir}
    
    cd ${l_installdir}
    
    unzip ${l_media}
    
    tar -xf ggs_Adapters_Linux_x64.tar
    
    rm -f ggs_Adapters_Linux_x64.tar
    
    ./ggsci  << EOFggscia
       CREATE SUBDIRS 
EOFggscia

    echo "PORT ${ogg4bdMgrPort}" > ${l_installdir}/dirprm/mgr.prm
    
    ./ggsci  << EOFggscib
        START MGR 
EOFggscib

    sleep 3
    
    ./ggsci  << EOFggscic
        INFO MGR 
EOFggscic

EOFogg4bd

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

    cp /u01/kafka-connect/bin/ogg-kafka-connect-1.0.jar ${ogg4bdHome}/ggjava/resources/lib
    
    su - oracle -c "bash -x $l_tmp_script" |tee ${l_log}
}

function installConfluent() 
{
    confluentVersion=3.0
    # confluentVersion=3.1

    # http://docs.confluent.io/3.0.1/installation.html
    # http://docs.confluent.io/3.1.2/installation.html
    # lot of effort to get a kafka client... 
    # will be installed here... /usr/share/java/kafka
    # sudo yum -y remove confluent-platform-2.11

    sudo rpm --import http://packages.confluent.io/rpm/${confluentVersion}/archive.key
    sudo su - -c "cat > /etc/yum.repos.d/confluent.repo << EOFrepo    
[Confluent.dist]
name=Confluent repository (dist)
baseurl=http://packages.confluent.io/rpm/${confluentVersion}/7
gpgcheck=1
gpgkey=http://packages.confluent.io/rpm/${confluentVersion}/archive.key
enabled=1

[Confluent]
name=Confluent repository
baseurl=http://packages.confluent.io/rpm/${confluentVersion}
gpgcheck=1
gpgkey=http://packages.confluent.io/rpm/${confluentVersion}/archive.key
enabled=1

EOFrepo
"
    sudo yum clean all
    sudo yum -y install confluent-platform-2.11
}

function openFirewall() {
    firewall-cmd --zone=public --add-port=${ogg4bdMgrPort}/tcp --permanent
    firewall-cmd --zone=public --add-port=${ogg4bdMgrPortRange}/tcp --permanent
    firewall-cmd --reload
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
    eval `grep ogg4bdMgrPortRange $INI_FILE`
    eval `grep ogg4bdHome $INI_FILE`
    eval `grep u01_Disk_Size_In_GB $INI_FILE`
    eval `grep ogg4bdMedia $INI_FILE`

    l_str=""
    if [ -z $ogg4bdMgrPort ]; then
        l_str+="ogg4bdMgrPort not found in $INI_FILE; "
    fi
    if [ -z $ogg4bdMgrPortRange ]; then
        l_str+="ogg4bdMgrPortRange not found in $INI_FILE; "
    fi
    if [ -z $ogg4bdHome ]; then
        l_str+="ogg4bdHome not found in $INI_FILE; "
    fi
    l_str=""
    if [ -z $u01_Disk_Size_In_GB ]; then
        l_str+="asmStorage(): u01_Disk_Size_In_GB not found in $INI_FILE; "
    fi
    if [ -z $ogg4bdMedia ]; then
        l_str+="asmStorage(): ogg4bdMedia not found in $INI_FILE; "
    fi
    if ! [ -z $l_str ]; then
        fatalError "$g_prog(): $l_str"
    fi
    
    # function calls
    fixSwap
    installRPMs 
    addGroups
    addUsers
    addLimits
    addPam
    allocateStorage
    makeFolders
    oracleProfile
    mountMedia
    oracleProfile
    installOgg4bd
    installKakfaConnect
    installConfluent
    openFirewall
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

