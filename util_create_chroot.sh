#!/bin/bash
# -*- coding: UTF8 -*-
echo "------------------- USAGES ------------------"
echo "-- create a minimun chroot based on ubuntu --"
echo "------------------- USAGES ------------------"

cd $(dirname $0)

readonly base_chroots_dir="chroots_dir"

get_path_to_chroot() {
	local distrib=$1
	echo ${base_chroots_dir}/${distrib}/chroot
}

checks() {
	if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi

	# Check if debootstrap package is present on host
	dpkg -s debootstrap > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
	        echo "debootstrap package not-installed, you need it: sudo apt-get install debootstrap"
	        exit 1
	fi
}

select_distrib() {
	local distrib_sources="http://us.archive.ubuntu.com/ubuntu/dists/"
	local distribs=`wget -nv -O - ${distrib_sources} | grep "href" | grep -v Last | grep -v Parent | grep -v backports| grep -v proposed | grep -v security | grep -v updates | sed 's/.*<a href="\([a-z]*\)\/".*/\1/g'`

	echo "select the ubuntu distrib to create the chroot"
	select distrib in $distribs;
	do
        	break;
	done
	echo you picked ${distrib} \($REPLY\)
	local __resultvar=$1
	eval $__resultvar="'$distrib'"
}

create_chroot() {
	local distrib=$1
	local chroot_dir=`get_path_to_chroot ${distrib}`
        echo "Cleaning workspace"
	echo "${base_chroots_dir}"
        sudo rm -rf ${base_chroots_dir}
	sudo mkdir -p ${chroot_dir}
        echo "Creating chroot ${distrib} in folder ${chroot_dir}"
        sudo debootstrap --include=openssh-server,python-apt,aptitude --arch i386 ${distrib} ${chroot_dir} http://us.archive.ubuntu.com/ubuntu/
}

customize_chroot() {
	local distrib=$1
	local chroot_dir=`get_path_to_chroot ${distrib}`
        echo "Customizing chroot"
        if [ ! -f ${chroot_dir}/etc/ssh/sshd_config ]; then
		echo "ssh server not installed, where this chroot come from?"
		exit 1
        fi
        sudo sed -i 's/Port 22$/Port 220/' ${chroot_dir}/etc/ssh/sshd_config
        sudo rm -rf ${chroot_dir}/var/cache/apt/archives/*.deb
        sudo cp custom_chroot/init_ssh.sh ${chroot_dir}/
        sudo mkdir ${chroot_dir}/root/.ssh/

        sudo cp custom_chroot/id_rsa* ${chroot_dir}/root/.ssh/
        sudo chmod 600 ${chroot_dir}/root/.ssh/id_rsa

        sudo cp ${chroot_dir}/etc/bash.bashrc .
        sudo chmod 777 bash.bashrc
        sudo echo "TZ='Europe/Paris'; export TZ" >> bash.bashrc
        sudo mv bash.bashrc ${chroot_dir}/etc/bash.bashrc
        sudo chmod 644 ${chroot_dir}/etc/bash.bashrc
}
finishChroot() {
        local distrib=$1
	echo "Packaging chroot"
	cd ${base_chroots_dir}
	sudo tar czf ${distrib}.tgz ${distrib}/
}

checks
select_distrib distrib
create_chroot $distrib
customize_chroot $distrib
finishChroot $distrib
