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

#define EELVERSION	90

#include "codes.h"

#define NORMSTRIP	(FILETYPE_AUTO)
#define DISPCHARS	"\xC4\xCD\xB3\xBA" \
			"\xDA\xC2\xBF\xC3\xC5\xB4\xC0\xC1\xD9" \
			"\xD6\xD2\xB7\xC7\xD7\xB6\xD3\xD0\xBD" \
			"\xD5\xD1\xB8\xC6\xD8\xB5\xD4\xCF\xBE" \
			"\xC9\xCB\xBB\xCC\xCE\xB9\xC8\xCA\xBC" \
			"\xBF    ^^^M-M-^x" \
			"\x1E\x1F\x04\x12" \
			"\xD8\xDB\xDC\xDD\xDE\xDF\xFB\xFC\xFD"

#define AUTOSAVENAME	"%p%b.asv"
#define SESSDEFDIR	""	/* put session in directory on path */
#define SESSROOTDIR	""	/* don't restrict tree search */
#define DEFPRINTNAME	"lpt1"	/* printer name or printing cmd */

#define SAMECOL		1	/* this_cmd code for up-line, down-line */
#define APPENDKILL	2	/* this_cmd code for killing commands */
#define C_INDENT	3	/* this_cmd code for c-indent command */
#define CMP_WINDOWS	4	/* this_cmd code for compare-windows */
/* the next group are used by complete.e, and set by same-named cmds */
#define INP_EXIT	5	/* <Enter> in completion */
#define INP_ADD		6	/* normal keys in menu */
#define INP_EDIT	7	/* ^O in view or menu (obsolete) */
#define INP_ABORT	8	/* ^G in view, menu, or completion */
#define INP_GET_EXIT	9	/* <Enter> in menu */
#define INP_SHOW_MATCHES 10	/* ? in menu or completion */
#define INP_TRY		11	/* <Space> in completion */
#define INP_DEFAULT	12	/* ^S or ^R in completion */
#define INP_SEEN	13	/* paged out of view mode */
#define INP_COMPLETE	14	/* inp-complete: complete, then maybe exit */
#define INP_GET		15	/* <Tab> in menu */
#define LAST_BOOKMARK	16	/* this_cmd code for jump-to-last-bookmark */
#define INP_RECALL	17	/* this_cmd code for picking prev response */
#define INP_GRAB_WORD	18	/* this_cmd code for grabbing word from buf */
#define INP_GRAB_LINE	19	/* this_cmd code for grabbing line from buf */
#define INP_TO_LIST		20	/* this_cmd code for switching to listbox */
#define CTR_WINDOW		21	/* this_cmd code for ^L */
#define INP_LAST_RECALL	22	/* this_cmd code: grab newest prev response */

#define NUMKEYS		704
#define NULL		((char *) 0)
#define FNAMELEN	256
#define TAGLEN		256

	/* These macros start at FKEY(1), not 0.) */
#define FSHIFT(c)	(NUMSHIFT(FKEY(c)))
#define FCTRL(c)	(NUMCTRL(FKEY(c)))
#define FALT(c)		(NUMALT(FKEY(c)))
#define FPLAIN(c)	(NUMPLAIN(FKEY(c)))


typedef int void;		/* for now, let void be synonym for int */

buffer short *mode_keys;	/* the buffer-specific key table */
buffer char *major_mode;	/* name of the current major mode */
zeroed buffer char *mode_extra;	/* other stuff to display on mode line */
user buffer short tab_size = 4;	/* distance between tab stops */
buffer char *_display_class;	/* display class table */
char *_echo_display_class;	/* display class table for echo area */
user buffer char over_mode = 0;	/* are we in overwrite mode? */
user buffer char fill_mode = 0;	/* are we in auto-fill mode? */
buffer int (*indenter)();	/* automatic indentation function */
user buffer char auto_indent = 0; /* does <Enter> do indentation? */
user buffer char indent_with_tabs = 1; /* should indenting use tab chars? */
user buffer short goal_column = -1; // up-, down-line stays in column if >= 0
user buffer int margin_right = 70;	/* right-hand margin */
user buffer char auto_fill_indents = 1;	/* does auto-fill do indenting? */
user buffer char virtual_space = 0;	// position where there are no chars?
				// if 2, even fwd- & bwd-char cmds do it
user char typing_deletes_highlight = 1;
	// do self-inserting chars delete highlighted region?
user char shift_selects = 1;	// does shift+arrow key select text?
zeroed char shift_selecting;	// the current selection started like this

zeroed window short _prev_buffer;	/* most recent buffer */
#define MAXOLDBUFS	30	/* number of previous bufs to remember */
zeroed short _prev_old_buffers[MAXOLDBUFS];	/* list of previous bufs */
zeroed short _prev_num;		/* # of remembered previous buffers */
zeroed buffer int buf_accessed;	// highest number is most recently used buf
zeroed int buf_accessed_clock;	// numbers to put in buf_accessed

window char _window_flags;	/* misc data */

user char want_auto_save = 0;	/* if 0, never do autosave */
short _auto_save_counter = 0;	/* counts cmds */
user short auto_save_count = 500; /* autosave when counter reaches this # */
user char auto_save_name[FNAMELEN] = AUTOSAVENAME;	/* autosave filename */
user char backup_name[FNAMELEN] = "%p%b.bak";
user char want_state_file_backups = 1;
user char state_file_backup_name[FNAMELEN] = "%pebackup%e";
user char ignore_file_extensions[FNAMELEN] = "|.obj|.exe|.b|.b2|.bu|";
user char warn_before_overwrite = 1;	// warn before overwriting file?
user char print_destination[FNAMELEN] = DEFPRINTNAME;
user char print_tabs = 0;	// if 0, convert tabs to spaces when printing
user char print_in_color = 1; // 0=never, 1=if it's a color printer, 2=always
user char print_color_scheme[30];	// Name of special color scheme for printing.
zeroed struct print_options print_options;   // retain page range here

#define PRHEAD_FNAME	(1)	/* display the file name */
#define PRHEAD_PAGECNT	(2)	/* display the page number and total */
#define PRHEAD_DATE		(4)	/* display the current date */
user char print_heading = (PRHEAD_FNAME | PRHEAD_PAGECNT | PRHEAD_DATE);

zeroed buffer char already_made_backup;
user buffer char want_backups = 0;	// create .bak file on each save?
user buffer char case_fold = 1;	    // should searches consider A and a equal?
user buffer char sort_case_fold = 2;	// should sorts?  2 means see case_fold
user buffer char delete_hacking_tabs = 0;
				/* should deleting change tabs to spaces? */
user buffer int undo_size = 500000;	/* max # of chars to save for undo */
buffer char *_char_class;	/* bits below for each char */
buffer char *_case_map;		/* maps A to a, a to A */
buffer char *_srch_case_map;	/* maps all chars for sorting & searching */
char _def_char_class[256];	/* default arrays for above */
char _def_case_map[256];
char _def_srch_case_map[256];

/* for get_window_info() and low_window_create() */
struct window_info {
	short left, top, right, bottom;
	short textcolor, hbordcolor, vbordcolor, titlecolor;
	short borders, other, bufnum;
	int point, dpoint;	/* primitives fill in up to & incl this line */
	int dcolumn;	/* preserve more window data */
	short prevbuf;
	short colscheme;
};

/* a screen worth of window info */
struct screen_info {
	struct window_info *wins;	/* window information structs */
	int lines, cols;	/* size of screen */
	int num;		/* # of tiled window on screen */
	int cur_window;		/* # of current window */
	int echo_line;		// line for echo area
	int avoid_top;		// # of lines at top with no tiled windows
	int avoid_bottom;	// # of lines at bottom with no tiled windows
	int permanent_menu;	// want perm menu?
} zoom_info, push_info;

zeroed char _recursion_level;	/* depth of recursive editing */

/* Searching flags for do_searching() and other search funcs. */
/* Some of these are defined in codes.h, with SEARCH_ names. */
#define FOLD		SEARCH_FOLD	/* case folding on? */
#define MODFOLD		2	/* use above bit? (if not, use case_fold buf var) */
#define REGEX		SEARCH_REGEX	/* regular expression mode? */
#define WORD		SEARCH_WORD	/* match only words? */
#define FAILING		16	/* current pattern not found? */
#define BAD			32	/* (if regex) current pattern illegal? */
#define QUERY		64	/* (if replace) ask at each match? */
#define REVERSE		SEARCH_REVERSE	/* look backwards for matches? */
#define INCR		256	/* search after each char? */
#define SONCE		512	/* search just once now */
#define UNKNOWN		1024	/* has search type been specified? */
#define REPLACE		2048	/* in replace, not just search? */
#define FILEGREP	4096	/* doing multi-file search/replace? */
#define BUFGREP		8192	/* doing multi-buffer search/replace? */
#define GREP		(FILEGREP | BUFGREP)	/* multi-anything search? */
#define SMODES		(MODFOLD | FOLD | WORD | REGEX)

/* return codes from do_searching(), or 1=found, 0=not found */
#define DSABORT		2	/* user aborted search */
#define DSBAD		3	/* illegal regular expression */
char _default_search[FNAMELEN], _default_regex_search[FNAMELEN];
char _default_replace[FNAMELEN], _default_regex_replace[FNAMELEN];
int _default_flags = FOLD;	/* 2 sets of defaults */
int _default_regex_flags = FOLD;
char _last_was_regex;		/* was last type of search a regex? */
user short fwd_search_key = -1;	/* accept these inside search too */
user short rev_search_key = -1;
user char regex_first_end = 0;	// find first match to end, or first to start?
user char regex_shortest = 0;	// find shortest possible match, or longest?
int replace_num_found;		// in last replace, # of matches found
int replace_num_changed;	// in last replace, # of matches changed
user short find_lines_visible = 8; // move dialog if we can't see this many

#define NUM_BOOKMARKS	36
spot _bookmark_spots[NUM_BOOKMARKS];
int _bookmark_slot;	/* # of last-set bookmark in ring, 0...9 */
int _last_bookmark;	/* last bookmark we jumped to */
int _bookmark_next;	/* next bookmark for repeated jump_to_last_bookmark */
int (*_blist_cmd)();		/* call this with selected bookmark */
int do_jump_to_bookmark();	/* possible values of above */
int say_set_bookmark();

keytable reg_tab, cx_tab;	/* the standard key tables */
keytable buf_tab;		/* the default buffer-specific key table */
keytable dired_tab;	/* key table for dired mode */
keytable bufed_tab;	/* key table for bufed mode */
keytable blist_tab;	/* key table for bookmark list mode */

#define MAX_MACRO	500
short def_text[MAX_MACRO];	/* keys in macro being defined */
zeroed short _len_def_mac;	/* size of macro, incl. len, or 0 if none */
zeroed char recording_suspended; // stopped recording in middle of macro?
zeroed char final_macro_pause;	// did macro end with a pause-macro?
short key_binding[30];		// ask_key() puts key info here

user char mention_delay = 0;	// time before mention() in .1 secs
user int see_delay = 100;  // time error msgs must be made visible in .01 secs
user short key_repeat_rate = 40; // make keys rpt even faster
user short new_search_delay = 250; // this long btw keys means new text in list

/* Values for preserve_session: */
#define SAVE_RESTORE_SESSION	1	/* old value for compatibility */
#define SAVE_SESSION			2
#define RESTORE_SESSION			4
user char preserve_session = SAVE_SESSION | RESTORE_SESSION;
user char session_always_restore = 1;	// restore even with cmd line files?
user char session_restore_files = 1; // 1=always, 2=only w/o cmd line files
user char session_tree_root[80] = SESSROOTDIR; // don't look in dirs outside
user char session_default_directory[80] = SESSDEFDIR;
				// put session files here by default
char *cmd_line_session_file;	// user specified from cmd line
char *explicit_session_file;	// set by write-session or read-session

#define SES_HDR		"# Epsilon session"	/* at top of file */
#define SES_DELIM	"<<SES!@!END>>"		/* follows each string */
#define SES_BNAME	"--session--"	/* saved buf may not have this name */

// Ways to default based on current buffer's directory:
#define PBD_NONE	0	/* don't do anything special */
#define PBD_TEMPCD	1	/* while prompting for a file, cd there */
#define PBD_INSERT	2	/* insert buffer's dir at prompt, strip // ala Gnu */
user char prompt_with_buffer_directory = PBD_INSERT;

// Windows common file dialog variables.
user char want_common_file_dialog = 1;	// Use if run from menu or toolbar.

zeroed void (*use_alternate_dialog)();	// call this func to create dialog
zeroed buffer char insert_newlines_in_dialog; // <Enter> doesn't exit dialog

user short beep_duration = 5;	// duration of beep in .01 seconds
user short beep_frequency = 370; // freq of beep in hertz, or 0 for system beep

user short kill_buffers = 10;		/* number of kill buffers */
user char clipboard_access = 1;		// Use MS-Windows clipboard?

int _preserve_column;	/* used to maintain the current column */
short _pushed_special_key = -1;	/* for foreign/graphic keys in dos */
zeroed char _now_quoting = 0;		/* just typed ^Q? */
user buffer char auto_quote_allowed = 1; // for graphic/international chars
#define MAXRECENT	60
short _recent_keys[MAXRECENT];
short _recent_place;
char _abort_load_on_error = 1;	/* for load-file, load-buffer */
char _errors_in_cmd_file = 0;	/* # of errors load-buffer found */
zeroed char load_fail_ok;	// give error if we can't autoload?

user char scroll_at_end = 1;	// should up- & down-line scroll if offscreen?
user char search_in_menu = 0;	/* does typing with menu up auto-search? */
user char response_tracks_list = 0; // does listbox copy its line to prompt?
user char insert_default_response = 1;	// prompts begin with default?
user short window_overlap = 2; /* #lines or -percent overlap when paging */
user char paging_centers_window = 1;	// put cursor in middle after page?
char _display_characters[75] = DISPCHARS; /* chrs to use for borders, contin */
user char mode_start[30] = " ";	/* initial part of mode line */
user char mode_end[60] = " %d%p %s";	/* final part of mode line */
user char mode_line_at_top = 0;	// want mode line at top of screen?
#define MODE_EDGE	(mode_line_at_top ? BTOP : BBOTTOM)
user short mode_line_position = TITLELEFT(2);	// put mode line at left
user char mode_line_shows_mode = 1;	// include mode inside []'s?
user char window_caption_file[128] = "Epsilon - %s";
user char window_caption[128] = "Epsilon";
user char want_window_borders = 1;	// put lines between windows?
zeroed short last_window_color_scheme;	// for borderless windows
user buffer char show_spaces = 0;	// make spaces & tabs visible
zeroed buffer char last_show_spaces;	// are spaces & tabs already visible?
char *_show_disp_class; // version of _display_class for show-spaces
char *_show_disp_chars; // version of _display_characters for show-spaces

user char show_when_idle[120];		// put text in echo area when not busy
user short show_when_idle_column = 48;	// starting at this column

user char border_left = 0;	// put border on left edge of screen?
user char border_top = 0;	// put border on top edge of screen?
user char border_right = 0;	// put border on right edge of screen?
user char border_bottom = 0;	// put border on bottom edge of screen?
user char border_inside = 1;	// put border between side-by-side windows?
user char tiled_border = ALL_BORD(BSINGLE);	// type of lines for border

zeroed short _help_on_cmd;	// if zero, give general help, else help on cur cmd
char *_show_help_on;	// but override with name if nonzero
user char preserve_filename_case;	// Don't display FILENAME as filename.
zeroed char was_quoted;	// Did the last file name typed have "" around it?
char _prev_kbd_extended;		// helps to avoid rewriting keytran
user window int display_column = 0;	// 1st col to show, or -1 to wrap
zeroed window char _highlight_control;	// want highlight in this window?
user char restore_color_on_exit = 1; // dos: set after-exiting color at start?
user char default_word[60] = "[a-zA-Z0-9_\xC0-\xD6\xD8-\xF6\xF8-\xFF]+";
user char default_oem_word[60] = "[a-zA-Z0-9_\x80-\x9A\xA0-\xA5\xE1]+";
user short default_translation_type = FILETYPE_AUTO;
user short new_buffer_translation_type = FILETYPE_MSDOS;
user buffer char *word_pattern;
user buffer char indents_separate_paragraphs = 0;
	/* otherwise, only blank lines and ^L's (form-feeds) do */
user buffer char tex_paragraphs = 0;	// exclude \ @ . lines at parag edges?

user buffer int comment_column = 40;
user buffer char comment_start[30] = ";[ \t]*";	/* pattern to find them */
user buffer char comment_begin[10] = "; ";	/* text to insert to make */
user buffer char comment_end[10] = "";		/* text to insert after */
user buffer char comment_pattern[50] = ";.*$";	/* match whole comment */

user short near_pause = 50; // delay in .01 secs when delimiter is on screen
user short far_pause = 100; // delay when it's not visible without new window
buffer int (*mode_move_level)();	/* mode-specific brace matcher */

/* the next 15 must be the first color classes, in this order */
color_class text;
color_class highlight;
color_class echo_area;
color_class mode_line;
color_class horiz_border;
color_class vert_border;
color_class popup_title;
color_class popup_border;
color_class after_exiting;
color_class debug_text;
color_class debug_highlight;
color_class default;
color_class overlap_even;
color_class overlap_odd;
color_class screen_border;

color_class viewed_text;
color_class viewed_border;
color_class viewed_link;		// make rest this color
color_class selected_link;		// make 1st one this color
color_class menu;
color_class menu_highlight;
color_class menu_bar;
color_class menu_bar_highlight;
color_class submenu;
color_class submenu_highlight;

short _our_mono_scheme;	/* name table index of scheme to use for mono mode */
short _our_color_scheme; /* name table index of scheme to use for color mode */
short _our_gui_scheme; /* name table index of scheme to use in gui version */
user int selectable_colors = 128; // # of colors selectable by set-color
user char restore_blinking_on_exit = 0;	// & disable bright backgrounds?

/* default display classes for all characters */
char _std_disp_class[256] = {
	BC, BC, BC, BC, BC, BC, BC, BC,
	BC, BTAB, BNEWLINE, BC, BC, BC, BC, BC,
	BC, BC, BC, BC, BC, BC, BC, BC,
	BC, BC, BC, BC, BC, BC, BC, BC,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, BC,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, BMC,
};

/* echo area display class */
char _echo_disp_class[256] = {
	BC, BC, BC, BC, BC, BC, BC, BC,
	BC, BC, BC, BC, BC, BC, BC, BC,
	BC, BC, BC, BC, BC, BC, BC, BC,
	BC, BC, BC, BC, BC, BC, BC, BC,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, BC,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, BMC,
};

// Cursor shapes contain the starting scan line and the ending scan line,
// expressed as a percentage of the character height.  Values close to
// 0 or 100 are absolute scan line counts, so 98 to 99 is exactly one
// scan line high.
user int normal_cursor = CURSOR_SHAPE(98, 99);	// shape of insert-mode cursor
user int overwrite_cursor = CURSOR_SHAPE(0, 99); // shape of overwrite cursor
   // use different cursor shapes in virtual space inside characters:
user int virtual_insert_cursor = CURSOR_SHAPE(93, 99);
user int virtual_overwrite_cursor = CURSOR_SHAPE(0, 5);

// Gui cursor shapes contain the height and width of the cursor,
// expressed as a percentage of the character dimensions.  Values
// close to 0 or 100 are absolute pixel counts, so a width of 98 is
// two pixels smaller than a character.  A width of exactly zero
// means use the default width.
// All measurements are from the top left corner of the character.
user int normal_gui_cursor = CURSOR_SHAPE(100, 2);	// insert-mode cursor
user int overwrite_gui_cursor = CURSOR_SHAPE(100, 100); // overwrite cursor
   // use different cursor shapes in virtual space inside characters:
user int virtual_insert_gui_cursor = CURSOR_SHAPE(50, 2);
user int virtual_overwrite_gui_cursor = CURSOR_SHAPE(50, 100);

user char want_bell = 1;		/* allow beeping at all? */
user char bell_on_abort = 0;		/* beep when ^G'ing */
user char bell_on_search = 1;		/* beep when search fails */
user char bell_on_date_warning = 1;	/* when file's changed on disk */
user char bell_on_bad_key = 1;		/* type illegal char at prompt */
user char bell_on_completion = 1;	/* no matches/multiple matches */
user char bell_on_read_error = 1;	/* can't read file */
user char bell_on_write_error = 1;	/* can't write file */
user char bell_on_autosave_error = 1;	/* autosave file can't be written */

keytable comp_tab, menu_tab, view_tab, grep_tab;
char *_view_title;		/* title for view_buffer to use */
window short *_view_prev_mode;	/* mode of buffer before viewing */
window int _view_prev_window;	/* window before viewing */
zeroed char _view_prev_input;		/* _doing_input before viewing */
zeroed char paging_retains_view;	// Can <Space> or Ctrl-V exit viewing?
short _view_left = 2;	/* space at sides of viewed popup */
short _view_top = 2;
short _view_right = 2;
short _view_bottom = 6;
short _view_border = LR_BORD(BSINGLE) + TB_BORD(BDOUBLE);
user char completion_pops_up = 1;	/* do ? when completion would ring */
zeroed char _doing_input;	/* are we doing input (2=recursed, 1=norm)? */
zeroed char _doing_completion;	/* should ?, <Space>, <Esc> do stuff? */
char _this_match[TAGLEN];	/* value returned by a matcher during completion */
buffer int (*go_to_link)();	// pass link name to this to go there
int list_matches();		/* std routine for showing all matches */
int list_recalls();		// lists user's prev responses to prompt
int *(*completion_lister)();	/* alternate to list_matches() */
char *(*list_finder)();		/* alternate finder for list_matches() */
char *only_file_extensions;	// completion only gives such files
char cmd_result;	// last completion special function
int _grab_word_loc;		// in input, grab chars from here in orig buf
int _grab_word_start;	// Already started grabbing.
char *recall_id;		// recall prompts via this key, not cmd name
#define OLDRESP	"-oldresp"
user int recall_maximum_size = 40000;	// max chars of stored old responses
user int recall_maximum_session = 40000; // max chars saved in session file

int w_left, w_top, w_right, w_bottom;	// coords for this window
window int (*mouse_handler)();	// do special mouse stuff for this win
zeroed char run_by_mouse;	// is this cmd being run via mouse menu?
zeroed char show_mouse_choices;	// put up menu of options?
zeroed window char _dragging_control; // 1 in window we're dragging text in
user buffer char mouse_goes_to_tag; // right button goes to tag in this buffer?
user char c_mode_mouse_to_tag = 1;	// set above nonzero in c buffers?
user int scroll_init_delay = 35;	/* hundredths of a second */
user int scroll_rate = 45;		/* lines per second */
char tiled_scroll_bar = 0; // want constant scroll bar on tiled wins?

user int wheel_click_lines = -1; // # of lines to scroll per click of mouse
		// wheel, 0 to scroll by pages, or -1 to use control panel setting.

	// various cursor images
MOUSE_CURSOR drag_and_drop_pointer;
MOUSE_CURSOR right_pointer;
MOUSE_CURSOR horiz_arrows;
MOUSE_CURSOR vert_arrows;
MOUSE_CURSOR move_arrows;
MOUSE_CURSOR left_pointer;

buffer char mouse_dbl_selects;	// is double-clicking like <Enter>?
char permanent_menu;		// want a permanent menu bar?
char want_gui_menu = 1;		// want a menu bar under Windows?
user char want_gui_help = 1;	// Invoke WinHelp on F1?
user char want_gui_prompts = 1;	// Use dialogs for prompting?
user char want_gui_printing = 1;	// Use Windows for printing?
user char winhelp_display_contents = 0;	// Should help show contents page?
user char alt_invokes_menu = 0;	// in Windows, does Alt key alone go to menu?
#define HELPBUF		"-help"		/* name of help buffer */

char _region_file[FNAMELEN];	/* last file inserted, or region written to */
char _docname[FNAMELEN];		/* name of doc file */

short *ask_key();		/* function to ask for key */
command normal_character();
command show_matching_delimiter();
command case_indirect();
command help();
char *temp_buf();		/* make temporary buffer */
command alt_prefix();
command ctrl_prefix();
command backward_delete_character();
command down_line();
command up_line();
command next_page();
command previous_page();
command center_window();
command scroll_up();
command scroll_down();
command beginning_of_window();
command end_of_window();
command goto_beginning();
command goto_end();
command forward_word();
command backward_word();
command forward_sentence();
command forward_level();
command backward_level();
int dired_examine_in_window();
int prev_indenter();
int do_lowercase_region();
int do_uppercase_region();
int do_capitalize_region();
int allow_mouse_switching();
int inp_recall();
int inp_grab_word();
int inp_grab_line();
int load_this_bytecode_file();
int compile_via_dll();
command edit_variables();
char *help_on_search();
command abort();
char *nt_match();
char *give_buffer_name();
char *get_var_val();
char *get_int_buf();
char *f_match();
char *f_all_match();
char *do_file_match();
char *b_match();
char *var_match();
char *tag_match();
char *variable_type_name();
char *get_cmdline();
char *default_search_string();

struct file_info {		/* returned by check_file() */
	int fsize;			/* file size in bytes */
	short year, month, day;		/* file date: 1980-2099, 1-12, 1-31 */
	short hour, minute, second;	/* 0-23, 0-59, 0-59 */
	short opsysattr;		/* opsys-dependent attribute */
	char attr;			/* epsilon standardized attribute */
	char check_type;		/* file/directory/device code */
};

buffer struct file_info file_info;	/* info when file was read */
user buffer char want_warn = 1;	/* warn about files updated on disk? */
buffer char ignoring_file_change;	// don't warn in this buffer for a while
user buffer char auto_read_changed_file = 0;
				// read a file that changed on disk w/o asking?
zeroed char _force_auto_read_changed_file; // Don't gripe if user said read.
buffer char _buf_readonly;	/* is buffer read-only? */
buffer char _read_aborted;	/* did we only read part of this buf? */
user char readonly_warning = 3;	/* 1=warn, 2=make buffer read-only, 4=bell */
zeroed buffer char force_save_as;
#define FSA_NEWFILE		1	/* buffer made by File/New command */
#define FSA_READONLY	2	/* user checked read-only box */
zeroed buffer char buffer_not_saveable;	// Telnet buffer: don't try to save.
user char new_file_mode[30] = "c-mode";	// File/New on menu runs this cmd
user char new_file_ext[30] = ".c";	// File/New on menu uses this extension

buffer char *(*file_io_converter)();	// Change char set on r/w?
zeroed char *(*new_file_io_converter)(); // Init value for new file.
// Bits for func parameter above.
#define FILE_CONVERT_READ	1
#define FILE_CONVERT_WRITE	2
#define FILE_CONVERT_ASK	4
char *oem_file_converter();	// A converter to r/w DOS/OEM files (Win only).

user char expand_wildcards = 0;	/* should "epsilon *.c" read all or dired? */
user char max_initial_windows = 3; // how many windows from epsilon a b c...?
char dired_sorts_files = 'n';	// how should dired sort the directory?
char dired_groups_dirs = 1;	// put all directories before files?

user char grep_keeps_files = 0;	/* when grep needs file, use temp? */
user char grep_empties_buffer = 0; /* should grep clear grep buffer first? */
char _last_was_grep;		/* which ran last: grep or proc? */
char _grep_files[FNAMELEN];	/* last file pattern we searched in */
buffer int _line_highlight;	/* region for highlighting current line */

struct disk_info {		/* returned by disk_space() */
	int sects_per_cluster, bytes_per_sector;
	int avail_clusters, tot_clusters;
};

struct time_info {		/* returned by time_and_day() */
	short year, month, day;			/* 1980-2099, 1-12, 1-31 */
	short hour, minute, second, hundredth;	/* 0-23, 0-59, 0-59, 0-99 */
	short day_of_week;	/* 0=Sunday .. 6=Saturday */
};

#define point_spot	get_spot(0)
#define mark_spot	get_spot(1)

#define to_begin_line()		(nl_reverse() ? point++ : 0)
#define to_end_line()		(nl_forward() ? point-- : 0)

/* macro for replacing a function */
/* The replacement function new_hello_start_up() can call the old
start_up() function as hello_start_up(), and is installed with
REPLACE_FUNC("hello", "start_up")
*/
#define REPLACE_FUNC(ext, func)					\
	when_loading() {					\
		if (!find_index(ext "_" func))			\
			replace_name(func, ext "_" func);	\
		else						\
			drop_name(func);			\
		replace_name("new_" ext "_" func, func);	\
	}

/* bits for full_getkey() */
#define ALTIFY_KEY	(1)	/* after alt-prefix */
#define CTRLIFY_KEY	(2)	/* after ctrl-prefix */

/* bits for completion's finder func */
#define STARTMATCH	(1)	/* return 1st match now */
#define LISTMATCH	(2)	/* making list of matches for display */
#define EXACTONLY	(4)	/* only exact matches, not prefix matches */
/* also FM_NO_DIRS	(0x10)	from file_match for files, not dirs */
/* or	FM_ONLY_DIRS (0x20)	/* only dirs, not files */

	/* bits for comp_read() */
#define CAUTIOUS	(1)	/* matches may not start with pattern */
#define COMP_FOLD	(2)	/* ignore case in comparison */
#define MUST_MATCH	(4)	/* don't allow non-matches... */
#define NONE_OK		(8)	/* ...but empty string is ok */
#define POP_UP_PROMPT (16) /* prompt in a pop-up window */
#define COMP_FILE	(32 | CAUTIOUS)	/* use special rules for files */
#define PASSWORD_PROMPT	(64)	/* don't echo the prompt */

user short menu_width = 35;	/* width of completion's menu of names */
user short bufed_width = 50;	/* width of bufed window */
zeroed int _nt_filter;	/* bits for name table entries to match in complete */
zeroed char show_all_variables;	// should get_var return only user vars?
zeroed char got_bad_number;	// was last numtoi() or get_number() valid?

#define BIT(x)		(1 << (x))

#define FOLDFILE	(COMP_FOLD)
#define TERMINAL	"con"

/* be compatible with the old names for things */
#define	display_class		_display_class
#define	case_map		_case_map
#define	srch_case_map		_srch_case_map
#define	char_class		_char_class
#define	display_characters	_display_characters
#define	len_def_mac		_len_def_mac
#define strchr			index		/* Understand ANSI name for it. */
