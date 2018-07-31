Notes on Epsilon 9.0

This file describes changes in Epsilon 9.0 since previous beta
versions.

Highlights of Epsilon 9.0:

Internet support.
Auto ID of file types (Binary, Unix and Macintosh).
Concurrent process for Windows NT.
Create file associations for Epsilon.
Add files to an Epsilon session via DDE.
Modes for HTML, TeX.
Syntax highlighting for HTML, TeX, dired, grep, process, diff, etc.
C Mode enhancements.
Integrated EEL compiler.
New set-colors dialog.
Auto show delimiters.
DOS/OEM character set translation.
Set the font for dialogs or printing.
Case preserving replace.

See the file changes\from80 for details on the above features and
other changes since Epsilon 8.0.


Changes from 9.0 Beta 7 to 9.0 Beta 8
======= ==== === ==== = == === ==== =

The preserve-comment-indent variable is now named
reindent-c-comments.  It now applies to lines that start with /*, as
well as lines within /* */ comments, and it has some new values.  The
new variable reindent-one-line-c-comments does something similar for
lines that start with //.

Yank won't auto-indent if you provide a negative argument.
Alt-<Minus> Ctrl-Y is one way to yank without reindenting in C mode.

The select-help-files command now knows the names of more recent
Borland help files.  Epsilon's WinHelp interface now goes to the help
file's keyword list, if no text was selected.  Set the new variable
winhelp-display-contents nonzero if you want it to go to the help
file's contents page as before.

Epsilon's syntax highlighting for scripts in .html files is smarter,
especially about .asp and .asa files.  Set the new variable
html-javascript-coloring to zero if you don't want Epsilon to
syntax-highlight embedded Java scripts.

Find-file now auto-reads files that were changed on disk even when
auto-read-changed-file is zero.

Epsilon for Windows 95/NT now displays many system error messages in
text form, not numbers.

Epsilon changes the mouse cursor when over a moveable window border.
This now works in certain cases where it didn't before.

A refresh bug involving highlighted regions not being removed was
fixed.

The default value of the anon-ftp-password variable now starts with a
dash.

Running a program non-concurrently failed under NT if you used
certain replacement shells.  Some changes were made to try and fix a
screen refresh bug after running a program.

Epsilon now works around an NT bug that occurs when the path to an
executable is specified with interior quotes.

Completely repainting Epsilon's window with Ctrl-L Ctrl-L now
repaints the menu bar and other surrounding areas.

Several more routines in C mode now respect the c-look-back variable.

Typing Ctrl-S Ctrl-C Ctrl-C Ctrl-C no longer moves back through the
buffer on each Ctrl-C.

Command history didn't work with query-replace.

FTP direds now ignore the version number of VMS files, and handle
wildcard patterns better.  Files in dired are sorted
case-insensitively now even if sort-case-fold is 0.

When you reread a file via FTP, Epsilon will discard prior undo
information if it can.

When viewing Epsilon's help file, Alt-E now brings down the edit menu
instead of selecting the "Set" button.

The do_sort_region() subroutine now respects sort-case-fold.

A bug in the look_up_tree() subroutine was fixed.

Grepping for ^$ no longer hangs.

The source to Epsilon's Internet support DLL epsnet.dll is no longer
part of the standard distribution (but is available by request).

The program-keys command and any other commands that create pop-up
non-dialog windows should no longer crash Epsilon for Windows when
Epsilon's main screen is very small.

The mouse-cursor-attr and mouse-cursor-char variables are now saved
in the state file.

Minimizing is now disabled on certain pop-up dialogs like bufed.

Line regions now display correctly on horizontally scrolled windows.

Splitting a window vertically works better now with very small windows.

Returning to Epsilon by clicking on the text of a buffer that then
auto-reads its modified file from disk no longer highlights part of
the text.


Changes from 9.0 Beta 8 to 9.0 Beta 9
======= ==== === ==== = == === ==== =

TeX mode now displays "LaTeX" as its mode name when it's using LaTeX
commands, not "TeX".

TeX syntax highlighting now understands the \[ \] construct and uses
math mode.  Typing \{ in TeX mode now inserts \}.  Typing \[ or \(
acts similarly.  Typing ) or ] now runs show-matching-delimiter, as
typing } did in previous betas.  The list of TeX environments is now
case-sensitive.

Set the new variable tex-look-back to a bigger number if you want TeX
mode to more accurately syntax highlight very large paragraphs but be
slower, or a smaller number if you want recoloring to be faster but
perhaps miscolor large paragraphs.

The internal display-scroll-bar variable is no longer incorrectly
marked as a customization variable.

The key bindings shown in Epsilon's help file now reflect the mode of
the current buffer in Epsilon, not just global bindings.

The call_dll() primitive now properly reports an error when executed
in Epsilon for DOS or Epsilon for OS/2.

OS/2's process buffer now correctly provides syntax highlighting and
command history features like the other versions.

Printing in Epsilon for Windows now has slightly better error
recovery.

Menu and tool bar commands in Epsilon for Windows are now recorded in
keyboard macros, as documented.  A bug in the argument command
related to this was fixed.

Toggling a permanent scroll bar on for the DOS version caused a
mouse problem in the Windows version.

Grep now deletes its temporary buffer after an error.

A killed rectangular region now goes on the clipboard.

Dragging and dropping a file on Epsilon now respects the
default-translation-type variable.

Epsilon wasn't discarding bad FTP passwords when the case-fold
variable's default value was 0.

The view-process command was rewritten to prevent some incorrect
modifications to the process buffer.

The kill-all-buffers command didn't work right when a buffer was
unsaved and the user said to delete it.


Changes from 9.0 Beta 9 to 9.0 Beta 10
======= ==== === ==== = == === ==== ==

The EEL compiler had the wrong version number and looked at the wrong
configuration variables.

The move-to-window command went to the wrong window under certain
conditions.


Changes from 9.0 Beta 10 to Epsilon 9.0
======= ==== === ==== == == ======= ===

Sometimes clicking on a window divider to move it scrolled the window
instead.

Epsilon for DOS didn't recognize ASCII character 224 (alpha) entered
from the keyboard.

The tex-center-line command didn't insert a \centerline{} directive
in LaTeX mode.

A bug that could cause Epsilon to crash under certain rare
circumstances typically involving file associations has been fixed.

Shutting down Windows 95 while a concurrent process was running
wasn't handled right.
