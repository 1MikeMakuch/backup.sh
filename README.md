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


