# Hadoop and Yarn Setup

## 1. set passwordless login

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
wget http://mirror.fibergrid.in/apache/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz
tar xvf hadoop-2.7.1.tar.gz --gzip
```

## 3. Update slaves file

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
 3. copy .bashrc to all other data nodes
  
  ``` 
  CP $HOME/.bashrc $HOME
  ```


## 5. Install Hadoop on all nodes
```
CP $HOME/hadoop-2.7.1.tar.gz $HOME
DN "tar xvf hadoop-2.7.1.tar.gz --gzip"
```

## 6. HDFS configuration

You need to modify the following 2 config files for HDFS

1. core-site.xml #Hostname for the Name node
  ```
  cp hadoop-cluster-utils/conf/core-site.xml.template core-site.xml
  vi core-site.xml
  cp core-site.xml $HADOOP_HOME/etc/hadoop
  CP core-site.xml $HADOOP_HOME/etc/hadoop
  ```
  
2. hdfs-site.xml 

  create local dir in name node for meta-data
  
  ``` mkdir -p /data/user/hdfs-meta-data ```
  
  create local dir in all data-nodes for hdfs-data 
  
  ``` DN "mkdir -p /data/user/hdfs-data" ```

  update dir path
  ```
  cp hadoop-cluster-utils/conf/hdfs-site.xml.template hdfs-site.xml
  vi hdfs-site.xml #update dir path
  ```
  Copy the files to all nodes
  
  ```
  cp hdfs-site.xml $HADOOP_HOME/etc/hadoop
  CP hdfs-site.xml $HADOOP_HOME/etc/hadoop
   ```

3. Format and Start HDFS 

```
$HADOOP_PREFIX/bin/hdfs namenode -format mycluster
start-hdfs.sh
AN jps 
# use stop-hdfs.sh for stopping
```

4. Verify HDFS is up and running..

 http://localhost:50070

