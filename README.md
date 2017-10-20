# Wekan source installer

Download the script and execute to install Wekan and its dependencies.

To run download and execute the installer:
# Installation

Edit the installer script and substitute **ROOT_URL**,**MAIL_URL**, **MONGO_URL** and **PORT** according to your installation.

```bash
$ wget -q https://raw.githubusercontent.com/wekan/wekan-source-installer/master/wekan.sh 
$ chmod +x wekan.sh
$ ./wekan.sh
```

After installation (it takes some time) you can run Wekan like:

$ ./wekan.sh --start

Check wekan.sh --help for all options available
