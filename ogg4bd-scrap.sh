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

