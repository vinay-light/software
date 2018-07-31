/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1985, 1997 Lugaru Software Ltd.  All rights reserved.	*
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

#define MAX(a, b)	((a) > (b) ? (a) : (b))
#define MIN(a, b)	((a) > (b) ? (b) : (a))
#define ABS(a)		((a) > 0 ? (a) : -(a))

/* The following only work on "normal", extended-ASCII keys < 512. */
#define CTRL(c)		((c) & 0x19f)
#define ALT(c)		((c) | 0x100)

/* Then the 12 function keys.  This macro starts at FKEY(1), not FKEY(0). */
#define FKEY(c)		((c - 1) + 512)

/* Then the 12 separate numeric pad keys, the 9 grey keys, and 
 * the 10 cursor keys. */
#define NUMDIGIT(c)	(FKEY(12) + 1 + c)
#define NUMDOT		(NUMDIGIT(10))
#define NUMENTER	(NUMDIGIT(11))
#define GREYPLUS	(NUMENTER + 1)
#define GREYMINUS	(NUMENTER + 2)
#define GREYSTAR	(NUMENTER + 3)
#define GREYENTER	(NUMENTER + 4)
#define GREYBACK	(NUMENTER + 5)
#define GREYTAB		(NUMENTER + 6)
#define GREYESC		(NUMENTER + 7)
#define GREYSLASH	(NUMENTER + 8)
#define SPACEBAR	(NUMENTER + 9)	/* treated like GREY... */
	/* the following keys are on the separate cursor keypad */
#define KEYINSERT	(SPACEBAR + 1)
#define KEYEND		(KEYINSERT + 1)
#define KEYDOWN		(KEYINSERT + 2)
#define KEYPGDN		(KEYINSERT + 3)
#define KEYLEFT		(KEYINSERT + 4)
#define KEYRIGHT	(KEYINSERT + 5)
#define KEYHOME		(KEYINSERT + 6)
#define KEYUP		(KEYINSERT + 7)
#define KEYPGUP		(KEYINSERT + 8)
#define KEYDELETE	(KEYINSERT + 9)

/* Then come the Shift, Control, and Alt versions of
 * function keys and numeric & cursor pad keys, an additional 129 keys.
 */
#define NUMSHIFT(c)	((c) + 43)	/* to convert special keys above */
#define NUMCTRL(c)	((c) + 86)
#define NUMALT(c)	((c) + 129)
#define NUMPLAIN(c)	(((c) - FKEY(1)) % 43 + FKEY(1))

/* The mouse keys represent pressing mouse buttons or moving the mouse. */

#define MOUSE_BGN	(NUMALT(KEYDELETE) + 1)

#define MOUSE_LEFT_DN	(MOUSE_BGN + 0)
#define MOUSE_LEFT_UP	(MOUSE_BGN + 1)
#define MOUSE_RIGHT_DN	(MOUSE_BGN + 2)
#define MOUSE_RIGHT_UP	(MOUSE_BGN + 3)
#define MOUSE_CENTER_DN (MOUSE_BGN + 4)
#define MOUSE_CENTER_UP (MOUSE_BGN + 5)

#define MOUSE_MOVE		(MOUSE_BGN + 6)
#define MOUSE_DBL_LEFT	(MOUSE_BGN + 7)
#define MOUSE_DBL_RIGHT	(MOUSE_BGN + 8)
#define MOUSE_DBL_CENTER (MOUSE_BGN + 9)

/* The window keys represent various window events in the GUI version.
 */

#define WIN_MENU_SELECT	(MOUSE_BGN + 10)	/* mouse down on menu bar */
#define WIN_RESIZE		(WIN_MENU_SELECT + 1)	/* resize, maximize */
#define WIN_VERT_SCROLL	(WIN_MENU_SELECT + 2)	/* click on vert scroll bar */
#define WIN_WHEEL_KEY	(WIN_MENU_SELECT + 3)	/* rolling mouse wheel */
#define WIN_DRAG_DROP	(WIN_MENU_SELECT + 4)	/* user dropped file on us */
#define WIN_EXIT		(WIN_MENU_SELECT + 5)	/* click on main close box */
#define WIN_HELP_REQUEST (WIN_MENU_SELECT + 6)	/* clicked on a WinHelp button */
#define WIN_BUTTON		(WIN_MENU_SELECT + 7)	/* clicked on an untranslated button */

#define GETFOCUS		(WIN_MENU_SELECT + 8)	/* window/screen got focus */
#define LOSEFOCUS		(GETFOCUS + 1)			/* window/screen lost focus */

#define EXTEND_SEL_KEY	(8192)	/* arrow key plus <Shift>, in kbd macro */
#define CMD_INDEX_KEY	(16384)	/* key codes to run cmd via index start here */

/* Classify key codes */

#define IS_WIN_KEY(k)	((k) >= WIN_MENU_SELECT)
#define IS_MOUSE_KEY(k) ((k) >= MOUSE_BGN && (k) < WIN_MENU_SELECT)
#define IS_TRUE_KEY(k)	((k) < MOUSE_BGN)

#define IS_MOUSE_LEFT(k) ((k) == MOUSE_LEFT_DN || (k) == MOUSE_DBL_LEFT)
#define IS_MOUSE_RIGHT(k) ((k) == MOUSE_RIGHT_DN || (k) == MOUSE_DBL_RIGHT)
#define IS_MOUSE_CENTER(k) ((k) == MOUSE_CENTER_DN || (k) == MOUSE_DBL_CENTER)

#define IS_MOUSE_SINGLE(k)  ((k) == MOUSE_LEFT_DN || (k) == MOUSE_RIGHT_DN \
				|| (k) == MOUSE_CENTER_DN)
#define IS_MOUSE_DOUBLE(k)  ((k) == MOUSE_DBL_LEFT || (k) == MOUSE_DBL_RIGHT \
				|| (k) == MOUSE_DBL_CENTER)
#define IS_MOUSE_DOWN(k)  (IS_MOUSE_SINGLE(k) || IS_MOUSE_DOUBLE(k))
#define IS_MOUSE_UP(k)	  ((k) == MOUSE_LEFT_UP || (k) == MOUSE_RIGHT_UP \
				|| (k) == MOUSE_CENTER_UP)

#define IS_SHIFT_KEY(k)	((k) >= NUMSHIFT(FKEY(1)) \
			&& (k) <= NUMSHIFT(KEYDELETE))
#define IS_CTRL_KEY(k)	(((k) < 512) ? !((k) & ~0x11f) : ((k) >= \
			NUMCTRL(FKEY(1)) && (k) <= NUMCTRL(KEYDELETE)))
#define IS_ALT_KEY(k)	(((k) >= 256 && (k) < 512) || ((k) >= NUMALT(FKEY(1)) \
			&& (k) <= NUMALT(KEYDELETE)))

/* Codes for use with mouse_mask */

#define MASK_MOVE	0x01
#define MASK_LEFT_DN	0x02
#define MASK_LEFT_UP	0x04
#define MASK_RIGHT_DN	0x08
#define MASK_RIGHT_UP	0x10
#define MASK_CENTER_DN	0x20
#define MASK_CENTER_UP	0x40
#define MASK_ALL	0x7f
#define MASK_BUTTONS	(MASK_ALL - MASK_MOVE)
#define MASK_DN		(MASK_LEFT_DN | MASK_RIGHT_DN | MASK_CENTER_DN)
#define MASK_UP		(MASK_LEFT_UP | MASK_RIGHT_UP | MASK_CENTER_UP)

/* Codes for mouse_shift and shift_pressed() */
#define KB_ALT_DN	0x08	/* Some Alt key */
#define KB_CTRL_DN	0x04	/* Some Ctrl key */
#define KB_LSHIFT_DN	0x02	/* Left shift key */
#define KB_RSHIFT_DN	0x01	/* Right shift key */
#define KB_SHIFT_DN	(KB_LSHIFT_DN | KB_RSHIFT_DN)	/* Either */

/* codes for key_type */
#define KT_NORMAL		(1)				/* an ordinary key */
#define KT_ACCENT		(2)				/* accented int'l key */
#define KT_ACCENT_SEQ	(3)				/* accented, multiple keystrokes */
#define KT_NONASCII		(4)				/* function, cursor key */
#define KT_NONASCII_EXT	(5)				/* ... that's not on 84-key kbd */
#define KT_KEYTRAN		(6)				/* generated by direct translation */
#define KT_MACRO		(9)				/* from keyboard macro */
#define KT_EXTEND_SEL	(10)			/* in kbd macro, shift+cursor key */

#define HELPKEY		(ALT('?'))
#define BACKTAB		(NUMSHIFT(GREYTAB))
#define DEL			(0x7f)
#define BELL		(CTRL('G'))
#define ESC			(CTRL('['))
#define IS_ENTER_KEY(k)	((k) == '\n' || (k) == '\r' || (k) == GREYENTER)

#define C_LOWER		(1)
#define C_UPPER		(2)
#define C_ALPHA		(C_LOWER | C_UPPER)

/* codes for entries in the name table */
#define NT_COMMAND	1	/* normal bytecode function */
#define NT_SUBR		2	/* hidden bytecode function */
#define NT_MACRO	3	/* keyboard macro */
#define NT_TABLE	4	/* key table */
#define NT_VAR		5	/* normal variable */
#define NT_BUFVAR	6	/* buffer-specific variable */
#define NT_WINVAR	7	/* window-specific variable */
#define NT_COLSCHEME	8	/* color scheme */
#define NT_BUILTVAR	9	/* built-in variable */
#define NT_AUTOLOAD	10	/* automatically load cmd from file */
#define NT_AUTOSUBR	11	/* automatically load subr from file */

/* codes returned by vartype() */
#define TYPE_CHAR	1
#define TYPE_SHORT	2		/* a 16-bit integer */
#define TYPE_INT	3		/* a 32-bit integer */
#define TYPE_CARRAY	4		/* character array */
#define TYPE_CPTR	5		/* character pointer */
#define TYPE_POINTER	6		/* contains pointers or spots */
#define TYPE_OTHER	7		/* none of the above */

#define KEYTRANPASS	1000		/* flag for keytran */

/* display class codes */
#define BNORMAL		0
#define BTAB		1
#define BNEWLINE	2
#define BC		3	/* show as ^A */
#define BM		4	/* show as M-A */
#define BMC		5	/* show as M-^A */
#define BHEX		6	/* show as x6F */

/* region types for add_region() */
#define REGNORM		1	/* mark chars between buffer positions */
#define REGRECT		2	/* mark columns in range */
#define REGLINE		3	/* mark entire lines in range */
#define REGINCL		4	/* like REGNORM, plus extra char at end */

/* codes for modify_region() */
#define MRSTART		0	/* start of region */
#define MREND		1	/* end of region */
#define MRCOLOR		2	/* color class of region */
#define MRTYPE		3	/* type of region (REGNORM, etc. above) */
#define MRCONTROL	4	/* index of controlling variable */

/* by default, tiled windows have a mode line and popup do not */
/* these _window_flags codes can alter that */
#define FORCE_MODE_LINE	1	/* give popups a mode line */
#define NO_MODE_LINE	2	/* remove mode line from tiled */
#define WANT_MODE_LINE	4	/* prepare_win to build_mode: do mode line? */
#define FIXED_BORDERS	8	/* never alter borders */
/* The following _window_flags codes are for gui versions. */
#define HIGHLIGHT_LINE	16	/* highlight current line when active */

/* for is_window() */
#define ISTILED		1
#define ISPOPUP		2

/* flags for permit_window_keys */
#define PERMIT_SCROLL_KEY	1
#define PERMIT_RESIZE_KEY	2
#define PERMIT_WHEEL_KEY	4

/* _doing_input values */
#define DI_SEARCH	1	/* in incremental (or other) search */
#define DI_LINEINPUT	2	/* getting line of input (completion) */
#define DI_VIEW		3	/* in call to view_buf() */
#define DI_VIEWLAST	4	/* top-level viewing, not in call */
#define DI_LISTBOX	5	/* in listbox copying to another window */

/* display characters */
#define NUMLINECHARS	4	/* line-drawing chars */
#define NUMCORNERCHARS	36	/* corners for line-drawing */
#define NUMTEXTCHARS	14	/* continuation mark, tabs, etc. */
#define NUMSCROLLCHARS	4	/* scroll bar chars */
#define NUMMOUSECHARS	9	/* dos mouse chars */
#define SCROLLCHARSTART	(NUMLINECHARS + NUMCORNERCHARS + NUMTEXTCHARS)
#define NUMDISPCHARS	(SCROLLCHARSTART + NUMSCROLLCHARS + NUMMOUSECHARS)

/* for window_edge(), window_split() */
#define HORIZONTAL	(0)
#define VERTICAL	(1)
#define TOPLEFT		(0)
#define BOTTOMRIGHT	(1)

/* macros for defining a window's borders */
#define BLEFT	0
#define BTOP	1
#define BRIGHT	2
#define BBOTTOM	3
#define BNONE	0
#define BBLANK	1
#define BSINGLE	2
#define BDOUBLE	3
#define BORD(side, val)		(((val) & 3) << ((side) * 2))
	/* BORD(BTOP, BSINGLE) puts single line on top */
#define GET_BORD(side, bord)	(((bord) >> ((side) * 2)) & 3)
	/* GET_BORD() take border code, gives border type on one side */
#define LR_BORD(val)	(BORD(BLEFT, (val)) + BORD(BRIGHT, (val)))
#define TB_BORD(val)	(BORD(BTOP, (val)) + BORD(BBOTTOM, (val)))
#define ALL_BORD(val)	(LR_BORD(val) + TB_BORD(val))

/* for window_title() */
#define TITLELEFT(n)	(1 + (n))	/* put n chars from left edge */
#define TITLECENTER	(0)		/* center in window */
#define TITLERIGHT(n)	(-(1 + (n)))	/* put n chars from right edge */

/* use BLEFT...BBOTTOM & these with get_wattrib() & set_wattrib() */
#define PBORDERS	4	/* border code for window */
#define PHORIZBORDCOLOR	5	/* color of horizontal border */
#define PVERTBORDCOLOR	6	/* color of vertical border */
#define PTEXTCOLOR	7	/* color of text in window */
#define PTITLECOLOR	8	/* color of window title */

#define MAKE_RGB(rd,grn,bl)	((rd) + ((grn) << 8) + ((bl) << 16))
#define GETRED(rgb)		((rgb) & 0xff)
#define GETGREEN(rgb)		(((rgb) >> 8) & 0xff)
#define GETBLUE(rgb)		(((rgb) >> 16) & 0xff)

/* The export-colors command scans the following definitions.  It
expects that all color names will use the format below, that the
first will be named "black", and that ctransparent will follow the
last color name. */

#define black		MAKE_RGB(0, 0, 0)
#define dark_red	MAKE_RGB(128, 0, 0)
#define dark_green	MAKE_RGB(0, 128, 0)
#define brown		MAKE_RGB(128, 128, 0)
#define dark_blue	MAKE_RGB(0, 0, 128)
#define dark_magenta	MAKE_RGB(128, 0, 128)
#define dark_cyan	MAKE_RGB(0, 128, 128)
#define light_grey	MAKE_RGB(192, 192, 192)
#define money_green	MAKE_RGB(192, 220, 192)
#define sky_blue	MAKE_RGB(166, 202, 240)
#define cream		MAKE_RGB(255, 251, 240)
#define medium_red	MAKE_RGB(192, 0, 0)
#define medium_blue	MAKE_RGB(0, 0, 192)
#define grey		MAKE_RGB(160, 160, 164)
#define dark_grey	MAKE_RGB(128, 128, 128)
#define red			MAKE_RGB(255, 0, 0)
#define green		MAKE_RGB(0, 255, 0)
#define yellow		MAKE_RGB(255, 255, 0)
#define blue		MAKE_RGB(0, 0, 255)
#define magenta		MAKE_RGB(255, 0, 255)
#define cyan		MAKE_RGB(0, 255, 255)
#define light_red	MAKE_RGB(255, 192, 192)
#define light_green	MAKE_RGB(192, 255, 192)
#define light_blue	MAKE_RGB(192, 192, 255)
#define white		MAKE_RGB(255, 255, 255)
#define ctransparent	(0x1000000L)

/* DOS & OS/2 text cursor is defined using this. */
#define CURSOR_SHAPE(top, bot)	((top) * 1000 + (bot))

/* Values for stock_cursor member of MOUSE_CURSOR structure. */
#define CURSOR_ARROW	1				/* Standard arrow */
#define CURSOR_IBEAM	2				/* Text i-beam */
#define CURSOR_WAIT		3				/* Hourglass */
#define CURSOR_CROSS	4				/* Crosshair */
#define CURSOR_UPARROW	5				/* Arrow pointing up */
#define CURSOR_SIZE		6				/* Resize icon (NT only) */
#define CURSOR_ICON		7				/* Empty icon (NT only) */
										/* Double-headed arrows pointing: */
#define CURSOR_SIZENWSE	8				/*   ...northwest and southeast */
#define CURSOR_SIZENESW	9				/*   ...northeast and southwest */
#define CURSOR_SIZEWE	10				/*   ...east and west */
#define CURSOR_SIZENS	11				/*   ...north and south */
#define CURSOR_PAN		12				/* neutral cursor for panning */
#define CURSOR_PAN_UP	13				/* panning up */
#define CURSOR_PAN_DOWN	14				/* panning down */

/* Possible fonts for windows_set_font() */
#define FNT_SCREEN		0
#define FNT_PRINTER		1
#define FNT_DIALOG		2

/* Searching flags for find dialog and many other places. */
/* A subset of the flags defined in eel.h. */
#define SEARCH_FOLD			1	/* case folding on? */
#define SEARCH_WORD			8	/* match only words? */
#define SEARCH_REGEX		4	/* regular expression mode? */
#define SEARCH_REVERSE		128	/* look backwards for matches? */


/* flags for regular expression searching */
#define RE_COMPAT	1	/* ignore other flags except RE_REVERSE */
#define RE_REVERSE	2	/* search backwards */
#define RE_FORWARD	0	/* (for consistency) */
#define RE_FIRST_END	4	/* find match that ends first */
#define RE_SHORTEST	8	/* find shortest possible match */
#define RE_FASTEST	(RE_FIRST_END | RE_SHORTEST)

/* values for abort_searching, etc.: what to do when user aborts */
#define ABORT_IGNORE	0	/* ignore abort key & continue */
#define ABORT_JUMP	-1	/* jump via check_abort() */
#define ABORT_ERROR	-2	/* return error code */

/* undo_op() return codes: these bits indicate what was done */
#define UNDO_MAINLOOP	1	/* got to the end of a cmd */
#define UNDO_REDISP	2	/* displayed the buffer */
#define UNDO_MOVE	4	/* moved to a new position */
#define UNDO_INSERT	8	/* originally, we inserted chars */
#define UNDO_DELETE	16
#define UNDO_REPLACE	32
#define UNDO_END	64	/* hit the end of the undo/redo buffer */
#define UNDO_FLAG	128	/* user-defined undo code encountered */
#define UNDO_CHANGES	(UNDO_INSERT | UNDO_DELETE | UNDO_REPLACE)

/* bit codes for attr in file_info */
#define ATTR_READONLY	1
#define ATTR_DIRECTORY	2

/* return codes for check_file() */
#define CHECK_FILE	1
#define CHECK_DIR	2
#define CHECK_PATTERN	3
#define CHECK_DEVICE	4
#define CHECK_PIPE	5
#define CHECK_OTHER	6

/* Possible file system case rules from filename_rules(): */
#define FSYS_CASE_IGNORED	0		/* like DOS */
#define FSYS_CASE_PRESERVED	1		/* like NTFS or VFAT */
#define FSYS_CASE_SENSITIVE	2		/* like Unix */
#define FSYS_CASE_UNKNOWN	3		/* call failed, assume like DOS */
#define FSYS_CASE_MASK		7		/* extract case bits */
#define FSYS_SHORT_NAMES	8		/* supports 8+3 only */

/* File type codes for line translation (translation_type variable) */
#define FILETYPE_BINARY 0
#define FILETYPE_MSDOS  1
#define FILETYPE_UNIX   2
#define FILETYPE_MAC    3
#define FILETYPE_AUTO   5


/* condition codes for delay() */
#define COND_KEY	(1)
#define COND_PROC	(2)

/* codes for file_match() */
#define FM_PREFIX	(1)	/* start prefix matches: *x means contains x */
#define FM_EXACT	(2)	/* start exact matches: *x means ends in x */
#define FM_NO_DIRS	(0x10)	/* only files, not dirs */
#define FM_ONLY_DIRS (0x20)	/* only dirs, not files */

/* possible values in directory_flags */
#define DIR_CWD_RESTORE	1	/* restore current dir from session file? */
#define DIR_CWD_EXCLUDE	2	/* ignored (was: exclude cur dir from epspath?) */
#define DIR_NO_EXE_DIR	4	/* don't look in executable's dir */
#define DIR_NO_EXE_PARENT 8	/* or in executable's parent dir */
#define DIR_CWD_FROM_FILE 16 /* get cur dir from 1st cmd line file */

/* our special file i/o error codes */
#define EDISKFULL	-1	/* couldn't write because disk was full */
#define ETEXTLOST	-2	/* couldn't write due to internal err */
#define ESTATEFILE	-3	/* state file was too big to read in again */
#define EREADABORT	-4	/* file read was aborted */
#define EWRITEABORT	-5	/* file write was aborted */
#define ENOMEMORY	-6	/* file read ran out of memory */
#define EBADSTATE	-7	/* state file inconsistent / truncated */
#define ETOOBIG		-8	/* text is too big to transfer right now */
#define ECLIPFAIL	-9	/* clipboard transfer failed */
#define ENOTEXT		-10	/* no text is on the clipboard */
#define ENOCLIP		-11 /* clipboard functions not supported */

/* opsys codes */
#define OS_DOS	1
#define OS_OS2	2
#define OS_UNIX	3

/* Codes for is_gui variable.  Zero means this isn't the Windows version. */
#define IS_WIN32S	1	/* (not supported) */
#define IS_NT		2
#define IS_WIN95	3
#define IS_WIN31	4	/* 16-bit version always says this */

/* textual clipboard formats */
#define CF_DEFAULT	0
#define CF_TEXT		1
#define CF_OEMTEXT	7

/* Epsilon supports these Common File Dialog flags. */
#define OFN_READONLY                 0x00000001
#define OFN_OVERWRITEPROMPT          0x00000002
#define OFN_HIDEREADONLY             0x00000004
#define OFN_NOCHANGEDIR              0x00000008
#define OFN_SHOWHELP                 0x00000010
#define OFN_NOVALIDATE               0x00000100
#define OFN_ALLOWMULTISELECT         0x00000200
#define OFN_PATHMUSTEXIST            0x00000800
#define OFN_FILEMUSTEXIST            0x00001000
#define OFN_CREATEPROMPT             0x00002000
#define OFN_SHAREAWARE               0x00004000
#define OFN_NOREADONLYRETURN         0x00008000
#define OFN_NOTESTFILECREATE         0x00010000

/* Epsilon supports these printer flags. */
#define PD_SELECTION                 0x00000001
#define PD_PAGENUMS                  0x00000002
#define PD_PRINTSETUP                0x00000040

/* Pass these values to winexec: */
#define SW_HIDE		    0
#define SW_SHOWNORMAL	    1
#define SW_SHOWMINIMIZED    2
#define SW_SHOWMAXIMIZED    3
#define SW_SHOWNOACTIVATE   4
#define SW_SHOW		    5
#define SW_MINIMIZE	    6
#define SW_SHOWMINNOACTIVE  7
#define SW_SHOWNA	    8
#define SW_RESTORE          9

/* Ftp operation codes */
#define FTP_RECV	0
#define FTP_SEND	1
#define FTP_LIST	2
#define FTP_MISC	3
#define FTP_OP_MASK	0xf		/* Extract one of above codes. */
#define FTP_WAIT	0x10	/* Don't return until op finishes. */
#define FTP_ASCII	0x20	/* Don't use Binary xfer -- only for VMS. */
#define FTP_USE_CWD	0x40	/* Use slow directory method needed for VMS. */

/* Flags for http_retrieve() */
#define HTTP_RETRIEVE_WAIT			1	/* Don't return until completed. */
#define HTTP_RETRIEVE_ONLY_HEADER	2	/* Only get header, not body. */

/* Activity codes for when_net_activity(). */
#define NET_RECV		1	/* just inserted text betw from & to in main buf */
#define NET_SEND		2	/* sending text in region (telnet: & deleting) */
#define NET_DONE		3	/* called with main buffer when task ends */
#define NET_LOG_WRITE	4	/* just inserted text betw from & to in ftp log */
#define NET_LOG_DONE	5	/* ftp job done, called with log buffer */

/* Activity codes for process_input() and when_process_input(). */

#define PROCESS_INPUT_LINE	1
#define PROCESS_INPUT_CHAR	2
