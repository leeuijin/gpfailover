# gpfailover 개요

  gpfailover 서비스로 등록하여 greenplum master node의 failover 를 설정할수 있는 스크립트입니다.


# 원리

	stand by master  (smdw) 에서 서비스로 등록한 gpfailover를 통하여 master node  (mdw) 서버의 heart beat 체크를 주기적으로 진행합니다.
	heart beat 체크가 연속 실패되는 경우 master node 에 문제가 있다고 판단하여 stand by master node로 promote를 진행합니다.
	failover 를 진행 후 master node 서버에서 서비스하던 VIP를 stand by master에서 기동합니다.
	모든 heart beat 체크 및 failover, VIP 관련 메세지 및 로그는 (smdw)의 /var/log/message 파일에 작성됩니다. 
	heart beat 체크 주기는 failover.sh 스크립트 수정을 통하여 변경가능합니다. 

# 개선사항 (2025.04.25)

	1) failover 가 정상적으로 완료된 경우에만 smdw VIP를 활성화 합니다.
	2) master node (mdw)와 stand by master mode (smdw) 에 동시에 VIP가 활성화된 경우 주기적으로 메세지를 발생합니다.
	3) VIP 가 활성화 되지 않았거나 두 노드에서 VIP가 활성화 되있는 경우 master node 와 stand by master 에 주기적으로 모두 메세지를 발생합니다.
	4) Greenplum 버젼에 따라 promote 명령어가 상이합니다. 버젼을 체크하여 적합한 명령어를 실행할수 있도록 합니다. (v6 & v7)

# 설정 방법

	1. vip_env.sh 수정 (mdw)
		
		vi 에디터를 이용하여 사용자 환경에 맞도록 설정하세요 
		주의사항1 : VIP_INTERFACE 설정에서 기존 네트워크 아답터 이름에서  ":0"을 붙여 설여 설정합니다.

	2. 사용자 OS환경에 적합한 setup 스크립트를 master 노드에서 실행합니다. (mdw)

		주의사항2 : master node에서 setup 스크립트를 실행합니다.
		ex)
		[gpadmin@mdw gpfailover]$ sudo sh setup_gpfo_rhel8.sh
		Is current GPDB started?
		vip_env.sh modified? y
		mkdir: cannot create directory ‘/usr/local/bin’: File exists
		1. Copy Files - mdw : OK
		mkdir: cannot create directory ‘/usr/local/bin’: File exists
		gpfailover.sh                                   100% 4455     5.9MB/s   00:00
		gpfailovershutdown.sh                           100%   99   191.8KB/s   00:00
		setup_gpfo_rhel6.sh                             100% 1756     3.9MB/s   00:00
		setup_gpfo_rhel7.sh                             100% 1988     4.5MB/s   00:00
		setup_gpfo_rhel8.sh                             100% 1988     4.5MB/s   00:00
		vip_env.sh                                      100%  134   278.8KB/s   00:00
		vip_start.sh                                    100%  187   368.7KB/s   00:00
		vip_stop.sh                                     100%   91   178.2KB/s   00:00
		vip                                             100%  493   846.4KB/s   00:00
		dest open("/etc/rc.d/rc3.d/"): Failure
		failed to upload file S99gpfailover to /etc/rc.d/rc3.d/
		chown: cannot access '/etc/rc.d/rc3.d/S99gpfailover': No such file or directory
		gpfailover                                      100%  837     2.0MB/s   00:00
		stat local "gpfailover.service": No such file or directory
		2. Copy Files - smdw : OK
		3. smdw .bash_profile modify : OK
		ARPING 172.16.200.2 from 172.16.200.100 ens160
		Unicast reply from 172.16.200.2 [00:50:56:EA:E7:14]  0.928ms
		Sent 1 probes (1 broadcast(s))
		Received 1 response(s)
		4. mdw vip_start : OK
		active
		● gpfailover.service
		     Loaded: loaded (/etc/rc.d/init.d/gpfailover; generated)
		     Active: active (exited) since Fri 2025-04-25 18:17:34 KST; 50s ago
		       Docs: man:systemd-sysv-generator(8)
		        CPU: 82ms

		Apr 25 18:17:34 smdw systemd[1]: Starting gpfailover.service...
		Apr 25 18:17:34 smdw gpfailover[3267]: Starting GPDB Auto failover Daemon:
		Apr 25 18:17:34 smdw gpfailover[3285]: gpfailover daemon is running
		Apr 25 18:17:34 smdw systemd[1]: Started gpfailover.service.
		Apr 25 18:17:37 smdw root[3384]: GP:INFO : Master node down. Please check Master node
		gpfailover.service is not a native service, redirecting to systemd-sysv-install.
		Executing: /usr/lib/systemd/systemd-sysv-install enable gpfailover
		Failed to execute /usr/lib/systemd/systemd-sysv-install: No such file or directory
		5. smdw service : OK

	3. master node VIP 확인 (mdw)

		[gpadmin@mdw ~]$ sudo ifconfig
		ens160: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		        inet 172.16.200.161  netmask 255.255.255.0  broadcast 172.16.200.255
		        inet6 fe80::20c:29ff:fe68:8d5  prefixlen 64  scopeid 0x20<link>
		        ether 00:0c:29:68:08:d5  txqueuelen 1000  (Ethernet)
		        RX packets 548909  bytes 741290128 (706.9 MiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 342889  bytes 485838094 (463.3 MiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

		ens160:0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500                    
		        inet 172.16.200.100  netmask 255.255.252.0  broadcast 172.16.203.255
		        ether 00:0c:29:68:08:d5  txqueuelen 1000  (Ethernet)

		ens224: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		        inet 192.16.200.161  netmask 255.255.255.0  broadcast 192.16.200.255
		        inet6 fe80::20c:29ff:fe68:8df  prefixlen 64  scopeid 0x20<link>
		        ether 00:0c:29:68:08:df  txqueuelen 1000  (Ethernet)
		        RX packets 181  bytes 17421 (17.0 KiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 55  bytes 7440 (7.2 KiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

		lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
		        inet 127.0.0.1  netmask 255.0.0.0
		        inet6 ::1  prefixlen 128  scopeid 0x10<host>
		        loop  txqueuelen 1000  (Local Loopback)
		        RX packets 55866  bytes 9456498 (9.0 MiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 55866  bytes 9456498 (9.0 MiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

	4. failover.service 확인 (smdw)
		
			[gpadmin@smdw coordinator]$ systemctl status gpfailover
		● gpfailover.service
		     Loaded: loaded (/etc/rc.d/init.d/gpfailover; generated)
		     Active: active (running) since Fri 2025-04-25 18:46:28 KST; 5s ago
		       Docs: man:systemd-sysv-generator(8)
		    Process: 1706 ExecStart=/etc/rc.d/init.d/gpfailover start (code=exited, status=0/SUCCESS)
		      Tasks: 5 (limit: 10887)
		     Memory: 2.7M
		        CPU: 108ms
		     CGroup: /system.slice/gpfailover.service
		             ├─1707 bin/bash /usr/local/bin/gpfailover.sh
		             ├─1740 bin/bash /usr/local/bin/gpfailover.sh
		             ├─1741 ping -c 5 -i 2 mdw
		             ├─1742 grep ", 0% packet loss"
		             └─1743 wc -l

		Apr 25 18:46:28 smdw systemd[1]: Starting gpfailover.service...
		Apr 25 18:46:28 smdw gpfailover[1706]: Starting GPDB Auto failover Daemon:
		Apr 25 18:46:28 smdw gpfailover[1724]: gpfailover daemon is running
		Apr 25 18:46:28 smdw systemd[1]: Started gpfailover.service.

# 작동 예)

	1. master node 에 VIP가 활성화 되지 않은 경우

		양족 노드에 다음과 같은 메세지가 주기적으로 발생합니다.

		[gpadmin@mdw gpfailover]$ sudo sh vip_stop.sh
		Broadcast message from root@mdw (somewhere) (Fri Apr 25 21:00:03 2025):
		GP:INFO : Does not activated VIP. Please running VIP.

	2. 	master node 와 stand by master node 모두 VIP가 활성화 되어 있는 경우

		양족 노드에 다음과 같은 메세지가 주기적으로 발생합니다.
		
          	Broadcast message from systemd-journald@smdw (Fri 2025-04-25 21:02:33 KST):
		root[8024]: GP:ERROR : VIP is activated both MASTER and STANDBY servers! please running one server.
		Message from syslogd@smdw at Apr 25 21:02:33 ...
 		root[8024]:GP:ERROR : VIP is activated both MASTER and STANDBY servers! please running one server.

 	3. 3차례 연속으로 heart beat 체크(응답) 이 없는 경우 

		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT RESET
		GPDB MASTER ALIVE
		{GPSMDW} is standby !!!
		DEAD CHECK COUNT :  1 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		GPDB MASTER ALIVE
		ssh: connect to host mdw port 22: No route to host
		GP:INFO : Master node down. Please check Master node

		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:34:58 KST):

		gpadmin[1795]: GP:INFO : Master node down. Please check Master node

		{GPSMDW} is standby !!!

		Message from syslogd@smdw at Apr 25 17:34:58 ...
		 gpadmin[1795]:GP:INFO : Master node down. Please check Master node
		DEAD CHECK COUNT :  2 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		GPDB MASTER ALIVE
		ssh: connect to host mdw port 22: No route to host
		GP:INFO : Master node down. Please check Master node

		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:21 KST):

		gpadmin[1821]: GP:INFO : Master node down. Please check Master node

		{GPSMDW} is standby !!!

		Message from syslogd@smdw at Apr 25 17:35:21 ...
		 gpadmin[1821]:GP:INFO : Master node down. Please check Master node
		DEAD CHECK COUNT :  3 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		GPDB RUN gpactivatestandby!!!
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:31 KST):
		gpadmin[1835]: GP:WARNING : GPDB MASTER VM IS NOT AVAILABLE !!!
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:31 KST):
		gpadmin[1836]: GP:INFO : Greenplum v7 detected. Failover Script Running ...
		Message from syslogd@smdw at Apr 25 17:35:31 ...
		 gpadmin[1835]:GP:WARNING : GPDB MASTER VM IS NOT AVAILABLE !!!

		Message from syslogd@smdw at Apr 25 17:35:31 ...
		 gpadmin[1836]:GP:INFO : Greenplum v7 detected. Failover Script Running ...
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:------------------------------------------------------
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Standby data directory    = /data/coordinator/gpseg-1
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Standby port              = 5432
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Standby running           = yes
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Force standby activation  = no
		20250425:17:35:31:001837 gpactivatestandby:smdw:gpadmin-[INFO]:------------------------------------------------------
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-found standby postmaster process
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Promoting standby...
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Standby coordinator is promoted
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Reading current configuration...
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:------------------------------------------------------
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-The activation of the standby coordinator has completed successfully.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-smdw is now the new primary coordinator.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-You will need to update your user access mechanism to reflect
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-the change of coordinator hostname.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Do not re-start the failed coordinator while the fail-over coordinator is
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-operational, this could result in database corruption!
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-COORDINATOR_DATA_DIRECTORY is now /data/coordinator/gpseg-1 if
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-this has changed as a result of the standby coordinator activation, remember
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-to change this in any startup scripts etc, that may be configured
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-to set this value.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-COORDINATOR_PORT is now 5432, if this has changed, you
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-may need to make additional configuration changes to allow access
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-to the Greenplum instance.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Refer to the Administrator Guide for instructions on how to re-activate
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-the coordinator to its previous state once it becomes available.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-Query planner statistics must be updated on all databases
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-following standby coordinator activation.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:-When convenient, run ANALYZE against all user databases.
		20250425:17:35:34:001837 gpactivatestandby:smdw:gpadmin-[INFO]:------------------------------------------------------
		ssh: connect to host mdw port 22: No route to host
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:37 KST):
		gpadmin[1904]: GP:INFO : Greenplum master failover has completed successfully
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:37 KST):
		gpadmin[1909]: GP:INFO : Stand by Master Virtual IP 172.16.200.100  is up
		ARPING 172.16.200.2 from 172.16.200.100 ens160
		Unicast reply from 172.16.200.2 [00:50:56:EA:E7:14]  1.553ms
		Sent 1 probes (1 broadcast(s))
		Received 1 response(s)
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:37 KST):
		gpadmin[1911]: GP:INFO : Executed arping
		Broadcast message from systemd-journald@smdw (Fri 2025-04-25 17:35:37 KST):
		gpadmin[1912]: GP:INFO : Greenplum master failover has completed successfully
		[gpadmin@smdw bin]$
		Message from syslogd@smdw at Apr 25 17:35:37 ...
		 gpadmin[1904]:GP:INFO : Greenplum master failover has completed successfully
		Message from syslogd@smdw at Apr 25 17:35:37 ...
		 gpadmin[1909]:GP:INFO : Stand by Master Virtual IP 172.16.200.100  is up
		Message from syslogd@smdw at Apr 25 17:35:37 ...
		 gpadmin[1911]:GP:INFO : Executed arping
		Message from syslogd@smdw at Apr 25 17:35:37 ...
		 gpadmin[1912]:GP:INFO : Greenplum master failover has completed successfully
		[gpadmin@smdw bin]$ psql
		psql (12.12)
		Type "help" for help.

		gpkrtpch=# \q

		[gpadmin@smdw gpfailover]$ ifconfig
		ens160: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		        inet 172.16.200.162  netmask 255.255.255.0  broadcast 172.16.200.255
		        inet6 fe80::20c:29ff:fe44:7257  prefixlen 64  scopeid 0x20<link>
		        ether 00:0c:29:44:72:57  txqueuelen 1000  (Ethernet)
		        RX packets 173769  bytes 244755902 (233.4 MiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 15698  bytes 2919254 (2.7 MiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

		ens160:0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		        inet 172.16.200.100  netmask 255.255.252.0  broadcast 172.16.203.255       
		        ether 00:0c:29:44:72:57  txqueuelen 1000  (Ethernet)

		ens224: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		        inet 192.16.200.162  netmask 255.255.255.0  broadcast 192.16.200.255
		        inet6 fe80::20c:29ff:fe44:7261  prefixlen 64  scopeid 0x20<link>
		        ether 00:0c:29:44:72:61  txqueuelen 1000  (Ethernet)
		        RX packets 383  bytes 28995 (28.3 KiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 20  bytes 1316 (1.2 KiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

		lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
		        inet 127.0.0.1  netmask 255.0.0.0
		        inet6 ::1  prefixlen 128  scopeid 0x10<host>
		        loop  txqueuelen 1000  (Local Loopback)
		        RX packets 22  bytes 2296 (2.2 KiB)
		        RX errors 0  dropped 0  overruns 0  frame 0
		        TX packets 22  bytes 2296 (2.2 KiB)
		        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0


