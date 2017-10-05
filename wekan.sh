#!/bin/bash

#
# Wekan Installation Script
# - written by Salvatore De Paolis <iwkse@claws-mail.org>
# Copyright 2017, GNU General Public License Version 3

VERSION=0.1.0
SUDO=$(which sudo)
SU=$(which su)
NODE=$(which node)
RM=$(which rm)
GIT=$(which git)
WEKAN=$(pwd)/wekan
APT=$(which apt-get)
NODE="build-essential g++ capnproto nodejs nodejs-legacy npm git curl"
NPM=$(which npm)
N=$(which n)
WEKAN_BUILD=$(pwd)/Wekan

# START WEKAN SETTINGS

# 1) Full URL to your wekan, for example:
#     http://example.com/wekan
#     http://192.168.100.1
#     http://192.168.100.1:3000
ROOT_URL='http://example.com'

# 2) URL to MongoDB database
MONGO_URL='mongodb://127.0.0.1:27017/admin'

# 3) SMTP server URL. Remember to also setup same settings in Admin Panel.
#    Also see https://github.com/wekan/wekan/wiki/Troubleshooting-Mail
MAIL_URL='smtp://user:pass@mailserver.example.com:25/'

# 5) Port where Wekan is running on localhost
PORT=3000

# END WEKAN SETTINGS




# START INSTALL

# init
declare -a NODE_MODULES=('/usr/local/lib/node_modules' '~/.npm');

function config_wekan {
	sed -i 's/api\.versionsFrom/\/\/api.versionsFrom/' $WEKAN/packages/meteor-useraccounts-core/package.js
	test $WEKAN/package-lock.json || rm $WEKAN/package-lock.json
}

function use_command {
    test $1 && echo "1" || echo "0"
}

function git_clone_wekan {
    printf "Checking git..."

    if [[ $(use_command 'git') -eq 0 ]]; then
        echo "[FAILED]"
        echo "git is missing. On Debian-like, sudo apt-get install git"
        exit
    else
        echo "[OK]"
    fi

    $GIT clone https://github.com/wekan/wekan
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An unknown error accourred: $?"
        exit
    fi
}

function git_clone_wekan_packages {
    pushd $(pwd)/wekan && mkdir packages && pushd packages

    $GIT clone https://github.com/wekan/flow-router.git kadira-flow-router
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An unknown error accourred: $?"
        exit
    fi

    $GIT clone https://github.com/meteor-useraccounts/core.git meteor-useraccounts-core
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An unknown error accourred: $?"
        exit
    fi
    echo "OK"
	popd
}
function clear_wekan {
    #clean node modules
    rm -rf $(pwd)/wekan
}
function install_node {
    rm -rf node_modules

	if [[ $USE_SUDO -eq 1 ]]; then
		echo "Insert password for $USER"
		$APT install $NODE -y
		$NPM -g install n
		$N 4.8.4
		$NPM -g install npm@4.6.1
		$NPM -g install node-gyp
		$NPM -g install node-pre-gyp
		$NPM -g install fibers@1.0.15
	else
		$SU -c "$APT install $NODE -y" root
		$SU -c "$NPM -g install n" root
		$SU -c "$N 4.8.4" root
		$SU -c "$NPM -g install npm@4.6.1" root
		$SU -c "$NPM -g install node-gyp" root
		$SU -c "$NPM -g install node-pre-gyp" root
		$SU -c "$NPM -g install fibers@1.0.15" root
	fi
	npm install
}
function del_node_mods {
    for m in "${NODE_MODULES[@]}";
        do
	if [[ -d "$sm" ]]; then
            printf "Cleaning $m..."
			if [[ $USE_SUDO -eq 1 ]]; then
            	$RM -rf "$m"
			else
				$SU -c "$RM -rf $m" root
			fi
            echo "[OK]"
	fi
    done
}
function del_wekan_build {
	test -d $WEKAN_BUILD || rm -rf $WEKAN_BUILD
}
function build_wekan {
    if [[ -d "$(pwd)/wekan" ]]; then
        echo "Existing sources found."
        read -p "Do you want to clear sources?" SOURCES_DELETE

        if [[ $SOURCES_DELETE = 'y' || $SOURCES_DELETE = 'Y' ]]; then
            clear_wekan
			git_clone_wekan
			git_clone_wekan_packages
        fi
	else
		git_clone_wekan
		git_clone_wekan_packages
    fi

	del_wekan_build
	install_node
    config_wekan

	#
	# Building with meteor
	# TODO Handle meteor
	#
	meteor build $WEKAN_BUILD --directory

	cp fix-download-unicode/cfs_access-point.txt $WEKAN_BUILD/bundle/programs/server/packages/cfs_access-point.js
	sed -i "s|build\/Release\/bson|browser_build\/bson|g" $WEKAN_BUILD/bundle/programs/server/npm/node_modules/meteor/cfs_gridfs/node_modules/mongodb/node_modules/bson/ext/index.js

	pushd $WEKAN_BUILD/bundle/programs/server/npm/node_modules/meteor/npm-bcrypt
	rm -rf node_modules/bcrypt
	npm install bcrypt
	popd
	pushd $WEKAN_BUILD/bundle/programs/server
	npm install
	popd
}


#init
#init_env
if [[ $USE_SUDO -eq 1 ]]; then
	RM=$SUDO $RM
	APT=$SUDO $APT
	NPM=$SUDO $NPM
	N=$SUDO $N
fi

if [[ "$1" = '--help' ]]; then
    echo "--help     this help"
    echo "--root     execute wekan.sh root (handy with no sudo installed)"
    echo "--start    run Wekan"
	echo "--version  script version"
fi

if [[ "$1" = '--root' ]]; then
    if [[ $UID -ne 0 ]]; then
        echo "You have to be root to execute wekan.sh with the -root option"
        exit
    fi
    del_node_mods
fi

if [[ "$1" = '--start' ]]; then
	pushd $WEKAN_BUILD/bundle
	export MONGO_URL=$MONGO_URL
	export ROOT_URL=$ROOT_URL
	export MAIL_URL=$MAIL_URL
	export PORT=$PORT
	node main.js
fi

if [[ "$1" = '--version' ]]; then
	echo Version: $VERSION
fi

if [[ "$1" = '--install-with-meteor' ]]; then
	curl https://install.meteor.com/ | sh
fi

if [[ "$1" = '' ]]; then
	echo "WELCOME TO WEKAN (standalone) INSTALLATION"
	echo "------------------------------------------"
	echo "This script installs WEKAN sources in the $WEKAN folder and build them in $WEKAN_BUILD"
	# Detect sudo and su
	test -f $SUDO && USE_SUDO=1 || USE_SUDO=0
	test -f $SU && USE_SU=1 || USE_SU=0

	if [[ $USE_SUDO -eq 1 ]]; then
		read -p "==> [INFO] sudo has been detected. Do you want to use it?  [yY]" USE_SUDO
		if [[ "$USE_SUDO" = 'y' || "$USE_SUDO" = 'Y' ]]; then
			echo "==> [SUDO] selected"
		else
			USE_SUDO=0
		fi
	fi

	if [[ "$UID" -eq 0 ]]; then
		echo "Do no execut this script as root. You will be prompted for the password."
		exit
	else
    	build_wekan
	fi

fi

# END INSTALL
