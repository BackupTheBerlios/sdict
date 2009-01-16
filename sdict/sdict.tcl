
# Load local packages
lappend auto_path [file dirname [info script]]
package require stardict
package require config

# Terminate application
# Suited for unix systems
proc ABORT { msg } {
  global argv0

  puts stderr "$argv0: $msg"
  exit 1
}

# Terminate application
# Suited for Windows
proc ABORT_WIN { msg } {
  tk_messageBox -title Error -icon error -type ok -message "$msg"
  exit 1
}

#########################################################
# Global variables
#########################################################

# Command line arguments passed to application
#array set config {
array set clargs {
  createcache	0
  cachequit	0
  showdicts	0
  autoclear	0
  words		{}
  rcfile	""
  font		fixed
  fontsize  	10
}

# Config file
set rcfile ""

# Flag signing that no need build gui
set nogui 0

array set enabled {}

# GUI widgets
array set win {}

# List of entered words
set history {}

# How much words in history
set hisptr  0

#########################################################
# End of global variables
#########################################################

# Try get rcfile from environment variable
if { [info exists env(SDICTRC)] } {
  set rcfile $env(SDICTRC)
}

# Parsing command line arguments
set state skip
foreach arg $argv {
  switch $state {
    rcfile   { set rcfile $arg; set state skip; continue }
    bookname { set clargs(booknames) $arg; set state skip; continue }
  }
  switch -glob -- $arg {
    -rc     { set state rcfile      }
    -c      { set clargs(createcache) 1 }
    -cq     { set clargs(cachequit)   1 }
    -d	    { set clargs(showdicts)   1 }
    -b	    { set state bookname	}
    default { 
      if {[string index $arg 0] == "-"} {
        ABORT "unknown argument: $arg"
      }
      lappend clargs(words) $arg
    }
  }
}
unset state

# If no rcfile specified, depending on
# running platform select appropriate.
set wince 0
switch $tcl_platform(platform) {
  unix {
    if { $rcfile == "" } {
      set rcfile [join [list $env(HOME) .sdictrc] [file separator]]
    }
  }
  windows {
    if { $rcfile == "" } {
      set rcfile [join [list [file dirname [info script]] sdictrc] [file separator]]
    }
    rename ABORT ABORT_OLD
    rename ABORT_WIN ABORT
    if { $tcl_platform(os) == "Windows CE" } {
      package require wce
      set wince 1
    }
  }
}

##################################################################
proc guiquit {} {
  global win enabled

  stardict close

  # Rewrite config on exit
  foreach n [lsort [array names enabled]] {
    if { ! $enabled($n) } { 
      config set $n "no" 
    } else { catch {config unset $n} }
  }
  config commit

  destroy $win(root)
}

proc putsWarn {} {
  if { [llength [stardict lasterr]] } { 
    foreach m [stardict lasterr] { Console -red "$m\n" }
  }
}

proc putsWord { word {bookname {}} } {
  global enabled

  if { [config get autoclear 0] } { guiclearoutput }
  array set result [stardict get [string tolower $word] $bookname]
  foreach d [lsort [array names result]] {
    # Skip disabled dictionaries
    if { [info exists enabled($d)] && !$enabled($d) } { continue }
    Console -bold "$d: "
    Console -italic "$word\n"
    if { [string index $result($d) end] != "\n" } {
      append result($d) "\n"
    }
    Console "$result($d)"
  }
  putsWarn
}

proc GenerateCache {} {
  global win nogui

  if { ! $nogui } { $win(entry) configure -state disable }
  foreach n [getbooks] {
    Console "Read book: $n\n"
    if { ! $nogui } { update idletasks }
    if { [catch {stardict open -nocache $n} err] } {
      puts stderr $err
      continue
    }
    Console "Generating cache for book: $n\n"
    if { ! $nogui } { update idletasks }
    stardict createcache $n
  }
  if { ! $nogui } { $win(entry) configure -state normal }
}

# Generate cache for dictionaries which have not one
proc SoftGenerateCache {} {
  foreach n [getbooks] {
    if { [stardict info -isload $n] && \
    	! [stardict info -iscached $n] } {
      Console -darkblue "$n: no cache, generating\n"
      update idletasks
      stardict createcache $n
      Console -darkblue "$n: done\n"
    } else {
      Console -red "$n: cache exists: [stardict info -cache $n]\n"
    }
  }
}

proc Console { args } {
  global win nogui

  if { [string index [lindex $args 0] 0] == "-" } {
    set msg [lindex $args 1]
    set style [string range [lindex $args 0] 1 end]
  } else {
    set msg [lindex $args 0]
    set style ""
  }

  if { $nogui } {
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
  $win(text) yview end
}

proc getbooks {} {
  global clargs enabled

  # High priority to books passed by command line
  if { [info exists clargs(booknames)] } {
    return [split $clargs(booknames) ,]
  }

  # Get booknames except those which obviuos disabled
  # by config file.
  set ret {}
  foreach n [stardict names] {
    if { [lsearch -exact [config names] $n] == -1 } {
      set enabled($n) 1
      lappend ret $n
    } else {
      set enabled($n) 0
    }
  }
  return $ret
}

proc showdicts {} {
  Console -bold "All available dicts:\n"
  foreach n [lsort [stardict names]] { 
    Console -bold "$n\n" 
    array set info [stardict info -info $n]
    foreach n [lsort [array names info]] { Console "$n: $info($n)\n" }
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
}

proc guihelp {} {
  global win wince

  Console -bold "Welcome to Sdict!\n"
  Console "Keys are:\n"
  if { $wince == 1 } {
    Console "Up/Down\thistory up/down\n"
    Console "#\tswitch output/input\n"
    return
  }
  Console "^Q\t\tquit\n"
  Console "^Z\t\tclear output\n"
  Console "^H\t\tthis help\n"
  Console "Up/Down\t\thistory up/down\n"
  Console "PgUp/PgDown\tscroll output\n"
  Console "Esc\t\tclear input\n"
}

proc guiclearoutput {} {
  global win
  $win(text) configure -state normal
  $win(text) delete 0.0 end
  $win(text) configure -state disabled
}

proc saveoutput {parent} {
  global win

  # Prepare file dialog
  set types {
  	{"Text files"	{.txt}}
	{"All files"	*}
  }
  set file [tk_getSaveFile -filetypes $types -parent $parent \
  	-initialfile output -defaultextension .txt]
  if { $file == "" } { return }

  if { [catch {set fd [open $file w]} err] } {
    Console -red "$file: $err\n"
    return
  }

  # Save output
  puts $fd [$win(text) get 0.0 end]
  close $fd
}

# Load/Unload dict from menu 'D'
proc dictOnOff {dict} {
  global enabled

  if { !$enabled($dict) } {
    Console -darkblue "Unload: $dict\n"
    stardict close $dict
  } else {
    Console -darkblue "$dict\n"
    stardict open $dict
  }
}

proc populateMenuD {wmenu} {
  global enabled

  foreach d [lsort [stardict names]] {
    if { ![info exists enabled($d)] } {
      set enabled($d) 1
    }
    $wmenu add check -label $d -variable enabled($d) \
    	-command [list dictOnOff $d]
  }
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
namespace import config::config

# Select appropriate stream to output messages
if { [llength $clargs(words)] || $clargs(showdicts) \
	|| $clargs(cachequit) } {
  set nogui 1
} else { 
  set argv {}; # Disable further argment processing by Tk package
  package require Tk
  set nogui 0 
}

if { [catch {config open $rcfile} err] } { ABORT $err }
# Check for required options
if { [catch {config get cachedir}] } {
  ABORT "$rcfile: no \"cachedir\" option"
}
if { [catch {config get search}] } {
  ABORT "$rcfile: no \"search\" option"
}

# Why this need? 
# On Unix systems all ok, but Windows is another matter. On Windows path
# separator is \ and Tcl treat this as control sequence and thus add additional
# level to list. For example, string "d:\work\dict" converted to list
# will be {d:\work\dict}. Arguments passed to setup -cachedir is string, but 
# last argument must be list. Thus, we need remove additional list level from
# cachedir value with 'join' command.
set search [config get search]
set cachedir [join [config get cachedir]]
# Setting up StarDict package
if { [catch {stardict setup -cachedir $cachedir $search} err] } {
  ABORT "$err"
}

# Show names of founded dictionaries and quit
if { $clargs(showdicts) } { showdicts; exit 0 }

# Create cache and quit
if { $clargs(cachequit) } { GenerateCache; exit 0 }

# Translate words from command line and quit
if { $nogui } {
  foreach n [getbooks] {
    if {[catch {stardict open $n} err]} {
      puts stderr $err
      continue
    }
    foreach w $clargs(words) { putsWord $w $n }
    stardict close $n
  }
  exit 0
}

# Create GUI
set win(root)	.
wm title $win(root) "Sdict"
wm iconname $win(root) "Sdict"
if { $wince == 0 } {
  set width 210
  set height 250
} else { 
  # We are running under Windows CE !
  # Adjust window size
  set ce_size     [wm maxsize .]
  set ce_menu     [wce menuheight]
  set ce_caption  [wce captionheight]
  set width       [lindex $ce_size 0]
  set height      [expr {[lindex $ce_size 1] - $ce_menu - $ce_caption}]
  wce inputmode $win(root) ambiguous
  wce keyon back $win(root)
}
wm geometry $win(root) ${width}x${height}

option add *BorderWidth 1
option add *HighlightThickness 0

# Setting up input field and two buttons: for translate and menu
pack [set f [frame $win(root).top]] -fill x -side top
button $f.b1 -text "<" -padx 1 -pady 1 -command guisearch
set mbD [menubutton $f.b3 -text "D" -direction below -relief raised \
	-underline 0 -padx 2 -pady 2]
set mbM [menubutton $f.b2 -text "M" -direction below -relief raised \
	-underline 0 -padx 2 -pady 2]
# Menu for button 'M'
menu $mbM.m -tearoff 0
$mbM.m add command -label "Dictionaries" -command showdicts
$mbM.m add command -label "Clear output" -command guiclearoutput
$mbM.m add command -label "Save output" -command [list saveoutput $win(root)]
$mbM.m add command -label "Cache dict" -command SoftGenerateCache
$mbM.m add command -label "Help" -command guihelp
$mbM.m add command -label "Quit" -command guiquit
$mbM configure -menu $mbM.m
# Menu for button 'D'
menu $mbD.m -tearoff 1
$mbD configure -menu $mbD.m
set win(entry) [entry $f.e -textvariable win(word)]
pack $mbM $mbD $f.b1 -side right
pack $win(entry) -side left -fill x -expand yes

# Create output
pack [set f [frame $win(root).f]] -fill both -expand yes
set win(text) [text $f.t -font \
	[list [config get font "fixed"] [config get fontsize 12]]  \
	-yscrollcommand [list $f.sy set]]
set win(scry) [scrollbar $f.sy -takefocus 0 \
	-command [list $win(text) yview]]
pack $win(scry) -side right -fill y
pack $win(text) -side left -fill both -expand yes

# Setting up application menu under Windows CE
if { $wince == 1 } {
  $mbM.m insert 0 command -label "To entry" -command [list focus -force $win(entry)]
  $mbM.m insert 1 command -label "To output" -command [list focus -force $win(text)]
  $win(root) config -menu $mbM.m 
}

# Setting up hot keys
# Common bindings
bind $win(entry) <Return> 	guisearch
bind $win(entry) <Up>		  [list rollhistory up]
bind $win(entry) <Down>		[list rollhistory down]
if { $wince == 0 } {
  bind $win(root)  <Control-q> 	guiquit
  bind $win(entry) <Escape>	[list $win(entry) delete 0 end]
  bind $win(entry) <Control-z>	guiclearoutput
  bind $win(entry) <Control-h>	guihelp
  bind $win(entry) <Next>		[list $win(text) yview scroll 1 pages]
  bind $win(entry) <Prior>	[list $win(text) yview scroll -1 pages]
} else {
  # Bind for Windows CE based devices
  bind $win(text)  <F9>  [list focus -force $win(entry)]
  bind $win(entry) <F9>  [list focus -force $win(text)]
  bind $win(text) <Up>   [list $win(text) yview scroll -1 pages]
  bind $win(text) <Down> [list $win(text) yview scroll 1 pages ]
}

# This ugly hack for handle hotkeys to invoke menu
# in menubuttons 'D' and 'M' under Windows.
# Tested on ActiveTcl 8.14.4.0 
if { $tcl_platform(platform) == "windows" } {
  proc winMenu {w} {
    tk::MbPost $w
    tk::MenuFirstEntry [$w cget -menu]
  }
  bind $win(root) <Alt-m> [list winMenu $mbM]
  bind $win(root) <Alt-d> [list winMenu $mbD]
}

# Setting up text styles
$win(text) tag configure bold -font \
	[list [config get font "fixed"] [config get fontsize 12] bold]
$win(text) tag configure italic -font \
	[list [config get font "fixed"] [config get fontsize 12] italic]
$win(text) tag configure darkblue -foreground darkblue
$win(text) tag configure red -foreground red

focus -force $win(entry)
$win(text) configure -state disabled
tkwait visibility $win(text)
update idletasks

if { $clargs(createcache) } { GenerateCache }

putsWarn
Console "Loading dictionary:\n"
update idletasks
foreach n [getbooks] {
  if { [info exists enabled($n)] && !$enabled($n) } { continue }
  if {[catch {stardict open $n} err]} {
    Console -red "$err\n"
  } else { Console -darkblue "$n\n" }
  update idletasks
}

populateMenuD $mbD.m
guihelp
