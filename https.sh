#!/bin/sh
# forum: https://1024.day
if [[ $EUID -ne 0 ]]; then
   clear
   echo "Error: This script must be run as root!" 1>&2
   exit 1
fi

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 生成随机用户名、密码和端口
username=$(echo -n $(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 9))
password=$(echo -n $(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 14))
# 生成1024-65535之间的随机端口
port=$(shuf -i 1024-65535 -n 1)

# 下载并解压 Caddy
wget https://github.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O - | tar -xz -C /usr/local/

echo "====输入已经DNS解析好的域名===="
read domain

# 检查端口占用
isPort=$(netstat -ntlp| grep -E ":$port ")
if [ "$isPort" != "" ];then
   clear
   echo " ================================================== "
   echo " ${port}端口被占用，请先释放端口再运行此脚本"
   echo
   echo " 端口占用信息如下："
   echo $isPort
   echo " ================================================== "
   exit 1
fi

# 创建 Caddy 配置目录
mkdir -p /etc/caddy

# 创建 Caddyfile 配置
cat >/etc/caddy/https.caddyfile<<EOF
{
    admin off
    auto_https disable_redirects
    servers {
        protocol {
            experimental_http3
            strict_sni_host
        }
    }
}

$domain:$port {
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
    forward_proxy {
        basic_auth $username $password
        hide_ip
        hide_via
        probe_resistance
    }
    
    handle {
        abort
    }
}
EOF

# 创建 systemd 服务
cat >/etc/systemd/system/caddy.service<<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
ExecStart=/usr/local/caddy run --environ --config /etc/caddy/https.caddyfile
ExecReload=/usr/local/caddy reload --config /etc/caddy/https.caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl enable caddy.service && systemctl restart caddy.service && systemctl status --no-pager caddy.service

# 删除安装脚本
rm -f https.sh

# 保存配置信息
cat >/etc/caddy/https.json<<EOF
{
===========配置参数=============
代理模式：Https正向代理
地址：${domain}
端口：${port}
用户：${username}
密码：${password}
====================================
http=$domain:$port, username=$username, password=$password, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https
}
EOF

# 输出配置信息
echo
echo "安装已经完成"
echo
echo "===========Https配置参数============"
echo
echo "地址：${domain}"
echo "端口：${port}"
echo "用户：${username}"  
echo "密码：${password}"
echo
echo "========================================="
echo "http=$domain:$port, username=$username, password=$password, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https"
