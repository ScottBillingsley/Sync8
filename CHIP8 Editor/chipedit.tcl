#!/usr/bin/env wish

# ============================================================
# CHIP-8 Editor with File, Serial, and Syntax Highlighting
# ============================================================
# NOTE:
# Syntax highlighting runs in two modes:
#   updateLines full     -> full-file pass (file load)
#   updateLines          -> visible-only pass (editing / scrolling)
#
#   A CHIP8 editor for the Sync-8 emulator running on an arduino mega
#
#   Vernon Billingsley
#   2/5/26
#

wm title . "CHIP-8 Editor"
set bg_color "#f0f0f0"

# ============================================================
# Globals
# ============================================================
set currentFile "Untitled"
set byteStatus "Bytes: 0"

set sel_port "/dev/ttyUSB0"
set sel_baud 9600
set echoEnabled 1
set serialChan ""
set serialStatus ""
set shapeCounter 0
set editMode "select"
set linkSource ""
set lightGray "#d9d9d9"
set snapEnabled 1
set gridSize 20
set AUTO_TAG {[AUTO]}

# ============================================================
# Paned Window
# ============================================================
ttk::panedwindow .pane -orient horizontal
pack .pane -fill both -expand 1

catch {ttk::style theme use clam}

# ============================================================
# Left Editor Pane
# ============================================================
frame .pane.left -bg "#5e636b"

# Main editor widgets
canvas .pane.left.gutter \
    -width 70 \
    -background #e8e8e8 \
    -highlightthickness 0

text .pane.left.editor \
    -background "#1e1e1e" \
    -fg "#888888" \
    -insertbackground white \
    -insertwidth 2 \
    -undo 1 \
    -wrap none \
    -font {"Courier New" 12} \
    -yscrollcommand {.pane.left.ysb set}

bind .pane.left.editor <Return> {
    handleEnter %W ; break
}

bind .pane.left.editor <MouseWheel> {
    if {[tk windowingsystem] eq "aqua"} {
        %W yview scroll [expr {-%D}] units
    } else {
        %W yview scroll [expr {-(%D / 120)}] units
    }
    redrawGutter
    break
}

# X11 fallback (some Linux setups)
bind .pane.left.editor <Button-4> {
    %W yview scroll -1 units
    redrawGutter
    break
}
bind .pane.left.editor <Button-5> {
    %W yview scroll 1 units
    redrawGutter
    break
}


bind .pane.left.editor <KeyRelease-Up>   { after idle redrawGutter }
bind .pane.left.editor <KeyRelease-Down> { after idle redrawGutter }
bind .pane.left.editor <KeyRelease-Prior> { after idle redrawGutter } ;# PageUp
bind .pane.left.editor <KeyRelease-Next>  { after idle redrawGutter } ;# PageDown

bind .pane.left.editor <KeyRelease> {
    after idle updateLines
}

bind .pane.left.gutter <Button-1> { setBreakpointFromGutter %y }

scrollbar .pane.left.ysb -orient vertical -command scrollEditor

# Save reference to editor
set w .pane.left.editor

.pane.left.editor configure -wrap none

# -----------------------------
# Tag configuration (syntax highlighting)
# -----------------------------
foreach {tag color} {
    comment        gray
    inlineComment  "#00FF00"
    labelLine      "#FF0000"
    hexRange       orange
    display        "#a1fa80"
    regIndex       "#693EFE"
    regRandom      "#FF0099"
    regB           "#FFEB3B"
    regE           "#CCFF00"
    regF           "#00BFA5"
    reg3           "#DAA520"
    reg4           "#693EFE"
    reg5           "#822659"
    reg6           "#B39CD0"
    reg7           "#FF6F61"
    reg8           "#FF5722"
} {
    $w tag configure $tag -foreground $color
}

set ::EDITOR .pane.left.editor

# Layout
pack .pane.left.gutter -side left -fill y
pack .pane.left.editor -side left -expand 1 -fill both
pack .pane.left.ysb    -side right -fill y

# Close window
wm protocol . WM_DELETE_WINDOW {
    if {![confirmSaveIfNeeded]} { return }
    exit
}

# ============================================================
# Right Scratchpad
# ============================================================
labelframe .pane.right -text "Scratchpad"
text .pane.right.txt -width 25 -bg "#1e1e1e" -fg "#00FFFF" \
    -insertbackground white -undo 1 -font {monospace 10}
scrollbar .pane.right.sbar -command ".pane.right.txt yview"
.pane.right.txt configure -yscrollcommand ".pane.right.sbar set"

pack .pane.right.sbar -side right -fill y
pack .pane.right.txt -side left -fill both -expand 1

.pane add .pane.left  -weight 3
.pane add .pane.right -weight 1

# ===========================================================
#   Jump to address
# ===========================================================
.pane.left.editor tag configure jumpHighlight \
    -background "#4444AA" -foreground white


 # ============================================================
# Breakpoint Entry Bar
# ============================================================
frame .breakbar -bg "#f0f0f0"

label .breakbar.l -text "Break @" -bg "#f0f0f0" -fg black
entry .breakbar.e \
    -bg black -fg "#00FF00" \
    -insertbackground "#00FF00" \
    -relief sunken \
    -width 12

pack .breakbar.l -side left -padx 3
pack .breakbar.e -side left -padx 3

bind .breakbar.e <Return> {
    sendBreakpoint [%W get]
    %W delete 0 end
}

# ============================================================
# Console
# ============================================================

labelframe .console -text "Arduino Debug Console" -bg black -fg "#00FF00"
text .console.txt -height 12 -bg black -fg "#00FF00" -state disabled
scrollbar .console.sbar -command ".console.txt yview"
.console.txt configure -yscrollcommand ".console.sbar set"

frame .console.btns -bg black
ttk::button .console.btns.listen -text "Connect" -command {listenSerial}
ttk::button .console.btns.disc   -text "Disconnect" -command {disconnectSerial}
ttk::button .console.btns.clear  -text "Clear" -command {
    .console.txt configure -state normal
    .console.txt delete 1.0 end
    .console.txt configure -state disabled
}
ttk::checkbutton .console.btns.echo -text "Echo Upload" -variable echoEnabled
ttk::button .console.btns.upload -text "Upload HEX" -command uploadHex

pack .console.btns.echo   -side top -anchor w -padx 5 -pady 5
pack .console.btns.listen -side top -fill x -padx 5
pack .console.btns.disc   -side top -fill x -padx 5
pack .console.btns.clear  -side top -fill x -padx 5
pack .console.btns.upload -side top -fill x -padx 5

pack .console.btns -side right -fill y
pack .console.sbar -side right -fill y
pack .console.txt  -side left -fill both -expand 1

pack .breakbar     -side bottom -fill x -padx 5 -pady 2
pack .console      -side bottom -fill x -padx 5 -pady 5

# ===========================================================
#   Flowchart
# ===========================================================
set editorBg "#1e1e1e"
set cyanFg   "#00FFFF"

# Configure the base Frame style
ttk::style configure Flow.TFrame -background $lightGray
# Configure the base Label style
ttk::style configure Flow.TLabel -background $lightGray -foreground $cyanFg
# Configure the Button style (optional: adjust as you like)
ttk::style configure Flow.TButton -padding 3

# ============================================================
# Status Bar
# ============================================================
ttk::frame .status -relief sunken
ttk::label .status.file  -textvariable currentFile -padding {5 2}
ttk::label .status.serial -textvariable serialStatus -padding {5 2}
ttk::label .status.count -textvariable byteStatus -padding {5 2}

pack .status -side bottom -fill x
pack .status.file -side left
pack .status.serial -side left -expand 1
pack .status.count -side right

# ============================================================
# Menu
# ============================================================
menu .menubar
. configure -menu .menubar

# --- FILE Menu ---
menu .menubar.file -tearoff 0
.menubar add cascade -label "File" -menu .menubar.file

.menubar.file add command -label "New" -command {

    if {![confirmSaveIfNeeded]} { return }

    closeFiles
    .pane.left.editor delete 1.0 end
    .pane.right.txt delete 1.0 end

    .pane.left.editor edit modified false
    .pane.right.txt edit modified false

    updateLines full
}

.menubar.file add command -label "Open Project" -command {openProject}
.menubar.file add command -label "Save Project" -command {saveProject}
.menubar.file add command -label "Save HEX" -command {saveFile}
.menubar.file add separator
.menubar.file add command -label "Load ROM" -command open_rom
.menubar.file add command -label "Save ROM" -command saveChip8Rom
.menubar.file add separator
.menubar.file add command -label "Exit" -command {
    if {![confirmSaveIfNeeded]} { return }
    exit
}

# --- SERIAL Menu ---
menu .menubar.serial -tearoff 0
.menubar add cascade -label "Serial" -menu .menubar.serial

.menubar.serial add command -label "Set Port" -command {setSerialPort}
.menubar.serial add command -label "Set Baud Rate" -command {setBaudRate}
.menubar.serial add separator
.menubar.serial add command -label "Upload HEX" -command {uploadHex}
.menubar.serial add separator
.menubar.serial add command -label "Disconnect" -command {disconnectSerial}
.menubar.serial add command -label "Clear Console" -command {
    .console.txt configure -state normal
    .console.txt delete 1.0 end
    .console.txt configure -state disabled
}
.menubar.serial add checkbutton -label "Echo Upload" -variable echoEnabled

menu .menubar.navigate -tearoff 0
.menubar add cascade -label "Navigate" -menu .menubar.navigate
.menubar.navigate add command \
    -label "Jump to Address…" \
    -accelerator "Ctrl+G" \
    -command jumpToAddress
bind . <Control-g> {jumpToAddress}

menu .menubar.help -tearoff 0
.menubar add cascade -label "Help" -menu .menubar.help
.menubar.help add command -label "CHIP-8 Opcodes" -command showChip8Help
.menubar.help add separator
.menubar.help add command -label "Flowchart Tool" -command openFlowchartEditor
.menubar.help add separator
.menubar.help add command -label "Sprite Editor" -command open_sprite_editor
.menubar.help add separator
.menubar.help add command -label "Break Point " -command showBreakPiontHelp
.menubar.help add separator
.menubar.help add command -label "About" -command showAbout

# ===========================================================
#	Window Centering
# ===========================================================
proc centerWindow {child parent} {
    update idletasks

    set pw [winfo width  $parent]
    set ph [winfo height $parent]
    set px [winfo x      $parent]
    set py [winfo y      $parent]

    set cw [winfo width  $child]
    set ch [winfo height $child]

    set x [expr {$px + ($pw - $cw) / 2}]
    set y [expr {$py + ($ph - $ch) / 2}]

    wm geometry $child +$x+$y
}

# ===========================================================
#   Sync Scroll
# ===========================================================

proc syncScroll {args} {
    .pane.left.editor yview {*}$args
    redrawGutter
}

proc redrawGutter {} {
    set t .pane.left.editor
    set g .pane.left.gutter

    $g delete all

    # start at top visible display fragment
    set index [$t index "@0,0"]

    # track last logical line drawn
    set lastLine -1

    while 1 {
        set info [$t dlineinfo $index]
        if {$info eq ""} break

        lassign $info x y w h b
        set line [lindex [split $index .] 0]

        # draw only once per logical line
        if {$line != $lastLine} {
            if {[info exists ::lineAddr($line)]} {
                set addr $::lineAddr($line)
#                set label [format "0x%04X" $addr]
                set label [format "%-6s" [format "0x%04X" $addr]]
            } else {
                set label ""
            }

            $g create text 66 [expr {$y + $h/2}] \
                -text $label \
                -anchor e \
                -font [$t cget -font]

            set lastLine $line
        }

        set index [$t index "$index +1 display line"]
    }
}

proc scrollEditor {args} {
    .pane.left.editor yview {*}$args
    redrawGutter
}

# ============================================================
# Line Numbers & Syntax Highlighting
# ============================================================

proc updateLines {{mode visible}} {
    global byteStatus
    set w .pane.left.editor

    array unset ::lineAddr

    set total_lines [lindex [split [$w index "end -1c"] .] 0]
    set current_hex 0x200
    set instr_count 0

    for {set i 1} {$i <= $total_lines} {incr i} {
        set line [$w get "$i.0" "$i.end"]
        set trimmed [string trimleft $line]

        if {$trimmed eq "" ||

            [string index $trimmed 0] eq ";" ||

            [string index $trimmed 0] eq "#"} {
            continue
        } else {
            set ::lineAddr($i) $current_hex
            incr current_hex 2
            incr instr_count
        }
    }

    set bytes [expr {$instr_count * 2}]
    set byteStatus "Bytes: $bytes"

    # -----------------------------
    # Highlighting visible lines
    # -----------------------------
    if {$mode eq "full"} {
        set first 1
        set last [lindex [split [$w index "end -1c"] .] 0]
    } else {
        set first [expr {int([$w index @0,0])}]
        set last  [expr {int([$w index @0,[winfo height $w]]) + 1}]
    }

    set tags {comment inlineComment labelLine hexRange display regIndex regRandom regB regE regF reg3 reg4 reg5 reg6 reg7 reg8}
     $w tag configure inlineComment -foreground "#888888"
     $w tag configure comment -foreground "#c9b51c"
     $w tag configure autoComment -foreground "#80720b"
     $w tag raise autoComment inlineComment

    foreach tag $tags { $w tag remove $tag "$first.0" "$last.end" }

    for {set i $first} {$i < $last} {incr i} {
        set line [$w get "$i.0" "$i.end"]
        if {$line eq ""} continue
        set trimmed [string trimleft $line]

        if {[string index $trimmed 0] eq ";"} {

            $w tag add comment "$i.0" "$i.end"
            continue
        }
        if {[string index $trimmed 0] eq "#"} {
            $w tag add labelLine "$i.0" "$i.end"
            continue
        }

        set cidx [string first ";" $line]

        if {$cidx >= 0} {
            $w tag add inlineComment "$i.$cidx" "$i.end"
            set limit $cidx

            # Look for [AUTO] inside the comment
            set autoIdx [string first "\[AUTO\]" $line]
            if {$autoIdx >= 0} {
            $w tag add autoComment "$i.$autoIdx" "$i.[expr {$autoIdx + 6}]"
            }

        } else {
            set limit [string length $line]
        }

        set code [string range $line 0 $limit]

        foreach m [regexp -all -inline -indices {\y[0-9A-Fa-f]{4}\y} $code] {
            set s [lindex $m 0]
            set e [expr {[lindex $m 1] + 1}]
            set start "$i.$s"
            set end   "$i.$e"

            # Auto-capitalize opcode
            set raw [$w get $start $end]
            set up  [string toupper $raw]
            if {$raw ne $up} { $w replace $start $end $up }

            set op [string index $up 0]
            switch -exact -- $op {
                "1" - "2" { $w tag add hexRange  $start $end }
                "3"       { $w tag add reg3      $start $end }
                "4"       { $w tag add reg4      $start $end }
                "5"       { $w tag add reg5      $start $end }
                "6"       { $w tag add reg6      $start $end }
                "7"       { $w tag add reg7      $start $end }
                "8"       { $w tag add reg8      $start $end }
                "A"       { $w tag add regIndex  $start $end }
                "B"       { $w tag add regB      $start $end }
                "C"       { $w tag add regRandom $start $end }
                "D"       { $w tag add display   $start $end }
                "E"       { $w tag add regE      $start $end }
                "F"       { $w tag add regF      $start $end }
            }

            # =================================================
            scan $up "%x" opcode
            set asm [decode_opcode $opcode]

        }

    }
    after idle redrawGutter
}

# ===========================================================
#   Edit tag
# ===========================================================
proc handleEnter {w} {
    # Get current cursor line
    set idx [$w index insert]
    set lineNum [lindex [split $idx .] 0]

    set line [$w get "$lineNum.0" "$lineNum.end"]

    # If no comment, attempt auto-decompile
    if {[string first ";" $line] < 0} {
        autoCommentLine $w $lineNum
    }

    # Let the normal Return behavior happen
    after idle [list $w insert insert "\n"]

    return -break
}

proc autoCommentLine {w i} {
    global AUTO_TAG

    set line [$w get "$i.0" "$i.end"]

    set matches [regexp -all -inline -indices {\y[0-9A-Fa-f]{4}\y} $line]

    foreach m $matches {
        lassign $m s e
        incr e

        set start "$i.$s"
        set end   "$i.$e"

        set raw [$w get $start $end]
        set up  [string toupper $raw]

        if {$raw ne $up} {
            $w replace $start $end $up
        }

        scan $up "%x" opcode
        set asm [decode_opcode $opcode]
        # Append AUTO comment safely
        $w insert "$i.end" "\t; $AUTO_TAG $asm"
        return
    }
}

# ============================================================
# File Operations
# ============================================================

proc closeFiles {} {
    global serialChan currentFile

    # Reset the filename
    set currentFile ""

    # Loop through all open Tcl channels
    foreach chan [file channels] {
        # 1. Skip standard I/O (stdin, stdout, stderr)
        if {$chan eq "stdin" || $chan eq "stdout" || $chan eq "stderr"} {
            continue
        }

        # 2. Skip your serial port (don't disconnect just because of a 'New' file)
        if {[info exists serialChan] && $chan eq $serialChan} {
            continue
        }

        # 3. Close everything else (files and other open handles)
        catch {close $chan}
    }
}

proc saveProject {} {
    global currentFile

    if {[info exists currentFile] && $currentFile ne ""} {
        set suggestedName $currentFile
    } else {
        set suggestedName "my_project.txt"
    }

    set f [tk_getSaveFile -defaultextension ".txt" \
        -initialfile $suggestedName \
        -title "Save Project As"]

    if {$f eq ""} return
    set currentFile [file tail $f]

    set fd [open $f w]

    puts $fd "#---EDITOR---"
    puts -nonewline $fd [.pane.left.editor get 1.0 "end -1c"]
    puts $fd ""
    puts $fd "#---SCRATCH---"
    puts -nonewline $fd [.pane.right.txt get 1.0 "end -1c"]

    close $fd
}

proc openProject {} {
    global currentFile

    set filename [tk_getOpenFile \
        -filetypes {{"Text Files" .txt} {"All files" *}}]
    if {$filename eq ""} return

    set currentFile [file tail $filename]

    set f [open $filename r]
    set data [read $f]
    close $f

    set editorData ""
    set scratchData ""

    set eMarker "#---EDITOR---"
    set sMarker "#---SCRATCH---"

    set ePos [string first $eMarker $data]
    set sPos [string first $sMarker $data]

    if {$ePos >= 0 && $sPos > $ePos} {

        set editorStart [expr {$ePos + [string length $eMarker]}]
        set editorData [string trim \
            [string range $data $editorStart [expr {$sPos - 1}]]]

        set scratchStart [expr {$sPos + [string length $sMarker]}]
        set scratchData [string trim \
            [string range $data $scratchStart end]]

    } else {
        # fallback (old format)
        set editorData $data
    }

    # Load main editor
    set w .pane.left.editor
    $w configure -state normal
    $w delete 1.0 end
    $w insert 1.0 $editorData
    $w edit reset
    $w edit modified false
    $w see 1.0
    $w yview moveto 0

    # Load scratchpad
    set s .pane.right.txt
    $s delete 1.0 end
    $s insert 1.0 $scratchData

    after idle {
        updateLines full
        redrawGutter
    }

    focus $w
}

proc confirmSaveIfNeeded {} {

    set editorModified [.pane.left.editor edit modified]
    set scratchModified [.pane.right.txt edit modified]

    if {!$editorModified && !$scratchModified} {
        return 1
    }

    bell -displayof .

    set res [tk_messageBox \
        -message "Project has unsaved changes.\nSave now?" \
        -type yesnocancel \
        -icon warning]

    switch $res {
        yes {
            saveProject
            return 1
        }
        no {
            return 1
        }
        cancel {
            return 0
        }
    }
}

proc saveFile {} {
    set filename [tk_getSaveFile -defaultextension ".hex" \
        -filetypes {{"Hex Files" .hex} {"All Files" *}}]
    if {$filename eq ""} return

    set editor .pane.left.editor
    set fh [open $filename w]

    set line " /* $filename */"
    puts $fh $line

    set bytes_per_row 32
    set byte_count 0
    set line ""
    set count 0

    puts $fh $line

    set line "const uint8_t test\[\] = \{ "
    puts $fh $line
    set line ""

    foreach lineText [split [$editor get 1.0 "end -1c"] "\n"] {
        set trimmed [string trim $lineText]

        if {$trimmed eq "" ||
            [string index $trimmed 0] eq "#" ||
            [string index $trimmed 0] eq ";"} {
                continue
            }

            if {[regexp {\y([0-9A-Fa-f]{4})\y} $trimmed -> match]} {
                scan $match %x val
                set hi [expr {($val >> 8) & 0xFF}]
                set lo [expr {$val & 0xFF}]

                append line [format "0x%02X, 0x%02X, " $hi $lo]
                incr byte_count 2
                incr count 2

            if {$byte_count >= $bytes_per_row} {
                puts $fh $line
                set line ""
                set byte_count 0
            }
        }
    }

    if {$line ne ""} {
        puts $fh $line
    }

    set line "\};"
    puts $fh $line

    set line ""
    puts $fh $line
    set line " /* Saved $count bytes */"
    puts $fh $line

    close $fh
    tk_messageBox -message "Saved $count bytes to $filename"
}

proc open_rom {} {
    set file [tk_getOpenFile \
        -title "Open CHIP-8 ROM" \
        -filetypes {
            {"CHIP-8 ROMs" {.ch8 .rom .bin}}
            {"All Files" *}
        }]

    if {$file eq ""} return
    load_chip8_rom $file
}

proc load_chip8_rom {filename} {
    set fh [open $filename rb]
    fconfigure $fh -translation binary
    set data [read $fh]
    close $fh

    set len [string length $data]

    $::EDITOR delete 1.0 end

    for {set i 0} {$i < $len-1} {incr i 2} {
        binary scan $data @${i}S opcode
        set opcode [expr {$opcode & 0xFFFF}]
        set asm [decode_opcode $opcode]
        $::EDITOR insert end [format "%04X\t; %s\n" $opcode $asm]
    }

        after idle {
        updateLines full
        redrawGutter
    }
}

proc saveChip8Rom {} {
    set types {
        {"CHIP-8 ROM" {.ch8 .rom}}
        {"All Files" *}
    }

    set fname [tk_getSaveFile -filetypes $types -defaultextension .ch8]
    if {$fname eq ""} return

    set w .pane.left.editor
    set lines [lindex [split [$w index end] .] 0]

    if {[catch {open $fname wb} fh]} {
        tk_messageBox -icon error -message "Cannot open file:\n$fh"
        return
    }

    fconfigure $fh -translation binary -encoding binary

    for {set i 1} {$i <= $lines} {incr i} {
        set line [$w get "$i.0" "$i.end"]
        set line [string trim $line]

        # Skip blank lines
        if {$line eq ""} continue

        # Skip comments + labels
        if {[regexp {^(;|//|#)} $line]} continue

        # Extract first 4 hex digits (opcode)
        if {[regexp {^([0-9A-Fa-f]{4})} $line -> op]} {
            scan $op %x value
            set hi [expr {($value >> 8) & 0xFF}]
            set lo [expr {$value & 0xFF}]
            puts -nonewline $fh [binary format cc $hi $lo]
        }
    }

    close $fh

    appendConsole "ROM saved: [file tail $fname]"
}

proc decode_opcode {opcode} {

set hi [format "0x%04X" [expr {$opcode & 0xF000}]]

switch $hi {
    0x0000 {
            set full [format "0x%04X" $opcode]
            switch -- $full {
                0x00E0 { return "CLS" }
                0x00EE { return "RET" }
                default { return "SYS" }
        }
    }

    0x1000 { return [format "JP %03X"  [expr {$opcode & 0x0FFF}]] }
    0x2000 {
        return [format "CALL %03X" [expr {$opcode & 0x0FFF}]]
    }
    0x3000 {
        return [format "SE V%X, %02X" \
            [expr {($opcode >> 8) & 0xF}] \
            [expr {$opcode & 0xFF}]]
    }
    0x4000 {
        return [format "SNE V%X, %02X" \
            [expr {($opcode >> 8) & 0xF}] \
            [expr {$opcode & 0xFF}]]
    }
    0x5000 {
        if {[expr {$opcode & 0xF}] == 0} {
            return [format "SE V%X, V%X" \
                [expr {($opcode >> 8) & 0xF}] \
                [expr {($opcode >> 4) & 0xF}]]
        }
        return "DATA"
    }
    0x6000 { return [format "LD V%X, %02X" \
                        [expr {($opcode >> 8) & 0xF}] \
                        [expr {$opcode & 0xFF}]] }
    0x7000 { return [format "ADD V%X, %02X" \
                        [expr {($opcode >> 8) & 0xF}] \
                        [expr {$opcode & 0xFF}]] }
    0x8000 {
        set x [expr {($opcode >> 8) & 0xF}]
        set y [expr {($opcode >> 4) & 0xF}]
        set n [expr {$opcode & 0xF}]

        switch $n {
            0 { return [format "LD V%X, V%X"  $x $y] }
            1 { return [format "OR V%X, V%X"  $x $y] }
            2 { return [format "AND V%X, V%X" $x $y] }
            3 { return [format "XOR V%X, V%X" $x $y] }
            4 { return [format "ADD V%X, V%X" $x $y] }
            5 { return [format "SUB V%X, V%X" $x $y] }
            6 { return [format "SHR V%X"      $x] }
            7 { return [format "SUBN V%X, V%X" $x $y] }
            14 { return [format "SHL V%X"     $x] }
            default { return "DATA" }
            }
    }
    0x9000 {
        if {[expr {$opcode & 0xF}] == 0} {
            return [format "SNE V%X, V%X" \
                [expr {($opcode >> 8) & 0xF}] \
                [expr {($opcode >> 4) & 0xF}]]
            }
        return "DATA"
    }

    0xA000 { return [format "LD I, %03X" [expr {$opcode & 0x0FFF}]] }

    0xB000 { return [format "JP %03X + v0" [expr {$opcode & 0x0FFF}]]}

    0xC000 { return [format "V%X = RND & %02X" [expr {($opcode >> 8) & 0xF}] \
                        [expr {$opcode & 0x00FF}]]}

    0xD000 { return [format "DRW V%X, V%X, %X" \
                        [expr {($opcode >> 8) & 0xF}] \
                        [expr {($opcode >> 4) & 0xF}] \
                        [expr {$opcode & 0xF}]] }
    0xE000 {
        set x  [expr {($opcode >> 8) & 0xF}]
        set lo [expr {$opcode & 0xFF}]

        switch $lo {
            158 { return [format "SKP V%X"  $x] }   ;# 0x9E
            161 { return [format "SKNP V%X" $x] }   ;# 0xA1
            default { return "DATA" }
            }
    }
    0xF000 {
        set x  [expr {($opcode >> 8) & 0xF}]
        set lo [expr {$opcode & 0xFF}]

        switch $lo {
            7   { return [format "LD V%X, DT" $x] }
            10  { return [format "LD V%X, K"  $x] }
            21  { return [format "LD DT, V%X" $x] }
            24  { return [format "LD ST, V%X" $x] }
            30  { return [format "ADD I, V%X" $x] }
            41  { return [format "LD F, V%X"  $x] }
            51  { return [format "LD B, V%X"  $x] }
            85  { return [format {LD [I], V%X} $x] }
            101 { return [format {LD V%X, [I]} $x] }
            default { return "DATA" }
            }
    }

    default { return "DATA" }
    }
}


# ============================================================
# Serial Placeholders
# ============================================================

proc appendConsole {msg} {
    .console.txt configure -state normal
    .console.txt insert end "$msg\n"
    .console.txt see end
    .console.txt configure -state disabled
}

proc readSerialData {chan} {
    if {[eof $chan]} {
        catch {close $chan}
        return
    }

    if {[gets $chan line] >= 0} {
        .console.txt configure -state normal
        .console.txt insert end "$line\n"
        .console.txt see end
        .console.txt configure -state disabled
    }
}

proc setSerialPort {} {
    global sel_port

    # Detect available ports
    set ports {}

    if {[string equal [tk windowingsystem] "aqua"] || [string equal [tk windowingsystem] "x11"]} {
        foreach p [glob -nocomplain /dev/ttyUSB* /dev/ttyAMA* /dev/ttyACM*] {
            lappend ports $p
        }
    } elseif {[string equal [tk windowingsystem] "win32"]} {
        for {set i 1} {$i <= 20} {incr i} {
            lappend ports "COM$i"
        }
    }

    if {[llength $ports] == 0} {
        tk_messageBox -message "No serial ports detected"
        return
    }

    # Create dialog
    set dlg [toplevel .portDlg]
    wm title $dlg "Select Serial Port"
    wm transient $dlg .       ;# stay on top of main window
	centerWindow .portDlg .
    focus $dlg                ;# grab keyboard focus
    grab set $dlg             ;# modal

    ttk::label $dlg.lbl -text "Select Serial Port:"
    ttk::combobox $dlg.combo -values $ports -textvariable sel_port -state readonly
    ttk::button $dlg.ok -text "OK" -command [list ::setPortOk $dlg]

    pack $dlg.lbl $dlg.combo $dlg.ok -padx 10 -pady 5
}

proc setPortOk {dlg} {
    global sel_port
    appendConsole "Serial port set to $sel_port"
    grab release $dlg
    destroy $dlg
}

proc setBaudRate {} {
    global sel_baud

    # Standard baud rates
    set rates {9600 19200 38400 57600 115200}

    # Create dialog
    set dlg [toplevel .baudDlg]
    wm title $dlg "Select Baud Rate"
    wm transient $dlg .       ;# stay on top of main window
	centerWindow .baudDlg .
    focus $dlg                ;# grab keyboard focus
    grab set $dlg             ;# modal

    ttk::label $dlg.lbl -text "Select Baud Rate:"
    ttk::combobox $dlg.combo -values $rates -textvariable sel_baud -state readonly
    ttk::button $dlg.ok -text "OK" -command [list ::setBaudOk $dlg]

    pack $dlg.lbl $dlg.combo $dlg.ok -padx 10 -pady 5
}

proc setBaudOk {dlg} {
    global sel_baud
    appendConsole "Baud rate set to $sel_baud"
    grab release $dlg
    destroy $dlg
}

proc uploadHex {} {
    global sel_port sel_baud byteStatus echoEnabled serialChan
	
	    if {[catch {fconfigure $serialChan -translation binary -buffering none -blocking 1} err]} {
        appendConsole "Failed to configure serial port: $err"
        close $serialChan
        return
    }

    # 3. Count lines and prepare byte counter
    set total_lines [lindex [split [.pane.left.editor index "end -1c"] .] 0]
    set bytes_sent 0

    appendConsole "--- Starting Binary Upload to $sel_port ---"

    # 4. Send opcodes line by line
    for {set i 1} {$i <= $total_lines} {incr i} {
        set line_content [.pane.left.editor get "$i.0" "$i.end"]
        set trimmed [string trimleft $line_content]

        # Skip empty lines or comments
        if {$trimmed eq "" || [string index $trimmed 0] eq "#" || [string index $trimmed 0] eq ";" } {
            continue
        }

        # Match 4-digit hex opcode
        if {[regexp {\y([0-9A-F]{4})\y} $line_content match hex_val]} {
            # Convert to integer
            scan $hex_val %x full_val

            # Split into hi/lo bytes
            set hi [expr {($full_val >> 8) & 0xFF}]
            set lo [expr {$full_val & 0xFF}]

            # Echo to console if enabled
            if {$echoEnabled} {
                appendConsole [format "SENDING: %02X %02X" $hi $lo]
            }

            # SEND BYTES INDIVIDUALLY (avoids c2 issues)
            if {[catch {
                set bin_hi [binary format c $hi]
                set bin_lo [binary format c $lo]
                puts -nonewline $serialChan $bin_hi
                puts -nonewline $serialChan $bin_lo
                flush $serialChan
            } err]} {
                appendConsole "Serial Write Error: $err"
                break
            }

            incr bytes_sent 2
            set byteStatus "Sent $bytes_sent bytes"
            update idletasks
        }
    }

    # 5. Restore text mode for listening
    fconfigure $serialChan -translation auto -buffering line -blocking 0
    fileevent $serialChan readable [list readSerialData $serialChan]

    appendConsole "--- Upload Finished: $bytes_sent bytes sent ---"
}

proc disconnectSerial {} {
    global serialChan sel_port sel_baud serialStatus
    if {$serialChan eq ""} {
    return
    }

    # Disable callbacks first
    catch { fileevent $serialChan readable {} }
    catch { fileevent $serialChan writable {} }

    # Disable the control lines
    catch { fconfigure $serialChan -ttycontrol {DTR 0 RTS 0} }

    # Flush and close
    catch { flush $serialChan }
    catch { close $serialChan }

    # Clear channel FIRST so other code sees "disconnected"
    set serialChan ""

    # Update UI / status
    set serialStatus "Port: $sel_port ($sel_baud bps)"
    appendConsole "Serial disconnected"

    }

proc listenSerial {} {
    global sel_port sel_baud serialChan serialStatus

    if {$serialChan ne ""} {
        tk_messageBox -message "Serial port already open."
        return
    }

    # Try opening the serial port
    if {[catch {set serialChan [open $sel_port r+]} err]} {
        tk_messageBox -message "Failed to open $sel_port: $err"
        return
    }

    # Correct mode string
    set modeStr "${sel_baud},n,8,1"
    if {[catch {fconfigure $serialChan -mode $modeStr \
                                       -blocking 0 \
                                       -buffering line \
                                       -encoding binary } err]} {
        tk_messageBox -message "Failed to configure serial port: $err"
        close $serialChan
        set serialChan ""
        return
    }

    # Callback to handle incoming data
    proc serialRead {chan} {
        if {[eof $chan]} {
            close $chan
            set ::serialChan ""
            tk_messageBox -message "Serial port closed."
            return
        }

        if {[gets $chan line] >= 0} {
            .console.txt configure -state normal
            .console.txt insert end "$line\n"
            .console.txt see end
            .console.txt configure -state disabled
        }
    }

    fileevent $serialChan readable [list serialRead $serialChan]

    appendConsole "Connected on $sel_port at $sel_baud baud"
    set serialStatus "Port: $sel_port ($sel_baud bps)"
}

proc clearSerialConsole {} {
    .console.txt configure -state normal
    .console.txt delete 1.0 end
    .console.txt configure -state disabled
}

# ================================================================
#       Break point
# ================================================================

proc sendBreakpoint {addr} {
    global serialChan

    if {$serialChan eq ""} {
        appendConsole "No serial connection"
        bell
        return
    }

    set addr [string trim $addr]

    # Allow 0x prefix
    if {[string match "0x*" $addr]} {
        set addr [string range $addr 2 end]
    }

    if {![regexp {^[0-9A-Fa-f]{1,4}$} $addr]} {
        appendConsole "Invalid breakpoint: $addr"
        bell
        return
    }

    # Convert to integer
    scan $addr %x value

    # Mask to 16-bit safety
    set value [expr {$value & 0xFFFF}]

    # Split into hi/lo
    set hi [expr {($value >> 8) & 0xFF}]
    set lo [expr {$value & 0xFF}]

    # Debug echo
    appendConsole [format "SENDING: %02X %02X" $hi $lo]

    # Convert hex → binary bytes (portable)
    set bin_hi [binary format H2 [format %02X $hi]]
    set bin_lo [binary format H2 [format %02X $lo]]

    if {[catch {
        puts -nonewline $serialChan $bin_hi
        puts -nonewline $serialChan $bin_lo
        flush $serialChan
    } err]} {
        appendConsole "Serial Write Error: $err"
        return
    }

appendConsole "Breakpoint set @ [format %04X $value]"

}

proc setBreakpointFromGutter {y} {
    set w .pane.left.editor
    set line [lindex [split [$w index "@0,$y"] .] 0]

    if {[info exists ::lineAddr($line)]} {
        set addr $::lineAddr($line)
        .breakbar.e delete 0 end
        .breakbar.e insert 0 [format %04X $addr]
        focus .breakbar.e
    }
}


# ============================================================
#   Jump to address
# ============================================================
proc jumpToAddress {} {
    set dlg .jumpDlg
    if {[winfo exists $dlg]} {
        raise $dlg
        return
    }

    toplevel $dlg
    wm title $dlg "Jump to Address"
    wm transient $dlg .
	centerWindow .jumpDlg .
    wm resizable $dlg 0 0

    ttk::label  $dlg.lbl -text "Hex Address (e.g. 0x278):"
    ttk::entry  $dlg.ent -width 12
    ttk::button $dlg.ok  -text "Jump" -command {
        set addr [.jumpDlg.ent get]
        destroy .jumpDlg
        performJump $addr
    }
    ttk::button $dlg.ca  -text "Cancel" -command {destroy .jumpDlg}

    grid $dlg.lbl -column 0 -row 0 -columnspan 2 -padx 10 -pady 5
    grid $dlg.ent -column 0 -row 1 -columnspan 2 -padx 10
    grid $dlg.ok  -column 0 -row 2 -padx 5 -pady 8
    grid $dlg.ca  -column 1 -row 2 -padx 5 -pady 8

    focus $dlg.ent
}

proc performJump {hexAddr} {
    set w .pane.left.editor

    # Validate hex input
    if {![regexp -nocase {^0x[0-9a-f]+$} $hexAddr]} {
        tk_messageBox -icon error -message "Invalid hex address."
        return
    }

    scan $hexAddr %x target
    set current 0x200

    set totalLines [lindex [split [$w index "end -1c"] .] 0]
    set targetLine -1

    for {set i 1} {$i <= $totalLines} {incr i} {
        set line [$w get "$i.0" "$i.end"]
        set trimmed [string trimleft $line]

        # Skip non-opcode lines
        if {$trimmed eq "" ||
            [string index $trimmed 0] eq ";" ||
            [string index $trimmed 0] eq "#"} {
            continue
        }

        # Look for a CHIP-8 opcode
        if {[regexp {\y[0-9A-Fa-f]{4}\y} $trimmed]} {
            if {$current == $target} {
                set targetLine $i
                break
            }
            incr current 2
        }
    }

    if {$targetLine < 0} {
        tk_messageBox -icon warning -message "Address not found."
        return
    }

    # Jump + highlight
    $w mark set insert "$targetLine.0"
    $w see "$targetLine.0"
    $w yview "$targetLine.0"

    $w tag remove jumpHighlight 1.0 end
    $w tag add jumpHighlight "$targetLine.0" "$targetLine.end"
    $w tag configure jumpHighlight -background "#444400"

    after 600 { $w tag remove jumpHighlight 1.0 end }
}



# ============================================================
#   Help Menu
# ===========================================================

proc showChip8Help {} {

    # Prevent duplicate windows
    if {[winfo exists .chip8help]} {
        raise .chip8help
        focus .chip8help
        return
    }

    toplevel .chip8help
    wm title .chip8help "CHIP-8 Opcode Reference"
    wm geometry .chip8help 640x700

    text .chip8help.txt \
        -wrap none \
        -font {Courier 12} \
        -bg "#1e1e1e" \
        -fg "#00FFFF" \
        -state normal

    scrollbar .chip8help.sb -command ".chip8help.txt yview"
    .chip8help.txt configure -yscrollcommand ".chip8help.sb set"

    pack .chip8help.sb -side right -fill y
    pack .chip8help.txt -side left -fill both -expand 1

    # Insert opcode reference
    .chip8help.txt insert end {
CHIP-8 OPCODE REFERENCE
======================

--- SYSTEM ---
00E0    CLS              Clear the display
00EE    RET              Return from subroutine

--- FLOW CONTROL ---
1NNN    JP addr          Jump to address NNN
2NNN    CALL addr        Call subroutine at NNN
3XNN    SE Vx, NN        Skip if Vx == NN
4XNN    SNE Vx, NN       Skip if Vx != NN
5XY0    SE Vx, Vy        Skip if Vx == Vy
9XY0    SNE Vx, Vy       Skip if Vx != Vy
BNNN    JP V0, addr      Jump to NNN + V0

--- REGISTERS ---
6XNN    LD Vx, NN        Vx = NN
7XNN    ADD Vx, NN       Vx += NN
8XY0    LD Vx, Vy
8XY1    OR Vx, Vy
8XY2    AND Vx, Vy
8XY3    XOR Vx, Vy
8XY4    ADD Vx, Vy       VF = carry
8XY5    SUB Vx, Vy       VF = NOT borrow
8XY6    SHR Vx           VF = LSB
8XY7    SUBN Vx, Vy
8XYE    SHL Vx           VF = MSB

--- MEMORY ---
ANNN    LD I, addr       I = NNN
FX1E    ADD I, Vx
FX29    LD F, Vx         Font sprite
FX33    LD B, Vx         BCD
FX55    LD [I], Vx       Store V0..Vx
FX65    LD Vx, [I]       Load V0..Vx

--- DISPLAY ---
DXYN    DRW Vx, Vy, N    Draw sprite, VF = collision

--- INPUT ---
EX9E    SKP Vx           Skip if key pressed
EXA1    SKNP Vx          Skip if key not pressed
FX0A    LD Vx, K         Wait for key

--- TIMERS ---
FX07    LD Vx, DT
FX15    LD DT, Vx
FX18    LD ST, Vx

--- RANDOM ---
CXNN    RND Vx, NN       Vx = rand & NN
}

    # Make read-only
    .chip8help.txt configure -state disabled
}

# ========================================================
#   Break Point Help
# ========================================================
proc showBreakPiontHelp {} {

    # Prevent duplicate windows
    if {[winfo exists .bphelp]} {
        raise .bp8help
        focus .bphelp
        return
    }

    toplevel .bphelp
    wm title .bphelp "Break Point Help"
    wm geometry .bphelp 480x480
	centerWindow .bphelp .

    text .bphelp.txt \
        -wrap none \
        -font {Courier 12} \
        -bg "#1e1e1e" \
        -fg "#00FFFF" \
        -state normal

    scrollbar .bphelp.sb -command ".bphelp.txt yview"
    .bphelp.txt configure -yscrollcommand ".bphelp.sb set"

    pack .bphelp.sb -side right -fill y
    pack .bphelp.txt -side left -fill both -expand 1

    .bphelp.txt insert end {

    Connect serial port.

    Upload CHIP8 program.

    Switch Sync-8 to debug.

    Press reset. The program will
    wait for break point to be set.

    Upload break point.

    The program will run until the
    program counter matchs the break
    point.

    Step through program with the step
    button.

    Program info will be displayed on
    the serial monitor.

    Switch back to run and the program
    will continue from step.

    }
    # Make read-only
    .bphelp.txt configure -state disabled

}

# =========================================================
#   About
# ========================================================
proc showAbout {} {
    set dlg .aboutDlg
    if {[winfo exists $dlg]} {
        raise $dlg
        return
    }

    toplevel $dlg
    wm title $dlg "About CHIP-8 Editor"
    wm transient $dlg .
	centerWindow .aboutDlg .
    wm resizable $dlg 0 0

    ttk::frame $dlg.f -padding 15
    pack $dlg.f -fill both -expand 1

    ttk::label $dlg.f.title \
        -text "CHIP-8 Editor" \
        -font {Helvetica 14 bold}

    ttk::label $dlg.f.ver   -text "Version: 1.0"
    ttk::label $dlg.f.auth  -text "Author: Scott Billingsley"
    ttk::label $dlg.f.date  -text "Date: 1-10-2026"
    ttk::label $dlg.f.web   -text "https://github.com/ScottBillingsley"
    ttk::separator $dlg.f.sep

    ttk::button $dlg.f.ok -text "OK" -command {destroy .aboutDlg}

    pack $dlg.f.title -pady {0 10}
    pack $dlg.f.ver   -anchor w
    pack $dlg.f.auth  -anchor w
    pack $dlg.f.date  -anchor w
    pack $dlg.f.web   -anchor w
    pack $dlg.f.sep   -fill x -pady 10
    pack $dlg.f.ok    -pady {5 0}

    focus $dlg.f.ok
    grab set $dlg
}


# ============================================================
#   Flowchart
# ============================================================
proc openFlowchartEditor {} {
    global editMode linkSource modeStatus

    # If the window exists, just bring it to the front
    if {[winfo exists .flow]} {
        raise .flow
        return
    }

    # 1. Create the freestanding popup
    toplevel .flow
    .flow configure -background "#d9d9d9"
    wm title .flow "Flowchart Designer"
    wm geometry .flow 800x600

    # 2. Local Menubar for the Popup
    set mbar [menu .flow.mbar]
    .flow configure -menu $mbar

    set helpMenu [menu $mbar.help -tearoff 0]
    $mbar add cascade -label "Help" -menu $helpMenu
    $helpMenu add command -label "Editor Shortcuts" -command {
        tk_messageBox -title "Flowchart Help" \
            -message "• Drag shapes to move\n• Shapes and text move together\n• Close window to exit"
    }

    # 3. Sidebar Palette & Canvas
    set side [ttk::frame .flow.side -padding 5]
    set c_frame [ttk::frame .flow.cframe]

    pack $side -side left -fill y
    pack $c_frame -side right -fill both -expand 1

    set can [canvas .flow.c -bg "#696762" -highlightthickness 0 -relief sunken \
             -xscrollcommand ".flow.hscroll set" \
             -yscrollcommand ".flow.vscroll set" \
             -scrollregion {0 0 3000 3000}]

    ttk::scrollbar .flow.vscroll -orient vertical   -command ".flow.c yview"
    ttk::scrollbar .flow.hscroll -orient horizontal -command ".flow.c xview"

    # 3. Grid them together using the widget names
    grid .flow.c       -in $c_frame -row 0 -column 0 -sticky nsew
    grid .flow.vscroll -in $c_frame -row 0 -column 1 -sticky ns
    grid .flow.hscroll -in $c_frame -row 1 -column 0 -columnspan 2 -sticky ew

    # 4. Make sure the canvas expands to fill the frame
    grid rowconfigure    $c_frame 0 -weight 1
    grid columnconfigure $c_frame 0 -weight 1

    # Update the 'can' variable so the rest of your script works
    set can .flow.c

    ttk::button $side.btnClear -text "Clear Canvas" -command {clearFlowchart .flow.c}
    pack $side.btnClear -pady 5 -fill x

   ttk::button $side.btn3 -text "Link Shapes" -command {
        global editMode linkSource
        set editMode "link"
        set linkSource ""
        set modeStatus "Mode: Linking..."
    }
    pack $side.btn3 -pady 5 -fill x

    ttk::label $side.status -textvariable modeStatus -style Flow.TFrame
    pack $side.status -side bottom -pady 10
    set modeStatus "Mode: Select"
    set editMode "select"
    set linkSource ""

    # 4. Palette Buttons
    ttk::button $side.btn1 -text "Add Decision" -command [list drawShape $can "diamond"]
    ttk::button $side.btn2 -text "Add Process"  -command [list drawShape $can "rect"]
    pack $side.btn1 $side.btn2 -pady 5 -fill x

    ttk::button $side.btnOval -text "Start / Stop" -command {drawShape .flow.c "oval"}
    ttk::button $side.btnCirc -text "Branch Point" -command {drawShape .flow.c "circle"}
    # Pack them in the order you prefer
    pack $side.btnOval $side.btnCirc -pady 5 -fill x

    ttk::button $side.btnDel -text "Delete Selected" -command deleteSelected
    pack $side.btnDel -pady 5 -fill x -side top

    ttk::button $side.btnSaveJ -text "Save Project (JSON)" -command {saveProjectJSON .flow.c}
    ttk::button $side.btnLoadJ -text "Load Project (JSON)" -command {loadProjectJSON .flow.c}
    ttk::button $side.btnPNG   -text "Export PNG"         -command {exportCanvasPNG .flow.c}
    pack $side.btnSaveJ $side.btnLoadJ $side.btnPNG -pady 5 -fill x

    ttk::button $side.btnZoomIn -text "Zoom In (+)" -command {canvasZoom .flow.c 1.25}
    ttk::button $side.btnZoomOut -text "Zoom Out (-)" -command {canvasZoom .flow.c 0.8}
    pack $side.btnZoomIn $side.btnZoomOut -pady 5 -fill x

    ttk::checkbutton $side.snap -text "Snap to Grid" -variable snapEnabled
    pack $side.snap -pady 10 -fill x

    # 5. Bindings for Dragging
    bind .flow <Delete> deleteSelected
    set modeStatus "Mode: Select"
    set editMode "select"
    set linkSource ""
    setupCanvasBindings $can
    drawGrid $can

    # Redraw grid if the user resizes the window
    bind $can <Configure> { drawGrid %W }

}

proc canvasZoom {can factor} {
    # 1. Scale all item coordinates relative to (0,0)
    $can scale all 0 0 $factor $factor

    foreach item [$can find all] {
        # Scale Line Widths
        set currentWidth [$can itemcget $item -width]
        if {$currentWidth > 0} {
            $can itemconfigure $item -width [expr {$currentWidth * $factor}]
        }

        # 2. Scale Fonts Safely
        if {[$can type $item] eq "text"} {
            set rawFont [$can itemcget $item -font]

            # Extract family and size even if font is a string like "Arial 12"
            if {[llength $rawFont] >= 2} {
                set family [lindex $rawFont 0]
                set size   [lindex $rawFont 1]
            } else {
                # Fallback if font is a single name
                set family $rawFont
                set size 10 ;# Default size if none found
            }

            # Calculate new size and apply
            set newSize [expr {round($size * $factor)}]
            if {$newSize == 0} {set newSize [expr {$factor > 1 ? 1 : -1}]}

            $can itemconfigure $item -font [list $family $newSize]

            # Update the text wrapping width
            set wrapWidth [$can itemcget $item -width]
            if {$wrapWidth > 0} {
                $can itemconfigure $item -width [expr {$wrapWidth * $factor}]
            }
        }
    }

    # 3. Adjust the world size and refresh the grid
    $can configure -scrollregion [$can bbox all]
    drawGrid $can
}


proc drawShape {c type} {
    global shapeCounter
    incr shapeCounter
    set myID "group$shapeCounter"
    set x 100; set y 100

    switch $type {
        "diamond" {
            $c create polygon $x [expr $y-30] [expr $x+40] $y $x [expr $y+30] [expr $x-40] $y \
                -fill "#fdfd96" -outline "black" -tags [list $myID "movable" "body"]
            set labelText "Decision"
        }
        "rect" {
            $c create rectangle [expr $x-45] [expr $y-25] [expr $x+45] [expr $y+25] \
                -fill "#add8e6" -outline "black" -tags [list $myID "movable" "body"]
            set labelText "Process"
        }
        "oval" {
            # Ellipse for Start/Stop (Terminator)
            $c create oval [expr $x-50] [expr $y-25] [expr $x+50] [expr $y+25] \
                -fill "#a1fa80" -outline "black" -tags [list $myID "movable" "body"]
            set labelText "Start/Stop"
        }
        "circle" {
            # Small circle for branching/connectors
            set r 20
            $c create oval [expr $x-$r] [expr $y-$r] [expr $x+$r] [expr $y+$r] \
                -fill "#FF6F61" -outline "black" -tags [list $myID "movable" "body"]
            set labelText "B"
        }
    }

    # Add the text label on top of the shape
    $c create text $x $y -text $labelText -fill "black" \
    -width 80 -justify center -tags [list $myID "movable" "label"]

}


proc setupCanvasBindings {c} {
    global editMode linkSource drag modeStatus

    # --- SINGLE CLICK: Select, Drag, or Start Linking ---
    bind $c <Button-1> {
        global editMode linkSource drag modeStatus
        set item [%W find withtag current]

        # 1. Identify the group (group1, group2, etc.)
        set group ""
        if {$item ne ""} {
            foreach t [%W gettags $item] {
                if {[string match "group*" $t]} { set group $t; break }
            }
        }

        # 2. Visual Reset: Revert all shape outlines to black
        # We target 'body' so we don't try to outline Text labels
        %W itemconfigure "body" -width 1 -outline black

        # 3. Handle clicking empty space
        if {$group eq ""} {
            %W dtag "selected"
            set linkSource ""
            return
        }

        # 4. Process Modes
        if {[info exists editMode] && $editMode eq "link"} {
            # LINKING MODE
            if {$linkSource eq ""} {
                set linkSource $group
                # Highlight the source body in Red
                %W itemconfigure "$group && body" -width 3 -outline red
            } elseif {$linkSource ne $group} {
                drawArrow %W $linkSource $group
                %W itemconfigure "body" -width 1 -outline black
                set linkSource ""
                set editMode "select"
                set modeStatus "Mode: Select"
            }
        } else {
            # SELECT / DRAG MODE
            %W dtag "selected"
            %W addtag "selected" withtag $group
            # Highlight the selection body in Blue
            %W itemconfigure "$group && body" -width 2 -outline blue
            set drag(x) %x
            set drag(y) %y
        }
    }

    # --- MOTION: Drag the group and update attached arrows ---
    bind $c <B1-Motion> {
        global drag editMode snapEnabled gridSize
        if {![info exists editMode] || $editMode eq "select"} {
            if {[%W find withtag "selected"] ne ""} {
                # Calculate actual mouse movement
                set rawDx [expr {%x - $drag(x)}]
                set rawDy [expr {%y - $drag(y)}]

                if {$snapEnabled} {
                    # Find the current position of the shape's center
                    set coords [%W coords "selected && label"]
                    if {$coords eq ""} { set coords [%W coords "selected"] }
                    lassign $coords curX curY

                    # Calculate the "snapped" target position
                    set targetX [expr {round(($curX + $rawDx) / $gridSize) * $gridSize}]
                    set targetY [expr {round(($curY + $rawDy) / $gridSize) * $gridSize}]

                    # The actual movement needed to hit that snap point
                    set dx [expr {$targetX - $curX}]
                    set dy [expr {$targetY - $curY}]
                } else {
                    set dx $rawDx
                    set dy $rawDy
                }

                # Only move if there is a delta (prevents jitter)
                if {$dx != 0 || $dy != 0} {
                    %W move "selected" $dx $dy
                    set drag(x) %x
                    set drag(y) %y
                    updateArrows %W "selected"
                }
            }
        }
    }

    # --- DOUBLE CLICK: Open Name Change Dialog ---
    bind $c <Double-1> {
        set item [%W find withtag current]
        if {$item eq ""} return

        # 1. Find the group and the specific label item
        set group ""
        foreach t [%W gettags $item] {
            if {[string match "group*" $t]} { set group $t; break }
            }
        set labelID [%W find withtag "$group && label"]
        set currentText [%W itemcget $labelID -text]

        # 2. Create a small popup window
        set x [winfo pointerx .]
        set y [winfo pointery .]

        toplevel .edit
        wm title .edit "Edit Text"
        wm geometry .edit "+$x+$y"
        wm transient .edit .flow ;# Keep it on top of the main window

        # 3. Use a 'text' widget instead of 'entry' for multi-line support
        text .edit.txt -width 25 -height 5 -font {Helvetica 10}
        .edit.txt insert 1.0 $currentText
        pack .edit.txt -padx 10 -pady 10 -fill both -expand 1

        # 4. Save Button
        ttk::button .edit.btn -text "Save" -command [list updateShapeText %W $labelID .edit.txt]
        pack .edit.btn -pady {0 10}

        # Focus the text box immediately
        focus .edit.txt
    }


    # Right-click to bring to front
    bind $c <Button-3> {
    set item [%W find withtag current]
    if {$item ne ""} {
        set group ""
        foreach t [%W gettags $item] {
            if {[string match "group*" $t]} { set group $t; break }
        }
            if {$group ne ""} {
                %W raise $group
                # Ensure the label stays on top of the shape body
                %W raise "$group && label"
            }
        }
    }

    # --- RELEASE: Drop the 'selected' tag ---
    bind $c <ButtonRelease-1> {
        # We don't clear the blue highlight (so Delete works),
        # but we stop the move logic
 #       %W dtag "selected"
    }

    # Highlight line when mouse is over it
    $c bind "connector" <Enter> { %W itemconfigure current -fill "#FF0000" -width 4 }
    $c bind "connector" <Leave> { %W itemconfigure current -fill "black" -width 3 }

    bind .flow <Button-4> { .flow.c yview scroll -1 units }
    bind .flow <Button-5> { .flow.c yview scroll 1 units }

}

proc updateShapeText {can labelID textWidget} {
    set newText [$textWidget get 1.0 "end - 1 chars"]
    $can itemconfigure $labelID -text $newText

    # 1. Identify the group and the body shape (rectangle, diamond, etc.)
    set group ""
    foreach t [$can gettags $labelID] {
        if {[string match "group*" $t]} { set group $t; break }
    }
    set bodyID [$can find withtag "$group && body"]

    # 2. Get the new size of the text
    lassign [$can bbox $labelID] tx1 ty1 tx2 ty2
    set tw [expr {$tx2 - $tx1}]
    set th [expr {$ty2 - $ty1}]

    # 3. Calculate center point of the text
    set cx [expr {$tx1 + ($tw / 2.0)}]
    set cy [expr {$ty1 + ($th / 2.0)}]

    # 4. Add padding (min 20px) so the text isn't touching the edges
    set pad 20
    set halfW [expr {max(45, ($tw / 2.0) + $pad)}]
    set halfH [expr {max(25, ($th / 2.0) + $pad)}]

    # 5. Redraw coordinates based on the shape type
    set type [lindex [$can gettags $bodyID] 0] ;# Assumes type is first tag or check 'diamond'

    # We check the tags to see which shape it is
    if {[$can type $bodyID] eq "polygon"} {
        # Diamond (Decision)
        $can coords $bodyID $cx [expr {$cy-$halfH}] [expr {$cx+$halfW}] $cy \
                             $cx [expr {$cy+$halfH}] [expr {$cx-$halfW}] $cy
    } elseif {[$can type $bodyID] eq "oval"} {
        # Oval or Circle
        $can coords $bodyID [expr {$cx-$halfW}] [expr {$cy-$halfH}] \
                             [expr {$cx+$halfW}] [expr {$cy+$halfH}]
    } else {
        # Rectangle (Process)
        $can coords $bodyID [expr {$cx-$halfW}] [expr {$cy-$halfH}] \
                             [expr {$cx+$halfW}] [expr {$cy+$halfH}]
    }

    # 6. Update arrows since the shape size changed
    updateArrows $can $group

    destroy [winfo parent $textWidget]
}


proc drawArrow {c src dest} {
    # Get centers of both shapes
    lassign [$c coords "$src && label"] sx sy
    lassign [$c coords "$dest && label"] dx dy

    $c create line $sx $sy $dx $dy -arrow last -width 3 -fill "black" -capstyle round -tags [list "connector" "from_$src" "to_$dest"]

    # Ensure connectors stay above the grid but below the shapes
    catch {
        $c lower "connector" "body"
        $c raise "connector" "grid"
    }

}

proc updateArrows {c movedGroup} {
    # Find the real group name (e.g., group1) because movedGroup is "selected"
    set groupName ""
    foreach t [$c gettags [lindex [$c find withtag "selected"] 0]] {
        if {[string match "group*" $t]} { set groupName $t; break }
    }

    # Update lines where this group is the source
    foreach line [$c find withtag "from_$groupName"] {
        lassign [$c coords "$groupName && label"] x1 y1
        lassign [$c coords $line] ox1 oy1 x2 y2
        $c coords $line $x1 $y1 $x2 $y2
    }
    # Update lines where this group is the target
    foreach line [$c find withtag "to_$groupName"] {
        lassign [$c coords "$groupName && label"] x2 y2
        lassign [$c coords $line] x1 y1 ox2 oy2
        $c coords $line $x1 $y1 $x2 $y2
    }
}



proc tk_inputDialog {parent title prompt default} {
    global dialog_res
    set dialog_res ""


    set d [toplevel .inputdlg]
    $d configure -background "#1e1e1e"
    wm title $d $title
    wm transient $d [winfo toplevel $parent]

    ttk::label $d.lbl -text $prompt
    ttk::entry $d.ent
    $d.ent insert 0 $default

    ttk::style configure TEntry -background "#1e1e1e" -foreground "black"

    ttk::frame $d.f
    # Use a global variable to capture the text before destroying the window
    ttk::button $d.f.ok -text "OK" -command {
        global dialog_res
        set dialog_res [.inputdlg.ent get]
        destroy .inputdlg
    }
    ttk::button $d.f.ca -text "Cancel" -command {destroy .inputdlg}

    pack $d.lbl $d.ent $d.f -padx 10 -pady 5
    pack $d.f.ok $d.f.ca -side left -padx 5

    raise $d
    tkwait visibility $d
    grab $d

    # Standard Linux positioning and focus
    focus $d.ent
    $d.ent selection range 0 end

    # Wait for the window to be destroyed before continuing
    tkwait window $d
    return $dialog_res
}

proc deleteSelected {} {
    set c .flow.c

    # 1. Find the group that is currently highlighted in blue
    set group ""
    foreach item [$c find withtag "body"] {
        if {[$c itemcget $item -outline] eq "blue"} {
            foreach t [$c gettags $item] {
                if {[string match "group*" $t]} { set group $t; break }
            }
        }
    }

    if {$group eq ""} {
        tk_messageBox -parent .flow -message "Please click a shape to select it first."
        return
    }

    # 2. Confirmation (Ensuring it stays on top of .flow)
    set ans [tk_messageBox -type yesno -title "Confirm Delete" \
             -parent .flow -icon warning \
             -message "Delete $group and all its connections?"]

    if {$ans eq "yes"} {
        $c delete "from_$group"
        $c delete "to_$group"
        $c delete $group
        puts "Deleted $group"
    }
}

proc saveProjectJSON {c} {
    set filename [tk_getSaveFile -defaultextension ".json" -parent .flow \
                  -filetypes {{"JSON Files" .json}}]
    if {$filename eq ""} return

    set shapeList {}
    set linkList {}

    # 1. Collect Shapes
    foreach item [$c find withtag "body"] {
        set tags [$c gettags $item]
        set group ""
        foreach t $tags { if {[string match "group*" $t]} {set group $t; break} }

        set type [$c type $item]
        set coords [$c coords $item]
        set color [$c itemcget $item -fill]
        set label [$c itemcget "$group && label" -text]

        #lappend shapeList [list group $group type $type coords $coords color $color text $label]
        lappend shapeList [dict create group $group type $type coords $coords color $color text $label]
    }

    # 2. Collect Links
    foreach item [$c find withtag "connector"] {
        set tags [$c gettags $item]
        set from ""; set to ""
        foreach t $tags {
            if {[string match "from_*" $t]} { set from [string range $t 5 end] }
            if {[string match "to_*" $t]}   { set to [string range $t 3 end] }
        }
        lappend linkList [list from $from to $to]
    }

    set finalData [list shapes $shapeList links $linkList]

    set fd [open $filename w]
    puts $fd $finalData
    close $fd
    tk_messageBox -message "Project Saved!" -parent .flow
}

proc loadProjectJSON {c} {
    global shapeCounter
    set filename [tk_getOpenFile -filetypes {{"JSON Files" .json}} -parent .flow]
    if {$filename eq ""} return

    set fd [open $filename r]
    set data [read $fd]
    close $fd

    $c delete all
    drawGrid $c;
    set shapeCounter 0

    # 1. Recreate Shapes
    foreach s [dict get $data shapes] {
        # dict get can now safely find these keys
        set group  [dict get $s group]
        set type   [dict get $s type]
        set coords [dict get $s coords]
        set color  [dict get $s color]
        set text   [dict get $s text]

        set idNum [string range $group 5 end]
        if {$idNum > $shapeCounter} { set shapeCounter $idNum }

        if {$type eq "polygon"} {
            $c create polygon $coords -fill $color -outline black -tags [list $group "movable" "body"]
        } elseif {$type eq "oval"} {
            # Tcl treats circles and ellipses as the same type: "oval"
            $c create oval $coords -fill $color -outline black -tags [list $group "movable" "body"]
        } else {
            $c create rectangle $coords -fill $color -outline black -tags [list $group "movable" "body"]
        }

        # Calculate center for text
        if {$type eq "rectangle"} {
            set tx [expr {([lindex $coords 0] + [lindex $coords 2]) / 2.0}]
            set ty [expr {([lindex $coords 1] + [lindex $coords 3]) / 2.0}]
        } elseif {$type eq "oval"} {
            set tx [expr {([lindex $coords 0] + [lindex $coords 2]) / 2.0}]
            set ty [expr {([lindex $coords 1] + [lindex $coords 3]) / 2.0}]
        } else {
            # Diamond center is simply the average of its points
            set tx [lindex $coords 0]; set ty [lindex $coords 3]
        }
        $c create text $tx $ty -text $text -fill black -tags [list $group "movable" "label"]
    }

    # 2. Recreate Links
    foreach l [dict get $data links] {
        drawArrow $c [dict get $l from] [dict get $l to]
    }
}


proc exportCanvasPNG {c} {
    set filename [tk_getSaveFile -defaultextension ".png" -parent .flow]
    if {$filename eq ""} return

    # 1. Generate PostScript
    $c postscript -file "temp.ps" -colormode color

    # 2. Try Ghostscript (Standard Linux) to convert PS to PNG
    # Use -r300 for high quality
    if {[catch {exec gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -sOutputFile=$filename temp.ps} err]} {
        # If Ghostscript fails, tell the user to use the .ps file
        tk_messageBox -icon warning -parent .flow \
            -message "Could not convert to PNG automatically. A high-quality PostScript file 'temp.ps' was created instead."
    } else {
        file delete "temp.ps"
        tk_messageBox -message "PNG Exported Successfully!" -parent .flow
    }
}

proc clearFlowchart {c} {
    global shapeCounter linkSource editMode modeStatus

    set ans [tk_messageBox -type yesno -title "Clear All" \
             -parent .flow -icon warning \
             -message "Are you sure you want to clear the entire diagram?"]

    if {$ans eq "yes"} {
        $c delete all

        # --- THE FIX ---
        # Redraw the grid immediately so it exists for future arrows
        drawGrid $c
        # ---------------

        set shapeCounter 0
        set linkSource ""
        set editMode "select"
        set modeStatus "Mode: Select"
    }
}


proc drawGrid {can} {
    global gridSize
    # Force Tcl to calculate window sizes before we ask for them
    update idletasks

    $can delete "grid_line"

    set region [$can cget -scrollregion]
    if {$region eq ""} { set region {0 0 1000 1000} }
    lassign $region x1 y1 x2 y2

    set spacing 20 ;# Your grid size

    # 3. Draw vertical lines across the FULL width (x2)
    for {set x $x1} {$x <= $x2} {incr x $spacing} {
        $can create line $x $y1 $x $y2 -fill "#a3a19d" -tags "grid_line"
    }

    # 4. Draw horizontal lines across the FULL height (y2)
    for {set y $y1} {$y <= $y2} {incr y $spacing} {
        $can create line $x1 $y $x2 $y -fill "#a3a19d" -tags "grid_line"
    }

    # Move grid to the back so it doesn't cover shapes
    $can lower "grid_line"

}

# ============================================================
#       Sprite editor
# ============================================================
set ::SPRITE_PARENT ""

# --- Config ---
set GRID_W 64
set GRID_H 32
set BASE_SCALE 18
set PREVIEW_SCALE 6

set SCALE $BASE_SCALE
set fullscreen 0

# --- Sprite selection ---
set sprite_w 8
set sprite_h 8
set origin_x 0
set origin_y 0

# --- State ---
array set pixels {}
set drawing_mode ""

set ::byte_columns {}

set ::BYTES_PER_ROW [expr {$::GRID_W / 8}]

proc open_sprite_editor {} {
    if {[winfo exists .sprite]} {
        raise .sprite
        return
    }

    toplevel .sprite
    wm title .sprite "Sprite Editor"

    wm transient .sprite .
    wm resizable .sprite 1 1

    set ::SPRITE_PARENT .sprite
   build_sprite_editor $::SPRITE_PARENT

#    build_sprite_editor .sprite
}

proc build_sprite_editor {parent} {
#!/usr/bin/env tclsh
package require Tk

for {set y 0} {$y < $::GRID_H} {incr y} {
    for {set x 0} {$x < $::GRID_W} {incr x} {
        set pixels($x,$y) 0
    }
}

# --- UI ---
frame $parent.top -bg "#5e636b"
pack $parent.top -side top -fill x

foreach {label w h} {
    "8x8"   8   8
    "16x16" 16  16
    "32x32" 32  32
    "64x32" 64  32
} {
    button $parent.top.b$label -text $label -command "
        set sprite_w $w
        set sprite_h $h
        update_output
        update_preview
    "
    pack $parent.top.b$label -side left -padx 4
}

button $parent.top.clear -text "Clear" -command clear_canvas
pack $parent.top.clear -side right -padx 8

frame $parent.main -bg "#5e636b"
pack $parent.main -fill both -expand 1

canvas $parent.c -bg black
pack $parent.c -side left -fill both -expand 1

frame $parent.side -bg "#5e636b"
pack $parent.side -side right -fill y

canvas $parent.preview -bg black
set ::SPRITE_PREVIEW $parent.preview
pack $parent.preview -padx 6 -pady 6

frame $parent.out -bg "#5e636b"
pack  $parent.out -side bottom -fill x

$parent configure -bg "#5e636b"

label $parent.status -text "Last Pixel: -" -bg "#5e636b"
pack $parent.status -side bottom -fill x
set ::SPRITE_STATUS $parent.status

button $parent.top.save -text "Save Grid" -command save_grid
pack $parent.top.save -side left -padx 4

button $parent.top.load -text "Load Grid" -command load_grid
pack $parent.top.load -side left -padx 4

# --- Grid ---
proc redraw_grid {} {
    global GRID_W GRID_H SCALE
    $::SPRITE_PARENT.c delete all
    $::SPRITE_PARENT.c configure \
        -width [expr {$::GRID_W * $::SCALE}] \
        -height [expr {$::GRID_H * $::SCALE}]\

    for {set y 0} {$y < $::GRID_H} {incr y} {
        for {set x 0} {$x < $::GRID_W} {incr x} {
            set id [$::SPRITE_PARENT.c create rectangle \
                [expr {$x * $::SCALE}] \
                [expr {$y * $::SCALE}] \
                [expr {($x+1) * $::SCALE}] \
                [expr {($y+1) * $::SCALE}] \
                -outline gray]
            $::SPRITE_PARENT.c addtag cell_$x,$y withtag $id
        }
    }
    redraw_pixels
}

proc redraw_pixels {} {
    global pixels GRID_W GRID_H SCALE
    for {set y 0} {$y < $::GRID_H} {incr y} {
        for {set x 0} {$x < $::GRID_W} {incr x} {
            $::SPRITE_PARENT.c itemconfigure cell_$x,$y \
                -fill [expr {$pixels($x,$y) ? "white" : "black"}]
        }
    }
}

# --- Output ---
frame $parent.columns -bg "#5e636b"
pack $parent.columns -side right -padx 4 -fill y

for {set i 0} {$i < $::BYTES_PER_ROW} {incr i} {
    frame $parent.columns.col$i -bg "#5e636b"
    pack $parent.columns.col$i -side left -padx 2

    label $parent.columns.col$i.lbl -text "B$i" -bg "#5e636b"
    pack $parent.columns.col$i.lbl

    button $parent.columns.col$i.copy \
        -text "Copy" \
        -command [list copy_column $i]
    pack $parent.columns.col$i.copy -pady 2

    text $parent.columns.col$i.text \
        -width 6 \
        -height $::GRID_H \
        -bg "#6c80a1" \
        -wrap none
    pack $parent.columns.col$i.text

    lappend ::byte_columns $parent.columns.col$i.text
}

proc update_output {} {
    global pixels sprite_w sprite_h origin_x origin_y byte_columns

    # Clear all columns
    foreach t $::byte_columns {
        $t delete 1.0 end
    }

    set bytes_per_row [expr {$sprite_w / 8}]

    for {set y 0} {$y < $sprite_h} {incr y} {
        for {set b 0} {$b < $bytes_per_row} {incr b} {
            set byte 0
            for {set i 0} {$i < 8} {incr i} {
                set x [expr {$origin_x + $b*8 + $i}]
                set yy [expr {$origin_y + $y}]
                if {$pixels($x,$yy)} {
                    set byte [expr {$byte | (1 << (7-$i))}]
                }
            }
            set txt [lindex $::byte_columns $b]
            if {$txt eq ""} continue
            $txt insert end [format "%02X\n" $byte]
        }
    }

}

proc copy_column {index} {
    set t [lindex $::byte_columns $index]
    set raw [$t get 1.0 end]

    set bytes {}
    foreach line [split $raw "\n"] {
        set line [string trim $line]
        if {$line ne ""} {
            lappend bytes $line
        }
    }

    set out ""
    for {set i 0} {$i < [llength $bytes]} {incr i 2} {
        set hi [lindex $bytes $i]
        set lo [lindex $bytes [expr {$i+1}]]
        if {$lo eq ""} { break }
        append out "${hi}${lo}\n"
    }

    clipboard clear
    clipboard append $out
}


# --- Preview ---
proc update_preview {} {
    global pixels sprite_w sprite_h origin_x origin_y PREVIEW_SCALE
    $::SPRITE_PREVIEW delete all
    $::SPRITE_PREVIEW configure \
        -bg black \
        -highlightthickness 0\
        -bd 0 \
        -relief flat \
        -width [expr {$sprite_w * $::PREVIEW_SCALE}] \
        -height [expr {$sprite_h * $::PREVIEW_SCALE}]

    for {set y 0} {$y < $sprite_h} {incr y} {
        for {set x 0} {$x < $sprite_w} {incr x} {
            if {$pixels([expr {$origin_x+$x}],[expr {$origin_y+$y}])} {
                $::SPRITE_PREVIEW create rectangle \
                    [expr {$x*$::PREVIEW_SCALE}] \
                    [expr {$y*$::PREVIEW_SCALE}] \
                    [expr {($x+1)*$::PREVIEW_SCALE}] \
                    [expr {($y+1)*$::PREVIEW_SCALE}] \
                    -fill white -outline ""
            }
        }
    }
}

# --- Clear ---
proc clear_canvas {} {
    global pixels GRID_W GRID_H
    for {set y 0} {$y < $GRID_H} {incr y} {
        for {set x 0} {$x < $GRID_W} {incr x} {
            set pixels($x,$y) 0
        }
    }
    redraw_pixels
    update_output
    update_preview
}

# --- Paint ---
proc paint_pixel {x y value } {
    global pixels
    if {$pixels($x,$y) == $value} { return }
    set pixels($x,$y) $value
    $::SPRITE_PARENT.c itemconfigure cell_$x,$y \
        -fill [expr {$value ? "white" : "black"}]
    update_output
    update_preview
    $::SPRITE_STATUS configure -text "Last Pixel: X=$x  Y=$y"

}

proc save_grid {} {
    global pixels GRID_W GRID_H

    set filename [tk_getSaveFile -defaultextension ".spr" \
        -filetypes {{"Sprite Grid" .spr} {"All Files" *}}]
    if {$filename eq ""} return

    set fh [open $filename w]
    fconfigure $fh -translation binary

    for {set y 0} {$y < $GRID_H} {incr y} {
        for {set x 0} {$x < $GRID_W} {incr x 8} {

            set byte 0
            for {set b 0} {$b < 8} {incr b} {
                if {$pixels([expr {$x+$b}],$y)} {
                    set byte [expr {$byte | (0x80 >> $b)}]
                }
            }

            puts -nonewline $fh [binary format c $byte]
        }
    }

    close $fh
}

proc load_grid {} {
    global pixels GRID_W GRID_H

    set filename [tk_getOpenFile \
        -filetypes {{"Sprite Grid" .spr} {"All Files" *}}]
    if {$filename eq ""} return

    set fh [open $filename r]
    fconfigure $fh -translation binary
    set data [read $fh]
    close $fh

    if {[string length $data] != 256} {
        tk_messageBox -message "Invalid sprite file size."
        return
    }

    set index 0
    for {set y 0} {$y < $GRID_H} {incr y} {
        for {set x 0} {$x < $GRID_W} {incr x 8} {

            binary scan $data @${index}c byte
            incr index

            for {set b 0} {$b < 8} {incr b} {
                set bit [expr {($byte >> (7-$b)) & 1}]
                set pixels([expr {$x+$b}],$y) $bit
            }
        }
    }

    redraw_pixels
    update_output
    update_preview
}


# --- Fullscreen ---
proc toggle_fullscreen {} {
    global fullscreen SCALE BASE_SCALE GRID_W GRID_H

    set fullscreen [expr {!$fullscreen}]
    wm attributes $::SPRITE_PARENT -fullscreen $fullscreen

    if {$fullscreen} {
        set sw [winfo screenwidth  $::SPRITE_PARENT]
        set sh [winfo screenheight $::SPRITE_PARENT]
        set SCALE [expr {min($sw / $GRID_W, $sh / $GRID_H)}]
    } else {
        set SCALE $BASE_SCALE
    }

    redraw_grid
}


# --- Mouse ---
bind $parent.c <Button-1> {
    set x [expr {%x / $::SCALE}]
    set y [expr {%y / $::SCALE}]
    if {$x>=0 && $y>=0 && $x<$::GRID_W && $y<$::GRID_H} {
        if {[lsearch [split %s] Shift] >= 0} {
            set ::origin_x $x
            set ::origin_y $y
            update_output
            update_preview
        } else {
            set ::drawing_mode 1
            paint_pixel $x $y 1
        }
    }
}

bind $parent.c <B1-Motion> {
    if {$::drawing_mode ne ""} {
        set x [expr {%x / $::SCALE}]
        set y [expr {%y / $::SCALE}]
        if {$x>=0 && $y>=0 && $x<$::GRID_W && $y<$::GRID_H} {
            paint_pixel $x $y 1
        }
    }
}

bind $parent.c <Button-3> {
    set ::drawing_mode 0
}

bind $parent.c <B3-Motion> {
    set x [expr {%x / $::SCALE}]
    set y [expr {%y / $::SCALE}]
    if {$x>=0 && $y>=0 && $x<$::GRID_W && $y<$::GRID_H} {
        paint_pixel $x $y 0
    }
}

bind $parent.c <Motion> {
    set gx [expr {%x / $::SCALE}]
    set gy [expr {%y / $::SCALE}]

    if {$gx >= 0 && $gy >= 0 &&
        $gx < $::GRID_W && $gy < $::GRID_H} {

        $::SPRITE_STATUS configure \
            -text "Cursor: X=$gx  Y=$gy"
    }
}


bind $parent.c <ButtonRelease-1> { set ::drawing_mode "" }
bind $parent.c <ButtonRelease-3> { set ::drawing_mode "" }

bind $parent <F11> { toggle_fullscreen }
bind $parent <Escape> {
    if {$::fullscreen} { toggle_fullscreen }
}

proc init_pixels {} {
    array unset ::pixels
    for {set y 0} {$y < $::GRID_H} {incr y} {
        for {set x 0} {$x < $::GRID_W} {incr x} {
            set ::pixels($x,$y) 0
        }
    }
}

# --- Init ---
init_pixels
redraw_grid
update_output
update_preview
wm title $parent "CHIP-8 Sprite Editor"


}

# ============================================================
# Startup
# ============================================================
updateLines
after 0 redrawGutter
focus .pane.left.editor
