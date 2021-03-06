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

// This file has Epsilon's commands for Brief emulation.

#include "eel.h"
#include "kill.h"
#include "menu.h"

/* Brief's Home and End keys move differently when you press one
several times in a row. */

#define BRIEF_END_KEY	40
#define BRIEF_END_TWO	41
#define BRIEF_HOME_KEY	42
#define BRIEF_HOME_TWO	43

command brief_end_key()
{
	cursor_to_column = -1;
	switch (prev_cmd) {
		case BRIEF_END_TWO:	/* third press */
			point = size();
			this_cmd = BRIEF_END_TWO;
			return;
		case BRIEF_END_KEY:	/* second press */
			point = window_end;
			this_cmd = BRIEF_END_TWO;
			return;
	}
	to_end_line();
	this_cmd = BRIEF_END_KEY;
}

command brief_home_key()
{
	cursor_to_column = -1;
	switch (prev_cmd) {
		case BRIEF_HOME_TWO:	/* third press */
			point = 0;
			this_cmd = BRIEF_HOME_TWO;
			return;
		case BRIEF_HOME_KEY:	/* second press */
			point = window_start;
			this_cmd = BRIEF_HOME_TWO;
			return;
	}
	to_begin_line();
	this_cmd = BRIEF_HOME_KEY;
}

/* Bookmarks: Brief has Alt-number keys for dropping bookmarks 1-10,
 * and a command on Alt-j that prompts for which one to jump to.
 * We store the ten bookmarks as Epsilon bookmarks A through M,
 * so as not to interfere with automatically-set Epsilon bookmarks
 * 0 through 9.
 */

command brief_drop_bookmark()
{
	int b;

	b = (key < 256) ? (key & 127) : 0;	/* Alt-3 => '3' */
	if (!isdigit(b)) {
		b = get_number("Drop bookmark [1-10]: ");
		if (b < 1 || b > 10)
			return;
	} else			/* set b to 1 ... 10 */
		b = (b == '0') ? (10) : (b - '0');
	do_set_bookmark(b - 1 + 10);	/* use bookmarks A ... M */
	say("Bookmark %d dropped.", b);
}

command brief_jump_to_bookmark()
{
	int b;

	b = get_number("Jump to bookmark [1-10]: ");
	if (b < 1 || b > 10)
		return;
	do_jump_to_bookmark(b - 1 + 10);	/* use bookmarks A ... M */
}

/* Brief's region commands behave differently with no highlighted region. */

command brief_cut_region()
{
	if (!is_highlight_on())	// if no region's highlighted, use current line
		mark_line_region();
	check_modify(bufnum);
	save_spot point, mark;
	fix_region();
	if (region_type() == REGRECT)
		pick_rectangle(1, 1);
	else {
		prev_cmd = 0;
		do_save_kill(point, mark);
		this_cmd = 0;
	}
	highlight_off();
}

command brief_copy_region()
{
	if (!is_highlight_on())	// if no region's highlighted, use current line
		mark_line_region();
	save_spot point, mark;
	fix_region();
	if (region_type() == REGRECT)
		pick_rectangle(1, 0);
	else {
		prev_cmd = 0;
		do_save_only(point, mark);
		this_cmd = 0;
	}
	highlight_off();
}

command brief_delete_region()
{
	save_spot point, mark;
	switch (is_highlight_on()) {
		case REGLINE:
		case REGINCL:
		case REGNORM:
			fix_region();
			delete(point, mark);
			break;
		case REGRECT:
			delete_rectangle();
			break;
		default:
			delete_character();
			break;
	}
	highlight_off();
}

command brief_open_line()
{
	to_end_line();
	key = '\n';
	maybe_break_line();
}

/* Brief's window commands always ask for a window edge to modify. */

command brief_split_window()
{
	int dir;

	tiled_only();
	while ((dir = get_direction()) == -1) {
		say("Select side for new window (use cursor keys)");
		getkey();
		check_abort();
	}
	switch (dir) {
		case BTOP:	split_window(); window_number--; break;
		case BBOTTOM:	split_window(); break;
		case BLEFT:	split_window_vertically();
				window_number--; break;
		case BRIGHT:	split_window_vertically(); break;
	}
	say("");
}

command brief_delete_window()
{
	int dir;

	tiled_only();
	while ((dir = get_direction()) == -1) {
		say("Select window edge to delete (use cursor keys)");
		getkey();
		check_abort();
	}
	if (give_window_space(dir))
		error("Can't delete that edge.");
	say("");
}

command brief_resize_window()
{
	int side, dir, opposite;

	tiled_only();
	while ((side = get_direction()) == -1) {
		say("Select side to move (use cursor keys)");
		getkey();
		check_abort();
	}
	opposite = (side + 2) % 4;	// opposite side
	do {
		note("Use cursor keys to move that side, "
		    "press <Enter> when done");
		getkey();
		check_abort();
		if ((dir = get_direction()) != -1) {
			if (dir == side)
				alter_window_size(window_handle, dir, 1);
			else if (dir == opposite)
				alter_window_size(window_handle, dir, 0);
		}
		maybe_refresh();
	} while (!IS_ENTER_KEY(key));
	say("");
}

/* Brief only displays this info when you ask for it. */

command display_buffer_info()
{
	char mode[FNAMELEN];

	set_mode(mode);
	say("%s: %s %s     Mode: \"%s\"",
	    *filename ? "File" : "Buffer",
	    *filename ? filename : bufname, modified ? "*" : " ", mode);
}

/* These commands change key bindings and set other variables. */

command brief_keyboard()
{
	virtual_space.default = 2;	// Brief always uses virtual space
	display_column.default = 0;	// and horiz scrolling
	virtual_space = 2;		// Also set for current buffer & window
	display_column = 0;
	mark_unhighlights = 1;
	keytran[GREYPLUS] = GREYPLUS;	// Make keys distinct
	keytran[GREYMINUS] = GREYMINUS;
	keytran[GREYSTAR] = GREYSTAR;
	keytran[NUMCTRL(GREYENTER)] = NUMCTRL(GREYENTER);
	abort_key = ESC;
	show_text(-1, -1, "Loading Brief keyboard, please wait...");
	load_cmd_file_from_path("brief.kbd");
	drop_pending_says();	// don't show cmd file loading msgs
	strcpy(menu_file, "brief.mnu");
	rebuild_menu();
	say("Brief keyboard loaded.");
}

command epsilon_keyboard()
{
	virtual_space.default = 0;	// set back to factory defaults
	virtual_space = 0;		// Also set for current buffer & window
	mark_unhighlights = 0;
	keytran[GREYPLUS] = -1;
	keytran[GREYMINUS] = -1;
	keytran[GREYSTAR] = -1;
	keytran[NUMCTRL(GREYENTER)] = -1;
	abort_key = CTRL('G');
	show_text(-1, -1, "Loading Epsilon keyboard, please wait...");
	load_cmd_file_from_path("epsilon.kbd");
	drop_pending_says();	// don't show cmd file loading msgs
	strcpy(menu_file, "epsilon.mnu");
	rebuild_menu();
	say("Epsilon keyboard loaded.");
}
