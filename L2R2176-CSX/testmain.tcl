
btb test L2R2176-CSX "Configuring new application links, deleting existing application links, enabling or disabling each application link, or changing all application link configuration parameters shall not require a server shutdown and restart"

btb requirement L2R2176

btb comment "Waiting for 2 seconds before starting the test.." 
after 2000 {btb comment "Wait is over" ; set vwait_startup 0} 
vwait vwait_startup 

after 240000 {btb abort "timeout"}

set string_1 {s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g}

proc syscmd {server args} {
    global num
    incr num
    btb comment " System Manager issues command to $server: '[join $args]'."
    if { [catch {eval btb ssh $server $args} rc] } {
        btb failed " System Manager issued bad command to $server: '[join $args]'. Cause: $rc"
    } else {
        btb comment "System Manager issued command to $server: '[join $args]'."
    }
    return $rc
}

btb begin TS-1 "Create application link, then Configure, Enable, Disable, Delete"

append create_command {-side=S -dir=B -localport=7800 -acktim=1000 -ackenable=Y -kaacktim=1000 -idleterm=N -contim=1000 -condly=1000 -conretry=5 -nckretry=5 -dest=COD_FM1_CAD01 -protocol=XML}

btb comment "1. System Manager issues command"
syscmd bos.1 classd create UTCS.5 $create_command

btb comment "2.	Select CLDENABLED from CLASSD where CLDID is UTCS.5"
set result [btb_select bos.1 CLDENABLED FROM CLASSD WHERE CLDID = [btb sqlstring "UTCS.5"]]
btb comment "2. The result is $result"

if { [expr [ llength $result ] - 1 ] == 1 } {
    btb comment "2.1 One Row Returned"
} else {
    btb failed "2.1 FAILED.  There should be a record in RTD"
}

# Get UUT address
set result [catch {exec ping -c1 -n uut | head -n1 | sed $string_1} uut_addr]
btb comment "uut_addr = $uut_addr"

#Get SMT address
set result [catch {exec ping -c1 -n smt | head -n1 | sed $string_1} smt_addr]
btb comment "smt_addr = $smt_addr"

btb comment "3. System Manager issues command"
syscmd bos.1 classd configure UTCS.5 -side=S -dir=B -localport=7800 -localaddr=$uut_addr -addr=$smt_addr -dest=COD_FM1_CAD01 -protocol=XML

after 1000 {set wait_one 0}
vwait wait_one 

set result [btb_select bos.1 CLDSIDE,CLDDIR,CLDLOCALADDR,CLDLOCALPORT,CLDREMOTEPORT,CLDDEST,CLDPROTOCOL FROM CLASSD WHERE CLDID = [btb sqlstring "UTCS.5"]]
btb comment "4. The result is $result"

append result_expected {CLDSIDE CLDDIR CLDLOCALADDR CLDLOCALPORT CLDREMOTEPORT CLDDEST CLDPROTOCOL S B } $uut_addr { 7800 0 COD_FM1_CAD01 XML}
if { $result == $result_expected } {
	btb comment "4.1.Expected values are returned for CLDSIDE,CLDDIR,CLDLOCALPORT,CLDREMOTEPORT,CLDDEST,CLDPROTOCOL"
} else {
	btb failed "4.1. Unexpected values are returned."
}

btb comment "5. System Manager issues command to enable"
syscmd bos.1 classd enable UTCS.5

after 1000 {set wait_one 0}
vwait wait_one 

set result [btb_select bos.1 CLDENABLED,CLDSTATUS FROM CLASSD WHERE CLDID = [btb sqlstring "UTCS.5"]]
btb comment "6. The result is $result"

if { $result == "CLDENABLED CLDSTATUS Y D"} {
	btb comment "6.1.Expected values are returned for CLDENABLED CLDSTATUS"
} else {
	btb failed "6.1. Unexpected values are returned."
}


btb comment "7.System Manager issues command: classd disable UTCS.5"
syscmd bos.1 classd disable UTCS.5 

after 1000 {set wait_one 0}
vwait wait_one 

set result [btb_select bos.1 CLDENABLED,CLDSTATUS FROM CLASSD WHERE CLDID = [btb sqlstring "UTCS.5"]]
btb comment "8. The result is $result"

if { $result == "CLDENABLED CLDSTATUS N D"} {
	btb comment "8.1.Expected values are returned for CLDENABLED CLDSTATUS"
} else {
	btb failed "8.1. Unexpected values are returned."
}

btb comment "9.System Manager issues command: classd delete UTCS.5"
syscmd bos.1 classd delete UTCS.5 

set result [btb_select bos.1 CLDENABLED FROM CLASSD WHERE CLDID = [btb sqlstring "UTCS.5"]]
btb comment "10. The result is $result"

if { $result == ""} {
	btb comment "10.1.No record is returned"
} else {
	btb failed "10.1. Unexpected values are returned."
}

btb end TS-1


btb begin TS-2 "(derived) Attempt to Create an Application Link to Bad IP Address – Failure does not cause Restart"

btb comment "Modify svrip value by adding 1 to it"

#Get SMT address
set result [catch {exec ping -c1 -n smt | head -n1 | sed $string_1} smt_addr]
btb comment "smt_addr = $smt_addr"

set str_last [string last . $smt_addr ]
btb comment "str_last = $str_last"

append svrip [string range $smt_addr 0 $str_last] [expr [string range $smt_addr [expr $str_last + 1] [string length $smt_addr] ] + 1]
btb comment "svrip = $svrip"

append client_command {-side=C -dir=B -localport=7805 -remoteport=7801 -addr=} $svrip { -acktim=1000 -ackenable=Y -kaacktim=1000 -idleterm=N -contim=1000 -condly=1000 -conretry=5 -nckretry=5 -dest=LOC_FM1_DISP03 -protocol=EMP}
btb comment "client_command = $client_command"

btb comment "11. System Manager issues command on client"
syscmd bos.1 classd create CSXLNK.1 $client_command

btb comment "12. Wait one second"
after 1000 {set wait_one 0}
vwait wait_one 

set server_command {-side=S -dir=B -localport=7801 -remoteport=7805 -acktim=1000 -ackenable=Y -kaacktim=1000 -idleterm=N -contim=1000 -condly=1000 -conretry=5 -nckretry=5 -dest=LOC_FM1_DISP03 -protocol=EMP}

btb comment "13. System Manager issues command on Server"
syscmd bos.1 classd create CSXLNK.1 $server_command

btb comment "14. Wait 120 seconds"
after 120000 {set wait_one_twenty 0}
vwait wait_one_twenty

btb comment "15. System manager issues command on both client and server to attempt to enable the link"

btb comment " Enable server side link"
syscmd bos.1 classd enable CSXLNK.1 -side=S

btb comment " Enable Client side link"
syscmd bos.1 classd enable CSXLNK.1 -side=C

btb comment "16. Wait one second"
after 1000 {set wait_one 0}
vwait wait_one 

set result [btb_select bos.1 CLDSTATUS FROM CLASSD WHERE CLDID = [btb sqlstring "CSXLNK.1"]]
btb comment "17. The result is $result"

if { $result == "CLDSTATUS D"} {
	btb comment "17.1.Expected values are returned for CLDENABLED CLDSTATUS"
} else {
	btb failed "17.1. Unexpected values are returned."
}

btb end TS-2




