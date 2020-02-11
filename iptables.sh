#!/usr/bin/env bash

### network adapter 
out_ad=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

### ip address
out_ip=$(ip route get 8.8.8.8 | awk -- '{printf $7}')

### wireguard
wg_active='false'
wg_dns='false'
wg_ad='wg0'
wg_ip='192.168.2.0/24'

### specific services active
munin_active='false'
monitorix_active='false'
rspamd_active='false'

### specific ip / hosts
munin_host=''
monitorix_host=''
rspamd_host=''

### ipv6
ipv6_active='false'


### find the right iptables command
if grep -q "Debian" /etc/os-release; then
	if grep -q "10" /etc/os-release; then
		IPT="/usr/sbin/iptables-nft"
	elif grep -q "9" /etc/os-release; then
		IPT="/usr/sbin/iptables"
	fi
else
	IPT="/usr/sbin/iptables"
fi

### ports
rspamd=$( ss -tlpn | grep 11334 | awk -- '{print $4}' | sed "s/0.0.0.0://g" )
monitorix=$( ss -tlpn | grep monitorix | awk -- '{print $4}' | sed "s/$out_ip://g" )
munin=$( ss -tlpn | grep munin | awk -- '{print $4}' | sed "s/$out_ip://g" )
udp_ports=$( ss -lnt | awk '{print $4}' | grep -e "0.0.0.0" -e "$out_ip" | sed "s/0.0.0.0://g; s/$out_ip://g" | uniq | sed "s/$monitorix//g; s/$munin//g; s/$rspamd//g" | sed '/^$/d' | tr '\n' ', ' | sed 's/,$//' )
tcp_ports=$( ss -lnU | awk '{print $4}' | grep -e "0.0.0.0" -e "$out_ip" | sed "s/0.0.0.0://g; s/$out_ip://g" | uniq | tr '\n' ', ' | sed 's/,$//' )

# iptables reset
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X
$IPT -t raw -F
$IPT -t raw -X
$IPT -t security -F
$IPT -t security -X
$IPT -P INPUT ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT ACCEPT

#Setting default filter policy
$IPT -P INPUT DROP
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD DROP

# allow unlimited traffic on loopback
$IPT -A INPUT -i lo -j ACCEPT

# any established or related conns are welcome
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ping
$IPT -A INPUT -i "$out_ad" -p icmp --icmp-type 8 -j ACCEPT

# reject all request for closed ports
$IPT -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
$IPT -A INPUT -p tcp -j REJECT --reject-with tcp-reset
$IPT -A INPUT -j REJECT --reject-with icmp-proto-unreachable

# tcp ports
$IPT -A INPUT -i "$out_ad" -p tcp --match multiport --dports "$tcp_ports" -m state --state NEW,ESTABLISHED -j ACCEPT -m comment --comment "Friendly Services TCP"

# udp ports
$IPT -A INPUT -i "$out_ad" -p udp --match multiport --dports "$udp_ports" -m state --state NEW,ESTABLISHED -j ACCEPT -m comment --comment "Friendly Services UDP"

# munin, monitorix, rspamd
if [[ "$monitorix_active" = true ]]; then
	$IPT -A INPUT -i "$out_ad" -p tcp -s "$monitorix_host" --dport "$monitorix" -j ACCEPT -m comment --comment "Monitorix Monitoring"
elif [[ "$munin_active" = true ]]; then
	$IPT -A INPUT -i "$out_ad" -p tcp -s "$munin_host" --dport "$munin" -j ACCEPT -m comment --comment "Munin Monitoring"
elif [[ "$rspamd_active" = true ]]; then
	$IPT -A INPUT -i "$out_ad" -p tcp -s "$rspamd_host" --dport "$rspamd" -j ACCEPT -m comment --comment "Rspamd Statistics"
fi

# wireguard
if [[ "$wg_active" = true ]]; then
	# set iptables rules for wireguard
	$IPT -A FORWARD -i "$wg_ad" -j ACCEPT -m comment --comment "Wireguard forward incoming Traffic"
	$IPT -A FORWARD -o "$wg_ad" -j ACCEPT -m comment --comment "Wireguard forward outgoing Traffic"
	$IPT -t nat -A POSTROUTING -o "$out_ad" -j MASQUERADE -m comment --comment "routing Wireguard Traffic"

	# use local dns server
	if [[ "$wg_dns" = true ]]; then
		$IPT -A INPUT -s "$wg_ip" -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "User of Wireguard using local DNS Server TCP"
		$IPT -A INPUT -s "$wg_ip" -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "User of Wireguard using local DNS Server UDP"
	fi	
fi

#
$IPT -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
$IPT -A INPUT -p tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP


# spoofing
$IPT -t raw -I PREROUTING -m rpfilter --invert -j DROP

# port scanning
$IPT -I TCP -p tcp -m recent --update --rsource --seconds 60 --name TCP-PORTSCAN -j REJECT --reject-with tcp-reset
$IPT -D INPUT -p tcp -j REJECT --reject-with tcp-reset
$IPT -A INPUT -p tcp -m recent --set --rsource --name TCP-PORTSCAN -j REJECT --reject-with tcp-reset
$IPT -I UDP -p udp -m recent --update --rsource --seconds 60 --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
$IPT -D INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
$IPT -A INPUT -p udp -m recent --set --rsource --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
$IPT -D INPUT -j REJECT --reject-with icmp-proto-unreachable
$IPT -A INPUT -j REJECT --reject-with icmp-proto-unreachable

# ssh  bruteforce
$IPT -N IN_SSH
$IPT -A INPUT -p tcp --dport 12500 -m conntrack --ctstate NEW -j IN_SSH
$IPT -A IN_SSH -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 10 -j DROP
$IPT -A IN_SSH -m recent --name sshbf --rttl --rcheck --hitcount 4 --seconds 1800 -j DROP 
$IPT -A IN_SSH -m recent --name sshbf --set -j ACCEPT

# logging
$IPT -N LOGGING
$IPT -A LOGGING -m limit --limit 5/m --limit-burst 10 -j LOG
$IPT -A LOGGING -j DROP
$IPT -A INPUT -m conntrack --ctstate INVALID -j logdrop

# ipv6 accept
if [[ "$ipv6_active" = true ]]; then
	$IPT -A INPUT -j ACCEPT --proto 41
	source /usr/local/bin/firewall6.sh
fi

exit 0
