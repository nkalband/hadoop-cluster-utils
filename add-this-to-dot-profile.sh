
export PATH=$HOME/hadoop-cluster-utils/utils:$HOME/hadoop-cluster-utils/hadoop:$PATH

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-ppc64el 
export HADOOP_HOME=$HOME/hadoop-2.6.5


export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop


# Some convenient aliases and functions for running Hadoop-related commands
unalias fs &> /dev/null
alias fs="hadoop fs"
unalias hls &> /dev/null
alias hls="fs -ls"

