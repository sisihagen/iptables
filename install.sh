#!/usr/bin/env bash

echo "You want install the scipt and had read the Readme? yes|no"
read -r install

if [[ "$install" = yes ]]; then
	if [[ $EUID -ne 0 ]]; then
		echo "To install the Script we need root access!"
		exit 1
	else
		install -D -m 755 -o root usr/local/bin/*.sh /usr/local/bin
		install -D -m 644 -o root etc/systemd/system/*.service /etc/systemd/system

		echo "files are copied, you want activate now the script or at boot? now|boot"

		read -r activate

		if [[ "$activate" = now ]]; then
			systemctl enable --now tcp_stack_hardening.service
			systemctl enable --now firewall.service
		fi

		if [[ "$activate" = boot ]]; then
			systemctl enable tcp_stack_hardening.service
			systemctl enable firewall.service
		fi
	fi

	exit 1
fi

case $1 in
	deactivate)
		echo "You want deactivate the firewall? yes|no"
		read -r deactivate

		if [[ "$deactivate" = yes ]]; then
			systemctl disable --now tcp_stack_hardening.service
			systemctl disable --now firewall.service
		fi

		echo "The Firewall is deactivated"
		exit 1
	;;

	uninstall)
		echo "You want uninstall the script? yes|no"
		read -r uninstall

		if [[ "$uninstall" = yes ]]; then
			systemctl disable --now tcp_stack_hardening.service
			systemctl disable --now firewall.service
		fi

		if [[ -f "/etc/systemd/system/firewall.service" ]]; then
			rm /etc/systemd/system/firewall.service
		fi

		if [[ -f "/etc/systemd/system/tcp_stack_hardening.service" ]]; then
			rm /etc/systemd/system/tcp_stack_hardening.service
		fi

		if [[ -f "/usr/local/bin/iptables.sh" ]]; then
			rm "/usr/local/bin/iptables.sh"
		fi

		if [[ -f "/usr/local/bin/tcp_stack_hardening.sh" ]]; then
			rm /usr/local/bin/tcp_stack_hardening.sh
		fi

		echo "The script is uninstalled!"
		exit 1
	;;
esac