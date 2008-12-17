
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
    set wince 0
    if { $tcl_platform(os) == "Windows CE" } {
      package require wce
      set wince 1
    }
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

proc putsWarn {} {
  if { [llength [stardict lasterr]] } { 
    foreach m [stardict lasterr] { Console -red "$m\n" }
  }
}

proc putsWord { word {bookname {}} } {
  global config

  array set result [stardict get $word $bookname]
  foreach d [lsort [array names result]] {
    Console -bold "$d: "
    Console -italic "$word\n"
    Console "$result($d)"
  }
  putsWarn
}

proc GenerateCache {} {
  global config win

  if { ! $config(nogui) } { $win(entry) configure -state disable }
  foreach n [getbooks] {
    Console "Read book: $n\n"
    if { ! $config(nogui) } { update idletasks }
    if { [catch {stardict open -nocache $n} err] } {
      puts stderr $err
      continue
    }
    Console "Generating cache for book: $n\n"
    if { ! $config(nogui) } { update idletasks }
    stardict createcache $n
  }
  if { ! $config(nogui) } { $win(entry) configure -state normal }
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
  $win(text) yview end
}

proc getbooks {} {
  global config

  if { [info exists config(booknames)] } {
    return [split $config(booknames) ,]
  } else {
    return [stardict names]
  }
}

proc showdicts {} {
  foreach n [lsort [stardict names]] { 
    Console "$n\n" 
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
  set argv {}; # Disable further argment processing by Tk package
  package require Tk
  set config(nogui) 0 
}

if {[catch {configOpen} err]} { ABORT $err }

# Show names of founded dictionaries and quit
if { $config(showdicts) } { showdicts; exit 0 }

# Create cache and quit
if { $config(cachequit) } { GenerateCache; exit 0 }

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
set mb [menubutton $f.b2 -text "M" -direction below -relief raised \
	-padx 2 -pady 2]
menu $mb.m -tearoff 0
$mb.m add command -label "Dictionaries" -command showdicts
$mb.m add command -label "Clear output" -command guiclearoutput
$mb.m add command -label "Cache dict" -command SoftGenerateCache
$mb.m add command -label "Help" -command guihelp
$mb.m add command -label "Quit" -command guiquit
$mb configure -menu $mb.m
set win(entry) [entry $f.e -textvariable win(word)]
pack $f.b2 $f.b1 -side right
pack $win(entry) -side left -fill x -expand yes

# Setting up application menu under Windows CE
if { $wince == 1 } { $win(root) config -menu $mb.m }

pack [set f [frame $win(root).f]] -fill both -expand yes
set win(text) [text $f.t -font [list $config(font) $config(fontsize)]  \
	-yscrollcommand [list $f.sy set]]
set win(scry) [scrollbar $f.sy -takefocus 0 \
	-command [list $win(text) yview]]
pack $win(scry) -side right -fill y
pack $win(text) -side left -fill both -expand yes

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

# Setting up text styles
$win(text) tag configure bold -font [list $config(font) $config(fontsize) bold]
$win(text) tag configure italic -font [list $config(font) $config(fontsize) italic]
$win(text) tag configure darkblue -foreground darkblue
$win(text) tag configure red -foreground red

focus -force $win(entry)
$win(text) configure -state disabled
tkwait visibility $win(text)
update idletasks

if { $config(createcache) } { GenerateCache }

putsWarn
Console "Loading dictionary:\n"
update idletasks
foreach n [getbooks] {
  if {[catch {stardict open $n} err]} {
    Console -red "$err\n"
  } else { Console -darkblue "$n\n" }
  update idletasks
}

guihelp
