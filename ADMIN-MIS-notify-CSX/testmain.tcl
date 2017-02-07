btb test ADMIN-MIS-notify-CSX "This test procedure validates the following requirements"

btb requirement L2R2765
btb requirement L2R2766
btb requirement L2R5868
btb requirement L2R5869
btb requirement L2R5870
btb requirement L2R5871

# The following line starts one proxy and waits for it to be ready: 
proxy start csx2 BTB_PRO_CSX UTCS.2
proxy start csx3 BTB_PRO_CSX UTCS.3
proxy start loco BTB_PRO_LOCOMOTIVE LOCOMOTIVE.1

btb comment "Waiting for 2 seconds before starting the test.."
after 2000 {btb comment "Wait is over" ; set vwait_startup 0}
vwait vwait_startup

after 2000000 {btb abort "timeout"}

btb comment "General Precondition - Setup"

set SCACID "CSXT"
set SUBDIV_NAME1 "AB"
set SUBDIV_NAME2 "WM"
set SUBDIV_ID1 201
set SUBDIV_ID2 468
set TRAINID1 "Train1234567890123456789"
set LOCOID1 "ARIN  9001"
set LOCOADDR "arin.l.arin.9001"
set MSG_2083 2083CAD
set MSG_2084 2084CAD
set MSG_2088 2088CAD

btb_registry_set_int bos.1 TBC_3 75
btb_registry_set_int bos.1 TBC_114 10
btb_registry_set_int bos.1 CAD_ACK 0
btb_registry_set_int bos.1 TBC_134 50
btb_registry_set_int bos.1 TBC_135 60

btb comment "General Precondition - Setup End"

btb begin TS-1 "L2R2765-1: Activate Notification messages for all events per subdivision/district – AB,WM  on G BOS"

btb comment "Test Precondition - Setup"

set LID [btb_select bos.1 ID FROM LOGIC_PUBLISH]
foreach ID $LID {
	if { $ID != "ID"} {
		if { [regexp {[0-9]+} $ID MSGID] } {
			catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $ID msgtype $MSGID district ALL} result
		}
	} else {
		continue
	}
}

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "0.1 Configure CFG 32 to disable all notification to CAD successfully"
} else {
    btb failed "0.1 Configure CFG 32 to disable all notification to CAD unsuccessfully - result=$result"
}

btb_registry_set_int bos.1 TBC_94 2
btb_sup_ptc_sync csx2 "$SUBDIV_NAME1"
btb_sup_ptc_sync csx3 "$SUBDIV_NAME2"
btb_sup_poll_setup csx3 "$SUBDIV_NAME2" "$TRAINID1" "$LOCOID1" "$SUBDIV_NAME2 $SUBDIV_NAME1"
btb_sup_poll_register_loco loco "$LOCOADDR" "$SCACID" "$TRAINID1" $SUBDIV_ID2
btb_sup_poll_setup csx2 "$SUBDIV_NAME1" "$TRAINID1" "$LOCOID1" "$SUBDIV_NAME1 $SUBDIV_NAME2"
btb_sup_poll_register_loco loco "$LOCOADDR" "$SCACID" "$TRAINID1" $SUBDIV_ID1

csx2 do {
    btb_send_file_periodic [btb testdir]/MBCDKPAB.1.xml msg_MBCDKPAB.1 5
}
csx3 do {
    btb_send_file_periodic [btb testdir]/MBCDKPAB.2.xml msg_MBCDKPAB.2 5
}

btb comment "Test Precondition - Setup End"

btb comment "Step 1. Verify that ENABLED = N and SUBDIDX = 0 for each MSGTYPE in LOGIC_PUBLISH table"
set lenabled [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH]
set lsubdidx [btb_select bos.1 SUBDIDX FROM LOGIC_PUBLISH]
set llenabled [llength $lenabled]
set llsubdidx [llength $lsubdidx]
set cenabled 0
foreach value $lenabled {
	if { $value == "ENABLED" || $value == "N" } {
		incr cenabled
	}
}
set csubdidx 0
foreach value $lsubdidx {
	if { $value == "SUBDIDX" || $value == "0" } {
		incr csubdidx
	}
}

if { $llenabled == $cenabled } { 
	btb comment "1.1 All ENABLED are equal to N - $llenabled == $cenabled" 
} else {
	btb failed "1.1 All ENABLED are not equal to N - $llenabled == $cenabled" 
}
if { $llsubdidx == $csubdidx } { 
	btb comment "1.2 All SUBDIDX are equal to 0 - $llsubdidx == $csubdidx" 
} else {
	btb failed "1.2 All SUBDIDX are not equal to 0 - $llsubdidx == $csubdidx" 
}

btb comment "Step 2. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"

btb comment "Step 2.0.1 Set SUBDIDX = $SUBDIV_NAME1 for ID = $MSG_2083"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2083CAD msgtype 2083 district $SUBDIV_NAME1} result

btb comment "Step 2.0.2 Set SUBDIDX = $SUBDIV_NAME2 for ID = $MSG_2084"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2084CAD msgtype 2084 district $SUBDIV_NAME2} result

btb_event_declare csx3_MBBSTEFA03.1
csx3 do {
    icd handler MBBSTEFA04 do {
        btb failed "2.1 CAD received MBBSTEFA03.1 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.1
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.1
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.1] } {
        btb comment "2.1 CAD did not receive MBBSTEFA03.1 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.1
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 3. TMC sends 02084 (Emergency Brake Application Report) to GBOS"
btb_event_declare csx3_MBBSTEMA04.1
csx3 do {
    icd handler MBBSTEMA05 do {
        btb failed "3.1 CAD received MBBSTEMA04.1 (Emergency Brake Application Report)"
        btb_event_wakeup csx3_MBBSTEMA04.1
    }
}
loco background {
    btb_send_file [btb testdir]/02084.1.xml msg_02084.1
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEMA04.1] } {
        btb comment "3.1 CAD did not received MBBSTEMA04.1 (Emergency Brake Application Report)"
    }
    btb_event_wakeup csx3_MBBSTEMA04.1
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 4. Configure CFG 32 to activate (enable) railroad network event notification for all events for individual subdivision/district $SUBDIV_NAME1"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc enepub msgtype ALL district $SUBDIV_NAME1} result
if { $result == "" } {
    btb comment "Step 4.1 Configure CFG 32 to enable all notification on $SUBDIV_NAME1 successfully"
} else {
    btb failed "Step 4.1 Configure CFG 32 to enable all notification on $SUBDIV_NAME1 unsuccessfully - result=$result"
}

btb comment "Step 5. Configure CFG 32 to activate (enable) railroad network event notification for all events for individual subdivision/district $SUBDIV_NAME2"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc enepub msgtype ALL district $SUBDIV_NAME2} result
if { $result == "" } {
    btb comment "Step 5.1 Configure CFG 32 to enable all notification on $SUBDIV_NAME2 successfully"
} else {
    btb failed "Step onfigure CFG 32 to enable all notification on $SUBDIV_NAME2 unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 6. Verify that ENABLED = Y for SUBDIV_NAME = $SUBDIV_NAME1"
set SUBIDX [lindex [btb_select bos.1 SORTNO FROM LOGIC_SUBDIVISION WHERE SUBDIV_NAME = [btb sqlstring $SUBDIV_NAME1]] 1]
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 6.1 ENABLED = Y for $SUBDIV_NAME1"
} else {
    btb failed "Step 6.1 ENABLED != Y for $SUBDIV_NAME1 -- result = $result"
}

btb comment "Step 7. Verify that ENABLED = Y for SUBDIV_NAME = $SUBDIV_NAME2"
set SUBIDX [lindex [btb_select bos.1 SORTNO FROM LOGIC_SUBDIVISION WHERE SUBDIV_NAME = [btb sqlstring $SUBDIV_NAME2]] 1]
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 7.1 ENABLED = Y for $SUBDIV_NAME2"
} else {
    btb failed "Step 7.1 ENABLED != Y for $SUBDIV_NAME1 -- result = $result"
}

btb comment "Step 8. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"
btb_event_declare csx3_MBBSTEFA03.2
csx2 do {
    icd handler MBBSTEFA04 do {
        btb comment "8.1 CAD received MBBSTEFA03.2 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.2
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.2
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.2] } {
        btb failed "8.1 CAD did not receive MBBSTEFA03.2 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.2
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 9. TMC sends 02084 (Emergency Brake Application Report) to GBOS"
btb_event_declare csx3_MBBSTEMA04.2
csx3 do {
    icd handler MBBSTEMA05 do {
        btb comment "9.1 CAD received MBBSTEMA04.2 (Emergency Brake Application Report)"
        btb_event_wakeup csx3_MBBSTEMA04.2
    }
}
loco background {
    btb_send_file [btb testdir]/02084.1.xml msg_02084.2
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEMA04.2] } {
        btb failed "9.1 CAD did not received MBBSTEMA04.2 (Emergency Brake Application Report)"
    }
    btb_event_wakeup csx3_MBBSTEMA04.2
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-1


btb begin TS-2 "L2R2766-1: Deactivate Notification messages for all events per subdivision/district – AB,WM  on G BOS"

btb comment "Test Precondition - Setup"

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2083CAD msgtype 2083 district ALL} result
if { $result == "" } {
    btb comment "0.2 Set district = 0  on 2083CAD successfully"
} else {
    btb failed "0.2 Set district = 0  on 2083CAD unsuccessfully"
}

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2084CAD msgtype 2084 district ALL} result
if { $result == "" } {
    btb comment "0.3 Set district = 0  on 2083CAD successfully"
} else {
    btb failed "0.3 Set district = 0  on 2083CAD unsuccessfully"
}

after 1000 {set event_delay 0}
vwait event_delay

btb_sup_ptc_sync csx2 "$SUBDIV_NAME1"

after 500 {set event_delay 0}
vwait event_delay

btb_sup_ptc_sync csx3 "$SUBDIV_NAME2"

after 1000 {set event_delay 0}
vwait event_delay

btb comment [btb ssh bos.1 rtdsh update LOGIC_SUBDIVISION set BOS_INSTANCE = [btb sqlstring "UPBOS1"] where SUBDIV_NAME = [btb sqlstring "CIBOS"]]

after 500 {set event_delay 0}
vwait event_delay

#### *** ENABLE event notification for specific message and subdiv ****
btb comment "System Manager command to ENABLE event notifications for message 2083"
btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2083CAD msgtype 2083 subdiv AB enabled Y

after 1000 {set event_delay 0}
vwait event_delay

btb comment "System Manager command to ENABLE event notifications for message 2084"
btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2084CAD msgtype 2084 subdiv WM enabled Y

after 1000 {set event_delay 0}
vwait event_delay

btb comment "Test Precondition - Setup End"

set msgtype_status_count [llength [lrange [btb_select bos.1 MSGTYPE from LOGIC_PUBLISH WHERE ID like [btb sqlstring "%CAD"] AND ENABLED = [btb sqlstring "Y"]] 1 end]]

btb comment "msgtype_status_count == $msgtype_status_count"

if { $msgtype_status_count == "2" } {
btb comment "10.1 ENABLED == Y. Result is expected."
} else {
btb failed "10.1 Failed. Result is  not expected."
}

btb comment "Step 11. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"

btb_event_declare csx3_MBBSTEFA03.3
csx2 do {
    icd handler MBBSTEFA04 do {
        btb comment "11.1 CAD received MBBSTEFA03.3 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.3
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.3
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.3] } {
        btb failed "11.1 CAD did not receive MBBSTEFA03.3 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.3
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 12. TMC sends 02084 (Emergency Brake Application Report) to GBOS"
btb_event_declare csx3_MBBSTEMA04.3
csx3 do {
    icd handler MBBSTEMA05 do {
        btb comment "12.1 CAD received MBBSTEMA04.3 (Emergency Brake Application Report)"
        btb_event_wakeup csx3_MBBSTEMA04.3
    }
}
loco background {
    btb_send_file [btb testdir]/02084.1.xml msg_02084.3
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEMA04.3] } {
        btb failed "12.1 CAD did not received MBBSTEMA04.3 (Emergency Brake Application Report)"
    }
    btb_event_wakeup csx3_MBBSTEMA04.3
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 13. Configure CFG 32 to deactivate (disable) railroad network event notification for all events for individual subdivision/district $SUBDIV_NAME1"

btb comment "Step 13.0.1 Set SUBDIDX = $SUBDIV_NAME1 for ID = $MSG_2083"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2083CAD msgtype 2083 district $SUBDIV_NAME1} result

btb comment "Step 13.0.2 Set SUBDIDX = $SUBDIV_NAME2 for ID = $MSG_2084"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2084CAD msgtype 2084 district $SUBDIV_NAME2} result

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district $SUBDIV_NAME1} result
if { $result == "" } {
    btb comment "Step 13.1 Configure CFG 32 to disable all notification on $SUBDIV_NAME1 successfully"
} else {
    btb failed "Step 13.1 Configure CFG 32 to disable all notification on $SUBDIV_NAME1 unsuccessfully - result=$result"
}

btb comment "Step 14. Configure CFG 32 to deactivate (disable) railroad network event notification for all events for individual subdivision/district $SUBDIV_NAME2"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district $SUBDIV_NAME2} result
if { $result == "" } {
    btb comment "Step 14.1 Configure CFG 32 to disable all notification on $SUBDIV_NAME2 successfully"
} else {
    btb failed "Step onfigure CFG 32 to disable all notification on $SUBDIV_NAME2 unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 15. Verify that ENABLED = N for SUBDIV_NAME = $SUBDIV_NAME1"
set SUBIDX [lindex [btb_select bos.1 SORTNO FROM LOGIC_SUBDIVISION WHERE SUBDIV_NAME = [btb sqlstring $SUBDIV_NAME1]] 1]
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 15.1 ENABLED = N for $SUBDIV_NAME1"
} else {
    btb failed "Step 15.1 ENABLED != N for $SUBDIV_NAME1 -- result = $result"
}

btb comment "Step 16. Verify that ENABLED = N for SUBDIV_NAME = $SUBDIV_NAME2"
set SUBIDX [lindex [btb_select bos.1 SORTNO FROM LOGIC_SUBDIVISION WHERE SUBDIV_NAME = [btb sqlstring $SUBDIV_NAME2]] 1]
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 16.1 ENABLED = N for $SUBDIV_NAME2"
} else {
    btb failed "Step 16.1 ENABLED != N for $SUBDIV_NAME1 -- result = $result"
}

btb comment "Step 17. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"
btb_event_declare csx3_MBBSTEFA03.4
csx3 do {
    icd handler MBBSTEFA04 do {
        btb failed "17.1 CAD received MBBSTEFA03.4 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.4
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.4
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.4] } {
        btb comment "17.1 CAD did not receive MBBSTEFA03.4 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.4
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 18. TMC sends 02084 (Emergency Brake Application Report) to GBOS"
btb_event_declare csx3_MBBSTEMA04.4
csx3 do {
    icd handler MBBSTEMA05 do {
        btb failed "18.1 CAD received MBBSTEMA04.4 (Emergency Brake Application Report)"
        btb_event_wakeup csx3_MBBSTEMA04.4
    }
}
loco background {
    btb_send_file [btb testdir]/02084.1.xml msg_02084.4
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEMA04.4] } {
        btb comment "18.1 CAD did not received MBBSTEMA04.4 (Emergency Brake Application Report)"
    }
    btb_event_wakeup csx3_MBBSTEMA04.4
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment [btb ssh bos.1 rtdsh update LOGIC_SUBDIVISION set BOS_INSTANCE = [btb sqlstring "CSXBOS1"] where SUBDIV_NAME = [btb sqlstring "CIBOS"]]

after 1000 {set event_delay 0}
vwait event_delay

btb end TS-2


btb begin TS-3 "L2R5868-1: Activate Notification messages for all events without subdivision/district – EV79,EV81 on G BOS"

btb comment "Test Precondition - Setup"

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2083CAD msgtype 2083 district ALL} result
if { $result == "" } {
    btb comment "0.4 Set district = 0  on 2083CAD successfully"
} else {
    btb failed "0.4 Set district = 0  on 2083CAD unsuccessfully"
}

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub 2084CAD msgtype 2084 district ALL} result
if { $result == "" } {
    btb comment "0.5 Set district = 0  on 2083CAD successfully"
} else {
    btb failed "0.5 Set district = 0  on 2083CAD unsuccessfully"
}

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "0.6 Configure CFG 33 to disable all notification to CAD successfully"
} else {
    btb failed "0.6 Configure CFG 33 to disable all notification to CAD unsuccessfully - result=$result"
}

after 500 {set event_delay 0}
vwait event_delay

btb_sup_ptc_sync csx2 "$SUBDIV_NAME1"

after 500 {set event_delay 0}
vwait event_delay

btb_sup_ptc_sync csx3 "$SUBDIV_NAME2"

after 500 { set wait_4_done 0 }
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 19. Verify that ENABLED = N and SUBDIDX = 0 for each MSGTYPE in LOGIC_PUBLISH table"
set lenabled [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH]
set lsubdidx [btb_select bos.1 SUBDIDX FROM LOGIC_PUBLISH]
set llenabled [llength $lenabled]
set llsubdidx [llength $lsubdidx]
set cenabled 0
foreach value $lenabled {
	if { $value == "ENABLED" || $value == "N" } {
		incr cenabled
	}
}
set csubdidx 0
foreach value $lsubdidx {
	if { $value == "SUBDIDX" || $value == "0" } {
		incr csubdidx
	}
}
if { $llenabled == $cenabled } { 
	btb comment "19.1 All ENABLED are equal to N - $llenabled == $cenabled" 
} else {
	btb failed "19.1 All ENABLED are not equal to N - $llenabled == $cenabled" 
}
if { $llsubdidx == $csubdidx } { 
	btb comment "19.2 All SUBDIDX are equal to 0 - $llsubdidx == $csubdidx" 
} else {
	btb failed "19.2 All SUBDIDX are not equal to 0 - $llsubdidx == $csubdidx" 
}

btb comment "Step 20. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.1
loco do {
    icd handler 01088 do {
        btb comment "20.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.1
        icd load [btb testdir]/02088.1.xml msg_02088.1
        msg_02088.1 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.1
}
btb_event_vwait_all

btb comment "Step 21. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.1
csx3 do {
    icd handler MBLOCFGB03 do {
        btb failed "21.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.1
    }
}
loco background {
    msg_02088.1 send
    btb comment "21.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.1] } {
        btb comment "21.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.1
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 22. CAD sends System Fault Request"

btb_event_declare loco_01081.1
loco do {
    icd handler 01081 do {
        btb comment "22.1 Received 01081 (System Fault Request)"
        btb_event_wakeup loco_01081.1
        icd load [btb testdir]/02081.1.xml msg_02081.1
        msg_02081.1 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOFSRA.1.xml msg_MBLOFSRA.1
}
btb_event_vwait_all

btb comment "Step 23. CAD sends Response to System Fault Request"

btb_event_declare csx3_MBLOFSRB01.1
csx3 do {
    icd handler MBLOFSRB02 do {
        btb failed "23.1 CAD received MBLOFSRB01 (Configuration Report)"
        btb_event_wakeup csx3_MBLOFSRB01.1
    }
}
loco background {
    msg_02081.1 send
    btb comment "23.0 TMC sent 02081, solicited by 01081"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOFSRB01.1] } {
        btb comment "23.1 CAD did not receive MBLOFSRB01 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOFSRB01.1
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 24. Set ENABLE = Y for all msgtype in LOGIC_PUBLISH table"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc enepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "24.1 Set ENABLE = Y for all msgtype in LOGIC_PUBLISH table successfully"
} else {
    btb failed "24.1 Set ENABLE = Y for all msgtype in LOGIC_PUBLISH table successfully"
}

btb comment "Step 25. Verify that ENABLED = Y and SUBDIDX = 0 for each MSGTYPE in LOGIC_PUBLISH table"
set lenabled [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH]
set lsubdidx [btb_select bos.1 SUBDIDX FROM LOGIC_PUBLISH]
set llenabled [llength $lenabled]
set llsubdidx [llength $lsubdidx]
set cenabled 0
foreach value $lenabled {
	if { $value == "ENABLED" || $value == "Y" } {
		incr cenabled
	}
}
set csubdidx 0
foreach value $lsubdidx {
	if { $value == "SUBDIDX" || $value == "0" } {
		incr csubdidx
	}
}
if { $llenabled == $cenabled } { 
	btb comment "25.1 All ENABLED are equal to Y - $llenabled == $cenabled" 
} else {
	btb failed "25.1 All ENABLED are not equal to Y - $llenabled == $cenabled" 
}
if { $llsubdidx == $csubdidx } { 
	btb comment "25.2 All SUBDIDX are equal to 0 - $llsubdidx == $csubdidx" 
} else {
	btb failed "25.2 All SUBDIDX are not equal to 0 - $llsubdidx == $csubdidx" 
}

btb comment "Step 26. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.2
loco do {
    icd handler 01088 do {
        btb comment "26.1 Received 01088 (System Fault Request)" [received get]
        icd load [btb testdir]/02088.1.xml msg_02088.2
        msg_02088.2 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
        btb_event_wakeup loco_01088.2
    }
}

csx3 background {
    btb comment "26. Sends MBLOCFGA to G BOS."
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.2
}
btb_event_vwait_all

btb comment "Step 27. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.2
csx3 do {
    icd handler MBLOCFGB03 do {
        btb comment "27.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.2
    }
}
loco background {
    msg_02088.2 send
    btb comment "27.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.2] } {
        btb failed "27.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.2
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 28. CAD sends System Fault Request"

btb_event_declare loco_01081.2
loco do {
    icd handler 01081 do {
        btb comment "28.1 Received 01081 (System Fault Request)"
        btb_event_wakeup loco_01081.2
        icd load [btb testdir]/02081.1.xml msg_02081.2
        msg_02081.2 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOFSRA.1.xml msg_MBLOFSRA.2
}
btb_event_vwait_all

btb comment "Step 29. CAD sends Response to System Fault Request"

btb_event_declare csx3_MBLOFSRB01.2
csx3 do {
    icd handler MBLOFSRB02 do {
        btb comment "29.1 CAD received MBLOFSRB01 (Configuration Report)"
        btb_event_wakeup csx3_MBLOFSRB01.2
    }
}
loco background {
    msg_02081.2 send
    btb comment "29.0 TMC sent 02081, solicited by 01081"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOFSRB01.2] } {
        btb failed "29.1 CAD did not receive MBLOFSRB01 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOFSRB01.2
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-3

btb begin TS-4 "L2R5869-1: Deactivate Notification messages for all events without subdivision/district - EV79,EV81 on G BOS"

btb comment "Test Precondition - Setup"

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc enepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "0.7 Configure CFG 33 to enable all notification to CAD successfully"
} else {
    btb failed "0.7 Configure CFG 33 to enable all notification to CAD unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0 }
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 30. Verify that ENABLED = Y and SUBDIDX = 0 for each MSGTYPE in LOGIC_PUBLISH table"
set lenabled [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH]
set lsubdidx [btb_select bos.1 SUBDIDX FROM LOGIC_PUBLISH]
set llenabled [llength $lenabled]
set llsubdidx [llength $lsubdidx]
set cenabled 0
foreach value $lenabled {
	if { $value == "ENABLED" || $value == "Y" } {
		incr cenabled
	}
}
set csubdidx 0
foreach value $lsubdidx {
	if { $value == "SUBDIDX" || $value == "0" } {
		incr csubdidx
	}
}
if { $llenabled == $cenabled } { 
	btb comment "30.1 All ENABLED are equal to Y - $llenabled == $cenabled" 
} else {
	btb failed "30.1 All ENABLED are not equal to Y - $llenabled == $cenabled" 
}
if { $llsubdidx == $csubdidx } { 
	btb comment "30.2 All SUBDIDX are equal to 0 - $llsubdidx == $csubdidx" 
} else {
	btb failed "30.2 All SUBDIDX are not equal to 0 - $llsubdidx == $csubdidx" 
}

btb comment "Step 31. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.3
loco do {
    icd handler 01088 do {
        btb comment "31.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.3
        icd load [btb testdir]/02088.1.xml msg_02088.3
        msg_02088.3 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.3
}
btb_event_vwait_all

btb comment "Step 32. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.3
csx3 do {
    icd handler MBLOCFGB03 do {
        btb comment "32.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.3
    }
}
loco background {
    msg_02088.3 send
    btb comment "32.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.3] } {
        btb failed "32.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.3
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 33. CAD sends System Fault Request"

btb_event_declare loco_01081.3
loco do {
    icd handler 01081 do {
        btb comment "33.1 Received 01081 (System Fault Request)"
        btb_event_wakeup loco_01081.3
        icd load [btb testdir]/02081.1.xml msg_02081.3
        msg_02081.3 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOFSRA.1.xml msg_MBLOFSRA.3
}
btb_event_vwait_all

btb comment "Step 34. CAD sends Response to System Fault Request"

btb_event_declare csx3_MBLOFSRB01.3
csx3 do {
    icd handler MBLOFSRB02 do {
        btb comment "34.1 CAD received MBLOFSRB01 (Configuration Report)"
        btb_event_wakeup csx3_MBLOFSRB01.3
    }
}
loco background {
    msg_02081.3 send
    btb comment "34.0 TMC sent 02081, solicited by 01081"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOFSRB01.3] } {
        btb failed "34.1 CAD did not receive MBLOFSRB01 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOFSRB01.3
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 35. Set ENABLE = N for all msgtype in LOGIC_PUBLISH table"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "35.1 Set ENABLE = N for all msgtype in LOGIC_PUBLISH table successfully"
} else {
    btb failed "35.1 Set ENABLE = N for all msgtype in LOGIC_PUBLISH table successfully"
}

btb comment "Step 36. Verify that ENABLED = N and SUBDIDX = 0 for each MSGTYPE in LOGIC_PUBLISH table"
set lenabled [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH]
set lsubdidx [btb_select bos.1 SUBDIDX FROM LOGIC_PUBLISH]
set llenabled [llength $lenabled]
set llsubdidx [llength $lsubdidx]
set cenabled 0
foreach value $lenabled {
	if { $value == "ENABLED" || $value == "N" } {
		incr cenabled
	}
}
set csubdidx 0
foreach value $lsubdidx {
	if { $value == "SUBDIDX" || $value == "0" } {
		incr csubdidx
	}
}
if { $llenabled == $cenabled } { 
	btb comment "36.1 All ENABLED are equal to N - $llenabled == $cenabled" 
} else {
	btb failed "36.1 All ENABLED are not equal to N - $llenabled == $cenabled" 
}
if { $llsubdidx == $csubdidx } { 
	btb comment "36.2 All SUBDIDX are equal to 0 - $llsubdidx == $csubdidx" 
} else {
	btb failed "36.2 All SUBDIDX are not equal to 0 - $llsubdidx == $csubdidx" 
}

btb comment "Step 37. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.4
loco do {
    icd handler 01088 do {
        btb comment "37.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.4
        icd load [btb testdir]/02088.1.xml msg_02088.4
        msg_02088.4 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.4
}
btb_event_vwait_all

btb comment "38. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.4
csx3 do {
    icd handler MBLOCFGB03 do {
        btb failed "38.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.4
    }
}
loco background {
    msg_02088.4 send
    btb comment "38.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.4] } {
        btb comment "38.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.4
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 39. CAD sends System Fault Request"

btb_event_declare loco_01081.4
loco do {
    icd handler 01081 do {
        btb comment "39.1 Received 01081 (System Fault Request)"
        btb_event_wakeup loco_01081.4
        icd load [btb testdir]/02081.1.xml msg_02081.4
        msg_02081.4 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOFSRA.1.xml msg_MBLOFSRA.4
}
btb_event_vwait_all

btb comment "40. CAD sends Response to System Fault Request"

btb_event_declare csx3_MBLOFSRB01.4
csx3 do {
    icd handler MBLOFSRB02 do {
        btb failed "40.1 CAD received MBLOFSRB01 (Configuration Report)"
        btb_event_wakeup csx3_MBLOFSRB01.4
    }
}
loco background {
    msg_02081.4 send
    btb comment "40.0 TMC sent 02081, solicited by 01081"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOFSRB01.4] } {
        btb comment "40.1 CAD did not receive MBLOFSRB01 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOFSRB01.4
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-4

btb begin TS-5 "Activate Notification messages per event - EV22 on G BOS"

btb comment "Test Precondition - Setup"

btb comment "Step 0.8 Set ID = $MSG_2083 ENABLE = N"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2083 msgtype 2083 district ALL enabled N} result
if { $result == "" } {
    btb comment "0.8.1 Updated $MSG_2083 successfully"
} else {
    btb comment "0.8.1 Updated $MSG_2083 unsuccessfully - result=$result"
}

btb_sup_ptc_sync csx2 "$SUBDIV_NAME1"
btb_sup_ptc_sync csx3 "$SUBDIV_NAME2"

after 2000 { set wait_4_done 0 }
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 41. Verify that ENABLED = N and SUBDIDX = 0 for $MSG_2083"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2083] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 41.1 ENABLED = N for $MSG_2083"
} else {
    btb failed "Step 41.1 ENABLED != N for $MSG_2083 -- result = $result"
}

btb comment "Step 42. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"

btb_event_declare csx3_MBBSTEFA03.5
csx3 do {
    icd handler MBBSTEFA04 do {
        btb failed "42.1 CAD received MBBSTEFA03.5 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.5
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.5
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.5] } {
        btb comment "42.1 CAD did not receive MBBSTEFA03.5 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.5
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 43. Configure CFG 34 to activate (enable) railroad network event notification for message 02083"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2083 msgtype 2083 district ALL enabled Y} result
if { $result == "" } {
    btb comment "Step 43.1 Update $MSG_2083 successfully"
} else {
    btb failed "Step 43.1 Update $MSG_2083 unsuccessfully"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 44. Verify that ENABLED = Y and SUBDIDX = 0 for $MSG_2083"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2083] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 44.1 ENABLED = Y for $MSG_2083"
} else {
    btb failed "Step 44.1 ENABLED != Y for $MSG_2083 -- result = $result"
}

btb comment "Step 45. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"
btb_event_declare csx3_MBBSTEFA03.6
csx2 do {
    icd handler MBBSTEFA04 do {
        btb comment "45.1 CAD received MBBSTEFA03 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.6
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.6
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.6] } {
        btb failed "45.1 CAD did not receive MBBSTEFA03 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.6
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-5

btb begin TS-6 "L2R5870-2: Activate Notification messages per event – EV79 on G BOS"

btb comment "Test Precondition - Setup"

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "Disable all notification to CAD successfully"
} else {
    btb failed "Disable all notification to CAD unsuccessfully - result=$result"
}

btb comment "Step 0.9 Set ID = $MSG_2088 ENABLE = N"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2088 msgtype 2088 district ALL enabled N} result
if { $result == "" } {
    btb comment "0.9.1 Updated $MSG_2088 successfully"
} else {
    btb comment "0.9.1 Updated $MSG_2088 unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 46. Verify that ENABLED = N and SUBDIDX = 0 for $MSG_2088"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2088] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 46.1 ENABLED = N for $MSG_2088"
} else {
    btb failed "Step 46.1 ENABLED != N for $MSG_2088 -- result = $result"
}

btb comment "Step 47. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.5
loco do {
    icd handler 01088 do {
        btb comment "47.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.5
        icd load [btb testdir]/02088.1.xml msg_02088.5
        msg_02088.5 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.5
}
btb_event_vwait_all

btb comment "Step 48. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.5
csx3 do {
    icd handler MBLOCFGB03 do {
        btb failed "48.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.5
    }
}
loco background {
    msg_02088.5 send
    btb comment "48.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.5] } {
        btb comment "48.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.5
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 49. Configure CFG 34 to activate (enable) railroad network event notification for message 02088 that does not have a subdivision/district context"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2088 msgtype 2088 district ALL enabled Y} result
if { $result == "" } {
	btb comment "Step 49.1 Update $MSG_2088 successfully"
} else {
	btb comment "Step 49.1 Update $MSG_2088 unsuccessfully"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 50. Verify that ENABLED = Y and SUBDIDX = 0 for $MSG_2088"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2088] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 50.1 ENABLED = Y for $MSG_2088"
} else {
    btb failed "Step 50.1 ENABLED != Y for $MSG_2088 -- result = $result"
}

btb comment "Step 51. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.6
loco do {
    icd handler 01088 do {
        btb comment "51.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.6
        icd load [btb testdir]/02088.1.xml msg_02088.6
        msg_02088.6 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.6
}
btb_event_vwait_all

btb comment "Step 52. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.6
csx3 do {
    icd handler MBLOCFGB03 do {
        btb comment "52.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.6
    }
}
loco background {
    msg_02088.6 send
    btb comment "52.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.6] } {
        btb failed "52.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.6
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-6

btb begin TS-7 "Deactivate Notification messages per event - EV22 on G BOS"

btb comment "Test Precondition - Setup"

btb comment "Step 0.10 Set ID = $MSG_2083 ENABLE = Y"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2083 msgtype 2083 district ALL enabled Y} result
if { $result == "" } {
    btb comment "0.10.1 Updated $MSG_2083 successfully"
} else {
    btb comment "0.10.1 Updated $MSG_2083 unsuccessfully - result=$result"
}

btb_sup_ptc_sync csx2 "$SUBDIV_NAME1"
btb_sup_ptc_sync csx3 "$SUBDIV_NAME2"

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 53. Verify that ENABLED = Y and SUBDIDX = 0 for $MSG_2083"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2083] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 53.1 ENABLED = Y for $MSG_2083"
} else {
    btb failed "Step 53.1 ENABLED != Y for $MSG_2083 -- result = $result"
}

btb comment "Step 54. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"

btb_event_declare csx3_MBBSTEFA03.7
csx2 do {
    icd handler MBBSTEFA04 do {
        btb comment "54.1 CAD received MBBSTEFA03.7 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.7
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.7
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.7] } {
        btb failed "54.1 CAD did not receive MBBSTEFA03.7 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.7
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 55. Configure CFG 34 to activate (disable) railroad network event notification for message 02083"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2083 msgtype 2083 district ALL enabled N} result
if { $result == "" } {
    btb comment "Step 55.1 Update $MSG_2083 successfully"
} else {
    btb failed "Step 55.1 Update $MSG_2083 unsuccessfully"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 56. Verify that ENABLED = N and SUBDIDX = 0 for $MSG_2083"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2083] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 56.1 ENABLED = N for $MSG_2083"
} else {
    btb failed "Step 56.1 ENABLED != N for $MSG_2083 -- result = $result"
}

btb comment "Step 57. TMC sends 02083 (Enforcement Warning/Braking Notification) to GBOS"
btb_event_declare csx3_MBBSTEFA03.8
csx3 do {
    icd handler MBBSTEFA04 do {
        btb failed "57.1 CAD received MBBSTEFA03 (Enforcement Report)"
        btb_event_wakeup csx3_MBBSTEFA03.8
    }
}
loco background {
    btb_send_file [btb testdir]/02083.1.xml msg_02083.8
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBBSTEFA03.8] } {
        btb comment "57.1 CAD did not receive MBBSTEFA03 (Enforcement Report)"
    }
	btb_event_wakeup csx3_MBBSTEFA03.8
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-7


btb begin TS-8 "L2R5870-2: Activate Notification messages per event – EV79 on G BOS"

btb comment "Test Precondition - Setup"

catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc disepub msgtype ALL district ALL} result
if { $result == "" } {
    btb comment "Disable all notification to CAD successfully"
} else {
    btb failed "Disable all notification to CAD unsuccessfully - result=$result"
}

btb comment "Step 0.11 Set ID = $MSG_2088 ENABLE = Y"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2088 msgtype 2088 district ALL enabled Y} result
if { $result == "" } {
    btb comment "0.11.1 Updated $MSG_2088 successfully"
} else {
    btb comment "0.11.1 Updated $MSG_2088 unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Test Precondition - Setup End"

btb comment "Step 58. Verify that ENABLED = Y and SUBDIDX = 0 for $MSG_2088"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2088] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "Y" } {
    btb comment "Step 58.1 ENABLED = Y for $MSG_2088"
} else {
    btb failed "Step 58.1 ENABLED != Y for $MSG_2088 -- result = $result"
}

btb comment "Step 59. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.7
loco do {
    icd handler 01088 do {
        btb comment "59.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.7
        icd load [btb testdir]/02088.1.xml msg_02088.7
        msg_02088.7 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.7
}
btb_event_vwait_all

btb comment "Step 60. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.7
csx3 do {
    icd handler MBLOCFGB03 do {
        btb comment "60.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.7
    }
}
loco background {
    msg_02088.7 send
    btb comment "60.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.7] } {
        btb failed "60.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.7
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb comment "Step 61. Configure CFG 34 to activate (disable) railroad network event notification for message 02088 that does not have a subdivision/district context"
catch {btb ssh bos.1 $env(AIM_INSTALL)/bin/ptc uepub $MSG_2088 msgtype 2088 district ALL enabled N} result
if { $result == "" } {
	btb comment "Step 61.1 Update $MSG_2088 successfully"
} else {
	btb comment "Step 61.1 Update $MSG_2088 unsuccessfully - result=$result"
}

after 2000 { set wait_4_done 0}
vwait wait_4_done

btb comment "Step 62. Verify that ENABLED = N and SUBDIDX = 0 for $MSG_2088"
set SUBIDX 0
set result [lindex [btb_select bos.1 ENABLED FROM LOGIC_PUBLISH WHERE ID = [btb sqlstring $MSG_2088] AND SUBDIDX = [btb sqlstring $SUBIDX]] 1]
if { $result == "N" } {
    btb comment "Step 62.1 ENABLED = N for $MSG_2088"
} else {
    btb failed "Step 62.1 ENABLED != N for $MSG_2088 -- result = $result"
}

btb comment "Step 63. CAD sends Onboard Configuration Request"

btb_event_declare loco_01088.8
loco do {
    icd handler 01088 do {
        btb comment "63.1 Received 01088 (System Fault Request)"
        btb_event_wakeup loco_01088.8
        icd load [btb testdir]/02088.1.xml msg_02088.8
        msg_02088.8 set "<EMP><MessageNumber>" [received get "<EMP><MessageNumber>"]
    }
}

csx3 background {
    btb_send_file [btb testdir]/MBLOCFGA.1.xml msg_MBLOCFGA.8
}
btb_event_vwait_all

btb comment "Step 64. CAD sends Response to Onboard Configuration Request"

btb_event_declare csx3_MBLOCFGB02.8
csx3 do {
    icd handler MBLOCFGB03 do {
        btb failed "64.1 CAD received MBLOCFGB02 (Configuration Report)"
        btb_event_wakeup csx3_MBLOCFGB02.8
    }
}
loco background {
    msg_02088.8 send
    btb comment "64.0 TMC sent 02088, solicited by 01088"
}
set wait_4_msg [after 5000 {
    if { ![info exists csx3_MBLOCFGB02.8] } {
        btb comment "64.1 CAD did not receive MBLOCFGB02 (Configuration Report)"
    }
    btb_event_wakeup csx3_MBLOCFGB02.8
    }]
btb_event_vwait_all
after cancel $wait_4_msg

btb end TS-8

