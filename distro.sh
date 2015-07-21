#!/bin/bash

# Figure out our distro
# TODO: SuSE support
distro=""
if grep -i centos /etc/redhat-release &> /dev/null
then
	distro=centos
fi
if grep -i red /etc/redhat-release &> /dev/null
then
	distro=rhel
fi
if grep -i ubuntu /etc/lsb-release &> /dev/null
then
	distro=ubuntu
fi

if [[ $distro = "" ]]
then
	echo "Unknown distro:"
	cat /etc/lsb-release
	exit 1
fi

case $distro in
	centos | rhel)
		apache_base=/etc/httpd
		mysql_pkg=mysql
                php_pkg=php
		apache_pkg=httpd
		apache_conf_dir="$apache_base/conf.d"
		apache_restart_cmd="service httpd restart"
		install_cmd="yum install"
		enable_site_cmd="true" # No site management on Red Hat :(
		#webaccesslog=/var/log/httpd/access_log
		#weberrorlog=/var/log/httpd/error_log
		;;
	ubuntu)
		apache_base=/etc/apache2
                mysql_pkg=mysql
                php_pkg=php
		apache_pkg=apache2
		apache_conf_dir="$apache_base/sites_available"
		apache_restart_cmd="service apache2 restart"
		install_cmd="apt-get install"
		enable_site_cmd="a2ensite"
		#webaccesslog=/var/log/apache2/access.log
		#weberrorlog=/var/log/apache2/error.log
		;;
	*)
		echo "Error -- unknown distribution $distro!  Aborting...";
		exit 1
		;;
esac

function check_package_installed
{
	case $distro in
		centos | rhel)
			return $(yum list installed "$@" > /dev/null 2>&1)
			;;
		ubuntu)
			return $(dpkg -l "$@" > /dev/null 2>&1)
			;;
	esac
}
