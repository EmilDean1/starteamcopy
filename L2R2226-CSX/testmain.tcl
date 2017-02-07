btb test L2R2226-CSX "Test ietms-state command with multiple BOS servers"
btb requirement L2R2226 "L2R2226 The BOS shall provide access to an external tool that can indicate the current server state for each BOS server. See section 8."

after 2000 {btb comment "Delay to start all BOS and Tesbed processes has elapsed" ; set vwait_startup 0}; vwait vwait_startup

after 300000 { btb abort "Timed out" }


set scenario 0
set num 0

# Define counters that tally the number of times a state was detected
# Thus, if zero, the state was never detected.
set CNT_OFFLINE 0
set CNT_INITIALIZE 0
set CNT_STANDALONE 0
set CNT_PRIMARY 0
set CNT_BACKUP 0
set CNT_STANDBY 0
set CNT_FAILED 0
set CNT_OOPS 0

proc tally str {
    global CNT_OFFLINE
    global CNT_INITIALIZE
    global CNT_STANDALONE
    global CNT_PRIMARY
    global CNT_BACKUP
    global CNT_STANDBY
    global CNT_FAILED
    global CNT_OOPS
    switch -exact -- $str {
        OFFLINE    {incr CNT_OFFLINE}
        INITIALIZE {incr CNT_INITIALIZE}
        STANDALONE {incr CNT_STANDALONE}
        PRIMARY    {incr CNT_PRIMARY}
        BACKUP     {incr CNT_BACKUP}
        STANDBY    {incr CNT_STANDBY}
        FAILED     {incr CNT_FAILED}
        default {incr CNT_OOPS; btb comment "unknown state is $str"}
    }
}
proc verify {} {
    global num
    global CNT_OFFLINE
    global CNT_INITIALIZE
    global CNT_STANDALONE
    global CNT_PRIMARY
    global CNT_BACKUP
    global CNT_STANDBY
    global CNT_FAILED
    global CNT_OOPS
    set good 0
    set bad 0

    incr num
    if {$CNT_OFFLINE} {incr good}
    if {$CNT_INITIALIZE} {incr good}
    if {$CNT_STANDALONE} {incr good}
    if {$CNT_PRIMARY} {incr good}
    if {$CNT_BACKUP} {incr good}
    if {$CNT_STANDBY} {incr good}
    if {$CNT_FAILED} {incr good}
    if {$CNT_OOPS} {incr bad}

    btb comment Step $num.  Verify accumulated server states
    if {$bad} {
        btb failed Step $num.1 Unknown operating state
    } elseif {$good == 7} {
        btb comment Step $num.1 all operating states were tested
    } else {
        btb failed Step $num.1 Not all Operating states were tested
        if {$CNT_OFFLINE == 0} {btb failed OFFLINE was not tested}
        if {$CNT_INITIALIZE == 0} {btb failed INITIALIZE was not tested}
        if {$CNT_STANDALONE == 0} {btb failed STANDALONE was not tested}
        if {$CNT_PRIMARY == 0} {btb failed PRIMARY was not tested}
        if {$CNT_BACKUP == 0} {btb failed BACKUP was not tested}
        if {$CNT_STANDBY == 0} {btb failed STANDBY was not tested}
        if {$CNT_FAILED == 0} {btb failed FAILED was not tested}
    }
}

# spurt output to the console and to the testbed log.
proc spurt args {
    eval puts "$args"
    flush stdout
    eval btb comment $args
}


proc syscmd {server args} {
    global num
    incr num
    spurt "Step $num. System Manager issues command to $server: '[join $args]'."
    if { [catch {eval btb ssh $server $args} rc] } {
        btb failed "Step $num.1.  System Manager issued bad command to $server: '[join $args]'. Cause: $rc"
    } else {
        btb comment "Step $num.1.  System Manager issued command to $server: '[join $args]'."
    }
    return $rc
}


proc shellcmd {server args} {
    global num
    incr num
# Where server is bos.1 or bos.2 etc.
# Where args are typical bash command line including redirection
    set server_name [split $server .]
    set server_number [lindex $server_name 1]
    incr server_number -1
    set the_server [lindex [btb uut] $server_number]
    spurt "Step $num.  Issue shell command to $server: '[join $args]'."
    if { [catch {eval exec /usr/bin/ssh $the_server $args} rc] } {
        btb failed "Step $num.1.  bad shell command issued to $server: '[join $args]'. Cause: $rc"
    } else {
        btb comment "Step $num.1.  shell command issued to $server: '[join $args]'."
    }
    return $rc
}

### CSX ssh login dumps login text
proc shellcmd_nofail {server args} {
    global num
    incr num
# Where server is bos.1 or bos.2 etc.
# Where args are typical bash command line including redirection
    set server_name [split $server .]
    set server_number [lindex $server_name 1]
    incr server_number -1
    set the_server [lindex [btb uut] $server_number]
    spurt "Step $num.  Issue shell command to $server: '[join $args]'."
    if { [catch {eval exec /usr/bin/ssh $the_server $args} rc] } {
        btb comment "Step $num.1.  bad shell command issued to $server: '[join $args]'. Cause: $rc"
    } else {
        btb comment "Step $num.1.  shell command issued to $server: '[join $args]'."
    }
    return $rc
}



proc hack_server_config srvr {
    global env
    set rc [shellcmd_nofail $srvr "echo \"FAM CLD_FM1_IOP558   CPF_PRO_FAIL       cp---\" >> $env(AIM_USER)/config/integration_process.txt"]
}

proc unhack_server_config srvr {
    global env
    set rc [shellcmd_nofail $srvr "sed -i --follow-symlinks '/FAM CLD_FM1_IOP558   CPF_PRO_FAIL       cp---/d' $env(AIM_USER)/config/integration_process.txt"]
}

# report and tally operating states of each server
proc do_it args {
    global env
    global num
    set bos1state 0
    set bos2state 0
    set bos3state 0
    incr num
    spurt "Step $num. [join $args]"
    set bos1state [btb ssh bos.1 $env(AIM_INSTALL)/bin/ietms-state]
#    spurt "Step $num.1. BOS 1: $bos1state"
    tally $bos1state
    set bos2state [btb ssh bos.2 $env(AIM_INSTALL)/bin/ietms-state]
#    spurt "Step $num.2. BOS 1: $bos1state, BOS 2: $bos2state"
    tally $bos2state
    set bos3state [btb ssh bos.3 $env(AIM_INSTALL)/bin/ietms-state]
    spurt "Step $num.1. BOS 1: $bos1state, BOS 2: $bos2state, BOS 3: $bos3state."
    tally $bos3state
    after 8000 {set vwait_pause 0}; vwait vwait_pause
    spurt "...waited 8 seconds..."
}

incr scenario
btb begin TS-$scenario "Redundant three server BOS instance"
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Redundant two server BOS instance"
# get bos_instance for later 'aim start' specifying --group
set x [syscmd bos.2 rtdsh select bos_instance from logic_subdivision where subdiv_name = [btb sqlstring WM]]
set bos_inst [lindex $x 1]
spurt "BOS server 2 bos instance is $bos_inst"
# syscmd bos.2 "aim stop"
syscmd bos.2 $env(AIM_INSTALL)/bin/ietms-uut stop
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Non-Redundant one server BOS instance"
# syscmd bos.3 "aim stop"
syscmd bos.3 $env(AIM_INSTALL)/bin/ietms-uut stop
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Start misconfigured second server"
hack_server_config bos.2
# syscmd bos.2 "aim -s start --group=$bos_inst"
syscmd bos.2 $env(AIM_INSTALL)/bin/ietms-uut start
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Stop misconfigured second server"
# syscmd bos.2 "aim stop"
syscmd bos.2 $env(AIM_INSTALL)/bin/ietms-uut stop
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Start configured second server"
unhack_server_config bos.2
#syscmd bos.2 "aim -s start --group=$bos_inst"
# start the bos via the testbed
syscmd bos.2 $env(AIM_INSTALL)/bin/ietms-uut start
do_it System Manager checks BOS server states using ietms-state
do_it System Manager checks BOS server states using ietms-state

incr scenario
btb begin TS-$scenario "Evaluate collected test results"
spurt "Step $num. check bos 2 state"
set bos2state [btb ssh bos.2 $env(AIM_INSTALL)/bin/ietms-state]
btb comment "Step $num.1. bos 2 state is $bos2state."
switch -exact -- $bos2state {
    PRIMARY {}
    STANDALONE {}
    BACKUP {}
    default { btb failed "Step $num.1 may need to remove last line of integration_process.txt file which contains CPF_PRO_FAIL."}
}

verify

btb end TS-1

