#!/usr/bin/env bash
### TCP/IP stack hardening
### create 2020-02-11
### Silvio Siefke <siefke@mail.ru>

vpn_active='false'
ping_disable='false'

if [[ "$vpn_active" = true ]]; then
	echo 1 > /proc/sys/net/ipv4/ip_forward	
fi

# TCP SYN cookie protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 2048 > /proc/sys/net/ipv4/tcp_max_syn_backlog
echo 3 > /proc/sys/net/ipv4/tcp_synack_retries
echo 3 > /proc/sys/net/ipv4/tcp_syn_retries
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 1800 > /proc/sys/net/ipv4/tcp_keepalive_time
echo 2 > /proc/sys/net/ipv4/tcp_keepalive_probes
echo 0 > /proc/sys/net/ipv4/tcp_window_scaling
echo 0 > /proc/sys/net/ipv4/tcp_sack
echo 0 > /proc/sys/net/ipv4/tcp_timestamps
echo 1 > /proc/sys/net/ipv4/tcp_orphan_retries
echo 1 > /proc/sys/net/ipv4/tcp_rfc1337

# Turn on Source Address Verification in all interfaces to prevent some spoofing attacks.
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter

# Do not accept ICMP redirects (prevent MITM attacks)
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/secure_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/secure_redirects
echo 0 > /proc/sys/net/ipv6/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv6/conf/default/accept_redirects

# Ignore ICMP broadcasts will stop gateway from responding to broadcast pings.
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Ignore bogus ICMP errors.
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Do not send ICMP redirects.
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects

if [[ "$ping_disable" = true ]]; then
	echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all
	echo 0 > /proc/sys/net/ipv6/icmp/echo_ignore_all
fi

# Do not accept IP source route packets.
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route

# Turn on log Martian Packets with impossible addresses.
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/conf/default/log_martians