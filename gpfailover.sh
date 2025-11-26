#!bin/bash

## define check variable (if DEADCNT >= 3 then run gpfailover)

DEADCNT=0

## get vip config
. /usr/local/bin/vip_env.sh
. /usr/local/greenplum-db/greenplum_path.sh
export PGPORT=5432

## killing previous gpfailover deamon
NO_OF_PROCESS=`ps -ef | grep gpfailover.sh | grep -v grep | grep -v status | grep -v stop | wc -l`

if [ $NO_OF_PROCESS -gt 2 ]; then
exit
fi

while true
do
        VIP_MD_FG=`ssh mdw "ifconfig | grep ${VIP} | wc -l"`
        VIP_SMD_FG=`ifconfig | grep ${VIP} | wc -l`

	if [[ -z "$VIP_MD_FG" ]]; then
    		echo "GP:INFO : Master node down. Please check Master node"
		logger -i -p user.emerg "GP:INFO : Master node down. Please check Master node"
	elif ! [[ "$VIP_MD_FG" =~ ^[0-9]+$ ]] || ! [[ "$VIP_SMD_FG" =~ ^[0-9]+$ ]]; then
    		echo "One of the variables (VIP_MD_FG or VIP_SMD_FG) is not a number."
    		logger -i -p user.emerg "GP:ERROR : VIP_MD_FG or VIP_SMD_FG is not numeric."
	elif [ "$VIP_MD_FG" -eq 1 ] && [ "$VIP_SMD_FG" -eq 1 ]; then
    		logger -i -p user.emerg "GP:ERROR : VIP is activated both MASTER and STANDBY servers!"
			logger -i -p user.emerg "GP:ERROR : You must use VIPs only on one server."
		ssh mdw 'echo "GP:ERROR : VIP is activated both MASTER and STANDBY servers! please running one server." | wall'
		ssh mdw 'echo "GP:ERROR : GP:ERROR : You must use VIPs only on one server." | wall'
	elif [ "$VIP_MD_FG" -eq 0 ] && [ "$VIP_SMD_FG" -eq 0 ]; then
    		logger -i -p user.emerg "GP:INFO : Does not activated VIP. Please running VIP."
		ssh mdw 'echo "GP:INFO : Does not activated VIP. Please running VIP." | wall'
	fi

	POSTGRESCNT=`ps -ef | grep postgres | wc -l`
	if [ $POSTGRESCNT -gt 8 ]; then
		echo "{GPSMDW} was activated !!!"
		exit 0
	else
		echo "{GPSMDW} is standby !!!"
	fi

	# ping 체크로 마스터서버 heart beat 체크 (연속적으로)
	CNT_A=`ping -c 6 -i 10 ${GPMDW} | grep ", 0% packet loss"| wc -l`
	if [ $CNT_A -eq 1 ]; then
		DEADCNT=$(($DEADCNT*0))
		echo "DEAD CHECK COUNT RESET"
	else
		DEADCNT=$(($DEADCNT+1))
		echo "DEAD CHECK COUNT : " $DEADCNT "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	fi

	if [ $DEADCNT -lt 3 ]
	then
		echo "GPDB MASTER ALIVE"
	else
		echo "GPDB RUN gpactivatestandby!!!"
                logger -i -p user.emerg "GP:WARNING : GPDB MASTER VM IS NOT AVAILABLE !!! "
                logger -i -p user.emerg "GP:INFO : Greenplum v6 detected. Failover Script Running ..."
                su - gpadmin -c "gpactivatestandby -d /data/master/gpseg-1 -a -q"
	### Checking the gpactivatestandby.log
        cd /home/gpadmin/gpAdminLogs
        SUCCESS_FG=`ls -lrt gpactivatestandby_*.log | tail -1  | awk '{print $9}' | xargs tail -30 | grep "The activation of the standby master has completed successfully" | wc -l`
        if [ ${SUCCESS_FG} -eq 1 ]
        then
             logger -i -p user.emerg "GP:INFO : The activation of the standby master has completed successfully "
        else
             logger -i -p user.emerg "GP:ERROR : Failed the activation of the standby master !!!"
             exit 1
        fi

         ifconfig ${VIP_INTERFACE} ${VIP}  netmask ${VIP_NETMASK} up

	### Start pgbouncer
        #su - gpadmin -c "gpstop -u"
        #su - gpadmin -c "/usr/local/greenplum-db/bin/pgbouncer -d /data/master/pgbouncer/pgbouncer.ini"

	### Checking VIP
        VIP_FG=`ifconfig | grep ${VIP} | wc -l`
        if [ ${VIP_FG} -eq 1 ]
        then
                logger -i -p user.emerg "GP:INFO : Stand by Master Virtual IP ${VIP}  is up"
        else
                logger -i -p user.emerg "GP:ERROR : Failed to start Stand by Master Virtual IP  ${VIP} "
        exit 1
	fi

	### arping
        arping -f -w 10 -s ${VIP} -U ${VIP_GW} -I ${ARPING_INTERFACE}
        logger -i -p user.emerg "GP:INFO : Executed arping"
        logger -i -p user.emerg "GP:INFO : Greenplum master failover has completed successfully"
        exit 0
	fi
sleep  10
done
exit 0
