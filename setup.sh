#!/bin/bash -l

# Need to create user manually
# Need to set JAVA_HOME in .bashrc files on all machines
# Need to complete ssh setup for all servers

ul=`tput smul`
nul=`tput rmul`

CURDIR=`pwd`            # Inside hadoop-cluster-utils directory where run.sh is exist
WORKDIR=${HOME}         # where hadoop and spark package will download 

current_time=$(date +"%Y.%m.%d.%S")

if [ ! -d $CURDIR/logs ];
then
    mkdir logs
fi

log=`pwd`/logs/hadoop_cluster_utils_$current_time.log
echo -e | tee -a $log
if [[ -n "$JAVA_HOME" ]]
then
    echo JAVA_HOME found on MASTER, java executable in $JAVA_HOME | tee $log
    echo "---------------------------------------------" | tee -a $log
else
    echo "JAVA_HOME not found in your environment, please set the JAVA_HOME variable in your environment then continue to run this script." | tee -a $log
    exit 1 
fi

grep '#case $- in' $HOME/.bashrc &>>/dev/null
 if [ $? -ne 0 ]
then
    grep 'case $- in' $HOME/.bashrc &>>/dev/null
	if [ $? -eq 0 ]
	then 
        echo 'Prerequisite not completed on Master. Please comment below lines in .bashrc file , also make sure same on slave machines' | tee -a $log
        echo "# If not running interactively, don't do anything" | tee -a $log
        echo "case \$- in" | tee -a $log
        echo "*i*) ;;" | tee -a $log
        echo "*) return;;" | tee -a $log
        echo "esac" | tee -a $log
	    exit 1
	fi	
fi

##Checking if wget and curl installed or not, and getting installed if not

if [ ! -x /usr/bin/wget ] ; then
   echo "wget is not installed on Master, so getting installed" | tee -a $log
   sudo apt-get install wget | tee -a $log
else
   echo "wget is already installed on Master" | tee -a $log
fi

if [ ! -x /usr/bin/curl ] ; then
   echo "curl is not installed on Master, so getting installed" | tee -a $log
   sudo apt-get install curl | tee -a $log
else
   echo "curl is already installed on Master" | tee -a $log
fi

## Validation for config file

if [ -f ${CURDIR}/config.sh ]; 
then
    ## First time permission set for config.sh file
    chmod +x config.sh
    source config.sh
 
    ## Checking config file for all required fields
  
    { cat ${CURDIR}/config.sh; echo; } | while read -r line; do
      if [[ $line =~ "=" ]] ;
      then
          confvalue=`echo $line |grep = | cut -d "=" -f2`
          if [[ -z "$confvalue" ]];
          then
              echo "Configuration vlaue not set properly for $line, please check config.sh file" | tee -a $log
              exit 1
          fi
      fi
    done

    ## Validation for hadoop port instances

    declare -a port_name=("NAMENODE_PORT" "NAMENODE_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTPS_ADDRESS" "DATANODE_ADDRESS" "DATANODE_HTTP_ADDRESS" "DATANODE_IPC_ADDRESS" "MAPREDUCE_JOBHISTORY_ADDRESS" "MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "RESOURCEMANAGER_SCHEDULER_ADDRESS" "RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "RESOURCEMANAGER_ADDRESS" "RESOURCEMANAGER_ADMIN_ADDRESS" "RESOURCEMANAGER_WEBAPP_ADDRESS" "NODEMANAGER_LOCALIZER_ADDRESS" "NODEMANAGER_WEBAPP_ADDRESS" "SPARKHISTORY_HTTP_ADDRESS")

    declare -a port_list=("$NAMENODE_PORT" "$NAMENODE_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTPS_ADDRESS" "$DATANODE_ADDRESS" "$DATANODE_HTTP_ADDRESS" "$DATANODE_IPC_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "$RESOURCEMANAGER_SCHEDULER_ADDRESS" "$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "$RESOURCEMANAGER_ADDRESS" "$RESOURCEMANAGER_ADMIN_ADDRESS" "$RESOURCEMANAGER_WEBAPP_ADDRESS" "$NODEMANAGER_LOCALIZER_ADDRESS" "$NODEMANAGER_WEBAPP_ADDRESS" "$SPARKHISTORY_HTTP_ADDRESS")

    i=0
    for j in "${port_list[@]}";
    do
      sudo netstat -pnlt | grep $j > /dev/null
      if [ $? -eq 0 ];
      then
          echo "${port_name[i]} running on port $j" >> temp
      fi
      i=$i+1
    done

    if [ -f temp ];
    then
        cat temp
        cat temp >> $log
        echo "Kindly kill above running instance(s) else change port number in config.sh file, then continue to run this script." | tee -a $log
        rm temp &>/dev/null 
        exit 1
    fi
   
    ## Adding slave machine names to slave file
    cat ${CURDIR}/config.sh | grep SLAVES | grep -v "^#" |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1  >${CURDIR}/conf/slaves 


    
    SLAVES=`cat ${CURDIR}/config.sh | grep SLAVES | grep -v "^#" |cut -d "=" -f2`
    
    cat ${CURDIR}/config.sh | grep SLAVES | grep -v "^#" | tr "%" "\n" | grep "$MASTER" &>>/dev/null
    if [ $? -eq 0 ]
    then
	    #if master is also used as data machine 
        SERVERS=$SLAVES
    else
	    ## Getting details for Master machine
 
        freememory_master="$(free -m | awk '{print $4}'| head -2 | tail -1)"
        memorypercent_master=$(awk "BEGIN { pc=80*${freememory_master}/100; i=int(pc); print (pc-i<0.5)?i:i+1 }")
        ncpu_master="$(nproc --all)"
        MASTER_DETAILS=''$MASTER','$ncpu_master','$memorypercent_master''
        SERVERS=`echo ''$MASTER_DETAILS'%'$SLAVES''`
    fi
     
    ## Validation for Slaves IPs
    echo -e "${ul}Validation for slave IPs${nul}" | tee -a $log
    while IFS= read -r ip; do
         if ping -q -c2 "$ip" &>/dev/null;
         then
             echo "$ip is Pingable" | tee -a $log
         else
             echo "$ip Not Pingable" | tee -a $log
             echo 'Please check your config.sh file. '$ip' is not pingalbe. \n' | tee -a $log
         exit 1
         fi
    done <${CURDIR}/conf/slaves

  
    ## Download and install hadoop For Master machine installation
  
    echo "---------------------------------------------" | tee -a $log
    echo "${ul}Downloading and installing hadoop...${nul}" | tee -a $log
	echo -e | tee -a $log
    cd ${WORKDIR}
    if [ ! -f ${WORKDIR}/hadoop-${hadoopver}.tar.gz ];
    then
        if curl --output /dev/null --silent --head --fail $HADOOP_URL
        then
            echo 'Hadoop file Downloading on Master- '$MASTER'' | tee -a $log
	        wget $HADOOP_URL | tee -a $log
        else
            echo "This URL Not Exist. Please check your hadoop version then continue to run this script." | tee -a $log
            exit 1
        fi 
    fi	

	  
    ## Copying hadoop tgz file , unzipping and exporting paths in the .bashrc file on all machines
		  	  
	for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
	do 
	  
	    if [ $i != $MASTER ]
	    then
	      echo 'Copying Hadoop setup file on '$i'' | tee -a $log
	      scp ${WORKDIR}/hadoop-${hadoopver}.tar.gz @$i:${WORKDIR} | tee -a $log
	    fi
        echo 'Unzipping Hadoop setup file on '$i'' | tee -a $log	  
	    ssh $i "tar xf hadoop-${hadoopver}.tar.gz --gzip" 
	 
         echo 'Updating hadoop variables on '$i'' | tee -a $log
		 
	     export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}
	     echo "#StartHadoopEnv"> tmp_b
         echo "export CURDIR="${CURDIR}"" >> tmp_b
         echo "export PATH="${CURDIR}":"${CURDIR}"/hadoop:\$PATH" >> tmp_b 
		 echo "export PATH="${CURDIR}":"${CURDIR}"/utils:\$PATH" >> tmp_b
         echo "export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}" >> tmp_b
         echo "export HADOOP_PREFIX=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_MAPRED_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_COMMON_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_HDFS_HOME=$HADOOP_HOME" >> tmp_b
         echo "export YARN_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export PATH=$HADOOP_HOME/bin:\$PATH" >> tmp_b
         echo "#StopHadoopEnv">> tmp_b
	 
	  scp tmp_b @$i:${WORKDIR} &>>/dev/null
	 
	  ssh $i "grep -q '#StartHadoopEnv' $HOME/.bashrc"
	  if [ $? -ne 0 ];
      then
	      ssh $i "cat tmp_b>>$HOME/.bashrc"
		  ssh $i "rm tmp_b"
      else
          ssh $i "sed -i '/#StartHadoopEnv/,/#StopHadoopEnv/d' $HOME/.bashrc"
          ssh $i "cat tmp_b>>$HOME/.bashrc"
		  ssh $i "rm tmp_b"
      fi
	  echo 'Sourcing updated .bashrc file on '$i'' | tee -a $log
	  ssh $i "source ~/.bashrc" &>>/dev/null
	  echo "---------------------------------------------" | tee -a $log
   done
   rm -rf tmp_b
	
	
	## Configuration changes in hadoop-clusterfor Core-site,hdfs-site and mapred-site xml
	
    echo 'Updating configuration properties in hadoop-cluster CURDIR for Core-site,hdfs-site and mapred-site xml ' | tee -a $log

    if [ ! -f ${CURDIR}/conf/core-site.xml ];
    then
	    #Copying xml templates for editing 
        cp ${CURDIR}/conf/core-site.xml.template ${CURDIR}/conf/core-site.xml
        cp ${CURDIR}/conf/hdfs-site.xml.template ${CURDIR}/conf/hdfs-site.xml
        cp ${CURDIR}/conf/mapred-site.xml.template ${CURDIR}/conf/mapred-site.xml
                  
       
        #core-site.xml configuration configuration properties
        sed -i 's|HADOOP_TMP_DIR|'"$HADOOP_TMP_DIR"'|g' ${CURDIR}/conf/core-site.xml
        sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/core-site.xml
        sed -i 's|NAMENODE_PORT|'"$NAMENODE_PORT"'|g' ${CURDIR}/conf/core-site.xml
		 
           
        # hdfs-site.xml configuration properties
        sed -i 's|REPLICATION_VALUE|'"$REPLICATION_VALUE"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_DIR|'"$NAMENODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_DIR|'"$DATANODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_HTTP_ADDRESS|'"$NAMENODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_SECONDARY_HTTP_ADDRESS|'"$NAMENODE_SECONDARY_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_SECONDARY_HTTPS_ADDRESS|'"$NAMENODE_SECONDARY_HTTPS_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_ADDRESS|'"$DATANODE_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_HTTP_ADDRESS|'"$DATANODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_IPC_ADDRESS|'"$DATANODE_IPC_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml

  
        # mapred-site.xml configuration properties
        sed -i 's|MAPREDUCE_JOBHISTORY_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
        sed -i 's|MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
        sed -i 's|MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS|'"$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
  
    fi  
      
   
    echo "---------------------------------------------" | tee -a $log

    ## yarn-site.xml configuration properties and hadoop-env.sh file updates for all machines

  	for i in `echo $SERVERS  |cut -d "=" -f2 | tr "%" "\n" `
    do
	 
      memorypercent=`echo $i| cut -d "," -f3`	
	  ncpu=`echo $i| cut -d "," -f2`
	  slaveip=`echo $i| cut -d "," -f1`
		 
	  echo 'Updating configuration properties for yarn-sites and hadoop.env.sh for '$slaveip'' | tee -a $log
		 
	  cp ${CURDIR}/conf/yarn-site.xml.template ${CURDIR}/conf/yarn-site.xml
	  
	  sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_MB|'"$YARN_SCHEDULER_MIN_ALLOCATION_MB"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_MB|'"$memorypercent"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_VCORES|'"$YARN_SCHEDULER_MIN_ALLOCATION_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_NODEMANAGER_RESOURCE_CPU_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|YARN_NODEMANAGER_RESOURCE_MEMORY_MB|'"$memorypercent"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|0.0.0.0:RESOURCEMANAGER_SCHEDULER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_SCHEDULER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_ADMIN_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_WEBAPP_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|NODEMANAGER_LOCALIZER_ADDRESS|'"$NODEMANAGER_LOCALIZER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|NODEMANAGER_WEBAPP_ADDRESS|'"$NODEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
		 
		 
	  scp ${CURDIR}/conf/*site.xml @$slaveip:$HADOOP_HOME/etc/hadoop | tee -a $log
		 
	  ## Updating java version in hadoop-env.sh file on all machines
		 
	  JAVA_HOME_SLAVE=$(ssh $slaveip 'grep JAVA_HOME ~/.bashrc | grep -v "PATH" | cut -d"=" -f2')
	  echo "sed -i 's|"\${JAVA_HOME}"|"${JAVA_HOME_SLAVE}"|g' $HADOOP_HOME/etc/hadoop/hadoop-env.sh" | ssh $slaveip bash
      echo "---------------------------------------------" | tee -a $log
	  
    done	 
	rm -rf ${CURDIR}/conf/*site.xml
 	
    ##Updating the slave file on master 
 
    cp ${CURDIR}/conf/slaves ${HADOOP_HOME}/etc/hadoop
     
else
    echo "Config file does not exist. Please check README.md for installation steps." | tee -a $log
    exit 1
fi  

##Spark installation

echo "${ul}Downloading and installing Spark...${nul}" | tee -a $log

cd ${WORKDIR}

if [ ! -f ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz ];
then
    if curl --output /dev/null --silent --head --fail $SPARK_URL
    then
	    echo 'SPARK file Downloading on Master - '$MASTER'' | tee -a $log
        wget $SPARK_URL | tee -a $log
    else 
        echo "This URL Not Exist. Please check your spark version then continue to run this script." | tee -a $log
        exit 1
    fi 
echo "***********************************************"
fi

## Exporting SPARK_HOME to the PATH and Add scripts to the PATH

for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
do
    if [ $i != $MASTER ]
	then
	    echo 'Copying Spark setup file on '$i'' | tee -a $log
	    scp ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz @$i:${WORKDIR} | tee -a $log
	fi
	echo 'Unzipping Spark setup file on '$i'' | tee -a $log
    ssh $i "tar xf spark*.tgz --gzip" | tee -a $log	
	
	echo 'Updating .bashrc file on '$i' with Spark variables '	
	echo '#StartSparkEnv' >tmp_b
	echo "export SPARK_HOME="${WORKDIR}"/spark-"${sparkver}"-bin-hadoop"${hadoopver:0:3}"" >>tmp_b
	echo "export PATH=\$SPARK_HOME/bin:\$PATH">>tmp_b
	echo '#StopSparkEnv'>>tmp_b
		
	scp tmp_b @$i:${WORKDIR}&>>/dev/null
		
	ssh $i "grep -q "SPARK_HOME" ~/.bashrc"
	if [ $? -ne 0 ];
	then
	    ssh $i "cat tmp_b>>$HOME/.bashrc"
	    ssh $i "rm tmp_b"
	else
	    ssh $i "sed -i '/#StartSparkEnv/,/#StopSparkEnv/ d' $HOME/.bashrc"
	    ssh $i "cat tmp_b>>$HOME/.bashrc"
		ssh $i "rm tmp_b"
	fi

	ssh $i "source $HOME/.bashrc"
		
done
rm -rf tmp_b
echo "---------------------------------------------" | tee -a $log	

## updating Slave file for Spark folder
source ${HOME}/.bashrc
echo 'Updating Slave file for Spark setup'| tee -a $log

cp spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves.template spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
sed -i 's|localhost||g' spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
cat ${CURDIR}/conf/slaves>>spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves

echo -e "Configuring Spark history server" | tee -a $log

cp $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf
grep -q "#StartSparkconf" $SPARK_HOME/conf/spark-defaults.conf 
if [ $? -ne 0 ];
then
    echo "#StartSparkconf" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.enabled   true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.dir       /tmp/${USER}/spark-events" >> $SPARK_HOME/conf/spark-defaults.conf 
    echo "spark.eventLog.compress  true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.history.fs.logDirectory   /tmp/${USER}/spark-events-history" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "#StopSparkconf">> $SPARK_HOME/conf/spark-defaults.conf
else
    sed -i '/#StartSparkconf/,/#StopSparkconf/ d' $SPARK_HOME/conf/spark-defaults.conf
    echo "#StartSparkconf" >> $SPARK_HOME/conf/spark-defaults.conf 
    echo "spark.eventLog.enabled   true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.dir       /tmp/${USER}/spark-events" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.compress  true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.history.fs.logDirectory   /tmp/${USER}/spark-events-history" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "#StopSparkconf">> $SPARK_HOME/conf/spark-defaults.conf
fi

CP $SPARK_HOME/conf/spark-defaults.conf $SPARK_HOME/conf &>/dev/null

echo -e "Spark installation done..!!\n" | tee -a $log

##to start hadoop setup

if [ ! -d "$HADOOP_TMP_DIR" ]
then
    # Creating directories
     AN "mkdir -p $HADOOP_TMP_DIR" &>/dev/null
     AN "mkdir -p $NAMENODE_DIR" &>/dev/null
     AN "mkdir -p $DATANODE_DIR" &>/dev/null
     AN "mkdir -p /tmp/${USER}/spark-events" &>/dev/null
     AN "mkdir -p /tmp/${USER}/spark-events-history" &>/dev/null
     echo "Finished creating directories"
else 
     AN "rm -rf /tmp/${USER}/*" &>/dev/null
	 AN "rm -rf /tmp/${USER}/spark-events" &>/dev/null
	 AN "rm -rf /tmp/${USER}/spark-events-history" &>/dev/null
	 AN "mkdir -p $HADOOP_TMP_DIR" &>/dev/null
     AN "mkdir -p $NAMENODE_DIR" &>/dev/null
     AN "mkdir -p $DATANODE_DIR" &>/dev/null
     AN "mkdir -p /tmp/${USER}/spark-events" &>/dev/null
     AN "mkdir -p /tmp/${USER}/spark-events-history" &>/dev/null
     echo "Finished creating directories"
fi        

echo 'Formatting NAMENODE'| tee -a $log

$HADOOP_PREFIX/bin/hdfs namenode -format mycluster >> $log
echo -e | tee -a $log
$CURDIR/hadoop/start-all.sh | tee -a $log
echo -e | tee -a $log
$CURDIR/utils/checkall.sh | tee -a $log

## use stop-all.sh for stopping

echo -e | tee -a $log
echo "${ul}Web URL link${nul}" | tee -a $log
echo "HDFS web address : http://"$MASTER":"$NAMENODE_HTTP_ADDRESS"" | tee -a $log
echo "Resource Manager : http://"$MASTER":"$RESOURCEMANAGER_WEBAPP_ADDRESS"/cluster" | tee -a $log
echo "SPARK history server : http://"$MASTER":"$SPARKHISTORY_HTTP_ADDRESS"" | tee -a $log
echo -e | tee -a $log

echo "---------------------------------------------" | tee -a $log	
echo "${ul}Ensure SPARK running correctly using following command${nul}" | tee -a $log
echo "${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10" | tee -a $log
echo -e 
source ${HOME}/.bashrc
read -p "Do you wish to run above command ? [y/N] " prompt


if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
  ${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10 &>> $log
  
else
  echo "Thanks for your response"
fi

echo -e | tee -a $log
echo "---------------------------------------------" | tee -a $log	
grep -r 'Pi is roughly' ${log}
if [ $? -eq 0 ];
then
   echo 'Spark services running.' | tee -a $log
   echo 'Please check log file '$log' for more details.'
else
   echo 'Expected output not found.' | tee -a $log
   echo 'Please check log file '$log' for more details'
fi
echo -e