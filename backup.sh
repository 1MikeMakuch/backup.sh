#!/bin/bash

# backup.sh
# Backup file systems with rsync
# Mike Makuch 2004
# I've had this running on linux, osx, cygwin

#CONFIG="$HOME/scripts/backup.config"
CONFIG=$1

H2B=$2

# some default values
HIGHWATER=90
PRUNEARCHIVES=0
Continue=1
export Continue

DF=/opt/local/libexec/gnubin/df
DU=/opt/local/libexec/gnubin/du
SORT=/opt/local/libexec/gnubin/sort

###########################################################################
# docom, echo a command then execute it. Mainly for consistent echoing of
# command executed for logging, and for testing: DOCOMMANDS=0
docom() {
###########################################################################
	command=$*
	if [[ "1" != "$Continue" ]] ; then
		return;
	fi
	if [[ "$DOCOMMANDS" == 1 ]]; then
		echo $command
		set -f
		$command
		set +f
	else
		echo "# $command"
	fi
}

###########################################################################
# do the rsync
dorsync() {

echo "######################################################################"

# The rsync command with options
#COMMAND="/usr/bin/rsync --write-batch=/tmp/backup.batch $GLOBALOPTIONS $OPTIONS"
COMMAND="/usr/bin/rsync $OPTIONS $GLOBALOPTIONS "

if [[ "$ARCHIVE_RSYNCD_PW" != "" ]] ; then
	COMMAND="$COMMAND --password-file=${ARCHIVE_RSYNCD_PW}"
fi

if [[ "$BACKUP_RSYNCD_MODULE" != "" ]] ; then

	COMMAND="$COMMAND ${BACKUP_RSYNCD_USER}@${BACKUP_RSYNCD_HOST}::${BACKUP_RSYNCD_MODULE}${BACKUP_RSYNCD_ROOT}"

#	ss="s@$BACKUPROOT@@"
#	ad=`echo $BACKUPDIR | sed -e $ss`
#	COMMAND="${COMMAND}${ad}"

else
	#echo "BEBU $BACKUPHOST $EXEHOST $BACKUPUSER"
	# If BACKUPUSER/HOST is different from EXEHOST then spell it out
	if [[ "$BACKUPHOST" != "$EXEHOST" && "$BACKUPUSER" != "" ]] ; then
		COMMAND="$COMMAND ${BACKUPUSER}@${BACKUPHOST}:"
	else
		COMMAND="$COMMAND "
	fi
fi

# dir to backup
COMMAND="${COMMAND}${BACKUPDIR}"

if [[ "$ARCHIVE_RSYNCD_MODULE" != "" ]] ; then

	COMMAND="$COMMAND ${ARCHIVE_RSYNCD_USER}@${ARCHIVE_RSYNCD_HOST}::${ARCHIVE_RSYNCD_MODULE}${ARCHIVE_RSYNCD_ROOT}"

	ss="s@$ARCHIVEROOT@@"
	ad=`echo $ARCHIVEDIR | sed -e $ss`
	COMMAND="${COMMAND}${ad}"

else
	# If ARCHIVEUSER/HOST is different from EXEHOST then spell it out
	if [[ "$ARCHIVEHOST" != "$EXEHOST" && "$ARCHIVEUSER" != "" ]] ; then
		COMMAND="$COMMAND ${ARCHIVEUSER}@${ARCHIVEHOST}:"
	else
		COMMAND="$COMMAND "
	fi
	# where to backup to
	COMMAND="${COMMAND}${ARCHIVEDIR}"
fi


#echo "thishost=$thishost, EXEHOST=$EXEHOST"
# If EXEHOST then do over ssh (for cygwin bug)
if [ "$thishost" != "$EXEHOST" -o $EXEUSER != "$thisuser" ] ; then
	COMMAND="/usr/bin/ssh ${EXEUSER}@${EXEHOST} ${COMMAND}"
fi
docom $COMMAND

}
###########################################################################
checkDiskSpaceAvail() {
# Check for filesystems use% gt highwater setting
###########################################################################
# Had to write result of df||| to /tmp cause couldn't set a shell var
# return 0 for over limit, 1 for good
	if [[ "1" != "$Continue" ]] ; then
		return
	fi
	userhost=$1
	filesys=$2
	echo "ssh $userhost $DF -hP $filesys"
	echo 1 > ${LOGFILE}.checkDiskSpaceAvail
	ssh $userhost $DF -hP $filesys | awk -F\  '{print $5}'|sed s/%//g|sed s/Use//g| while read line
	do
		if [[ $line -ge $HIGHWATER ]] ; then
			echo 0 > ${LOGFILE}.checkDiskSpaceAvail
			break
		fi
	done

	ret=`cat ${LOGFILE}.checkDiskSpaceAvail`
	rm ${LOGFILE}.checkDiskSpaceAvail >/dev/null
	return $ret
}

###########################################################################
isalivecheck() {
###########################################################################
echo "isalive $BACKUPUSERHOST $BACKUPUNAME"
isaa=`isalive $BACKUPUSERHOST $BACKUPUNAME`
if [[ "$isaa" != 1 ]] ; then
	echo "BackupError: host apparently not up isaa:$isaa BUH:$BACKUPUSERHOST BU:$BACKUPUNAME"
	return 0
else
	echo "Up isaa:$isaa BUH:$BACKUPUSERHOST BU:$BACKUPUNAME"
fi

if [[ "$EXEHOST" == "$thishost" ]] ; then
	return 1
fi

# check exehost
echo "isalive $EXEUSERHOST $EXEHOST"
isaa=$(isalive $EXEUSERHOST $EXEHOST)

if [[ "$isaa" != 1 ]] ; then
	echo "BackupError: host apparently not up ssh $BACKUPUSERHOST isalive.sh root@$thishost $thishost"
	return 0
else
	echo "Up ssh $BACKUPUSERHOST isalive.sh root@$thishost $thishost"
fi
return 1
}
###########################################################################
isalive() {
###########################################################################
# Parameters 
# 1 user@host
# 2 expected result from uname -a, optional host used otherwise
# 	On gridserver uname -a returns something completely different than the public hostname
# 	so I had to come up with a way to specify that.
	isaUserAtHost=$1
	isaExpectedUname=$2

	if [[ -n "$isaExpectedUname" ]] ; then
		isaHost=$isaExpectedUname
	else
		isaHost=`echo $isaUserAtHost | sed -e 's/.*@//'`
	fi
	isaHost=`echo $isaHost | awk -F\. '{print $1}'`

	#tmp=`ssh $isaUserAtHost uname -a 2>&1|tail -1`
	tmp=`ssh $isaUserAtHost uname -a 2>&1`
	isaUname=`echo $tmp | awk -F\  '{print $2}'`
	isaUname=`echo $isaUname | awk -F\. '{print $1}'`

	if [[ "$isaHost" != "$isaUname" ]] ; then
		echo 0
	else
		echo 1
	fi
}

###########################################################################
remoteDirtest() {
###########################################################################
host=$1
path=$2
if ssh $host test -d $path 
	then
		echo 1
	else
		echo 0
	fi
}

###########################################################################
# prepare for backup
doit() {
###########################################################################

bdate=`date`
Continue=1

echo "######################################################################"
echo "######################################################################"
echo "Starting $BNUM ${BACKUPUSER}@${BACKUPHOST}:${BACKUPDIRS} ${ARCHIVEUSER}@${ARCHIVEHOST}:${ARCHIVEROOTHOST} $bdate"

if [[ "$thishost" != "oak.makuch.org" && "$thishost" != "boxwood.makuch.org" ]] ; then
	isalivecheck
	r=$?
	if [[ 1 != $r ]] ; then
		return
	fi
fi

checkDiskSpaceAvail $ARCHIVEUSERHOST $ARCHIVEROOTHOST
TheresRoom=$?
if [[ 1 == $Continue && "$TheresRoom" != "1" ]] ; then
	echo "BackupError:Avail > $HIGHWATER no backup done"
	Continue=0
	return
fi

# create sure target dir is there
docom ssh ${ARCHIVEUSERHOST} install -d $ARCHIVEROOTHOST/$CURRENT

# create backup dir and symlink
if [[ "$ARCHIVES2KEEP" -gt 0 ]] ; then
	docom ssh ${ARCHIVEUSERHOST} install -d $ARCHIVEROOTHOST/$INCREMENTDIR
	docom ssh ${ARCHIVEUSERHOST} rm $ARCHIVEROOTHOST/lasti
#	docom ssh ${ARCHIVEUSERHOST} ln -s $ARCHIVEROOTHOST/$INCREMENTDIR $ARCHIVEROOTHOST/lasti
	docom ssh ${ARCHIVEUSERHOST} "(cd $ARCHIVEROOTHOST; ln -s $INCREMENTDIR lasti)"

	BUPDIR="$ARCHIVEROOTHOST/$INCREMENTDIR"
	if [[ "$ARCHIVE_RSYNCD_ROOT" != "" ]] ; then
		ss="s@$ARCHIVEROOT@@"
		ad=`echo $ARCHIVEROOTHOST | sed -e $ss`
		BUPDIR="${ARCHIVE_RSYNCD_ROOT}${ad}/${INCREMENTDIR}"
	fi
	GLOBALOPTIONS="${GLOBALOPTIONS} --backup --backup-dir=$BUPDIR"
fi

if [[ -z "$MAILADDR" || -z "$CURRENT" ]] ; then
	echo "BackupError: missing config vars!"
	Continue=0
	return
fi

# check target dir is there
echo "ssh ${ARCHIVEUSERHOST} remoteDirtest $ARCHIVEROOTHOST/$CURRENT"
#rslt=`ssh ${ARCHIVEUSERHOST} remoteDirtest "$ARCHIVEROOTHOST/$CURRENT"`

rslt=$(remoteDirtest ${ARCHIVEUSERHOST} "$ARCHIVEROOTHOST/$CURRENT")

if [[ "$rslt" != "1" ]] ; then
	echo "BackupError: No $ARCHIVEROOTHOST/$CURRENT dir"
	Continue=0
	return
fi

# check backup dir is there
if [[ "$ARCHIVES2KEEP" -gt 0 ]] ; then
#	rslt=`ssh ${ARCHIVEUSERHOST} remoteDirtest "$ARCHIVEROOTHOST/$INCREMENT"`
	rslt=$(remoteDirtest ${ARCHIVEUSERHOST} "$ARCHIVEROOTHOST/$INCREMENT")
	if [[ "$rslt" != "1" ]] ; then
		echo "BackupError: No $ARCHIVEROOTHOST/$INCREMENT dir"
		Continue=0
	return
	fi
fi

if [[ -z "$GLOBALOPTIONS" ]] ; then
	echo "BackupError: No GLOBALOPTIONS!"
	Continue=0
	return
fi

if [[ "$PRECOMMAND" != "" ]] ; then
	echo "##### PRECOMMAND #####################################################"
	docom $PRECOMMAND
	echo "######################################################################"
fi

# set exclude patterns
set -f
if [[ -n "$EXCLUDESFILE" ]] ; then
	GLOBALOPTIONS="$GLOBALOPTIONS --exclude-from=${EXCLUDESFILE} "
fi
for exc in $EXCLUDES
do
	GLOBALOPTIONS="$GLOBALOPTIONS --exclude=$exc "
done
for inc in $INCLUDES
do
	GLOBALOPTIONS="$GLOBALOPTIONS --include=$inc "
done
set +f


if [[ "$HOSTOPTIONS" != "" ]] ; then
	GLOBALOPTIONS="$GLOBALOPTIONS $HOSTOPTIONS"
fi


echo "BACKUPDIRS=$BACKUPDIRS"
# check that no filesystems are over highwater%
ARCHIVEDIR=$ARCHIVEROOTHOST/$CURRENT
if [[ "$Continue" == 1 ]] ; then
	for dir2backup in $BACKUPDIRS
	do
		echo "dir2backup $dir2backup"
		BACKUPDIR="$dir2backup"
		dorsync
		checkDiskSpaceAvail $ARCHIVEUSERHOST $ARCHIVEROOTHOST
		TheresRoom=$?
		if [[ "$TheresRoom" != "1" ]] ; then
			echo "BackupError:Avail > $HIGHWATER after backup"
			Continue=0
			break
		fi
	done
fi
if [[ "$POSTCOMMAND" != "" ]] ; then
	echo "##### POSTCOMMAND ####################################################"
	docom $POSTCOMMAND
	echo "######################################################################"
fi

#
# Anything in incr dir? (I.e. did anything change, i.e. did anything get backed up?
#
if [[ "$Continue" == 1 && "$ARCHIVES2KEEP" -gt 0 ]] ; then
	NumFilesInIncrDir=`ssh ${ARCHIVEUSERHOST} ls -a1 $ARCHIVEROOTHOST/$INCREMENTDIR |  egrep -v "\.$|\.\." | wc | awk -F\  '{print $1}'`
	if [[ "$NumFilesInIncrDir" -lt 1 ]] ; then
		echo "Nothing in incrementdir so:"
		echo "ssh ${ARCHIVEUSERHOST} rmdir $ARCHIVEROOTHOST/$INCREMENTDIR"
		ssh ${ARCHIVEUSERHOST} rmdir $ARCHIVEROOTHOST/$INCREMENTDIR
		Continue=0
	fi
fi

#
# Prune old backup dirs
#
if [[ "$PRUNEARCHIVES" == 1 && "$Continue" == 1 ]] ; then
	echo "######################################################################"
	if [[ "$ARCHIVES2KEEP" -gt 0 ]] ; then
		echo "Old archive removal"
	else
		echo "No Old archive removal ARCHIVES2KEEP=$ARCHIVES2KEEP"
	fi

	if [[ "$ARCHIVES2KEEP" -gt 0 ]]; then

		# get a list of the backup dirs
		ssh ${ARCHIVEUSER}@${ARCHIVEHOST} ls -1d $ARCHIVEROOTHOST/\* > ${LOGFILE}.arcount

		# how many are there? grep to make sure we only examine backup dirs we created
		arcount=`cat ${LOGFILE}.arcount | grep '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9]' | wc | awk -F\  '{print $1}'`

		echo -n "You have $arcount archives and "
		echo "ARCHIVES2KEEP is set to [$ARCHIVES2KEEP]"

		# Prune if
		if [[ "$arcount" -gt "$ARCHIVES2KEEP" ]] ; then

			# how many to prune?
			let num2delete=$arcount-${ARCHIVES2KEEP}
			ssh ${ARCHIVEUSER}@${ARCHIVEHOST} ls -1d $ARCHIVEROOTHOST/\* > ${LOGFILE}.ardirs
			grep '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9].[0-9][0-9].[0-9][0-9]' ${LOGFILE}.ardirs | head -$num2delete > ${LOGFILE}.rmdirs

			# get the list of dirs to prune
			dirs2rm=""
			while read dir2rm
			do
				# since we're doing an 'rm -rf' do some additional checks just to make sure!
				if [[ -n "$dir2rm" && "$dir2rm" != "/" && "$dir2rm" != "${ARCHIVEROOTHOST}/" ]] ; then
					dirs2rm="${dirs2rm} ${dir2rm}"
				else
					echo "BackupError: dirs2rm = [$dirs2rm]"
					break
				fi
			done < ${LOGFILE}.rmdirs

			# prune 'em
			docom ssh ${ARCHIVEUSER}@${ARCHIVEHOST} rm -rf $dirs2rm
		fi
	fi
fi

# Show du -hcs and df -h in log
echo "######################################################################"

echo "ssh ${BACKUPUSERHOST} $DF -h"
docom "ssh ${BACKUPUSERHOST} $DF -h"
echo
if [[ "${BACKUPUSERHOST}" != "${ARCHIVEUSERHOST}" ]] ; then
echo "ssh ${ARCHIVEUSERHOST} $DF -h"
docom "ssh ${ARCHIVEUSERHOST} $DF -h"
echo
fi

###
# Here's what this looks like
# find /mnt/md0/backups/media/ -maxdepth 1 | egrep "/2|/main" | $SORT | tail -3 | xargs $DU -hcs | grep media
#1004K   /mnt/md0/backups/media/2013-03-15_07-58-52
#1.5M    /mnt/md0/backups/media/2013-03-15_08-04-17
#1.3T    /mnt/md0/backups/media/main
###

#if [[ "$DODU" == 1 ]] ; then
docom "ssh ${ARCHIVEUSERHOST} /usr/bin/find $ARCHIVEROOTHOST -maxdepth 1 |egrep '/2|/main' |$SORT    |tail -3 | xargs $DU -hcs|grep $ARCHIVEROOTHOST"
#fi

edate=`date`
echo "######################################################################"
echo "Done ${BACKUPUSER}@${BACKUPHOST}:${BACKUPDIRS} ${ARCHIVEUSER}@${ARCHIVEHOST}:${ARCHIVEROOTHOST}"
echo "Began $bdate"
echo "Done  $edate"
}


#################################################################
# myexit. rm our pid file then exit
#################################################################
PIDFILE=/var/run/backup.sh.pid
myexit() {
	rm $PIDFILE >/dev/null
	exit
}
#################################################################
# main ##########################################################
#################################################################

if [[ -a "$PIDFILE" ]] ; then
	echo "$PIDFILE exists, backup already running?"
	exit
fi
pid=$$
echo $pid > $PIDFILE

# linux uname returns fqdn, cygwin returns just hostname so stripping off
# dn
#thishost=`uname -n | awk -F\  '{print $1}' | sed -e 's/\.makuch\.org//'`
thishost=`uname -n | awk -F\  '{print $1}'`
thisuser=`/usr/bin/whoami`

# this one can be overridden by config
ARCHIVES2KEEP=30

if [[ -a $CONFIG ]] ; then
. $CONFIG
else
	echo "no config!"
	myexit
fi
if [[ "$LOGFILEALLLOC" == "" ]] ; then
	echo "no LOGFILEALLLOC!"
	myexit
fi

BEGINDATE=`date`
DW=`date +%w`
INCREMENTDIR=`date +%Y-%m-%d_%H-%M-%S`
LOGFILE=/tmp/backup.logfile

# cleanup backup.logs from previous run, they'll be left there
# till next run
rm ${LOGFILE}* > /dev/null 2>&1
echo -n "Backup started " > ${LOGFILE}.all
echo "$0 $1 $2" >> ${LOGFILE}.all
date >> ${LOGFILE}.all
echo >> ${LOGFILE}.all

# prebackup defined in config file, optionally do some checks, mounts etc.
preresult=0
if [[ "$DOPREBACKUP" == 1 ]] ; then
	prebackup >>${LOGFILE}.all 2>&1
	preresult=$?
fi

if [[ "$preresult" != 0 ]] ; then
	echo "prebackup failed" | mail -s "$HOSTNAME backup failed to run" $MAILADDR
	myexit
else

if [[ -n "$H2B" ]] ; then
	NUMBACKUPS=$H2B
	DODU=0
fi


#
# main loop
#
	bctr=0
	ectr=0
	for BNUM in $NUMBACKUPS
	do

		# setup all the _NN backup vars

#####################################
# 		Here's how to do this var var;
#		xyz_ONEVAR=123
#		VAR=xyz
#		eval x="\$${VAR}_ONEVAR"
#		echo $x
#####################################


#		tmp='$'
#		tmp=$tmp`echo "EXEHOST_$BNUM"`
#		EXEHOST=`eval echo $tmp`

		eval CURRENT="\$ICURRENT_${BNUM}"

		GLOBALOPTIONS="-av --force --ignore-errors --delete --delete-excluded"
		eval IOPTIONS="\$IOPTIONS_${BNUM}"
		if [ "$IOPTIONS" != "" ] ; then
			GLOBALOPTIONS=$IOPTIONS
		fi
		eval APPEND_OPTIONS="\$APPEND_OPTIONS_${BNUM}"
		if [ "$APPEND_OPTIONS" != "" ] ; then
			GLOBALOPTIONS="$GLOBALOPTIONS $APPEND_OPTIONS"
		fi

		eval tmp="\$thishost_${BNUM}"
		if [[ "$tmp" != "" ]] ; then
			thishost=$tmp
		fi

		eval EXEHOST="\$EXEHOST_${BNUM}"

		eval EXEUSER="\$EXEUSER_${BNUM}"

		eval BACKUPUSER="\$BACKUPUSER_${BNUM}"

		eval BACKUPHOST="\$BACKUPHOST_${BNUM}"

		eval BACKUPUNAME="\$BACKUPUNAME_${BNUM}"

		eval ARCHIVEUSER="\$ARCHIVEUSER_${BNUM}"

		eval ARCHIVEHOST="\$ARCHIVEHOST_${BNUM}"

		if [[ "$EXEHOST" == "" ]]; then
			EXEHOST=$thishost
		fi
		if [[ "$EXEUSER" == "" ]]; then
			EXEUSER=$thisuser
		fi
		if [[ "$BACKUPHOST" == "" ]]; then
			BACKUPHOST=$thishost
		fi
		if [[ "$BACKUPUSER" == "" ]]; then
			BACKUPUSER=$thisuser
		fi
		if [[ "$ARCHIVEHOST" == "" ]]; then
			ARCHIVEHOST=$thishost
		fi
		if [[ "$ARCHIVEUSER" == "" ]]; then
			ARCHIVEUSER=$thisuser
		fi
		if [[ "" == "$BACKUPUNAME" ]] ; then
			BACKUPUNAME=$BACKUPHOST
		fi

		EXEUSERHOST="${EXEUSER}@${EXEHOST}"
		BACKUPUSERHOST="${BACKUPUSER}@${BACKUPHOST}"
		ARCHIVEUSERHOST="${ARCHIVEUSER}@${ARCHIVEHOST}"

		eval BACKUPDIRS="\$BACKUPDIRS_${BNUM}"

		eval ARCHIVES2KEEP="\$ARCHIVES2KEEP_${BNUM}"

		SINGLEDIR=0
		eval SINGLEDIR="\$SINGLEDIR_${BNUM}"

		eval ARCHIVEHARDROOT="\$ARCHIVEHARDROOT_${BNUM}"
		eval ARCHIVEROOT="\$ARCHIVEROOT_${BNUM}"
		if [[ "$thishost" == "$ARCHIVEROOT" ]]; then
			LOGFILEALLLOC="${ARCHIVEROOT}/${BACKUPHOST}/lasti/"
		fi

		if [ "$ARCHIVEHARDROOT" == "" ] ; then
			#ARCHIVEROOTHOST="$ARCHIVEROOT/$BACKUPHOST"
			ARCHIVEROOTHOST="$ARCHIVEROOT/$BNUM"
		else
			ARCHIVEROOTHOST=$ARCHIVEHARDROOT
		fi
		tmp='$'
		tmp=$tmp`echo "ARCHIVEROOTHOST_$BNUM"`
		if [[ "$tmp" != "" ]] ; then
			tmp=`eval echo $tmp`
		fi
		if [[ "$tmp" != "" ]] ; then
			ARCHIVEROOTHOST=$tmp
		fi

		if [[ "$DUROOTS" == "" ]] ; then
			DUROOTS=$ARCHIVEROOT
		fi

		eval ARCHIVE_RSYNCD_USER="\$ARCHIVE_RSYNCD_USER_${BNUM}"

		eval ARCHIVE_RSYNCD_HOST="\$ARCHIVE_RSYNCD_HOST_${BNUM}"

		eval ARCHIVE_RSYNCD_PW="\$ARCHIVE_RSYNCD_PW_${BNUM}"

		eval ARCHIVE_RSYNCD_MODULE="\$ARCHIVE_RSYNCD_MODULE_${BNUM}"

		eval ARCHIVE_RSYNCD_ROOT="\$ARCHIVE_RSYNCD_ROOT_${BNUM}"

		eval BACKUP_RSYNCD_USER="\$BACKUP_RSYNCD_USER_${BNUM}"

		eval BACKUP_RSYNCD_HOST="\$BACKUP_RSYNCD_HOST_${BNUM}"

		eval BACKUP_RSYNCD_PW="\$BACKUP_RSYNCD_PW_${BNUM}"

		eval BACKUP_RSYNCD_MODULE="\$BACKUP_RSYNCD_MODULE_${BNUM}"

		eval BACKUP_RSYNCD_ROOT="\$BACKUP_RSYNCD_ROOT_${BNUM}"

		eval tmp="\$ERRORIGNORE_${BNUM}"
		ERRORIGNORE="ErrorIgnoreXyzzyPlugh"
		if [[ "$tmp" != "" ]] ; then
			ERRORIGNORE=$tmp
			date >> /tmp/backup.logfile.errorignores
			echo $ERRORIGNORE >> /tmp/backup.logfile.errorignores
		fi

		set -f
		eval EXCLUDES="\$EXCLUDES_${BNUM}"
		eval EXCLUDESFILE="\$EXCLUDESFILE_${BNUM}"
		eval INCLUDES="\$INCLUDES_${BNUM}"
		set +f

		tmp='$'
		tmp=$tmp`echo "HIGHWATER_$BNUM"`
		if [[ "$tmp" != "" ]] ; then
			tmp=`eval echo $tmp`
		fi
		if [[ "$tmp" != "" ]] ; then
			HIGHWATER=$tmp
		fi
		tmp='$'
		tmp=$tmp`echo "PRECOMMAND_$BNUM"`
		if [[ "$tmp" != "" ]] ; then
			tmp=`eval echo $tmp`
		fi
		PRECOMMAND=""
		if [[ "$tmp" != "" ]] ; then
			PRECOMMAND=$tmp
		fi
		tmp='$'
		tmp=$tmp`echo "POSTCOMMAND_$BNUM"`
		if [[ "$tmp" != "" ]] ; then
			tmp=`eval echo $tmp`
		fi
		POSTCOMMAND=""
		if [[ "$tmp" != "" ]] ; then
			POSTCOMMAND=$tmp
		fi
		tmp='$'
		tmp=$tmp`echo "HOSTOPTIONS_$BNUM"`
		if [[ "$tmp" != "" ]] ; then
			tmp=`eval echo $tmp`
		fi
		HOSTOPTIONS=""
		if [[ "$tmp" != "" ]] ; then
			HOSTOPTIONS=$tmp
		fi

		# if LOGGING then redir all output to logfile(s)
		if [[ "$LOGGING" == 1 ]]; then

			doit > $LOGFILE 2>&1

			# format logs for summary, email report etc. Pretty hacky...
			LOGFILERMT="${ARCHIVEROOTHOST}/${INCREMENTDIR}/backup.log"
			scp $LOGFILE ${ARCHIVEUSER}@${ARCHIVEHOST}:$LOGFILERMT >/dev/null  2>&1
			cat $LOGFILE >> ${LOGFILE}.all

			began=`grep "^Began" ${LOGFILE}|cut -c1-25`
			done=`grep "^Done" ${LOGFILE}|/usr/bin/tail -1|cut -c1-25`


			#error=`egrep -i "^BackupError:|^rsync.*error:|Connection.*refused|^Corrupted${ERRORIGNORE}" ${LOGFILE}`
			error=`egrep -i "rsync error|input/output error|^BackupError:|^rsync.*error:|Connection.*refused|^Corrupted" ${LOGFILE}`
			if [[ "${ERRORIGNORE}" != "" ]] ; then
				error=`echo $error | egrep -iv "some files/attrs were not transferred|${ERRORIGNORE}"`
			fi

			size1=`/usr/bin/tail -7 ${LOGFILE} | head -2|/usr/bin/tail -1|awk -F\  '{printf"%s", $1}'`
			size2=`/usr/bin/tail -7 ${LOGFILE} | head -3|/usr/bin/tail -1|awk -F\  '{printf"%s", $1}'`
			if [[ "$ARCHIVES2KEEP" == 0 ]] ; then
				size1="n/a"
			fi

# ${parameter/pattern/string} If pattern begins with /, all matches of
# pattern are replaced with string.

			size1=`echo $size1|cut -c1-9`
			size2=`echo $size2|cut -c1-9`

			echo "$began ${BNUM} ${EXEUSERHOST}" >> ${LOGFILE}.summary
			echo "$done ${size1}, ${size2}" >> ${LOGFILE}.summary
			echo "${BACKUPUSERHOST} ${BACKUPDIRS}" >> ${LOGFILE}.summary
			echo "${ARCHIVEUSERHOST} ${ARCHIVEROOTHOST}" >> ${LOGFILE}.summary
			if [[ "$error" != "" ]] ; then
				echo "!!! $error" >> ${LOGFILE}.summary
				let ectr=$ectr+1
			fi
			echo "" >> ${LOGFILE}.summary

		else
			# else just let it go to stdout
			doit
		fi
		let bctr=$bctr+1

	done

	if [[ 1 == "$UNISON" ]] ; then
		/root/backup/unison.sh
	fi

fi
#ENDDATE=`date`

dototal() {
ENDDATE=`date`
	echo "$HOSTNAME backup report $INCREMENTDIR: "
	echo "Began $BEGINDATE"
	echo "Done  $ENDDATE"
	echo
if [[ "$DOCOMMANDS" == 1 ]] ; then
	localdf
	echo
fi
}

if [[ "$LOGGING" == 1 ]]; then
	if [[ "$DODU" == 1 ]]; then
		cp /dev/null ${LOGFILE}.total.tmp.du 2>&1
		for dur in $DUROOTS
		do
			echo  "######################################################" >> ${LOGFILE}.total.tmp.du 2>&1
			echo "$DU -hcs $dur/* | $SORT -h" >> ${LOGFILE}.total.tmp.du 2>&1
			date >> ${LOGFILE}.total.tmp.du 2>&1
			$DU -hcs $dur/* | $SORT -h >> ${LOGFILE}.total.tmp.du 2>&1
			echo  >> ${LOGFILE}.total.tmp.du 2>&1
			date >> ${LOGFILE}.total.tmp.du 2>&1
			echo  "######################################################" >> ${LOGFILE}.total.tmp.du 2>&1
			#echo "$DU -kcs $dur/* " >> ${LOGFILE}.total.tmp.du 2>&1
			#$DU -kcs $dur/* >> ${LOGFILE}.total.tmp.du 2>&1
			#echo  >> ${LOGFILE}.total.tmp.du 2>&1
		done
	fi
	dototal > ${LOGFILE}.total.tmp 2>&1
	if [[ "$DODU" == 1 ]]; then
		cat ${LOGFILE}.total.tmp.du  >> ${LOGFILE}.total.tmp
	fi

	head -3 ${LOGFILE}.total.tmp > ${LOGFILE}.total
	echo -e "\nBackups performed: $NUMBACKUPS" >> ${LOGFILE}.total
	echo "" >> ${LOGFILE}.total
	cat ${LOGFILE}.summary >> ${LOGFILE}.total
	echo "" >> ${LOGFILE}.total
	cat ${LOGFILE}.total.tmp >> ${LOGFILE}.total
	if [[ 1 == "$UNISON" ]] ; then
		cat /tmp/backup.logfile.unisonSummary >> ${LOGFILE}.total
	fi
	mv ${LOGFILE}.all ${LOGFILE}.tmp
	cp ${LOGFILE}.total ${LOGFILE}.all
	cat ${LOGFILE}.tmp >> ${LOGFILE}.all
	rm ${LOGFILE}.tmp
	echo >> ${LOGFILE}.all
	cat $CONFIG >> ${LOGFILE}.all
	cp ${LOGFILE}.all ${LOGFILEALLLOC}/${INCREMENTDIR}
	rm ${LOGFILEALLLOC}/last >/dev/null 2>&1
	ln -s ${LOGFILEALLLOC}/${INCREMENTDIR} ${LOGFILEALLLOC}/last

# append to end of log
	if [[ 1 == "$UNISON" ]] ; then
		cat /tmp/backup.logfile.unisonSummary >> ${LOGFILEALLLOC}/${INCREMENTDIR}
		cat /tmp/backup.logfile.unison >> ${LOGFILEALLLOC}/${INCREMENTDIR}
	fi
fi


if [[ "$SENDEMAIL" == 1 ]] ; then
	if [[ $ectr ]] ; then
		e=" $ectr errors"
	fi
	#mail -s "$HOSTNAME backup report $e" $MAILADDR < ${LOGFILE}.total
	cat ${LOGFILE}.total | ssh $MAILSSHER mail -s "\"$HOSTNAME backup report $e\"" $MAILADDR
fi

myexit
