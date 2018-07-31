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

// This file has commands for running other programs.

#include "eel.h"
#include "proc.h"
#include "colcode.h"

/* Process commands. */

no_running()			/* make sure no process is running */
{
	if (!another_process())
		return 0;
	say("A process is already running.");
	if (strcmp(bufname, PROCBUF)) {
		tiled_only();
		locate_window(PROCBUF, "");
		maybe_refresh();
	}
	point = size();
	return 1;
}

char *get_cmdline(msg, buf)	/* prompt for & return cmd */
char *msg, *buf;		/* if !has_arg, prepare cmd in buf */
{				/* but don't return it */
	if (has_arg) {
		get_strdef(buf, msg, push_cmd);
		strcpy(push_cmd, buf);
		iter = 1;
	}
	build_filename(buf, push_cmd, filename);
	return has_arg ? buf : "";
}

command push() on cx_tab[CTRL('E')]
{
	char cmd[FNAMELEN];

	_last_was_grep = 0;
	do_push(get_cmdline("Push With Command", cmd), capture_output, 1);
}

do_push(cmdline, cap, show)
char *cmdline;	// cap nonzero means capture output, show means show it to user
{		// but show -1 means don't wait for keystroke
	char *s, dir[FNAMELEN], old[FNAMELEN];
	int result, tbuf;

	if (!another_process())
		save_var restart_concurrent = 0;
	if (opsys == OS_DOS && !is_gui)
		try_exit_concurrent();
	iter = 1;
	before_push();
	if (start_process_in_buffer_directory) {
		getcd(old);
		get_buffer_directory(dir);
		chdir(dir);
	}
	result = shell("", cmdline, cap ? bufnum_to_name(tbuf = tmp_buf())
					: "");
	if (start_process_in_buffer_directory == 2)
		chdir(old);
	if (cap) {
		process_captured(tbuf, cmdline);
		buf_delete(tbuf);
	} else if (cmdline[0] && show != -1 && !is_gui) {
		if (!char_avail()) {
			s = "Press any key to return to Epsilon";
			term_write(0, screen_lines - 1, s, strlen(s),
				color_class after_exiting, 1);
			term_position(strlen(s), screen_lines - 1);
		}
		getkey();
	}
	after_push();
	if (cmdline[0] && cap && show) {
		locate_window(PROCBUF, "");
		point = size();
	}
	if (result == -1 && errno) {
		file_error(errno, "During exec", "Couldn't exec");
		quick_abort();
	}
	maybe_restart_concurrent();
	if (cmdline[0] && result)
		say("Process returned %d", result);
	else
		check_dates(0);
	return result;
}

before_push()
{
	if (is_gui)
		return;
	save_screen(&push_info);
	sayput("");
	while (!in_macro() && unseen_msgs())
		check_abort();
	term_position(0, screen_lines - 1);
	term_mode(0);
}

after_push()
{
	if (is_gui)
		return;
	build_first = 1;
	screen_messed();
	if (term_mode(1))
		restore_screen(&push_info);
	say("");
}

process_captured(b, cmdline)	/* move captured output to process buffer */
char *cmdline;
{
	save_var bufnum;
	create(PROCBUF);
	bufname = PROCBUF;
	if (clear_process_buffer)
		zap(PROCBUF);
	point = another_process() ? type_point : size();
	set_error_spot();
	_had_errors = 0;
	if (point > 0 && character(point - 1) != '\n')
		insert('\n');
	if (cmdline[0])
		bprintf("%s\n", cmdline);
	grab_buffer(b);
	if (point > type_point)
		type_point = point;
}


command start_process() on cx_tab[CTRL('M')]
{
	char cmd[FNAMELEN], *cmdline;

	_last_was_grep = 0;
	tiled_only();
	if (no_running())
		return;
	error_if_input(1);
	cmdline = get_cmdline("Start Process With Command", cmd);
	create_concur(cmdline);
	iter = 1;
	locate_window(PROCBUF, "");
	point = size();
	process_mode();
}

create_concur(cmdline)
char *cmdline;
{
	char dir[FNAMELEN], old[FNAMELEN];
	int err;

	create(PROCBUF);
	if (clear_process_buffer)
		zap(PROCBUF);
	bufname = PROCBUF;
	point = size();
	if (start_process_in_buffer_directory) {
		getcd(old);
		get_buffer_directory(dir);
		chdir(dir);
	}
	err = !another_process() && concur_shell("", cmdline);
	if (start_process_in_buffer_directory == 2)
		chdir(old);
	if (err) {
		file_error(errno, "During exec", "Couldn't exec");
		quick_abort();
	}
}

command stop_process() on reg_tab[CTRL('C')]
{
	halt_process(has_arg);
	iter = 1;
}

command exit_process()
{
	tiled_only();
	if (!another_process() || !exist(PROCBUF))
		error("No process to exit");
	bufname = PROCBUF;
	type_point = point = size();
	stuff("exit\n");
	delay(500, COND_PROC);
	if (another_process() && !char_avail()) {
		locate_window(PROCBUF, "");
		error("Couldn't exit from concurrent process.");
	}
}

command kill_process()
{
	if (!process_kill())
		say("Unable to kill the process.");
}

command compile_buffer() on reg_tab[FALT(3)]
{		// compile the current buffer (mode-specific)
	int res;
	char cmd[FNAMELEN], full[FNAMELEN], *ext;

	tiled_only();
	if (!compile_buffer_cmd) {
		ext = get_extension(filename);
		sprintf(cmd, "compile-%s-cmd", *ext ? (ext + 1) : "none");
		if (ext = get_str_var(find_index(cmd)))
			save_var compile_buffer_cmd = ext;
	}
	if (!compile_buffer_cmd) {
		get_string(cmd, "Command to compile this buffer: ");
		compile_buffer_cmd = strsave(cmd);
	}
	save_var concurrent_make, shell_shrinks;
	if (pre_compile_hook)	// hook can change above vars
		if ((*pre_compile_hook)())
			return;		// hook says don't do compile
	if (concurrent_compile < 3)
		concurrent_make = concurrent_compile;
	if (concurrent_compile == 0 && is_gui)	// Run in the concur proc
		concurrent_make = 4;		//  if any, but keep control.
	if (start_process_in_buffer_directory) {
		char dir[FNAMELEN], old[FNAMELEN];

		getcd(old);
		get_buffer_directory(dir);
		chdir(dir);
		build_filename(full, compile_buffer_cmd, filename);
		chdir(old);
	} else
		build_filename(full, compile_buffer_cmd, filename);
	res = do_compile(full);
	if ((!res || res == 4) && post_compile_hook)
		(*post_compile_hook)(res);
}

load_this_bytecode_file(res)	// load .b file made from current file
{
	char file[FNAMELEN];

	strcpy(file, filename);
	strcpy(get_extension(file), byte_extension);
	if (check_file(file, NULL) == CHECK_FILE) {
		load_commands(filename);
		say("%s compiled and loaded.%s", filename,
		   res == 4 ? "  (There were warnings.)" : "");
	}
}

compile_via_dll()	// Try to compile .e file using a DLL, return 1 if ok.
{
	if (is_gui != IS_NT && is_gui != IS_WIN95)
		return 0;			// Only supported in 32-bit Windows.
	_had_errors = 0;
	save_var point;
	switch (eel_compile(bufname, 0, compile_eel_dll_flags, "eel-errors")) {
		case 2:		// Couldn't access DLL.
			say("Unable to compile using eel_lib.dll, running process.");
			return 0;
		case 0:
			say("%s compiled and loaded.%s",
				filename ? filename : "Buffer",
				buffer_size("eel-errors") ? "  (There were warnings.)" : "");
	}
	restore_vars();
	save_var bufname = "eel-errors";
	if (size()) {
		point = 0;			// Starting at the beginning,
		set_error_spot();	//    scan in this buffer.
		do_next_error(1);	// Scan for error messages.
	} else {
		restore_vars();
		delete_buffer("eel-errors");
	}
	return 1;
}

command make() on cx_tab['m']
{
	char cmd[FNAMELEN];

	tiled_only();
	get_cmdline("Make using command", cmd);
	save_var start_process_in_buffer_directory
			= start_make_in_buffer_directory;
	do_compile(cmd);
}

// Run the given cmd, then search for errors.
// Return 0 if the compile was ok,
// 1 if the process returned an error code,
// 2 if we ran it concurrently and the user started typing,
// 3 if the user didn't ok saving,
// 4 if the process returned 0, but next-error found some errors.
do_compile(cmd)
char *cmd;
{
	int err = 0, nerr;
	int obuf = bufnum;

	_last_was_grep = 0;
	if (maybe_save_all())
		return 3;
	if (!another_process())
		save_var restart_concurrent = 0;
	if (concurrent_make == 2)
		create_concur("");
	else if (concurrent_make == 0)
		try_exit_concurrent();
	if (concurrent_make == 4 && another_process()) {
		save_var bufname = PROCBUF;	// Run the program in the concur
		set_error_spot();			// proc buffer, but don't process
		_had_errors = 0;			// the user's keys until it finishes.
		if (*cmd) {
			point = size();
			bprintf("%s\n", cmd);
		}
		maybe_refresh();
		iter = 1;
		delay(-1, COND_PROC);
		if (!another_process() || !process_input())
			return 2;	/* else assume it's compiled */
	} else if (no_running()) {	/* goes to end of proc buffer */
		set_error_spot();
		_had_errors = 0;
		if (*cmd)
			bprintf("%s\n", cmd);
		maybe_refresh();
		iter = 1;
#ifndef UNIX
		delay(-1, COND_PROC | COND_KEY);
#endif
		if (!another_process() || !process_input())
			return 2;	/* else assume it's compiled */
	} else
		err = do_push(cmd, 1, 0);
	maybe_restart_concurrent();
	nerr = do_next_error(1);	// scan for error messages
	if (!nerr && err) {	// no message recognized, but error code
		say("Process returned %d", err);
		locate_window(PROCBUF, "");
		point = size();		/* show end of process buffer */
		return err;
	} else
		bufnum = obuf;
	if (err)
		return 1;
	else if (nerr)
		return 4;
	return 0;
}

// The following functions save & restore a concurrent process.  To use,
// you must first execute:
// 	if (!another_process()) save_var restart_concurrent = 0;
// Then call try_exit_concurrent(), run the process, and then call
// maybe_restart_concurrent().

try_exit_concurrent()
{
	if (another_process()) {
		exit_process();
		if (another_process())
			error("Couldn't exit from concurrent process.");
	}
}

maybe_restart_concurrent()
{
	if (restart_concurrent && !another_process())
		concur_shell("", "");
}

command next_error()
{
	do_next_error(iter);
	iter = 1;
}

command previous_error()
{
	do_next_error(-iter);
	iter = 1;
}

/* if you change ERROR_PATTERN, change the next 3 macros as well */
#define ERROR_PATTERN	"^(e \"|w \"|<*>*(error|warning|fatal|Buffer )<*>*|[\"(]?) *" \
			"(([a-z]:)?[+-9A-z~]+<.>[+-9A-z]+)\"?" \
			"([ (:,]( line|L)?) *" \
			"([0-9]+)(<rparen|:>|[^0-9\n].*[:;]).*"
#define FILE_PAREN	3	/* filename is in 3rd () pair above */
#define LINE_PAREN	7	/* line# is in 7th pair of parens above */
#define SIMP_PATTERN	"[:;)]"	/* search with simple pattern first */

do_next_error(count)	// return 0 if no errors, else 1
{
	char *orig = bufname, file[FNAMELEN], number[30], line[130], *p;
	int lineno, origpt, dir, from, to, is_bufname;

	tiled_only();
	_last_was_grep = 0;
	if (spot_to_buffer(error_spot) <= 0 && !exist(PROCBUF))
		error("No process buffer to read errors from.");
	tiled_only();
	if (spot_to_buffer(error_spot) > 0)
		bufnum = spot_to_buffer(error_spot);
	else
		bufname = PROCBUF;
	origpt = point;
	case_fold = 1;
	if (spot_to_buffer(error_spot) > 0)
		point = *error_spot;
	else {
		error_spot = alloc_spot();
		point = 0;
	}

	noteput("Searching...");
	if (!count)
		find_error(-1), count = 1;
	dir = (count > 0) ? 1 : -1;
	for (; count; count -= dir) {
		if (!find_error(dir)) {
			point = origpt;
			bufname = orig;
			say(_had_errors ? "No more errors" : "No errors");
			return 0;
		}
	}
	_had_errors = 1;
	grab(find_group(FILE_PAREN, 1), find_group(FILE_PAREN, 0), file);
	grab(find_group(LINE_PAREN, 1), find_group(LINE_PAREN, 0), number);
	from = find_group(LINE_PAREN, 0);
	to = find_group(0, 0);
	if (to > from + sizeof(line) - 1)
		to = from + sizeof(line) - 1;
	grab(from, to, line);
	is_bufname = (parse_string(1, "Buffer ") != 0);
	if (dir > 0)
		to_end_line();
	*error_spot = point;
	point = origpt;
	lineno = strtoi(number, 10);
	bufname = orig;
	if (is_bufname)
		locate_window(file, "");
	else {
		if (another_process() && *process_current_directory)
			absolute(file, process_current_directory);
		else
			absolute(file);
		locate_window("", file);
		find_it(file, default_translation_type);
	}
	go_line(lineno);
	for (p = line; *p && index("() :;\t", *p); p++)
		;			// skip over these chars at start of msg
	say("=> %s", p);
	return 1;
}

find_error(dir)		/* find next error in direction, return 1 */
{
	int old = point;

	if (point > 0 && dir > 0)
		to_end_line();
	else
		to_begin_line();
	while (re_search(dir, SIMP_PATTERN)) {
		to_begin_line();
		if ((!*ignore_error || !parse_string(1, ignore_error, NULL))
				&& parse_string(1, ERROR_PATTERN, (char *)0))
			return 1;
		if (dir > 0)
			nl_forward();
	}
	*error_spot = old;
	return 0;
}

command view_process() on reg_tab[FSHIFT(3)]	// put up a list of errors,
{					//  let user select one, and go there
	int w = window_handle, win, buf, pos;

	tiled_only();
	if (!exist(PROCBUF))
		error("No process buffer to read errors from.");
	save_var menu_width = screen_cols - _view_left - _view_right;
	save_var _doing_input = DI_LINEINPUT;

	save_var bufname = PROCBUF;
	if (spot_to_buffer(error_spot) != bufnum) {
		pos = 0;
		set_error_spot();
	} else
		pos = *error_spot;
	win = new_menu(buf = tmp_buf());
	grab_buffer(name_to_bufnum(PROCBUF));
	point = pos;
	to_begin_line();
	window_title(win, BTOP, TITLECENTER, " Compiler Errors ");
	window_to_fit(screen_lines - 7);
	save_var _window_flags |= HIGHLIGHT_LINE;
	save_var search_in_menu = 0;
	save_var display_column = -1;	// ensure all of msg is visible
	if (is_gui && want_gui_prompts) {
		one_window_to_dialog("Select an error message", win,
							 "To Error", "Cancel", "");
	} else
		say("Select an error message and press <Enter>.");
	set_read_only(1);
	select_menu_item(0, win, w, 0);
	bufnum = buf;
	pos = point;
	buf_delete(buf);
	check_abort();
	bufname = PROCBUF;
	point = pos;
	set_error_spot();
	ungot_key = -1;
	restore_vars();
	do_next_error(0);
}

buffer spot process_input_starts_at;

color_process_range(from, to)
{
	if (from >= to || spot_to_buffer(process_input_starts_at) <= 0)
		return to;
	save_var point, matchstart, matchend;
	point = *process_input_starts_at;
	to_end_line();
	set_character_color(*process_input_starts_at, point,
						color_class process_input);
	return to;
}

#define PROC_CMDS_BUF	"-process-cmds-"	/* store prev cmds here */

process_cmds_to_end()
{
	save_var bufname = PROC_CMDS_BUF;
	point = 0;
	do_uniq(1, 1, 0);		// discard adjacent duplicate cmds silently
	point = size();
}

when_process_input(int type, int start)
{
	save_var bufname = PROCBUF;
	save_var point;
	if (type == PROCESS_INPUT_LINE) {
		create(PROC_CMDS_BUF);
		process_cmds_to_end();
		nl_forward();
		if (point > start + 1)		// don't store empty (just \n) cmds
			xfer(PROC_CMDS_BUF, start, point);
		process_cmds_to_end();
	} else if (type == PROCESS_INPUT_CHAR)
		set_character_color(start, start + 1, color_class process_input);
	else if (!type) {		// Got a request for input (might now wait).
		if (spot_to_buffer(process_input_starts_at) <= 0)
			process_input_starts_at = alloc_spot();
		*process_input_starts_at = start;
		point = start;
		to_begin_line();
		set_character_color(point, start, color_class process_prompt);
	}
}

when_process_output(int start, int end)
{
	save_var bufname = PROCBUF;
	set_character_color(start, end, color_class process_output);
}

command process_mode()
{
	mode_keys = process_tab;
	major_mode = _process_mode_name;
	tab_size = process_tab_size;
	discardable_buffer = 1;
	recolor_range = color_process_range;	// set up coloring rules
	recolor_from_here = recolor_from_top;
	when_setting_want_code_coloring();	// maybe turn on coloring
	make_mode();
}

command process_enter() on process_tab['\r'], process_tab[GREYENTER]
{
	if (process_enter_whole_line && point >= type_point)
		to_end_line();
	enter_key();
	if (spot_to_buffer(error_spot) != bufnum || point < *error_spot)
		set_error_spot();
	_last_was_grep = 0;
}

process_get_previous_cmd(int down)
{
	point = size();
	if (!exist(PROC_CMDS_BUF))
		return;
	if (spot_to_buffer(process_input_starts_at) > 0
		&& !lines_between(*process_input_starts_at, point))
		delete(*process_input_starts_at, point);
	else {
		if (spot_to_buffer(process_input_starts_at) <= 0)
			process_input_starts_at = alloc_spot();
		*process_input_starts_at = point;
	}
	save_var bufname = PROC_CMDS_BUF;
	down_or_up_lines(down);
	xfer(PROCBUF, give_begin_line(), give_end_line());
}

command process_previous_cmd() on process_tab[ALT('p')]
{
	process_get_previous_cmd(0);
}

command process_next_cmd() on process_tab[ALT('n')]
{
	process_get_previous_cmd(1);
}

set_error_spot()	/* maybe allocate, then set to point */
{
	if (spot_to_buffer(error_spot) == bufnum)
		*error_spot = point;
	else {
		if (spot_to_buffer(error_spot) > 0)
			free_spot(error_spot);
		error_spot = alloc_spot();
	}
}
