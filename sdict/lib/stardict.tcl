# stardict.tcl --
#
#	interface to StarDict dictionaries.
#

package provide stardict 0.1

namespace eval ::stardict {
    namespace export stardict

    variable 	dict
    array set 	dict {}
    set 	dict(names) {}

    variable	words
    array set	words {}

    variable	config
    array set	config {}

}

# ::stardict::stardict --
#
# Main command to interfere with StarDict dictionaries.
#
# Arguments:
#	cmd	Invoked method
#	args	Arguments to method.
#
# Results:
#	As of the invoked method.

proc ::stardict::stardict {cmd args} {
  set method [info commands ::stardict::stardict_cmd_$cmd*]

  if {[llength $method] == 1} {
    return [uplevel 1 [linsert $args 0 $method]]
  } else {
    foreach c [info commands ::stardict::stardict_cmd_*] {
      lappend cmds [string range $c 25 end]
    }
    return -code error "unknown subcommand \"$cmd\": \
    		must be one of [join [lsort $cmds] {, }]"
  }
}

# ::stardict::stardict_cmd_setup --
#
# Setup path for search dictionaries and load dictionary
# information.
# 
# Arguments:
#	?-cachedir dir?
#	searchpath ...
#
# Results:
#	Throw exception if argument to -cachedir is not directory,
# no .ifo files found in search path.

proc ::stardict::stardict_cmd_setup {args} {
  variable 	config

  set path 	{}
  set state 	none

  # Parsing arguments
  foreach arg $args {
    if { $state == "none" } {
      switch -- $arg {
   	-cachedir 	{ set state cachedir }
    	default	   	{ set path $arg }
      }
      continue
    }
    switch -- $state {
    	cachedir  	{ set config(cachedir) $arg; set state none }
    }
  }

  # If not -cachedir option defined, using by default current
  # directory, else check for exists defined directory.
  if {![info exists config(cachedir)] || ![string length $config(cachedir)]} {
    set config(cachedir) ""
  } else {
    if {![file isdirectory $config(cachedir)]} {
      return -code error "$config(cachedir): is not directory"
    }
  }

  # Search for .ifo files in defined directories. 
  # Throw exception if no files found.
  if {![llength $path]} { set path . }
  set files [list]
  foreach dir $path {
    set res [glob -nocomplain -type f -directory $dir *.ifo]
    if [llength $res] {
      set files [concat $files $res]
    }
  }
  if {![llength $files]} {
    return -code error "no .ifo files found in: [join $path {, }]"
  }

  # Load founded ifo files.
  foreach ifo $files {
    if {[catch {loadifo $ifo} err]} {
      puts stderr $err
    }
  }

}

# ::stardict::loadifo --
#
# Load information .ifo file.
#
# Arguments:
#	filename	.ifo file full path
# 
# Results:
#	Throw exception if filename is not ifo file.
#	On successful return 1.

proc ::stardict::loadifo {filename} {
  variable dict
  variable config

  # All available ifo options 
  set opts [list version bookname wordcount idxfilesize \
  	author email website description date sametypesequence]

  # Open file and check stardict signature
  set fd [open $filename]
  gets $fd line
  if {![string equal $line "StarDict's dict ifo file"]} {
    close $fd
    return -code error "$filename: is not StarDict file"
  }

  # Read options
  while {![eof $fd]} {
    gets $fd line
    if {[string length [string trim $line]] == 0} {
      continue
    }
    set pair [split $line =]
    set key  [lindex $pair 0]
    set val  [lindex $pair 1]
    if {[lsearch -exact $opts $key] != -1} {
      set ifo($key) $val
    } else {
      close $fd
      return -code error "$filename: unknown option: $key"
    }
  }
  close $fd
  
  # Check for required options
  foreach req {version bookname wordcount idxfilesize sametypesequence} {
    if {[lsearch -exact [array names ifo] $req] == -1} {
      return -code error "$filename: no required option: $req"
    }
  }

  # Check for version = 2.4.2
  if {![string equal $ifo(version) "2.4.2"]} {
    return -code error "$filename: unsupported version $ifo(version)"
  }

  # Check for sametypesequence = m
  if {![string equal $ifo(sametypesequence) "m"]} {
    return -code error "$filename: unsupported sametypesequence $ifo(sametypesequence)"
  }

  upvar 0 ifo(bookname) bookname
  set dict($bookname,file_ifo)   $filename
  set dict($bookname,file_idx)   [string map {.ifo .idx} $filename]
  set dict($bookname,file_dict)  [string map {.ifo .dict} $filename]
  set dict($bookname,file_cache) [string map {.ifo .cache} \
  	[file join $config(cachedir) [file tail $filename]]]

  # Ok, all check are done, add information about dictionary
  # to dict array.
  foreach n [array names ifo] {
    set dict($bookname,$n) $ifo($n)
  }
  set dict($bookname,isload) 	0
  set dict($bookname,iscached) 	0
  lappend dict(names) $bookname

  return 1
}

# ::stardict::findnull --
#
# This finds null byte in buffer of binary data.
#
# Arguments:
# 	bufName		reference to actual binary data
#
# Results:
#	Index of first occurience of null byte in bufName
# else return -1 if no null byte found.

proc ::stardict::findnull {bufName} {
  upvar $bufName buf

  set count 0
  set val 99

  while {$val != 0} {
    binary scan $buf @${count}c val
    incr count
  }

  if {$val != 0} { set count -1 }

  return $count
}

# ::stardict::cacheload --
#
# Load words cache file.
#
# Arguments:
#	bookname	name of dictionary
#
# Results:
#	Throw exception if load cache failed.
#

proc ::stardict::cacheload {bookname} {
  variable dict
  variable words

  set dict($bookname,isload)	0
  set dict($bookname,iscached)	0
  set fd [open [stardict info -cache $bookname]]
  set woc 0
  while {![eof $fd]} {
    gets $fd line
    set buf  [split $line]
    set lett [lindex $buf 0]
    foreach {offset count} [lrange $buf 1 end] {
      lappend words($bookname,$lett) [binary format II $offset $count]
      incr woc
    }
  }
  #puts "cacheload: $woc = $dict($bookname,wordcount)"
  if { $woc != $dict($bookname,wordcount) } {
    array unset words "$bookname,*"
    return -code error "$bookname: broken cache"
  }
  set dict($bookname,isload)	1
  set dict($bookname,iscached)	1
  close $fd

  return 1
}

# ::stardict::stardict_cmd_createcache --
#
# Build words cache. Delete old one and create new.
#
# Arguments:
#	bookname	name of dictionary
#
# Results:
#

proc ::stardict::stardict_cmd_createcache {bookname} {
  variable dict
  variable words

  if {![stardict info -isload $bookname]} {
    return -code error "$bookname: must be loaded"
  }

  set fd [open [stardict info -cache $bookname] w]
  set woc 0
  foreach w [array names words "$bookname,*"] {
    set book [lindex [split $w ,] 0]
    set lett [lindex [split $w ,] 1]
    puts -nonewline $fd "$lett"
    foreach oct $words($book,$lett) {
      binary scan $oct II offset count
      puts -nonewline $fd " $offset $count"
      incr woc
    }
    puts $fd ""
  }
  #puts "createcache: $woc = $dict($bookname,wordcount)"
  close $fd
}

# ::stardict::stardict_cmd_open --
#
# Load words from dictionary index.
# Changes flags -iscached, -isload.
#
# Arguments:
#	?-usecache?	try to load cache (by default)
#	?-nocache?	do not load cache
#	bookname	name of dictionary
#
# Results:
#	Throw exception if open failed.

proc ::stardict::stardict_cmd_open { args } {
  variable dict
  variable words

  # Extract option from arguments list
  set arg [lindex $args 0]
  if {[string index $arg 0] == "-"} {
    switch -- $arg {
      -usecache { set opt usecache }
      -nocache  { set opt nocache  }
      default   {
        return -code error "unknown argument: $arg"
      }
    }
    set bookname [lindex $args 1]
  } else {
    set bookname [lindex $args 0]
    set opt usecache
  }

  check_bookname $bookname

  # Try to load cache 
  set f [stardict info -cache $bookname]
  if {$opt == "usecache" && ([file exists $f] && [file readable $f])} {
    if {![catch {cacheload $bookname}]} {
      return 1
    }
  }

  upvar 0 dict($bookname,wordcount) wordcount
  set fd [open [stardict info -idx $bookname]]
  fconfigure $fd -encoding binary -translation binary

  set offset 0
  set wd 0
  set filesize [file size [stardict info -idx $bookname]]
  set done 0

  while { ! $done } {
    seek $fd $offset start
    set buf [read $fd 264]
    if {[set count [findnull buf]] == -1} {
      return -code error "$bookname: dictionary index format error"
    }
    binary scan $buf A$count val
    binary scan $buf @${count}II woff wdat
    set val [string index [encoding convertfrom utf-8 "$val"] 0]
    lappend words($bookname,$val) [binary format II $offset $count]
    incr offset [expr $count+8]
    incr wd
    if {[expr $offset + 1] > $filesize} { set done 1 }
  }

  if { $wd != $wordcount } {
    return -code error "$bookname: index failed $wd <> $wordcount"
  }

  set dict($bookname,isload) 1
  close $fd
  return 1
}

# ::stardict::stardict_cmd_names --
#
# Get available dictionaries.
#
# Arguments:
#	none
#
# Results:
#	List of available dictionaries.

proc ::stardict::stardict_cmd_names {} {
  variable dict

  return [lsort $dict(names)]
}

# ::stardict::check_bookname
#
# Check for valid dictionary bookname.
#
# Arguments:
#	bookname	name of dictionary
#
# Results:
#	Throw exception if check failed.

proc ::stardict::check_bookname { bookname } {
  if {[lsearch [stardict names] $bookname] == -1} {
    return -code error "no such dictionary: $bookname"
  }
}

# ::stardict::stardict_cmd_close --
#
# Close dictionary.
#
# Arguments:
#	?booknames?	list of dictionaries
#
# Results:
#	Free items related with dictionaty.
#

proc ::stardict::stardict_cmd_close { {booknames {}} } {
  variable dict
  variable words

  if {![llength $booknames]} {
    set booknames [stardict names]
  }
  foreach b $booknames {
    array unset dict "$b,*"
    array unset words "$b,*"
  }
}

proc ::stardict::datachunk {bookname offset size} {
  set fd [open [stardict info -dict $bookname]]
  fconfigure $fd -encoding binary -translation binary
  seek $fd $offset start
  set out [read $fd $size]
  close $fd
  return [encoding convertfrom utf-8 "$out"]
}

proc ::stardict::searchfor { data bookname } {
  variable words

  set in [string index [set data [string trim $data]] 0]
  upvar 0 words($bookname,$in) wolist

  set len	[llength $wolist]
  set leftpos 	0
  set rightpos	$len
  set currpos	[expr $len / 2]
  set result	{}

  set fd [open [stardict info -idx $bookname]]
  fconfigure $fd -encoding binary -translation binary

  while { $len > 1 } {
    binary scan [lindex $wolist $currpos] II offset count
    seek $fd $offset start
    set buf [read $fd $count]
    binary scan $buf A$count val
    set val [encoding convertfrom utf-8 "$val"]
    set cmp [string compare -nocase "$val" "$data"]
    if { $cmp == 1 } {
      set rightpos 	$currpos
      set len		[expr {$rightpos - $leftpos}]
      set currpos	[expr {$len/2}]
    } elseif { $cmp == -1 } {
      set leftpos	$currpos
      set len		[expr {$rightpos - $leftpos}]
      set currpos	[expr {($len/2) + $leftpos}]
    } else {
      seek $fd [expr {$offset+$count}] start
      binary scan [read $fd 8] II dict_offset dict_size
      set result [datachunk $bookname $dict_offset $dict_size]
      break
    }
  }

  close $fd
  return $result
}

# ::stardict::stardict_cmd_get --
#
# Get word from dictionary.
#
# Arguments:
#	data		actual search data (word)
#	?booknames?	list of dictionaries
#
# Results:
#	Array with items index is bookname and word
# data.
#

proc ::stardict::stardict_cmd_get { data {booknames {}} } {
  variable dict

  array set result {}
  if {![llength $booknames]} {
    set booknames [stardict names]
  }
  foreach b $booknames {
    if [stardict info -isload $b] {
      if {![catch {set out [searchfor $data $b]}]} {
        set result($b) $out
      } else {
        set result($b) {}
      }
    }
  }
  return [array get result]
}

# ::stardict::stardict_cmd_info --
#
# Retrieve various information about dictionary.
# 
# Arguments:
#	opt		option:
#	-isload		return status if dictionary open or not
#	-ifo		file name of .ifo file
#	-idx		file name of .idx file
#	-dict		file name of .dict file
#	-cache		file name of .cache file
#	-iscached	return status if dictionary cached
#	-files		list of all dictionary files
#	bookname	name of dictionary
#
# Results:
#

proc ::stardict::stardict_cmd_info {opt bookname} {
  variable dict

  switch -exact -- $opt {
    "-isload" {
      return $dict($bookname,isload)
    }
    "-ifo" {
      return $dict($bookname,file_ifo)
    }
    "-idx" {
      return $dict($bookname,file_idx)
    }
    "-dict" {
      return $dict($bookname,file_dict)
    }
    "-cache" {
      return $dict($bookname,file_cache)
    }
    "-iscached" {
      return $dict($bookname,iscached)
    }
    "-files" {
      return $dict($bookname,files)
    }
  }
}

######################################################
#namespace import stardict::stardict
#stardict setup [file join $env(HOME) .dict]
#foreach n [stardict names] {
#  puts "$n"
#  stardict open $n
#  #puts "caching $n..."
#  #stardict createcache $n
#}
#stardict get cat
#puts "ready"
#gets stdin line
#puts "---------------------------------"
#puts [stardict::stardict get stream]
#stardict close
