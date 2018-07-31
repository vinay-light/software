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

// This file has dired mode.

#include "eel.h"
#include "dired.h"
#include "colcode.h"
#include "epsnet.h"

when_loading()		/* disable self-inserting chars */
{
	fix_key_table(reg_tab, (short) normal_character, dired_tab, -1);
}

dired_help() on dired_tab['h'], dired_tab['?']
{
	help_on_command("dired-mode");
}

// Given a prefix like "dired-isdir-", returns an index to
// the subroutine dired-isdir-unix when the buffer has a Unix-style
// directory list, dired-isdir-simple when the buffer has that format
// of directory list, or NULL if the buffer isn't from an FTP or the
// appropriate function doesn't exist.  Func is nonzero if the item
// should be a subroutine, or 0 if it should be a variable.

int get_dired_item(char *prefix, int func)
{
	char item[100];
	int i;

	strcpy(item, prefix);
	switch (dired_format) {
		case DF_UNIX:		strcat(item, "unix"); break;
		case DF_SIMPLE:		strcat(item, "simple"); break;
		case DF_OLDNT:		strcat(item, "oldnt"); break;
		case DF_VMS:		strcat(item, "vms"); break;
		default:			return 0;
	}
	i = find_index(item);
	switch (name_type(i)) {
		case NT_COMMAND: case NT_SUBR:
		case NT_AUTOLOAD: case NT_AUTOSUBR:
			if (func)
				return i;
			break;
		case NT_VAR: case NT_BUFVAR:
		case NT_WINVAR:
			if (!func)
				return i;
			break;
	}
	return 0;
}

dired_examine() on dired_tab[' '], dired_tab['\n'],
		   dired_tab['e'], dired_tab['\r'], dired_tab[GREYENTER]
{
	char fname[FNAMELEN];

	dired_getname(fname);
	do_dired_examine(fname, dired_isdir());
	iter = 0;
}

dired_parent() on dired_tab['^'], dired_tab['.']
{				/* view parent directory */
	char fname[FNAMELEN];

	to_begin_line();
	dired_try_getdir(fname, 1);
	strcat(fname, "..");
	do_dired_examine(fname, 1);
	iter = 0;
}

do_dired_examine(fname, isdir)
char *fname;
{
	char file[FNAMELEN], *p;

	strcpy(file, fname);
	absolute(file);
	if (isdir) {
		if (is_remote_file(file) && isdir == 1
			&& is_path_separator(file[strlen(file) - 1]) != 1)
			strcat(file, "/");	// If dir, not link, add /.
		if (dired_one(file) || is_remote_file(file))
			return;
		strcpy(file, fname);
		p = get_tail(file, 0);	/* for .., go to right place */
		if (p > file && strcmp(p, "..") == 0) {
			strcpy(p - 1, AFTER_DIR);
			col_search(get_tail(file, 0), goal_column);
			move_to_column(goal_column);
			build_first = 1;
		}
	} else			/* regular file */
		find_it(file, ask_line_translate());
}

dired_examine_in_window() on dired_tab['1'], dired_tab['2'],
				dired_tab['5'], dired_tab['z']
{		/* do appropriate window cmd, then examine */
	int olditer = iter, oldarg = has_arg;

	has_arg = iter = 0;
	do_command(cx_tab[key]);
	iter = olditer, has_arg = oldarg;
	ungot_key = 'e';
}

dired_examine_in_next_window() on dired_tab['o']
{
	char fname[FNAMELEN];
	int isdir;

	dired_getname(fname);
	isdir = dired_isdir();
	next_user_window(1);
	do_dired_examine(fname, isdir);
	iter = 0;
}

dired_refresh() on dired_tab['r']
{
	char msg[FNAMELEN];
	int yes, remote;

	if (modified) {
		sprintf(msg, "Relist %s, discarding markings? ", bufname);
		yes = ask_yn("Discard markings", msg, "Yes", "No", 1);
		check_abort();
		if (!yes)
			return;
	}
	remote = (dired_format != 0);
	if (dired_format)
		point = 0;
	else
		save_var point, window_start;
	create_dired_listing(dired_buffer_pattern ? dired_buffer_pattern
											  : bufname);
	restore_vars();
	if (!remote)
		move_to_column(goal_column);
	dired_orig_position = point;
	fix_window_start();
}

dired_create_directory() on dired_tab['+']
{
	char dir[FNAMELEN], cmd[FNAMELEN], url[FNAMELEN];

	get_file_dir(dir, "Create directory: ");
	if (is_remote_file(dir)) {
		dired_getdir(url);
		sprintf(cmd, "MKD %s", get_url_file_part(dir, 0));
		ftp_misc_operation(url, cmd);
		say("Operation queued.");
	} else {
		mkdir(dir);
		dired_refresh();
	}
}

dired_sort() on dired_tab['s']
{
	char *p, msg[200];
	int rev, sort;

	if (dired_format == DF_VMS)
		error("Sorting VMS directories not supported.");
	rev = isupper(dired_sorts_files);
	switch (sort = toupper(dired_sorts_files)) {
		case 'N': case 'D': case 'S':  case 'E': 
			break;
		case 0: case 'U':
			sort = 'U', rev = 0; break;
		default:
			sort = 'N';
	}
	for (;;) {
		strcpy(msg, "Name, Ext, Size, Date, Unsorted,");
		p = index(msg, sort);
		p = index(p, ',');
		msg[strlen(msg) - 1] = 0;
		sayput("Sort by %.*s (now)%s; Reverse; %sGroup dirs"
			   " [NESDURG] ", p - msg, msg, p,
			   dired_groups_dirs ? "un" : "");
		getkey();
		check_abort();
		switch (toupper(key)) {
			case 'N':
			case 'D':
			case 'S':
			case 'E': sort = toupper(key); break;
			case 'U': say("Future listings will be unsorted.");
					  sort = 0; break;
			case 'R': rev = !rev; break;
			case '+': rev = 0; break;
			case '-': rev = 1; break;
			case 'G': dired_groups_dirs = !dired_groups_dirs;
					  break;
			default:  if (IS_ENTER_KEY(key))
						  break;
					  else if (root_keys[key] == (short) help
							   || key == 'h' || key == '?')
						  help_on_command("dired-sort");
					  continue;
		}
		break;
	}
	dired_sorts_files = rev ? toupper(sort) : tolower(sort);
	if (sort) {
		sprintf(msg, "%s%s, %s", rev ? "Reverse " : "",
				(sort == 'N') ? "Name" : (sort == 'E') ? "Extension"
			: (sort == 'S') ? "Size" : "Date",
				dired_groups_dirs ? "grouping directories at top"
								  : "not grouping directories");
		noteput("Sorting...");
		sort_for_dired();
		say("Sorted by %s.", msg);
	} else
		say("Future listings will be unsorted.");
	maybe_refresh();
}

dired_repl(newchar)
{
	to_begin_line();
	if (parse_string(1, SKIPLINEPAT))
		nl_forward();
	if (index("DCM ", curchar()) && character(point + 1) == ' ')
		replace(point, newchar);
	save_var iter = 1;		// call us to do each repetition
	dired_down_line();
}

dired_mark_for_delete() on dired_tab['d']
{
	dired_repl('D');
}

dired_mark_for_copy() on dired_tab['c']
{
	if (dired_format)
		error("Copy operation not implemented for remote files.");
	dired_repl('C');
}

dired_mark_for_move() on dired_tab['m']
{
	dired_repl('M');
}

dired_unmark() on dired_tab['u']
{
	dired_repl(' ');
}

dired_do_delete(name, to)	/* return 1 if error */
char *name, *to;
{
	to = to;
	if (is_remote_file(name)) {
		buffer_printf(REMOTE_FTP_OP_BUFFER,
					  dired_isdir() ? "RMD %s\n" : "DELE %s\n",
					  get_url_file_part(name, 0));
	} else {
		noteput("Deleting %s.", name);
		if (dired_isdir() ? rmdir(name) : delete_file(name))
			return 1;
	}
	save_var modified;	// leave modify bit alone
	to_begin_line();	// but delete line
	delete(point - 1, give_end_line());
	return 0;
}

dired_do_copy(name, to)	/* return 1 if error */
char *name, *to;
{
	char dest[FNAMELEN];

	make_copy_name(name, to, dest);
	if (is_remote_file(name)) {
//		noteput("Copy operation not implemented for remote files.");
		return 1;
	}
	noteput("Copying %s to %s.", name, dest);

	if (!strcmp(name, dest) || warn_existing_file(dest)
	    || copyfile(name, dest))
		return 1;	// disallow copying file to itself
	save_var modified;	// leave modify bit alone
	dired_unmark();
	nl_reverse();
	return 0;
}

dired_do_move(name, to)	/* return 1 if error */
char *name, *to;
{
	char dest[FNAMELEN];

	make_copy_name(name, to, dest);
	if (is_remote_file(name)) {
		buffer_printf(REMOTE_FTP_OP_BUFFER, "RNFR %s\nRNTO %s\n",
				get_url_file_part(name, 0), get_url_file_part(dest, 0));
	} else {
		noteput("Moving %s to %s.", name, dest);
		if (rename_file(name, dest))
			return 1;
	}
	save_var modified;	// leave modify bit alone
	to_begin_line();	// but delete line
	delete(point - 1, give_end_line());
	return 0;
}

make_copy_name(src, dest, res)	// if dest is a dir, append src to it
char *src, *dest, *res;		// else copy dest
{
	int remote = is_remote_file(dest);

	strcpy(res, dest);
	if (remote ? is_path_separator(res[strlen(res) - 1])
			   : is_directory(res)) {
		dest = res + strlen(res);
		if (*res && !is_path_separator(dest[-1]))
			*dest++ = remote ? '/' : path_sep;
		strcpy(dest, get_tail(src, 0));
	}
}

// If the buffer of operations is nonempty, start executing it.

send_remote_ftp_op()
{
	char url[FNAMELEN], *p;

	dired_getdir(url);
	if (!exist(REMOTE_FTP_OP_BUFFER))
		return;
	save_var bufname = REMOTE_FTP_OP_BUFFER;
	delete_final_newlines();
	if (!size())
		return;
	p = malloc(size() + 1);
	grab(0, size(), p);
	ftp_misc_operation(url, p);
	free(p);
	say("Operation queued.");
}

dired_execute() on dired_tab['q'], dired_tab['x']
{
	int del, copy, move;

	if (dired_format && exist(REMOTE_FTP_OP_BUFFER))
		zap(REMOTE_FTP_OP_BUFFER);
	del = dired_do_no_param("Delete", "\nD ", "deleted", dired_do_delete);
	copy = dired_do_param("Copy", "\nC ", "copied", dired_do_copy);
	move = dired_do_param("Move", "\nM ", "moved", dired_do_move);
	if (del + copy + move == 0)
		error("No files marked");
	modified = 0;
	if (!dired_format && (move || copy))
		dired_refresh();	// could be rename or similar, make new listing
	if (dired_format)
		send_remote_ftp_op();
	fix_window_start();
	iter = 0;
}

dired_do_no_param(op, tag, past, func)
char *op, *tag, *past;
int (*func)();
{
	int count = dired_ask(op, tag, "? ", NULL);

	if (count > 0)
		dired_do(past, tag, count, func, NULL);
	return count;
}

dired_do_param(op, tag, past, func)
char *op, *tag, *past;
int (*func)();
{
	char to[FNAMELEN];
	int count = dired_ask(op, tag, " to: ", to);

	if (count > 1 && !is_remote_file(to))	// can only copy/move mult
		switch (check_file(to, NULL)) {		// to a dir
		case 0:		if (mkdir(to)) {
					file_error(errno, to, "make dir");
					quick_abort();
				}
		case CHECK_DIR:	break;
		default:	error("%s is not a directory.", to);
		}
	if (count > 0)
		dired_do(past, tag, count, func, to);
	return count;
}

dired_ask(op, tag, end, file)	// make list of files, confirm/get param if any
char *op, *tag, *end, *file;	// return count or 0 if none were marked
{
	int list = tmp_buf(), count = 0;
	char msg[FNAMELEN], name[FNAMELEN];

	save_var point = 0;
	save_var abort_searching = ABORT_ERROR;
	while (search(1, tag) == 1) {
		dired_getname(name);
		count++;
		if (count > 1)
			sprintf(msg, "%s these %d files%s", op, count, end);
		else
			sprintf(msg, "%s this file%s", op, end);
		if (count > 1 && !(is_gui && want_gui_prompts))
			note(msg);
		buf_printf(list, "%s\n", name);
	}
	restore_vars();

	if (!count) {
		buf_delete(list);
		return 0;
	} else if (count == 1 && (!(is_gui && want_gui_prompts) || file)
			   && strlen(name) < screen_cols / 2)
		sprintf(msg, "%s file %s%s", op, name, end);
	else {
		if (!(is_gui && want_gui_prompts) || file)
			say(msg);
		sprintf(name, " Files to %s ", op);
		save_var _view_title = (is_gui && want_gui_prompts && !file)
							   ? msg : name;
		buf_delete_final_newlines(list);
		save_var paging_retains_view = 1;
		view_buf(list, 0);
	}
	save_var prompt_with_buffer_directory = PBD_INSERT;
	if (is_gui && want_gui_prompts && key == abort_key)
		file = 0, *name = 'N';		// User clicked Cancel.
	else if (file) {
		get_file_dir(file, msg);
		if (count > 1 && is_remote_file(file)
			&& !is_path_separator(file[strlen(file) - 1]))
			strcat(file, "/");
	} else if (is_gui && want_gui_prompts) {	// Already prompted so don't
		*name = toupper(key) == 'Y' || IS_ENTER_KEY(key) // ask again.
				|| toupper(key) == 'O' ? 'Y' : 'N';
		ungot_key = -1;
	} else
		get_string(name, msg);
	buf_delete(list);
	if (file ? *file : (toupper(*name) == 'Y'))
		return count;
	error("No action taken.");
}

dired_do(op, tag, count, func, to)
char *op, *tag, *to;
int (*func)();
{
	spot final;
	int bad = 0;
	char name[FNAMELEN];

	final = alloc_spot();
	point = 0;
	save_var abort_searching = 0;
	while (search(1, tag)) {
		if (user_abort) {
			if (!bad)
				*final = point;
			break;
		}
		dired_getname(name);
		if ((*func)(name, to))
			if (!bad++)		/* error occurred */
				*final = point;	/* 1st error */
	}
	point = *final;
	free_spot(final);
	move_to_column(goal_column);
	if (bad)
		error("%d of %d file%s not %s", bad, count,
			count > 1 ? "s" : "", op);
	say("%d file%s %s", count, count > 1 ? "s" : "", op);
}

dired_del_line()	/* delete current line, leave modify bit alone */
{
	save_var modified;	// leave modify bit alone
	to_begin_line();	// but delete line
	delete(point, give_end_line() + 1);
}

dired_run_viewer() on dired_tab['v']
{
	char fname[FNAMELEN], dirname[FNAMELEN];

	dired_getname(fname);
	strcpy(dirname, fname);
	*get_tail(dirname, 1) = 0;
	if ( run_viewer(fname, "open", dirname) == 0)
		say("Could not run viewer for \"%s\"", fname);
}

dired_goto_dir() on dired_tab['g']
{
	char fname[FNAMELEN];

	dired_getname(fname);
	if (chdir(fname) && (dired_try_getdir(fname, 1), chdir(fname)))
		file_error(errno, fname, "unknown error");
	else {
		getcd(fname);
		say("Current directory: %s", fname);
	}
	iter = 0;
}

dired_down_line() on dired_tab['n']
{
	down_line();
	to_begin_line();
	while (parse_string(1, SKIPLINEPAT))
		nl_forward();
	move_to_column(goal_column);
}

dired_up_line() on dired_tab['p']
{
	up_line();
	to_begin_line();
	while (parse_string(1, SKIPLINEPAT)) {
		if (!nl_reverse())
			break;
		to_begin_line();
	}
	move_to_column(goal_column);
}

dired_getdir(fullname)	// grab directory, add / to end, for completion
char *fullname;		// set fullname to "" if error
{
	return dired_try_getdir(fullname, 0);
}

dired_try_getdir(fullname, showerr)	// grab directory, add / or \ to end
char *fullname;		// if we can't find, set fullname "" if !showerr
{			// return nonzero if ok
	int i;
	char *p, path_char;

	*fullname = 0;
	save_var point;
	to_end_line();
	if (!re_search(-1, DIRLINEPAT))	// find prev "Directory of "
		if (showerr)		// bad dired buf
			error("Can't determine directory of files");
		else
			return 0;
	point = matchstart;
	re_search(1, " *");		// skip initial spaces
	parse_string(1, FILECHARS, fullname);
	p = fullname + (i = strlen(fullname));
	path_char = is_remote_file(fullname) ? '/' : path_sep;
	if (i > 0 && !is_path_separator(fullname[i - 1]))
		p[0] = path_char, p[1] = 0; // add final / or \ if none
	return 1;
}

dired_getname(fullname)
char *fullname;
{
	char *p, *q;

	dired_try_getdir(fullname, 1);
	p = fullname + strlen(fullname);
	dired_getindex(p, goal_column);		/* the file name */
	to_begin_line();
	if (parse_string(1, SKIPLINEPAT))  /* on dir line, make name illegal */
		*p = 0;
	move_to_column(goal_column);
	if (!*p || isspace(*p))
		error("Can't read file name");
	q = strstr(p, " -> ");			// replace file name with link dest
	if (q)
		strcpy(p, q + 4);
	if (is_path_separator(*p) == 1)	// If link dest starts with /,
		strcpy(get_url_file_part(fullname, 0), p);	// just use that.
	if (dired_format == DF_SIMPLE) {
		q = index(fullname, ' ');		// Remove stuff after file name.
		if (q)
			*q = 0;
	} else if (dired_format == DF_VMS) {
		q = index(fullname, ' ');		// Remove stuff after file name.
		if (q)
			*q = 0;
		q = strstr(fullname, ".DIR;");	// Refer to directories without
		if (q)							// .DIR extension to see contents.
			*q = 0;
		q = strstr(fullname, ";");		// Remove version number.
		if (q && isdigit(q[1]))
			*q = 0;
	}
	p += strlen(p) - 1;		// Unix file name might use "ls -F" format
	if (*p == '/' || *p == '*')
		*p = 0;
}

// Look for continuation lines in VMS directory listing, combine.

dired_vms_fix_lines()
{
	save_spot point = 0;
	save_var modified;
	while (re_search(1, "\n                    "))
		delete(matchstart, matchend);
}

dired_isdir_unix()	// Return 2 if link, 1 if dir, else 0.
{
	save_var point;
	to_begin_line();
	if (!parse_string(1, dired_dirsearch_unix))
		return 0;
	return (character(matchend - 1) == 'l') ? 2 : 1;
}

// Return 1 if this line refers to a directory, 2 if a symbolic link,
// 0 otherwise.

dired_isdir()
{
	char buf[FNAMELEN];
	int i;

	i = get_dired_item("dired-isdir-", 1);
	if (i)
		return (*(int (*)())i)();
	i = get_dired_item("dired-dirsearch-", 0);
	if (i) {
		save_var point;
		to_begin_line();
		return parse_string(1, get_str_var(i)) != 0;
	}
	dired_getindex(buf, ISDIR_START);
	return !strncmp(buf, DIRMARK, strlen(DIRMARK));
}

dired_getindex(s,i)	/* put current line in s, starting at column i */
char *s;
{
	save_var point;
	move_to_column(i);
	re_search(1, " *");		/* skip initial spaces */
	parse_string(1, FILECHARS, s);
}

is_dired_buf()		/* is the current buffer a dired buffer? */
{
	return mode_keys == dired_tab;
}

color_dired_range(from, to)
{
	int color, namecolor, old, namestart, nameend;
	char buf[FNAMELEN];

	if (from >= to)
		return to;
	detect_dired_format();
	save_var point, matchstart, matchend;
	point = from;
	save_var narrow_start = give_begin_line();
	point = to;
	nl_forward();
	save_var narrow_end = size() - point;
	point = 0;
	while (point < size() - narrow_end) {
		switch (curchar()) {
			case 'D': color = color_class dired_deleted; break;
			case 'M': color = color_class dired_moved; break;
			case 'C': color = color_class dired_copied; break;
			default: color = color_class dired_normal; break;
		}
		old = point;
		if (parse_string(1, SKIPLINEPAT) != 0) {
			color = color_class dired_header;
			namestart = matchend;
			nameend = give_end_line();
			namecolor = color_class dired_dir_name;
		} else {
			dired_getindex(buf, goal_column);
			namestart = matchstart;
			nameend = matchend;
			namecolor = color_class dired_file_name;
			if (dired_format == DF_VMS)
				nameend = point + parse_string(1, "[^\n;]*;?[0-9]*");
			if (dired_isdir()) {
				namecolor = color_class dired_dir_name;
				if (!dired_format)
					namestart = column_to_pos(ISDIR_START);
			}
			if (!dired_format && character(namestart - 1) == ' ')
				namestart--;
		}
		nl_forward();
		set_character_color(old, point - 1, color);
		set_character_color(namestart, nameend, namecolor);
	}
	return point;
}

command dired() on cx_tab['d']
{
	char dir[FNAMELEN];

	tiled_only();
	get_file_dir(dir, "Edit directory: ");
	return dired_one(dir);
}

detect_dired_format()
{
	int old = dired_format;

	dired_format = 0;
	goal_column = NAME_START;
	save_var point = 0, case_fold = 1;
	while (parse_string(1, SKIPLINEPAT))
		nl_forward();
	if (point >= size())
		return;
	if (parse_string(1, ".*" UNIX_DATE)) {
		dired_format = DF_UNIX;
		goal_column = get_column(matchend);
	} else if (parse_string(1, ".*" OLDNT_DATE)) {
		dired_format = DF_OLDNT;
		goal_column = 41;
	} else if (parse_string(1, ".*" VMS_DATE)) {
		dired_format = DF_VMS;
		goal_column = 2;
	} else if (!parse_string(1, ". [ 0-9][0-9]-[0-9][0-9]-[0-9][0-9]")) {
		dired_format = DF_SIMPLE;
		goal_column = 2;
	}
	if (dired_format != old)
		drop_all_colored_regions();
}

char _dired_mode_name[] = "Dired";

dired_mode()
{
	mode_keys = dired_tab;
	major_mode = _dired_mode_name;
	mouse_dbl_selects = 1;
//	goal_column = NAME_START;
	detect_dired_format();
	recolor_range = color_dired_range;	// set up coloring rules
	recolor_from_here = recolor_by_lines;
	when_setting_want_code_coloring();	// maybe turn on coloring
	discardable_buffer = 1;
	make_mode();
}

dired_one(dir)	/* dir is absolute pathname of directory or pattern */
char *dir;	/* return 0 if ok */
{
	char buf[FNAMELEN], *to;
	int uniq = 1;

	if (is_remote_file(dir))
		standardize_remote_pathname(dir);	// Try to remove . and ..
	if (*dir)
		strcpy(buf, dir);
	else if (prompt_with_buffer_directory) {
		get_buffer_directory(buf);	// this file's directory
		dir = buf;
	} else {
		dir = ".";	/* "" means current directory */
		getcd(buf);
	}
	if (!is_remote_file(buf))
		dired_standardize(buf);		/* fix appropriately for this o/s */
	else {
		standardize_remote_pathname(buf);	// Try to remove . and ..
		standardize_remote_pathname(dir);	// Try to remove . and ..
	}
	to = buf + strlen(buf);
	while (exist(buf)) {	/* make it unique */
		bufname = buf;
		if (is_dired_buf())	/* reuse existing dired buffer */
			break;
		sprintf(to, "<%d>", uniq++);
	}
	to_buffer(buf);
	move_to_column(goal_column);
	if (is_remote_file(buf) && is_dired_buf())
		return 0;
	return create_dired_listing(dir);
}

int create_dired_listing(char *dir)
{
	buf_zap(bufnum);
	translation_type = FILETYPE_MSDOS;
	dired_mode();
	noteput("Building directory listing...");
	if (make_dired(dir)) {
		say("No matches.");
		return 1;
	}
	say("");
	return 0;
}

dired_ftp_activity(int activity, int buf, int from, int to)
{
	to = to;
	save_var bufnum = buf;
	switch (activity) {
		case NET_DONE:
			detect_dired_format();
			if (dired_format == DF_VMS)
				dired_vms_fix_lines();
			if (!modified && point == dired_orig_position)
				sort_for_dired();
			else
				say("Sorting omitted, press S to sort.");
			break;
		case NET_RECV:
			save_spot point = from;
			save_var modified;
			while (re_search(1, "^.")) {
				point--;
				stuff("  ");
				point++;
			}
			break;
		case NET_LOG_WRITE:
			break;
	}
}

do_remote_dired(char *dir)
{
	char plain[FNAMELEN], *p;

	strcpy(plain, dir);
	p = get_tail(plain, 1);	// If name contains wildcards, strip them.
	if (index(p, '*') || index(p, '?'))
		*p = 0;
	buffer_ftp_activity = dired_ftp_activity;
	bprintf("     Directory of %s\n", plain);
	point = modified = 0;
	dired_orig_position = point;
	if (index(dir, '*') || index(dir, '?'))	// Make FTP listing
		save_var ftp_compatible_dirs = 1;	// show just the basename.
	return url_operation(dir, FTP_LIST);
}

make_dired(dir)
char *dir;
{
	modified = 0;
	save_var abort_file_matching = ABORT_JUMP;
	if (is_remote_file(dir))
		do_remote_dired(dir);
	else if (do_dired(dir))
		return 1;
	detect_dired_format();
	switching_to_buffer();
	modified = 0;
	if (!is_remote_file(dir))
		sort_for_dired();
	else {
		to_end_line();
		type_point = size();
	}
	dired_orig_position = point;
	return 0;
}

sort_for_dired()
{
	int start, done = 0;

	if (dired_format == DF_VMS)
		return;		// Sorting not supported.
	save_var modified;
	window_start = point = 0;
	save_var abort_searching = 0;
	while (!done) {
		do {			/* skip past . and .. */
			nl_forward();	/* exclude 1st lines */
			move_to_column(goal_column);
		} while (parse_string(1, "<.><.>?[/\\]?($| )"));
		to_begin_line();
		start = point;
		if (re_search(1, SKIPLINEPAT))
			to_begin_line();
		else
			done = 1;
		dired_sorter(start, point);
	}
	point = 0;
	dired_down_line();		/* position on 2nd line */
	window_start = 0;
}

dired_sorter(start, end)
{
	int tmp, next;
	char *pat = DIRSEARCH;
	int i = get_dired_item("dired-dirsearch-", 0);

	if (i)
		pat = get_str_var(i);
	save_var case_fold = 1, sort_case_fold = 1;
	save_var narrow_start = start;
	save_var narrow_end = size() - end;
	if (dired_groups_dirs) {
		save_var point = 0;
		tmp = tmp_buf();
		while (re_search(1, pat) && !user_abort) {
			to_begin_line();
			next = give_end_line() + 1;
			buf_xfer(tmp, point, next);
			delete(point, next);
		}
		dired_group_sorter(start, point);
		point = 0;
		grab_buffer(tmp);
		buf_delete(tmp);
		dired_group_sorter(mark, point);
	} else
		dired_group_sorter(start, end);
}

dired_group_sorter(start, end)
{
	int on_col = goal_column, stripwid = 0, i;

	if (!dired_sorts_files || user_abort)
		return;
	save_var narrow_start = start;
	save_var narrow_end = size() - end;
	save_var point;
	save_var abort_searching = ABORT_ERROR;
	switch (toupper(dired_sorts_files)) {
		case 'D': stripwid = dired_sort_by_date(); break;
		case 'E': stripwid = dired_sort_by_exten(); break;
		case 'S': i = get_dired_item("dired-sort-by-size-", 1);
				  if (i)		// Call style-specific function.
					  stripwid = (*(int (*)())i)();
				  else
					  on_col = SIZE_COL;
				  break;
	}
	do_sort_region(0, size(), on_col, isupper(dired_sorts_files));
	if (stripwid)
		strip_columns(goal_column, goal_column + stripwid);
}

dired_sort_by_size_simple()
{
	say("Sorting by size not supported.");
	return 0;
}

// Insert size in each line, return length.
dired_sort_by_size_unix()
{
	char line[FNAMELEN];

	if (size() - narrow_end - narrow_start > 10000)
		noteput("Sorting by size...");
	point = 0;
	while (re_search(1, UNIX_DATE)) {
		point = matchstart;
		if (!parse_string(-1, "[0-9]+ *", line)) {
			note("Unrecognized format, can't sort.");
			strcpy(line, "0");
		}
		move_to_column(goal_column);
		bprintf("%15d", numtoi(line));
		to_end_line();
	}
	return 15;
}

dired_sort_by_date_simple()
{
	say("Sorting by date not supported.");
	return 0;
}

	/* insert numeric sortable date in each line, return length */
dired_sort_by_date_unix()
{
	char line[FNAMELEN], *p, *months, *time;
	int month, year;
	struct time_info now;

	time_and_day(&now);
	months = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ";
	point = 0;
	while (re_search(1, UNIX_DATE)) {
		grab(matchstart + 1, point, line);
		if (line[3] != ' ' || line[6] != ' ') {
			say("Unrecognized date format, can't sort.");
			strcpy(line, " Jan  1  1970 ");	// Fake default date.
		}
		line[3] = line[6] = 0;	// break into pieces
		p = strstr(months, line);
		if (!p) {
			say("Unrecognized month %s, can't sort.", line);
			p = months;
		}
		month = 1 + (p - months) / 4;	// Compute month 1..12.

		if (line[9] == ':') {	// Either a time (in the last 6 months)...
			time = line + 7;	// Year is this year or late last year.
			year = now.year - (month > now.month + 1);
		} else {			// Or a prior year, so make up a fake time.
			time = "00:00 ";
			year = numtoi(line + 7);
		}
		move_to_column(goal_column);
		bprintf("%5d%02d%2s%5s", year, month, line + 4, time);
		to_end_line();
	}
	return 15;
}


/* insert numeric sortable date in each line, return length */
dired_sort_by_date_oldnt()
{
	char line[FNAMELEN];
	int hour;

	point = 0;
	while (re_search(1, OLDNT_DATE)) {
		grab(matchstart, point, line);
		hour = numtoi(line + 10);
		if (hour == 12)
			hour = 0;
		if (toupper(line[15]) == 'P')
			hour += 12;
		move_to_column(goal_column);
		bprintf("%.2s%.5s%02d%.2s", line + 6,
				line, hour, line + 13);
		to_end_line();
	}
	return 11;
}

dired_sort_by_date()	/* insert stuff in each line, return length */
{
	char line[FNAMELEN];
	int end, hour, i;

	if (size() - narrow_end - narrow_start > 10000)
		noteput("Sorting by date...");
	point = 0;
	i = get_dired_item("dired-sort-by-date-", 1);
	if (i)		// Call style-specific function.
		return (*(int (*)())i)();
	do {
		end = give_end_line();
		if (point == end)
			break;
		grab(point, end, line);
		hour = numtoi(line + DATESTART + 14);
		if (hour == 12)
			hour = 0;
		if (line[DATESTART + 19] == 'p')
			hour += 12;
		move_to_column(goal_column);
		bprintf("%.4s%.5s%2d%.2s", line + DATESTART + 8,
			line + DATESTART + 2, hour, line + DATESTART + 17);
		point = end;
	} while (nl_forward());
	return 13;
}

dired_sort_by_exten()	/* insert stuff in each line, return length */
{
	char line[FNAMELEN];

	if (size() - narrow_end - narrow_start > 10000)
		noteput("Sorting by extension...");
	point = 0;
	do {
		if (point == give_end_line())
			break;
		dired_getindex(line, goal_column);
		move_to_column(goal_column);
		bprintf("%-30.30s", get_extension(line));
	} while (nl_forward());
	return 30;
}

strip_columns(scol, ecol)
{
	point = 0;
	do {
		delete(column_to_pos(scol), column_to_pos(ecol));
	} while (nl_forward());
}

when_loading()
{
	set_case_indirect(dired_tab);
}
