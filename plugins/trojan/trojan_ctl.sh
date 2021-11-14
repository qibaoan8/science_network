#!/bin/sh

dir=$(cd $(dirname $0})/; pwd)
CMD=./trojan-go
CONFIG=config.json

cd $dir || exit -1

do_start()
{
	
	 $CMD -config $CONFIG > /dev/null 2>&1 &
}
 
do_stop()
{
	pidof $CMD |xargs  kill
}

do_status()
{
	ps -ef |grep $CMD |grep -v grep |grep -v status
}	
 
do_restart() {
	do_stop
	sleep 2
	do_start
}
 
case "$1" in
  start)
	do_start
	;;
  stop)
	do_stop
	;;
  status)
	do_status
	exit $?
	;;
  restart)
	do_restart
	;;
  *)
	echo "Usage: {start|stop|status|restart}" >&2
	exit 3
	;;
esac
