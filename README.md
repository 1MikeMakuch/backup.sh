# backup.sh
rsync based backup script

I've used this for around 10 years or more to backup both personal and production
systems, both home lan as well as in the cloud. It got tweaked for many years and now
these days needs very little tweaking. It works. 

Basically it uses rsync to backup hosts, file systems, any os that has ssh and rsync
on it. I've had it working on various linux flavors, osx and cygwin on Windoz).

It uses the rsync --backup and --backup-dir options to do incremental backups. Basically
a complete copy of the backed up system is maintained in 'main' and the incrementals
are in date-time stamped dir names as in

```
./backups
./backups/cottonwood
./backups/cottonwood/2015-08-08_01-00-00
./backups/cottonwood/2015-08-10_01-00-01
./backups/cottonwood/2015-08-17_01-00-00
./backups/cottonwood/2015-08-23_01-00-00
./backups/cottonwood/2015-09-05_01-00-01
./backups/cottonwood/2015-09-09_23-22-46
./backups/cottonwood/main
./backups/beech
./backups/beech/2015-09-05_01-00-01
./backups/beech/2015-09-06_01-00-01
./backups/beech/2015-09-07_01-00-01
./backups/beech/2015-09-08_01-00-01
./backups/beech/main
./backups/media
./backups/media/2015-02-01_01-00-01
./backups/media/2015-02-02_01-00-02
./backups/media/2015-03-18_01-00-01
./backups/media/2015-04-21_01-00-01
./backups/media/main


```

To use copy the sample config file and modify to suit then just run as

backup.sh <configFile> [name]

The optional [name] will only perform backup for that one backup config, not all the
others you may have configured.

It's very configurable in that numerous variables are set in the config file as
needed. Peruse the config file and you'll get a sense of what you need to do.
Ultimately you'll want to peruse the backup.sh as well if you intend to really use it.

There's a couple of test modes so you can run backup.sh without actually performing
any backup, so you can see what it would do.

Set OPTION to "-n" and it'll run rsync with -n which means it won't actually copy
anything.

Also, you can set DOCOMMANDS=0 and backup.sh won't actually execute any commands it'll
just display them so you can see what it will do when you set DOCOMMANDS=1

With the sample config file you can run it as is and you'll see the following;

```
$ sudo ./backup.sh backup.config.examples testit
######################################################################
######################################################################
Starting testit root@localhost:/ root@localhost:/tmp/backups/testit Thu Sep 10 16:44:40 CDT 2015
isalive root@localhost localhost
Up isaa:1 BUH:root@localhost BU:localhost
ssh root@localhost /opt/local/libexec/gnubin/df -hP /tmp/backups/testit
# ssh root@localhost install -d /tmp/backups/testit/main
# ssh root@localhost install -d /tmp/backups/testit/2015-09-10_16-44-40
# ssh root@localhost rm /tmp/backups/testit/lasti
# ssh root@localhost (cd /tmp/backups/testit; ln -s 2015-09-10_16-44-40 lasti)
ssh root@localhost remoteDirtest /tmp/backups/testit/main
BackupError: No /tmp/backups/testit/main dir
```

Note that above we're running just the 'testit' config which is set to localhost.
DOCOMMANDS is set to 0 so the install's don't actually create anything, so the backup
fails. Suggest you run it like this as you begin to customize your config file for
your system(s).

And here's what a successful run looks like on a test dir in /tmp/src

```
# ./backup.sh backup.config.examples testit
######################################################################
######################################################################
Starting testit root@localhost:/tmp/src root@localhost:/tmp/backups/testit Thu Sep 10 16:59:15 CDT 2015
isalive root@localhost localhost
Up isaa:1 BUH:root@localhost BU:localhost
isalive root@localhost localhost
Up ssh root@localhost isalive.sh root@localhost localhost
ssh root@localhost /opt/local/libexec/gnubin/df -hP /tmp/backups/testit
ssh root@localhost install -d /tmp/backups/testit/main
ssh root@localhost install -d /tmp/backups/testit/2015-09-10_16-59-15
ssh root@localhost rm /tmp/backups/testit/lasti
ssh root@localhost (cd /tmp/backups/testit; ln -s 2015-09-10_16-59-15 lasti)
ssh root@localhost remoteDirtest /tmp/backups/testit/main
BACKUPDIRS=/tmp/src
dir2backup /tmp/src
######################################################################
/usr/bin/ssh root@localhost /usr/bin/rsync -av --force --ignore-errors --delete --delete-excluded --backup --backup-dir=/tmp/backups/testit/2015-09-10_16-59-15 --exclude=/backup** --exclude=/dev** --exclude=**.gvfs** --exclude=/media** --exclude=**/plugh/tmp** --exclude=/mnt --exclude=/mnt** --exclude=/net --exclude=/opt --exclude=/proc --exclude=/sys --exclude=/var/named/chroot/proc** --exclude=/var/cache/** /tmp/src /tmp/backups/testit/main
building file list ... done
src/
src/1
src/2
src/3
src/4
src/5

sent 319 bytes  received 136 bytes  910.00 bytes/sec
total size is 0  speedup is 0.00
ssh root@localhost /opt/local/libexec/gnubin/df -hP /tmp/backups/testit
Nothing in incrementdir so:
ssh root@localhost rmdir /tmp/backups/testit/2015-09-10_16-59-15
######################################################################
ssh root@localhost /opt/local/libexec/gnubin/df -h

######################################################################
Done root@localhost:/tmp/src root@localhost:/tmp/backups/testit
Began Thu Sep 10 16:59:15 CDT 2015
Done  Thu Sep 10 16:59:16 CDT 2015
```

Note that you'll have to change localhost to your actual hostname in your
config file. Specifically it must be set to what ever 'uname -a' returns.

