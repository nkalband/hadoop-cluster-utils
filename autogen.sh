#!/bin/bash -l


# Creating new config.sh
echo -en '# Default hdfs configuration properties\n' > config.sh
echo -en 'HADOOP_TMP_DIR=/tmp/'"${USER}"'/app-hadoop\n' >> config.sh
echo -en 'REPLICATION_VALUE=3\n' >> config.sh
echo -en 'NAMENODE_DIR=/tmp/'"${USER}"'/hdfs-meta\n' >> config.sh
echo -en 'DATANODE_DIR=/tmp/'"${USER}"'/hdfs-data\n\n' >> config.sh

echo -en '# Master Details\n' >> config.sh
MASTER=`ifconfig | grep "inet" |head -1 | awk {'print $2'} | cut -f2 -d ":"`
echo -en 'MASTER='$MASTER'\n\n' >> config.sh

echo -en 'Please enter slave IP detail in format slave1IP,slave2IP \n'
read SLAVEIP

echo -en '# Using these format to save SLAVE Details: slave1IP,slave1cpu,slave1memory....\n' >> config.sh
echo -e

j=0
for i in `echo $SLAVEIP |tr ',' ' '`
do
slaveip=$(ssh $i /sbin/ifconfig | grep "inet" |head -1 | awk {'print $2'} | cut -f2 -d ":")
echo -en 'Collecting memory details from SLAVE machine '$slaveip' \n'
freememory=$(ssh $slaveip free -m | awk '{print $4}'| head -2 | tail -1)
memorypercent=$(awk "BEGIN { pc=80*$freememory/100; i=int(pc); print (pc-i<0.5)?i:i+1 }")
ncpu=$(ssh $slaveip nproc --all)
if [ $j -eq 0 ]
then
SLAVE=`echo ''$slaveip','$ncpu','$memorypercent''`
else
SLAVE=`echo ''$SLAVE'%'$slaveip','$ncpu','$memorypercent''`
fi
((j=j+1))
done

echo -en 'SLAVES='$SLAVE'\n\n' >> config.sh

echo -en '#Node Manager properties (Default yarn cpu and memory value for all nodes)\n' >> config.sh	 
echo -en 'YARN_SCHEDULER_MIN_ALLOCATION_MB=128\n' >> config.sh				 
echo -en 'YARN_SCHEDULER_MIN_ALLOCATION_VCORES=1\n\n' >> config.sh
echo -e
echo -en 'Default Spark version : 2.0.1\n'
sparkver="2.0.1"
echo -en 'Default hadoop version : 2.7.1\n'	
hadoopver="2.7.1"

echo -en '#Hadoop and Spark versions and setup zip download urls\n' >> config.sh
echo -e
echo -en 'sparkver='"$sparkver"'\n' >> config.sh
echo -en 'hadoopver='"$hadoopver"'\n\n' >> config.sh

HADOOP_URL="http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz"
SPARK_URL="http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz"

echo -en 'SPARK_URL='$SPARK_URL'\n' >> config.sh
echo -en 'HADOOP_URL='$HADOOP_URL'\n\n' >> config.sh


echo -en '# Default port values\n' >> config.sh

echo -en 'NAMENODE_PORT=9000\n' >> config.sh
echo -en 'NAMENODE_HTTP_ADDRESS=50070\n' >> config.sh
echo -en 'NAMENODE_SECONDARY_HTTP_ADDRESS=50090\n' >> config.sh
echo -en 'NAMENODE_SECONDARY_HTTPS_ADDRESS=50091\n\n' >> config.sh

echo -en 'DATANODE_ADDRESS=50010\n' >> config.sh
echo -en 'DATANODE_HTTP_ADDRESS=50075\n' >> config.sh
echo -en 'DATANODE_IPC_ADDRESS=50020\n\n' >> config.sh

echo -en 'MAPREDUCE_JOBHISTORY_ADDRESS=10020\n' >> config.sh
echo -en 'MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS=10039\n' >> config.sh 
echo -en 'MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS=19883\n\n' >> config.sh

echo -en 'RESOURCEMANAGER_SCHEDULER_ADDRESS=8034\n' >> config.sh
echo -en 'RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS=8039\n' >> config.sh
echo -en 'RESOURCEMANAGER_ADDRESS=8038\n' >> config.sh
echo -en 'RESOURCEMANAGER_ADMIN_ADDRESS=8033\n' >> config.sh
echo -en 'RESOURCEMANAGER_WEBAPP_ADDRESS=8089\n\n' >> config.sh

echo -en 'NODEMANAGER_LOCALIZER_ADDRESS=8043\n' >> config.sh
echo -en 'NODEMANAGER_WEBAPP_ADDRESS=8045\n\n' >> config.sh
echo -en 'SPARKHISTORY_HTTP_ADDRESS=18080\n\n' >> config.sh

echo -e 'Please check configuration (config.sh file) once before run (setup.sh file).'
echo -e 'You can modify hadoop or spark versions in config.sh file'
echo -e
chmod +x config.sh

