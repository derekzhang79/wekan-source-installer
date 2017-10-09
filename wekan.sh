#!/bin/bash

#
# Wekan Installation Script
# - written by Salvatore De Paolis <iwkse@claws-mail.org>
# Copyright 2017, GNU General Public License Version 3

GOSU_VERSION=1.10
SCRIPT_VERSION=0.2.1

NODE_VERSION=4.8.4
METEOR_RELEASE=1.4.4.1
METEOR_EDGE=1.5.beta.17
NPM_VERSION=4.6.1
FIBERS_VERSION=1.0.15
BUILD_DEPS="build-essential g++ capnproto nodejs nodejs-legacy npm git curl"

APT=$(which apt-get)
GIT=$(which git)
METEOR=$(which meteor)
N=$(which n)
NODE=$(which node)
NPM=$(which npm)
RM=$(which rm)
SUDO=$(which sudo)
SU=$(which su)
WGET="$(which wget) -qO-"

WEKAN=$(pwd)/wekan
WEKAN_SRC=$WEKAN/src
WEKAN_BUILD=$WEKAN/build

# START WEKAN_SRC SETTINGS

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

# END WEKAN_SRC SETTINGS

# init
declare -a NODE_MODULES_PATH=('/usr/local/lib/node_modules' '~/.npm');

function config_wekan {
	sed -i 's/api\.versionsFrom/\/\/api.versionsFrom/' $WEKAN_SRC/packages/meteor-useraccounts-core/package.js
	test $WEKAN_SRC/package-lock.json || rm $WEKAN_SRC/package-lock.json
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

    test -d $WEKAN || mkdir $WEKAN
    pushd $WEKAN
    printf "Getting Wekan..."
    $GIT clone -q https://github.com/wekan/wekan src
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An error accourred: $?"
        exit
    else
        echo "[OK]"
    fi
}

function git_clone_wekan_packages {
    pushd $WEKAN_SRC && mkdir packages && pushd packages
    printf "Getting kadira-flow-router..."
    $GIT clone -q https://github.com/wekan/flow-router.git kadira-flow-router
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An error accourred: $?"
        exit
    else
        echo "[OK]"
    fi
    printf "Getting meteor-useraccounts-core..."
    $GIT clone -q https://github.com/meteor-useraccounts/core.git meteor-useraccounts-core
    if [[ $? -gt 0 ]]; then
        echo "[FAILED]"
        echo "An error accourred: $?"
        exit
    else
        echo "[OK]"
    fi
    popd
}

function install_deps {
    for d in $BUILD_DEPS;
    do
        test -z "$(dpkg -l | grep $d | awk '{print $2}')" && PKG_INST=1
    done

    if [[ $PKG_INST -eq 1 ]]; then
        $APT install $BUILD_DEPS
    fi

    test -f $METEOR || PKG_INST=1
    if [[ $PKG_INST -eq 1 ]]; then
        $WGET https://install.meteor.com/ | sed "s~RELEASE=".*"~RELEASE=$METEOR_RELEASE~g" | sh
    fi
}

function install_node {
    #TODO Check if modules are already installed 

    rm -rf node_modules

    if [[ $USE_SUDO -eq 1 ]]; then
        $NPM -g install n
        $N $NODE_VERSION
        $NPM -g install npm@$NPM_VERSION
        $NPM -g install node-gyp
        $NPM -g install node-pre-gyp
        $NPM -g install fibers@$FIBERS_VERSION
    else
        $SU -c "$APT install $BUILD_DEPS -y" root
        $SU -c "$NPM -g install n" root
        $SU -c "$N $NODE_VERSION" root
        $SU -c "$NPM -g install npm@$NPM_VERSION" root
        $SU -c "$NPM -g install node-gyp" root
        $SU -c "$NPM -g install node-pre-gyp" root
        $SU -c "$NPM -g install fibers@$FIBERS_VERSION" root
    fi
    npm install
}

function del_node_mods {
    for m in "${NODE_MODULES_PATH[@]}";
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
    test -f "$METEOR" || install_deps
    if [[ -d "$WEKAN_SRC" ]]; then
        echo "Existing sources found."
        read -p "Do you want to clear sources?" SOURCES_DELETE
        if [[ $SOURCES_DELETE = 'y' || $SOURCES_DELETE = 'Y' ]]; then
            rm -rf $WEKAN_SRC
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

if [[ "$1" = '--help' ]]; then
    echo "--help     this help"
    echo "--start    run Wekan"
    echo "--version  Installer and deps version"
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
    echo Installer Version: $SCRIPT_VERSION

    if [[ -z "$NODE" ]]; then
        echo "Node is not installed."
        exit
    else
        echo "Node is installed at $NODE"
        echo "Version: $($NODE -v)"
    fi
    if [[ -z "$METEOR" ]]; then
        echo "Meteor is not installed."
        exit
    else
        echo "Meteor is installed at $METEOR"
        echo "Version: $($METEOR --version)"
    fi
fi

if [[ "$1" = '--install_deps' ]]; then
   install_deps 
fi

if [[ "$1" = '' ]]; then
	
        if [[ "$UID" -eq 0 ]]; then
		echo "Do no execut this script as root. You will be prompted for the password."
		exit
        fi

	echo "WELCOME TO WEKAN (standalone) INSTALLATION"
	echo "------------------------------------------"
	echo "This script installs Wekan sources in the $WEKAN_SRC folder and build them in $WEKAN_BUILD"
	# Detect sudo and su
	test -f $SUDO && USE_SUDO=1 || USE_SUDO=0

	if [[ $USE_SUDO -eq 1 ]]; then
            read -p "==> [INFO] sudo has been detected. Do you want to use it?  [yY]" USE_SUDO
            if [[ "$USE_SUDO" = 'y' || "$USE_SUDO" = 'Y' ]]; then
                APT="$SUDO $APT"
                N="$SUDO $N"
                NPM="$SUDO $NPM"
                RM="$SUDO $RM"
                USE_SUDO=1
                echo "==> [SUDO] selected"
            else
                USE_SUDO=0
            fi
	fi
    	build_wekan
fi

