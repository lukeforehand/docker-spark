#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}

$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

rm /tmp/*.pid

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

# altering the core-site configuration
sed s/HOSTNAME/$HOSTNAME/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml

# setting spark defaults
echo spark.yarn.jar hdfs:///spark/spark-assembly-1.4.0-hadoop2.6.0.jar > $SPARK_HOME/conf/spark-defaults.conf
printf "*.sink.graphite.class=org.apache.spark.metrics.sink.GraphiteSink\n\
*.sink.graphite.host=$HOSTNAME\n\
*.sink.graphite.port=2003\n\
*.sink.graphite.period=10\n\
*.sink.graphite.unit=seconds\n\
master.sink.graphite.period=15\n\
master.sink.graphite.unit=seconds\n\
driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource\n\
executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource\n\
master.source.jvm.class=org.apache.spark.metrics.source.JvmSource\n\
worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource\n" > $SPARK_HOME/conf/metrics.properties

service sshd start
$HADOOP_PREFIX/sbin/start-dfs.sh
$HADOOP_PREFIX/sbin/start-yarn.sh

# graphite setup
cp /opt/graphite/conf/carbon.conf.example /opt/graphite/conf/carbon.conf
cp /opt/graphite/conf/storage-schemas.conf.example /opt/graphite/conf/storage-schemas.conf
cp /opt/graphite/conf/storage-aggregation.conf.example /opt/graphite/conf/storage-aggregation.conf
/opt/graphite/bin/carbon-cache.py start
cp /opt/graphite/conf/graphite.wsgi.example /opt/graphite/webapp/graphite/graphite_wsgi.py
python /opt/graphite/webapp/graphite/manage.py syncdb --noinput
cd /opt/graphite/webapp/graphite
gunicorn --bind=0.0.0.0:8000 graphite_wsgi:application &

CMD=${1:-"exit 0"}
if [[ "$CMD" == "-d" ]];
then
	service sshd stop
	/usr/sbin/sshd -D -d
else
	/bin/bash -c "$*"
fi
