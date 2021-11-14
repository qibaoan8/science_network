## science_network介绍

`science_network`是自己拼装的一个在edgeos上一键安装的科学上网，目前在`er-x` 上运行没问题，在其他设备上运行理论上也没啥问题，我理解只要是在edgeos上就行。



起初需求就是想在 `er-x` 上安装一个科学上网工具，但是从网上查找资料都是使用`openwrt`	系统，我也尝试的刷机到这个系统，但是无奈每次都是刷完后无法启动，路由器反复重启，差点变砖。还好找到了这个[文档](https://pfschina.org/wp/?p=1979) ，让我通过`TFTP`刷回到了原装系统。注意，他这个文档里面没写清楚tftp服务端的ip地址，经过我多次扫描确认，路由器上tftp的默认地址是`192.168.1.10` 。



后来就坚持在`edgeos`上寻找解决方案，大多数文档介绍的都是通过`ss`  `chinadns`  `dnsmasq`  `firewall` 实现的，但是我的代理工具是`trojan`是一个协议实现的，几乎没有相关文档介绍，有介绍的写的也不是太详细。

另外还有`chinadns`	 已经停止维护了，有些小bug，而且他的实现原理不太可靠，所以只能自己动手研究了。



然后就有了这个`science_network`	 解决方案， 在`er-x`设备`edgeos`系统使用`trojan`代理一键安装方案。



## 安装方法

这里先介绍下`安装方法`，想了解实现原理的可以下面查看详细介绍。



先将代码下载到本地，修改`trojan` 的配置文件`plugins/trojan/config.json` ，将自己的服务器和密码配置上。

```json
{
    "remote_addr": "wwwabc.com",   // 填写自己的服务
    "remote_port": 443,
    "password":
    [
        "*****"   // 填写自己的密码
    ]
}
```



然后将整个目录拷贝到`edgeos`路由器上

```shell
scp -r science_network ubnt@192.168.1.1:/tmp/
```

复制到路由器的系统目录，启动工具，启动会自动配置路由器开机启动

```shell
mkdir /usr/local
cp -rf /tmp/science_network/ /usr/local/
cd /usr/local/science_network/bin/
sh science_network_ctl.sh start
```

确认所有的组件启动状态码正常即可。

开机自动启动脚本在如下路径， 会自动生成。

```shell
cat /config/scripts/post-config.d/start.sh

#!/bin/bash
/usr/local/science_network/bin/science_network_ctl.sh start
```

然后就可以使用局域网的设备科学上网了。



注意：路由器本身无法实现科学上网，一定要用局域网内的设备测试。



## 实现原理

`science_network` 是由多个组件拼成的一个解决方案，里面用到的组件有`dnsmasq` `cloudflare` `trojan` `iptables` 。

`dnsmasq `就是路由器自己的dns服务。

`cloudflare` 是通过`DOH`(Dns over Https)协议实现的防劫持工具，代替原来的`chinadns`。

`trojan` 通过TLS协议，和服务端通信，模拟https请求。

`iptables `配置端口转发逻辑。默认走网关，在指定`ipset`的ip走代理。



#### dnsmasq

该模块负责dns解析，默认使用运营商分配的dns。如果是国外域名，使用`cloudflare`解析。

国外域名这里是写死了一个域名列表，路径在`conf/foreign_domain.txt`，也可以从其他url自动获取，我是没找到持续更新国外域名的地方，有人知道的可以给推荐一下。

如果有域名不在国外域名列表内，又需要配置科学上网的，可以直接修改如上列表文件。

`dnsmasq`	是系统自带的服务，不需要安装，直接启停即可。



#### cloudflare

cloudflare 是一个支持DOH协议的dns代理服务，默认启动53端口接受请求通过https协议转发给权威dns服务器，防止网络传输过程中被劫持。

该工具默认连接的doh服务端是搭建在国外的`https://1.1.1.1/dns-query` `https://1.0.0.1/dns-query`

当然我们国内也权威有doh服务端，腾讯、阿里云等，可以查看[文档](https://www.zhihu.com/question/428931557)

我使用的就是腾讯的: `https://doh.pub/dns-query`



最核心的问题来了，edgerouter 采用的是mips架构处理器，[cloudflare ](https://github.com/cloudflare/cloudflared) 的git仓库里Releases有没有这个架构的包，网上搜索了好久也没找到，所以只能自己编译了。这个真是个大工程。

编译使用的海外的ubuntu交叉编译，海外的下载依赖库是真快。

首先安装golang，安装默认的golang， 这个最高到1.13版本

```shell
apt update 
apt upgrade
apt install golang
apt install git
```



edgerouter的源码推荐使用1.17，这个版本的只能源码安装

```shell
tar zxf go1.17.3.src.tar.gz  -C /usr/local/
cd /usr/local/go/src/
./all.bash
ln -sf /usr/local/go/bin/go /usr/bin/go
```



下面正式开始编译edgerouter

```shell
# 设置代码下载路径
go env -w GOPATH=/root/go/

# 设置自动寻找go.mod 否则build的时候会报错
go env -w GO111MODULE=auto

# 下载代码库包
go get -v github.com/cloudflare/cloudflared/cmd/cloudflared

# 这里要使用GOARCH=mipsle 编译出来的才可以使用。之前有个文档说用GOARCH=mips，但是编译出来的无法使用。
GOOS=linux GOARCH=mipsle go build -v -x github.com/cloudflare/cloudflared/cmd/cloudflared

```

编译好之后cloudflare的二进制文件会在当前目录下。 直接拷贝到路由器就能使用。

不过有个问题，编译完的文件有29M，我的只有256M的RAM和ROM，路由器的资源相当紧缺。我觉得这里肯定可以去掉一些不必要的东西来瘦身，没精力了，以后再说吧。



#### trojan

trojan 是使用go语言编写的工具，通过https协议通信的代理服务，稳定性较强，实际是[trojan-go](https://github.com/p4gefau1t/trojan-go)这个代码库，。这个包在git仓库有编译好的包，直接下载使用就行。

这里用的是 `trojan-go-linux-mips-hardfloat.zip`这个包。

配置文件代码里提供的，修改下服务器和密码就行。代理模式要选择`nat`模式。



#### iptables

iptables 是最后一层负责转发的逻辑，按理说trojan支持TCP/UDP两种代理方式，UDP协议如果使用trojan的话就不用再装个`cloudflared`了，但是可惜自带的iptables 不支持TPROXY网关模式，没法把请求转发到trojan。

所以这里只有TCP使用的iptables转发，只有一条配置。

```shell
iptables -t nat -I PREROUTING -p tcp -m set --match-set $ipset_name dst -j REDIRECT --to-ports 1080
```





## 结束

好了，这就是全部了，投入了一周空闲时间研究这个原理和实现方案，有些包还需要自己编译，是在不容易。所以就沉淀个文档，以后方便大家安装使用。

纯原创，希望大家支持。

**该方案仅限技术交流和学习记录，严禁用于任何商业用途和非法行为，否则后果自负**	