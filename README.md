# Hadoop and Yarn Setup

## 1. set passwordless login

For local host

```
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa 
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
 ```
For other hosts

```
ssh b@B mkdir -p .ssh
cat .ssh/id_rsa.pub | ssh b@B 'cat >> .ssh/authorized_keys'
ssh b@B
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
cat add-this-to-dot-profile.sh >> $HOME/.bashrc
. ~ /.bashrc
```

check whether cluster scripts are working

```
AN hostname
```

If you want some code to execute in .bashrc during remote ssh command, 
add it before "If not running interactively, don't do anything"





