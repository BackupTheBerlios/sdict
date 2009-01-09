# ::config
#
# Very simple config reader.
# Config file is plain text file. Empty lines and lines beginning
# with # silently skipped.
# Config file contain pairs key and value separated by spaces or
# tabs. If some key repeat more than once then value of this key
# appended to previous values.
#
# Config example:
#
# logfile /var/log/messages
# pidfile /var/run/daemon.pid
# allowusers guest admin nobody
# allowusers ftpadmin proxyadmin
#
# In this example key ''allowusers'' contain two lists of users:
# {guest admin nobody} {ftpadmin proxyadmin}
#
# Commands:
#
# config open ?-quiet? ?-opts list? filename
#	Given command open config file ''filename'' and read it.
# Option -opts define options list which will be find in config
# file. If not valid option are meet, exception generated, in
# case of -quiet option then no exception generated.
# 
# config names
# 	Return list of keys.
#
# config get key ?defaultValue?
# 	Return value of ''key''. If no such ''key'' exists throw
# exception, else return ''defaultValue'' if it defined.
#
# config set key value
#	Set ''key'' to ''value''. Note, this command overwrite
# old key value.
#
# config unset key
#	Remove ''key'' from config.
#
# config add key value
#	Add ''value'' to values of ''key''.
#
# config commit ?filename?
#	Write changes to config. If no ''filename'' then changes
# commits to file opened by ''config open''.

package provide config 0.1

namespace eval ::config {
	
	namespace export config

	variable option
	array set option {}

	variable filename

}

proc ::config::config {cmd args} {
  set method [info commands ::config::config_cmd_$cmd*]

  if {[llength $method] == 1} {
    return [uplevel 1 [linsert $args 0 $method]]
  } else {
    set prefix_len [string length "::config::config_cmd_"]
    foreach c [info commands ::config::config_cmd_*] {
      lappend cmds [string range $c $prefix_len end]
    }
    return -code error "unknown subcommand \"$cmd\": \
    	must be one of [join [lsort $cmds] {, }]"
  }
}

# ::config::config_cmd_open --
#
# Open and read configuration file.
#
# Arguments:
# config open ?-quiet? ?-opts optionList? filename
# -quiet	do not generate exception if option 
#		from 'optionList' is not found in 'filename'
# -opts	optList	list of option names 	
# filename	file which will be read

proc ::config::config_cmd_open {args} {
  variable option
  variable filename

  # Parse command arguments
  set opts [set quiet 0]
  foreach arg $args {
    if { $opts } { set names $arg; set opts 0; continue }
    switch -exact -- $arg {
      "-quiet" { set quiet 1 }
      "-opts"  { set opts 1  }
      default  { set filename $arg }
    }
  }

  set fd [open $filename]

  # line number
  set lnum 0

  while {![eof $fd]} {
    incr lnum
    gets $fd line
    # Ignore empty lines and comments
    if { [regexp {(^[ \t]*$)|(^[ \t]*#.*$)} $line] } { continue }
    set tok [split $line]
    set opt [string trim [lindex $tok 0]]
    if {[info exists names]} {
      if { [lsearch $names $opt] == -1 } {
        if { !$quiet } { 
	  return -code error "$filename: error in line: $lnum \
	  	unknown option \"$opt\""
	}
	continue
      }
    }
    lappend option($opt) [lrange $tok 1 end]
  }

  close $fd
}

proc ::config::config_cmd_names {} {
  variable option

  return [lsort [array names option]]
}

proc ::config::operate {args} {
  variable option

  set cmd [lindex $args 0]
  set opt [lindex $args 1]

  # Check for existence options only
  # for 'get' and 'unset' commands.
  if { [lsearch -exact {get unset} $opt] != -1 } {
    if {![info exists option($opt)]} {
      return -code error "unknown option \"$opt\""
    }
  }

  switch -exact -- $cmd {
    get {
      return $option($opt)
    }
    set {
      set option($opt) [lrange $args 2 end]
    }
    unset {
      unset option($opt)
    }
    add {
      lappend option($opt) [lrange $args 2 end]
    }
  }

}

proc ::config::config_cmd_get {opt {def {}}} {
  if { [catch {set ret [::config::operate get $opt]} err] } {
    if { [llength $def] } {
      return $def
    } else {
      return -code error $err
    }
  }
  return $ret
}

proc ::config::config_cmd_set {opt value} {
  ::config::operate set $opt $value
}

proc ::config::config_cmd_unset {opt} {
  ::config::operate unset $opt
}

proc ::config::config_cmd_add {opt value} {
  ::config::operate add $opt $value
}

proc ::config::config_cmd_commit { {newfilename {}} } {
  variable option
  variable filename

  if { [string length $newfilename] } { set filename $newfilename }

  set fd [open $filename "w"]
  foreach opt [lsort [array names option]] {
    foreach v $option($opt) {
      puts $fd [join [list $opt $v] " "]
    }
  }
  close $fd
}
