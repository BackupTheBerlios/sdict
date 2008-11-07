
# Load StarDict package
lappend auto_path [file dirname [info script]]
package require stardict

proc ABORT { msg } {
  global argv0

  puts stderr "$argv0: $msg"
  exit 1
}

proc ABORT_WIN { msg } {
  tk_messageBox -title Error -icon error -type ok -message "$msg"
  exit 1
}

# Global variables
array set config {
  createcache	0
  cachequit	0
  showdicts	0
  words		{}
  rcfile	""
  font		fixed
  fontsize  	10
}
array set win {}
set history {}
set hisptr  0

# Try get rcfile from environment variable
if { [info exists env(SDICTRC)] } {
  set config(rcfile) $env(SDICTRC)
}

# Parsing command line arguments
set state skip
foreach arg $argv {
  switch $state {
    rcfile   { set config(rcfile) $arg; set state skip; continue }
    bookname { set config(booknames) $arg; set state skip; continue }
  }
  switch -glob -- $arg {
    -rc     { set state rcfile      }
    -c      { set config(createcache) 1 }
    -cq     { set config(cachequit)   1 }
    -d	    { set config(showdicts)   1 }
    -b	    { set state bookname	}
    default { 
      if {[string index $arg 0] == "-"} {
        ABORT "unknown argument: $arg"
      }
      lappend config(words) $arg
    }
  }
}
unset state

# If no rcfile specified, depending on
# running platform select appropriate.
switch $tcl_platform(platform) {
  unix {
    if { $config(rcfile) == "" } {
      set config(rcfile) [join [list $env(HOME) .sdictrc] [file separator]]
    }
  }
  windows {
    if { $config(rcfile) == "" } {
      set config(rcfile) [join [list [file dirname [info script]] sdictrc] [file separator]]
    }
    rename ABORT ABORT_OLD
    rename ABORT_WIN ABORT
  }
}

##################################################################
proc configOpen {} {
  global config
  
  set fd [open $config(rcfile)]
  while {![eof $fd]} {
    gets $fd line
    set tok [split $line =]
    switch [lindex $tok 0] {
      search {
        lappend config(searchdir) [lindex $tok 1]
      }
      cachedir {
        set config(cachedir) [lindex $tok 1]
      }
      fontsize {
        set size [lindex $tok 1]
        if { ![string is integer $size] } {
          ABORT "fontsize is not integer"
        }
        set config(fontsize) $size
      }
      font { set config(font) [lindex $tok 1] }
    }
  }
  if { ![info exists config(searchdir)] } {
    return -code error "$config(rcfile): no one 'searchdir' option"
  }
  if { ![info exists config(cachedir)] } {
    return -code error "$config(rcfile): no one 'cachedir' option"
  }

  close $fd
  eval {stardict setup -cachedir $config(cachedir) $config(searchdir)}
}

proc guiquit {} {
  global win

  destroy $win(root)
  stardict close
}

proc putsWord { word {bookname {}} } {
  global config

  array set result [stardict get $word $bookname]
  foreach d [lsort [array names result]] {
    Console -bold "$d: "
    Console -italic "$word\n"
    Console "$result($d)"
  }
}

proc Console { args } {
  global config win

  if { [string index [lindex $args 0] 0] == "-" } {
    set msg [lindex $args 1]
    set style [string range [lindex $args 0] 1 end]
  } else {
    set msg [lindex $args 0]
    set style ""
  }

  if { $config(nogui) } {
    puts -nonewline stdout $msg
    return
  }
  $win(text) configure -state normal
  if { $style == "" } {
    $win(text) insert end $msg
  } else {
    $win(text) insert end $msg $style
  }
  $win(text) configure -state disabled
}

proc getbooks {} {
  global config

  if { [info exists config(booknames)] } {
    return [split $config(booknames) ,]
  } else {
    return [stardict names]
  }
}

proc guisearch {} {
  global win history hisptr

  if { ! [string length $win(word)] } {
    return
  }
  putsWord $win(word)
  lappend history $win(word)
  set hisptr -1
  $win(entry) delete 0 end
  $win(text) yview end
}

proc guihelp {} {
  global win

  Console -bold "Welcome to Sdict!\n"
  Console "Keys are:\n"
  Console "^Q\t\tquit\n"
  Console "^Z\t\tclear output\n"
  Console "^H\t\tthis help\n"
  Console "Up/Down\t\thistory up/down\n"
  Console "PgUp/PgDown\tscroll output\n"
  Console "Esc\t\tclear input\n"
  $win(text) yview end
}

proc guiclearoutput {} {
  global win
  $win(text) configure -state normal
  $win(text) delete 0.0 end
  $win(text) configure -state disabled
}

proc rollhistory { dir } {
  global win history hisptr

  if { $hisptr == -1 } {
    set hisptr [expr [llength $history]-1]
  }
  switch $dir {
    up {
      if { $hisptr < [llength $history] } {
        $win(entry) delete 0 end
	$win(entry) insert 0 [lindex $history $hisptr]
        incr hisptr 
      }
    }
    down {
      if { $hisptr >= 0 } {
        $win(entry) delete 0 end
	$win(entry) insert 0 [lindex $history $hisptr]
	incr hisptr -1
      }
    }
  }
}

##################################################################
namespace import stardict::stardict

# Select appropriate stream to output messages
if { [llength $config(words)] || $config(showdicts) \
	|| $config(cachequit) } {
  set config(nogui) 1
} else { 
  package require Tk
  set config(nogui) 0 
}

if {[catch {configOpen} err]} { ABORT $err }

# Show names of founded dictionaries and quit
if { $config(showdicts) } {
  foreach n [lsort [stardict names]] { 
    Console "$n\n" 
  }
  exit 0
}

# Create cache
if { $config(cachequit) || $config(createcache) } {
  foreach n [getbooks] {
    Console "Read book: $n\n"
    if { [catch {stardict open -nocache $n} err] } {
      puts stderr $err
      continue
    }
    Console "Generating cache for book: $n\n"
    stardict createcache $n
  }
  if { $config(cachequit) } { exit 0 }
}

# Translate words from command line and quit
if { $config(nogui) } {
  foreach n [getbooks] {
    if {[catch {stardict open $n} err]} {
      puts stderr $err
      continue
    }
    foreach w $config(words) { putsWord $w $n }
    stardict close $n
  }
  exit 0
}

# Create GUI
set win(root)	.
wm title $win(root) "Sdict"
wm geometry $win(root) 210x250

option add *BorderWidth 1
option add *HighlightThickness 0

pack [set win(entry) [entry $win(root).e -textvariable win(word)]] \
	-side top -fill x
pack [set f [frame $win(root).f]] -fill both -expand yes
set win(text) [text $f.t -font [list $config(font) $config(fontsize)]  \
	-yscrollcommand [list $f.sy set]]
set win(scry) [scrollbar $f.sy -takefocus 0 \
	-command [list $win(text) yview]]
pack $win(scry) -side right -fill y
pack $win(text) -side left -fill both -expand yes

# Setting up hot keys
bind $win(root)  <Control-q> 	guiquit
bind $win(entry) <Return> 	guisearch
bind $win(entry) <Escape>	[list $win(entry) delete 0 end]
bind $win(entry) <Control-z>	guiclearoutput
bind $win(entry) <Control-h>	guihelp
bind $win(entry) <Up>		[list rollhistory up]
bind $win(entry) <Down>		[list rollhistory down]
bind $win(entry) <Next>		[list $win(text) yview scroll 1 pages]
bind $win(entry) <Prior>	[list $win(text) yview scroll -1 pages]

# Setting up text styles
$win(text) tag configure bold -font [list $config(font) $config(fontsize) bold]
$win(text) tag configure italic -font [list $config(font) $config(fontsize) italic]
$win(text) tag configure darkblue -foreground darkblue
$win(text) tag configure red -foreground red

focus -force $win(entry)
$win(text) configure -state disabled
update idletasks

foreach n [getbooks] {
  if {[catch {stardict open $n} err]} {
    Console -red $err
  } else { Console -darkblue "$n\n" }
  update idletasks
}

guihelp
