
#!/bin/sh

### BEGIN INIT INFO
# Provides:        trojan
# Required-Start:  $network $remote_fs $syslog
# Required-Stop:   $network $remote_fs $syslog
# Default-Start:   2 3 4 5
# Default-Stop:
# Short-Description: Start trojan-go
### END INIT INFO

dir=$(cd $(dirname $0})/; pwd)
CMD=./cloudflared
CONFIG=config.json

cd $dir || exit -1

do_start()
{

	$CMD proxy-dns --address 0.0.0.0 --port 5353 &>/dev/null &
}

do_stop()
{
	pidof  $CMD |xargs  kill
}

do_status()
{
	ps -ef |grep ${CMD} |grep -v grep |grep -v status
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


