# Hadoop and Yarn Setup

## 1. set passwordless login

To create user
```
sudo adduser testuser
sudo adduser testuser sudo
```

For local host

```
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa 
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
 ```
For other hosts

```
ssh-copy-id -i ~/.ssh/id_rsa.pub user@host
ssh user@host
```
## 2. Download and install hadoop

http://hadoop.apache.org/releases.html#Download

```
#Choose the right mirror, below link is for US machines.
wget http://www-us.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz
tar xf hadoop-2.7.3.tar.gz --gzip
export HADOOP_HOME=$HOME/hadoop-2.7.3
```

## 3. Update slaves file

Add data nodes, don't add master node.
```bash
vi $HADOOP_HOME/etc/hadoop/slaves
user@host1
user@host2
```

## 4. Hadoop utils setup
```
git clone https://github.com/kmadhugit/hadoop-cluster-utils.git
cd hadoop-cluster-utils
vi add-this-to-dot-profile.sh #update correct path to env variables.
. add-this-to-dot-profile.sh
```

check whether cluster scripts are working

```
AN hostname
```

Update .bashrc

 1. Delete the following check.
  ```
   # If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac
  ```
  
 2. Read add-this-to-dot-profile.sh at the end of .bashrc

 ```
  vi $HOME/.bashrc
  Gi
  :r $HOME/hadoop-cluster-utils/add-this-to-dot-profile.sh
  G
  set -o vi
 ```
 
 3. copy .bashrc to all other data nodes
  
  ``` 
  CP $HOME/.bashrc $HOME
  ```


## 5. Install Hadoop on all nodes
```
CP $HOME/hadoop-2.7.3.tar.gz $HOME
DN "tar xf hadoop-2.7.3.tar.gz --gzip"
```

## 6. HDFS configuration

You need to modify 2 config files for HDFS

1. core-site.xml #Modify the Hostname for the Name node
  ```
  cd $HOME/hadoop-cluster-utils/conf
  cp core-site.xml.template core-site.xml
  vi core-site.xml
  cp core-site.xml $HADOOP_HOME/etc/hadoop
  CP core-site.xml $HADOOP_HOME/etc/hadoop
  ```
  
2. hdfs-site.xml 

  create local dir in name node for meta-data (
  
  ``` mkdir -p /data/user/hdfs-meta-data ```
  
  create local dir in all data-nodes for hdfs-data 
  
  ``` DN "mkdir -p /data/user/hdfs-data" ```

  update dir path
  ```
  cd $HOME/hadoop-cluster-utils/conf
  cp hdfs-site.xml.template hdfs-site.xml
  vi hdfs-site.xml #update dir path
  ```
  Copy the files to all nodes
  
  ```
  cp hdfs-site.xml $HADOOP_HOME/etc/hadoop
  CP hdfs-site.xml $HADOOP_HOME/etc/hadoop
   ```

3. Start HDFS as fresh FS

 ```
$HADOOP_PREFIX/bin/hdfs namenode -format mycluster
start-hdfs.sh
AN jps 
# use stop-hdfs.sh for stopping
 ```

4. Start HDFS on existing cluster data
 You need to modify ownership to self to use already created data

 ```
 AN "sudo chown user:user /data/hdfs-meta-data"
 AN "sudo chown user:user /data/hdfs-data"
 start-hdfs.sh
 AN jps
 ```

5. HDFS web address 

 ```
 http://localhost:50070
 ```

## 7. Yarn configuration

You need to modify 2 config files for HDFS

1. capacity-scheduler.xml #Modify resource-calculator property to DominantResourceCalculator

  ```bash
  vi $HADOOP_HOME/etc/hadoop/capacity-scheduler.xml
  ```  
  ```xml
    <property>
     <name>yarn.scheduler.capacity.resource-calculator</name>
     <value>org.apache.hadoop.yarn.util.resource.DominantResourceCalculator</value>
    </property>
  ```
2. yarn-site.xml # Modify the properties as per the description provided in the template
  
  ```
  cd $HOME/hadoop-cluster-utils/conf
  cp yarn-site.xml.template yarn-site.xml
  vi yarn-site.xml
  cp yarn-site.xml $HADOOP_HOME/etc/hadoop
  CP yarn-site.xml $HADOOP_HOME/etc/hadoop
  AN jps
  ```
  
3. Start Yarn
 ```
 start-yarn.sh
 AN jps
 ```
 
3. Resource Manager and Node Manager web Address
 ```
 Resource Manager : http://localhost:8088/cluster
 Node Manager     : http://datanode:8042/node (For each node)
 ```
 
## 8. Useful scripts
 
 ```
  > stop-all.sh #stop HDFS and Yarn
  > start-all.sh #start HDFS and Yarn
  > CP <localpath to file> <remotepath to dir> #Copy file from name nodes to all slaves
  > AN <command> #execute a given command in all nodes including master
  > DN <command> #execute a given command in all nodes excluding master
 ```

## 9. Spark Installation.

### a. Download Binary

```
http://spark.apache.org/downloads.html
#Choose the right mirror, below link is for US machines.
wget http://www-us.apache.org/dist/spark/spark-2.0.1/spark-2.0.1-bin-hadoop2.7.tgz
tar -zvf spark-2.0.1-bin-hadoop2.7.tgz
```

### b. Build it yourself

```
git clone https://github.com/apache/spark.git
git checkout -b v2.0.1 v2.0.1
export MAVEN_OPTS="-Xmx32G -XX:MaxPermSize=8G -XX:ReservedCodeCacheSize=2G"
./build/mvn -T40 -Pyarn -Phadoop-2.7 -Dhadoop.version=2.7.3 -Phive -Phive-thriftserver -DskipTests -Dmaven.javadoc.skip=true install
```

### c. Test (pre-built spark version)
```
#Add in ~/.bashrc
export SPARK_HOME=$HOME/spark-2.0.1-bin-hadoop2.7 

. ~/.bashrc

${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi   --master yarn-client --driver-memory 1024M --num-executors 2  --executor-memory 1g  --executor-cores 1   ${SPARK_HOME}/lib/spark-examples-2.0.1-bin-hadoop2.7.jar    10 
```

### d. Test (manual spark build)

```
#Add in ~/.bashrc
export SPARK_HOME=$HOME/spark

. ~/.bashrc

$SPARK_HOME/bin/spark-submit --class org.apache.spark.examples.SparkPi     --master yarn-client --driver-memory 1024M --num-executors 2    --executor-memory 1g     --executor-cores 1  /home/testuser/spark/examples/target/scala-2.11/jars/spark-examples_2.11-2.0.1.jar

```

### e. Enable EventLogging & additional settings by adding the following content to $SPARK_HOME/conf/spark-defaults.conf
```
spark.eventLog.enabled   true
spark.eventLog.dir       /tmp/spark-events
spark.eventLog.compress  true
spark.history.fs.logDirectory   /tmp/spark-events
spark.serializer                 org.apache.spark.serializer.KryoSerializer
```

### f. Start/Stop All Services.

 The below scripts are used to start/stop the following services in an automated way,
 
  - namenode daemon (only on hdfs master)
  - datanode daemon (on all slave nodes)
  - resource manager daemon (only on yarn master)
  - node manager daemon (on all slave nodes)
  - job history server (only on yarn master)
  - Spark history server (on yarn master)

```
 # Start 
 
 start-all.sh
 
 # Stop
 
 stop-all.sh
```


## 10. Spark command line options for Yarn Scheduler.


| Option | Description |
|--------|-------------|
| --num-executors | Total number of executor JVMs to spawn across Yarn Cluster |
| --executor-cores | Total number of cores in each executor JVM |
| --executor-memory | Memory to be allocated for each JVM 1024M/1G|
| --driver-memory | Memory to be allocated for driver JVM |
| --driver-cores  | Total number of vcores for driver JVM |
|   | Total vcores = num-executors * executor-vcores + driver-cores  |
|   | Total Memory = num-executors * executor-memory + driver-memory |  
|--driver-java-options | To pass driver JVM, useful in local mode for profiling |

-----------------------------------------------------------------
