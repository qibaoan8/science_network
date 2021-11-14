#!/bin/bash

dir=$(cd $(dirname $0})/../; pwd)
file_name=$(basename $0)
cd $dir || exit -1

ipset_name="CROSS_WALL_SET"
doh_dns="127.0.0.1#5353"
default_dns=$(route -n |grep '^0.0.0.0' |awk '{print $2}')
dnsmasq_domain_list="conf/foreign_domain.txt"
dnsmasq_domain_conf="/etc/dnsmasq.d/foreign_domain.conf"

set_env(){
    export PS1="\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m\`pwd\`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n$"
    alias ll='ls -lh'
    alias vim='vi'
}

set_auto_start(){
	start_file="/config/scripts/post-config.d/start.sh"
	echo '#!/bin/bash' > /config/scripts/post-config.d/start.sh
	echo "$dir/bin/$file_name start" >> /config/scripts/post-config.d/start.sh
	chmod a+x /config/scripts/post-config.d/start.sh
}


dnsmasq_start(){
	# clear default conf
	rm -rf /etc/dnsmasq.d/*

	# create ipset
	ipset -N $ipset_name hash:net maxelem 65536
	ipset add $ipset_name 1.1.1.1
	ipset add $ipset_name 1.0.0.1

	# dnsmasq make domain conf
	echo '' > $dnsmasq_domain_conf
	for domain in `cat $dnsmasq_domain_list`; do
		echo "server=/$domain/127.0.0.1#5353" >> $dnsmasq_domain_conf
		echo "ipset=/$domain/$ipset_name" >> $dnsmasq_domain_conf
	done

    grep '^server=' /etc/dnsmasq.conf &>/dev/null

    if test "$?" == "0"; then
    	sed -i "/^server=/cserver=$default_dns" /etc/dnsmasq.conf
    else
        echo "server=$default_dns" >> /etc/dnsmasq.conf
    fi


	# config default dns, add file lock
	sed -i '/^nameserver/cnameserver 127.0.0.1' /etc/resolv.conf
	chattr +i /etc/resolv.conf


	# restart service
	/etc/init.d/dnsmasq restart
}

dnsmasq_stop(){

        # delete ipset
	ipset destroy $ipset_name

	# recovery resolv conf
	chattr -i /etc/resolv.conf
	# sed -i "/^nameserver/cnameserver $default_dns" /etc/resolv.conf

        # restart service
        # /etc/init.d/dnsmasq stop

}

iptables_start(){
	iptables -t nat -I PREROUTING -p tcp -m set --match-set $ipset_name dst -j REDIRECT --to-ports 1080
}

iptables_stop(){
	iptables -t nat -D PREROUTING -p tcp -m set --match-set $ipset_name dst -j REDIRECT --to-ports 1080
}

start(){
	echo "bagine start ..."

	sh plugins/trojan/trojan_ctl.sh start
	echo "trojan start retunt code: $?"

	sh plugins/cloudflared/cloudflared_ctl.sh start
	echo "cloudflared start retunt code: $?"

	dnsmasq_start
	echo "dnsmasq start retunt code: $?"

	iptables_start
	echo "iptables start retunt code: $?"
}


stop(){
	echo "bagine stop ..."

        sh plugins/trojan/trojan_ctl.sh stop
        echo "trojan stop retunt code: $?"

        sh plugins/cloudflared/cloudflared_ctl.sh stop
        echo "cloudflared stop retunt code: $?"

        iptables_stop
        echo "iptables stop retunt code: $?"

        dnsmasq_stop
        echo "dnsmasq stop retunt code: $?"

}


restart(){
	stop
	start
}

main() {
    if [ $# -eq 0 ]; then
        echo "usage: $0 start|stop|restart ..."
        return 1
    fi

    for funcname in "$@"; do
        if [ "$(type -t $funcname)" != 'function' ]; then
            echo "'$funcname' not a shell function"
            return 1
        fi
    done

    for funcname in "$@"; do
        $funcname
    done
    return 0
}
main "$@"
set_auto_start
set_env
