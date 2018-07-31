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

// This file has commands that act on other commands.

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "kill.h"

when_aborting()
{
	mac_unsave();
	all_must_build_mode = 1;
	maybe_ding(bell_on_abort);
}

table_prompt()	/* display prompt when key bound to key table is pressed */
{
	char msg[80];

	make_prompt(msg);
	mention("%s", msg);
}

make_prompt(s)	/* put prompt in s based on key tables seen so far */
char *s;
{
	int i;

	if (has_arg)
		sprintf(s, "%d ", iter);
	else
		*s = 0;
	for (i = 0; i < table_count; i++) {
		show_char(s, table_keys[i], 1);
		strcat(s, " ");
	}
}

/* set key to next key, from macro or keyboard */
getkey()
{
	if (ungot_key != -1) {		/* check before calling */
		wait_for_key();
		return key;
	} else if (_pushed_special_key != -1) {
		key = _pushed_special_key;
		_pushed_special_key = -1;
	} else {
		if (want_auto_save && !cmd_len && !in_macro()
				&& _auto_save_counter++ > auto_save_count) {
			_auto_save_counter = 0;
			auto_save_buffers();
		}
		wait_for_key();
		if ((key_type == KT_ACCENT_SEQ || key_type == KT_ACCENT)
			&& !_now_quoting && auto_quote_allowed) {
			_pushed_special_key = key;
			key = CTRL('Q');
		}
	}
	if (!in_macro() && IS_TRUE_KEY(key)) {
		_recent_keys[_recent_place++] = key;
		_recent_place %= MAXRECENT;
	}
	if (_len_def_mac > 0 && IS_TRUE_KEY(key))
		add_key_to_macro(key);
	return key;
}

add_key_to_macro(int i)
{
	if (_len_def_mac > 0 && !recording_suspended) {
		def_text[_len_def_mac++] = i;
		if (_len_def_mac >= MAX_MACRO) {
			end_kbd_macro();
			error("Macro definition buffer full: "
				  "keyboard macro defined");
		}
	}
}

mac_unsave()	/* remove the current command from the macro being defined */
{
	if (_len_def_mac > 0 && !recording_suspended)
		_len_def_mac -= cmd_len;
}

/* define a keyboard macro */
command start_kbd_macro() on cx_tab['(']
{
	if (_len_def_mac)
		error("Already defining.");
	say("Remembering");
	_len_def_mac = 1;
	recording_suspended = 0;
	all_must_build_mode = 1;
}

command end_kbd_macro() on cx_tab[')']
{
	mac_unsave();
	if (!_len_def_mac)
		error("Not defining.");
	if (_len_def_mac > 0) {
		def_text[0] = _len_def_mac;
		name_macro("last-kbd-macro", def_text);
		say("Keyboard macro defined");
	}
	_len_def_mac = 0;
	recording_suspended = 0;
	all_must_build_mode = 1;
}

command record_kbd_macro()	// start or end a kbd macro, as appropriate
{
	if (!_len_def_mac)
		start_kbd_macro();
	else
		end_kbd_macro();
}

/* do the keyboard macro on ^xe */
command last_kbd_macro() on cx_tab['e'], reg_tab[FCTRL(4)]
{
	error("No keyboard macro.");
}

/* names the last keyboard macro defined */
command name_kbd_macro() on cx_tab[ALT('n')]
{
	char name[200], msg[200];
	int i;

	i = find_index("last-kbd-macro");
	if (!i || name_type(i) != NT_MACRO)
		error("No keyboard macro.");
	get_cmd(name, "Name", "");
	if (find_index(name)) {
		sprintf(msg, "Replace existing %s? ", name);
		if (!ask_yn("Replace with macro", msg, "Yes", "No", 1))
			return;
	}
	name_macro(name, get_macro(i));
}

command pause_macro() on reg_tab[FSHIFT(4)]
{
	if (in_macro())
		show_macro_suspend(ignore_kbd_macro = !ignore_kbd_macro,
				   "playback");
	else if (key_type == KT_MACRO || key_type == KT_EXTEND_SEL
			 || final_macro_pause)
		show_macro_suspend(final_macro_pause = !final_macro_pause,
				   "playback");
	else if (_len_def_mac)
		show_macro_suspend(recording_suspended = !recording_suspended,
				   "recording");
	else
		error("Not recording or running a macro.");
	all_must_build_mode = 1;
}

show_macro_suspend(status, op)
char *op;
{
	char binding[80];

	if (status) {
		give_binding(binding, "pause-macro");
		say("Macro %s has been suspended, %s to resume.", op, binding);
	} else
		say("Resuming macro %s.", op);
}

command abort() on reg_tab[CTRL('G')]
{
	highlight_off();
	error("Canceled.");
}

/* Indirect through command of other case */
command case_indirect()
{
	int meta = key & 0x100;
	int bot = key & 0xff;

	if (key >= 512 || !isalpha(bot))
		error("Case-indirect on illegal key.");
	else if (isupper(bot))
		key = tolower(bot) | meta;
	else
		key = toupper(bot) | meta;
	do_again();
}

set_case_indirect(table)	// set case-indirect for A-Z in keytable
short *table;
{
	int i;

	for (i = 'A'; i <= 'Z'; i++)
		table[i] = (short) case_indirect;
}

set_list_keys(table)	// set keytable for list of items, with n & p moving
short *table;
{
	set_case_indirect(table);
	table['n'] = (short) down_line;
	table['p'] = (short) up_line;
}

command alt_prefix() on reg_tab[CTRL('[')], cx_tab[CTRL('[')]
{
	char msg[40];

	if (is_gui && window_to_screen(window_handle) && key == ESC
		&& abort_key != ESC) {		// translate to abort
		key = abort_key;
		user_abort = 1;
		do_topkey();
		return;
	}
	make_prompt(msg);
	full_getkey(msg, ALTIFY_KEY);
	say("");
	do_again();
}

command ctrl_prefix() on reg_tab[CTRL('^')], cx_tab[CTRL('^')],
			reg_tab[ALT(CTRL('^'))], cx_tab[ALT(CTRL('^'))]
{
	char msg[40];

	make_prompt(msg);
	full_getkey(msg, CTRLIFY_KEY);
	say("");
	do_again();
}

make_alt(k)
{
	if (k < FKEY(1))
		k = ALT(k);	/* make it an alt key */
	else if (k < MOUSE_BGN)			/* numeric keypad */
		k = NUMALT(NUMPLAIN(k));
	return k;
}

make_ctrl(k)
{
	if (k < FKEY(1)) {
		if ((k & 0x7f) == '?')		/* convert to DEL */
			k |= 0x40;
		else
			k = CTRL(k);
	} else if (k < MOUSE_BGN)		/* numeric keypad */
		k = NUMCTRL(NUMPLAIN(k));
	return k;
}

/* iterate the next command, or give it a numeric argument */

#define MAXARG 200000000

command argument() on reg_tab[CTRL('U')], reg_tab[ALT('-')],
			reg_tab[NUMALT(GREYMINUS)]
{
	int seendigit, fixkey, newiter, first = 1, sign = 1;

	iter = 1;
	seendigit = 0;
	for (;;) {
		fixkey = key & 0xff; /* strip meta bit: use A-1, A-2, etc */
		if (IS_TRUE_KEY(key) && isdigit(fixkey)) {
			newiter = (seendigit ? (10 * iter) : 0) + fixkey-'0';
			seendigit = 1;
		} else if (IS_TRUE_KEY(key) && fixkey == '-') {
			newiter = first ? 4 : iter;
			sign = -sign;
		} else if (first || !(key & CMD_INDEX_KEY)
				    && root_keys[key] == find_index("argument")) {
			newiter = iter * 4;
			seendigit = 0;
		} else if (key != MOUSE_MOVE)
			break;
		first = 0;
		if (newiter <= MAXARG)
			iter = newiter;
		mention("Argument: %d ", iter * sign);
		getkey();
	}
	iter *= sign;
	has_arg = 1;
	say("");

	do_topkey();
	has_arg = 0;
	iter = 1;
}

when_loading()
{
	int i;

	for (i = '0'; i <= '9'; i++)
		reg_tab[ALT(i)] = (short) argument;
}

fix_key_table(ftab, fval, ttab, tval)	/* set ttab[key] to tval for any */
short *ftab, *ttab;			/* key with ftab[key] == fval */
{
	int i;

	for (i = 0; i < NUMKEYS; i++)
		if (ftab[i] == fval)
			ttab[i] = tval;
}

/* Exit without saving anything.  If it returns, user aborted, or a process
   was running. */

command exit() on cx_tab[CTRL('C')], reg_tab[WIN_EXIT],
				  reg_tab[NUMALT(FKEY(4))]
{
	iter = 0;
	if (!has_arg)
		error_if_input(0);
	if (opsys == OS_DOS && !is_gui && another_process()) {
		if (!ask_yn("Kill process", "A subprocess is running.  Kill it? ",
					"Yes", "No", 1)) {
			check_abort();
			tiled_only();
			locate_window(PROCBUF, "");
			point = size();
			say("You must kill this subprocess before exiting.");
			return;
		}
		exit_process();
	}
	if (!has_arg) {
		if (unsaved_buffers() && !bufed_ask_exit())
			return;
		save_session();
	}
	sayput("");
	while (!in_macro() && unseen_msgs())
		check_abort();
	finish_up();
	if (!is_gui) {
		term_position(0, screen_lines - 1);
		term_mode(0);
		if (restore_blinking_on_exit)
			vid_bright_back(0);
	}
	when_exiting();
	leave();
}

recursive_edit()
{
	int res;

	save_var run_by_mouse = 0;
	_recursion_level++;		/* do explicit recursion */
	all_must_build_mode = 1;	/* and display */
	res = do_recursion();
	_recursion_level--;
	all_must_build_mode = 1;
	return res;
}

command exit_level() on cx_tab[CTRL('Z')]
{
	iter = 0;
	if (!has_arg)
		error_if_input(0);
	leave_recursion(0);
}

get_command_index(pr)
char *pr;
{
	char cmd[80];

	save_var _nt_filter = BIT(NT_MACRO) | BIT(NT_COMMAND)
			      | BIT(NT_AUTOLOAD);
	prompt_comp_read(cmd, pr, nt_match, MUST_MATCH, "");
	return check_command(cmd);
}

check_command(cmd)	// return index of cmd, but give error if not runnable
char *cmd;
{
	int name_index = find_index(cmd);

	if (name_index)
		switch (name_type(name_index)) {
			case NT_MACRO: case NT_SUBR:
			case NT_COMMAND: case NT_AUTOLOAD:
			case NT_AUTOSUBR:
				return name_index;
		}
	error("There's no command named '%.50s'.",cmd);
	return 0;
}

command named_command() on reg_tab[ALT('x')], reg_tab[FKEY(2)]
{
	char msg[40];
	int index;

	if (has_arg)
		sprintf(msg, "%d Command", iter);
	else
		sprintf(msg, "Command");
	if (index = get_command_index(msg))
		do_command(index);
}

command bind_to_key() on reg_tab[FKEY(4)]
{
	char msg[80];
	int name_index;

	if (name_index = get_command_index("Bind command"))
		*ask_key("To key: ", msg) = name_index;
	rebuild_menu();
}

command unbind_key()
{
	char keyname[80];

	*ask_key("Unbind key: ", keyname) = 0;
	rebuild_menu();
}

command create_prefix_command()
{
	char keyname[80];
	short *loc;

	loc = ask_key("New prefix key: ", keyname);
	*loc = make_anon_keytable();
	set_case_indirect(index_table(*loc));
}

make_anon_keytable()
{
	char name[80];
	int i = 0;

	do {			/* find a free name for keytable */
		sprintf(name, "fake_prefix_%d", i++);
	} while (find_index(name));
	return new_table(name);
}

char _fundamental_mode_name[] = "Fundamental";

command fundamental_mode()
{
	mode_keys = buf_tab;		/* use these keys */
	major_mode = _fundamental_mode_name;
	indenter = indenter.default;
	if (!indenter)
		indenter = prev_indenter;
	auto_indent = auto_indent.default;
	strcpy(comment_start, comment_start.default);
	strcpy(comment_pattern, comment_pattern.default);
	strcpy(comment_begin, comment_begin.default);
	strcpy(comment_end, comment_end.default);
	when_displaying = 0;
	recolor_range = recolor_from_here = 0;
	drop_coloring(bufnum);
	make_mode();
}

// Get the value of a variable whose name depends on the current mode.
// The name may also refer to a function; its value will be returned.
// Sets got_bad_number to indicate there's no such variable.
// Pat is the name to look for, with its %s replaced by the mode name.

int get_mode_variable(char *pat)
{
	char name[100];
	int i;

	got_bad_number = 0;
	sprintf(name, pat, major_mode);
	i = find_index(name);
	switch (name_type(i)) {		// i has name table index of subr/var
		case NT_SUBR: case NT_COMMAND:
		case NT_AUTOSUBR: case NT_AUTOLOAD:
			return (*(int (*)())i)();
		case NT_VAR: case NT_BUFVAR:
		case NT_WINVAR: case NT_BUILTVAR:
			return get_num_var(i);
	}
	got_bad_number = 1;
	return 0;
}

load_from_path(f)	/* load .b file with given name if it's on path */
char *f;		/* (or, optionally, in current directory) */
{
	char file[FNAMELEN], *s;

	strcpy(file, f);
	strcpy(get_extension(file), byte_extension);
	if (s = lookpath(file))
		load_commands(s);
	else if (!load_fail_ok)
		error("Can't find %s", file);
}

int blist_help(), bufed_help(), dired_help();
int blist_abort(), bufed_abort(), inp_abort();

copy_help_bindings()
{
	fix_key_table(reg_tab, (short) help, blist_tab, (short) blist_help);
	fix_key_table(reg_tab, (short) help, bufed_tab, (short) bufed_help);
}

copy_abort_bindings()
{
	fix_key_table(reg_tab, (short) abort, blist_tab, (short) blist_abort);
	fix_key_table(reg_tab, (short) abort, bufed_tab, (short) bufed_abort);
	fix_key_table(reg_tab, (short) abort, menu_tab, (short) inp_abort);
	fix_key_table(reg_tab, (short) abort, view_tab, (short) inp_abort);
	fix_key_table(reg_tab, (short) abort, comp_tab, (short) inp_abort);
}

copy_bindings()
{
	copy_help_bindings();
	copy_abort_bindings();
}

/* user-definable routines can replace these */
start_up()
{
}

finish_up()
{
}

when_exiting()
{
}

zeroed TIMER idle_display_time;
int auto_show_delimiter_delay;	// time before next check (.01 sec units)

when_idle(cnt)		// called when there's nothing to do, waiting for key
{
	if (!cnt || time_done(&idle_display_time)) {
		show_idle_text();
		time_begin(&idle_display_time, 100);	// 10 times a second
	}
	if (auto_show_matching_characters && cnt == 1) {
		auto_show_delimiter_delay = 5;
		if (maybe_auto_show_delimiter() == 2)	// No match, wait .5 sec
			auto_show_delimiter_delay = 50;	 // before looking on next key.
		refresh();
	}
	if (when_idle_coloring(cnt))
		return 0;		// call us again immediately
	else if (*show_when_idle)		// Wait for .1 seconds.
		return time_remaining(&idle_display_time);
	if (cnt < 2)
		return auto_show_delimiter_delay;
	return -1;		// don't need to call us until next key
}

when_repeating()	// called when keys repeat
{
	show_idle_text();
}

show_idle_text()
{
	char text[200];
	int col;

	if (*show_when_idle && !_doing_input && !_doing_completion
	    && !cmd_len) {
		make_title(text, show_when_idle, 199);
		col = show_when_idle_column;
		if (col < 0)
			col = screen_cols + col;
		show_text(col, 0, "%s", text);
	}
}
