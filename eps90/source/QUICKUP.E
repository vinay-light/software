/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1984, 1997 Lugaru Software Ltd.  All rights reserved.	*
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "menu.h"
#include "bufed.h"
#include "c.h"
#include "grep.h"
#include "html.h"
#include "kill.h"
#include "tags.h"
#include "browse.h"
#include "tex.h"
#include "diff.h"
#include "epsnet.h"
#include "dired.h"

/*
Load this file to update your Epsilon state file from 9.0 B7 to
this version.
*/

command kill_all_buffers()	// kill all user-visible buffers
{
	int count = 0, newbuf;
	char *oldbuf;

	tiled_only();
	buffer_list(1);         // Count the buffers.
	do {
		count++;
	} while (buffer_list(0));

	while (count-- >= 0) {
		if (another_process()) {	// try to skip past process buffer
			if (!strcmp(bufname, "process"))
				next_buffer();
			if (!strcmp(bufname, "process"))
				break;
		}
		oldbuf = bufname;
		if (modified && *filename && size() && !is_dired_buf()
			&& !discardable_buffer) {
			if (!check_drop_buffer(bufname))	// Ask user if ok to drop.
				return;
		} else {
			if (newbuf = give_prev_buf())
				to_buffer_num(newbuf);
			else
				make_newfile_buf();
		}
		delete_user_buffer(oldbuf);
	}
}


int c_move_level(int dir);
jmp_buf c_indent_giveup;	/* come here when we hit narrowed edge */

c_indenter()		/* replace surrounding indentation with new */
{
	if (!(in_c_comment(c_look_back) & IN_COMMENT))
		indent_to_column(c_compute_indent());
	else if (reindent_c_comments)
		indent_c_comment();
}

c_move_level(dir)
{
	int first, second;
	int level = 0, cstart, cnow;
	char pat[6];			/* temporary pattern */
	char *findch = (dir > 0) ? "[({" : "])}";
	char *otherch = (dir < 0) ? "[({" : "])}";

	save_var point;			// if aborted, don't move anywhere
	sprintf(pat, "[%s]", findch);
	cstart = in_c_comment(c_look_back);	// in comment or string at start?
	do {
		if (!re_search(dir, pat))	/* find the first char of pair */
			return point;	/* at end of buffer */
		cnow = in_c_comment(c_look_back);	// ignore if it's in a comment/string
	} while (cnow && cnow != cstart);	// (unless we started in one)

	point -= dir;			/* move back over first char */
	first = character(point - (dir < 0)); /* get the character we found */
	second = otherch[index(findch, first) - findch];
					/* find the matching char */

	if (second == ']')		/* ] is special in patterns, so */
		strcpy(pat, "[][]");	/* use this: matches [ or ] */
	else
		sprintf(pat, "[%c%c]", first, second);
	cstart = cnow;			// in comment or string at start?

	while (re_search(dir, pat)) {	/* look for either first or second */

		cnow = in_c_comment(c_look_back);
		if (cstart) {			// If we started in comment/string,
			if (cnow != cstart)	// stop if we ever search outside it.
				break;
		} else if (cnow)	// We didn't start in a comment/string,
			continue;		// so ignore delimiters in comments/strings.

		if (character(point - (dir > 0)) == first)
			level++;
		else
			level--;
		if (level == 0)  /* when we return to same level, done */
			return point;
	}
	return -1;
}

c_compute_indent()
{
	int ind = 0;		/* indentation to use */
	int orig = point;
	int first_char = curchar(); /* cur line's first char */
	int pstart;		/* start position of prev line */
	int pafter;		/* after label on prev line */
	int pend;		/* end position of prev line */
	int prev_end = ';';	/* last char on previous line */
	int norm_narrow;	/* narrowing setting for most parsing */

	save_var point;
	if (setjmp(&c_indent_giveup))	/* if we hit end & gave up, */
		return ind;		/* use best guess so far */
	norm_narrow = fix_narrowing(point - c_look_back);
	save_var narrow_start = norm_narrow;
	if (!reindent_c_comments && parse_string(1, "[ \t\f]*/<*>"))
		return get_indentation(point);
	if (!reindent_one_line_c_comments && parse_string(1, "[ \t\f]*//"))
		return get_indentation(point);
	if (first_char == '#')
		return 0;
	else if (first_char == '}')
		return cind_close();

	to_begin_line();
	if (character(point - 2) == '\\')
		return indent_after_backslash();
	cind_space();			/* skip whitespace and comments */
	if (character(point - 1) == ':')
		move_before_labels();
	prev_end = character(point - 1); /* get last relevant char */
	pend = point;

	to_statement_start();		/* if contin line, back up */
	pstart = point;			/* now at start of biggest statement */
	past_labels();			/* containing original point */
	pafter = point;			/* just after label */
	ind = current_column();
	narrow_start = norm_narrow;	/* ok to look far back again */

	if (is_case(orig)) {
		ind = indent_case(orig);
	} else if (have_label(orig)) {
		ind = c_label_indent;
	} else if (prev_end == ':' && is_label(pstart)) {
		ind = get_column(pstart);
		if (!(Closeback && just_open(orig)))
			ind += get_c_indent();
		if (just_open(orig))
			ind += c_brace_offset;
	} else if (is_else(orig)) {
		point = orig;
		ind = indent_else(ind);
	} else if (prev_end == ';') {
		if (just_open(orig) && func_start_block(pstart))
			ind = c_top_braces;
		else
			ind = indent_after_statement(orig);
	} else if (prev_end == '}') {
		point = pend;
		ind = indent_after_block(orig);
	} else if (prev_end == '{') {
		if (ind <= c_top_braces	// special case if no previous indent
		    || get_column(pend - 1) <= c_top_braces) {
			ind += top_indent(prev_end) ? get_c_indent() : c_top_braces;
			if (just_open(orig))
				ind += c_brace_offset;
			if (ind < c_top_braces)
				ind = c_top_braces;
		} else if (Closeback || curchar() != '{')
			ind += get_c_indent();
		if (just_open(pafter))
			ind -= c_brace_offset;
	} else if (just_open(orig))
		return indent_just_open(ind);
	else if (is_contin_statement(pend, 1, orig)) {
		return indent_c_contin(ind, orig, pend);
	} else if (!index(":);{}", c_line_before()) && !c_statement_start()
				&& !(Closeback && just_open(point)))
		return ind;
	else
		ind += get_c_indent();
	return ind;
}


indent_case(orig)	// indent case-like statement at orig
{
	point = orig;
	for (;;) {		// look for case-like statement, or {}'s
		cind_search("([^a-zA-Z0-9_]!(case|default|public|"
					"private|protected)[^a-zA-Z0-9_])|[{}]");
		if (in_c_comment(c_look_back))
			continue;
		else if (curchar() != '}')
			break;
		point++;
		if (!c_rev_skip_level('{', '}')) // move before matching {
			longjmp(&c_indent_giveup, 1);
	}
	if (curchar() != '{')	// copy indentation from prior case
		return get_indentation(point);

	cind_space();	// skip over switch-like construct before {
	if (character(point - 1) == ')') // back past () of switch
		if (!c_rev_skip_level('(', ')'))
			longjmp(&c_indent_giveup, 1);
	to_indentation();
	past_labels();	// might be "case 3: switch ()", get to switch
	point += parse_string(1, "[ \t\f]*");
	return current_column() + get_c_indent() + c_case_offset;
}


to_matching_if()	/* go to matching if statement, assuming we're */
{			/* just before an else keyword */
	int extra_elses = 0;	/* ret 0 if couldn't find it, 1 if ok */

	while (cind_search("<min>(([^a-zA-Z0-9]|^)(else|if)[^a-zA-Z0-9]|})")) {
		if (!in_c_comment(c_look_back)) {
			if (curchar() == '}') {
				point++;	/* find matching { */
				c_rev_skip_level('{', '}');
			} else if (character(point + 1) == 'e')
				extra_elses++;
			else if (--extra_elses < 0)
				return 1;
		}
	}
	return 0;
}

command forward_ifdef()
{
	to_begin_line();
	if (in_c_comment(c_look_back * 2))
		forward_paragraph();
	else
		move_by_ifdef(1);
}

command backward_ifdef()
{
	to_begin_line();
	if (in_c_comment(c_look_back * 2))
		backward_paragraph();
	else
		move_by_ifdef(-1);
}


save_recall(text, key)	// save response to prompt using this key
char *text, *key;
{
	char resp[FNAMELEN * 2];

	save_var matchstart, matchend, user_abort = 0, abort_searching = 0;
	if (*text) {
		save_var bufnum = create(OLDRESP);
		if (size() > recall_maximum_size) {
			point = size() - recall_maximum_size;
			to_begin_line();
			delete(0, point);
		}
		if (strlen(key) + strlen(text) < sizeof(resp) / 2) {
			point = size();		// delete old identical resps
			sprintf(resp, "^%q: %q\n", key, text);
			if (re_search(-1, resp))
				delete(matchstart, matchend);
		}
		point = size();
		bprintf("%s: %s\n", key, text);
	}
}


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

#define MAXARG 200000000

command argument()
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


int dired_ftp_activity();

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


prepare_windows()	/* fix up borders before each window */
{			/* is displayed */
	int i = -1, j = 0, popup, wantmode;

	if (show_spaces != last_show_spaces || using_new_font)
		when_setting_show_spaces();
	popup = (is_window(window_handle) == ISPOPUP);
	_window_flags &= ~WANT_MODE_LINE;
	wantmode = popup ? (_window_flags & FORCE_MODE_LINE)
					 : !(_window_flags & NO_MODE_LINE);
	if (wantmode) {
		_window_flags |= WANT_MODE_LINE;
		j = BORD(MODE_EDGE, -1);
	}
	if (!popup) {
		tiled_window_colors();	// set color scheme for tiled window
		j = tiled_window_border(j);
		if (!(_window_flags & FIXED_BORDERS))
			display_scroll_bar = tiled_scroll_bar && !is_gui;
		i = tiled_border & j;
	} else if (wantmode) {
		i = get_wattrib(window_number, PBORDERS);
		if (!(i & BORD(MODE_EDGE, -1)))
			i |= tiled_border & BORD(MODE_EDGE, -1);
	}
	if (i != -1 && !(_window_flags & FIXED_BORDERS))
		set_wattrib(window_number, PBORDERS, i);
}

tiled_window_border(j)		// adjust border code for this window
{
	if (!want_window_borders) {
		_window_flags &= ~WANT_MODE_LINE;
		return (tiled_scroll_bar && !is_gui) ? BORD(BRIGHT, -1) : 0;
	}
	if (!window_left && border_left)
		j |= BORD(BLEFT, -1);
	if (window_top <= !echo_line && border_top)
		j |= BORD(BTOP, -1);
	if (window_left + window_width >= screen_cols ? border_right
		: border_inside)
		j |= BORD(BRIGHT, -1);
	if (window_top + window_height >= screen_lines - !!echo_line
		&& border_bottom)
		j |= BORD(BBOTTOM, -1);
	return j;
}

// The file has been modified on disk; maybe re-read it without prompting.
maybe_auto_read(struct file_info *now)
{
	int pos;

	// Only auto-read if size on disk is > 90% of current size, or
	// file is very small.
	if (!modified && (now->fsize / 9 >= size() / 10 || size() < 300)) {
		pos = point;
		if (!read_file(filename, translation_type))
			say("%s: Modified file read from disk.", filename);
		else
			auto_read_changed_file = _force_auto_read_changed_file = 0;
		point = pos;
		to_begin_line();
		maybe_add_readonly_once(now);
		return 1;
	}
	return 0;
}

check_dates(save) /* compare this file's time info w/ version on disk */
{		/* 0 means ok, 1 means cancel save */
	struct file_info now, *then = &file_info;
	int ret = 1, temp, orig = bufnum, pos;

	if (number_of_popups() > 0)	// Don't pop up over bufed or similar.
		return 0;
	ignoring_file_change = 0;	// Resume checking on getting focus.
	if (!want_warn || !filename || then->check_type != CHECK_FILE
			|| check_file(filename, &now) != CHECK_FILE)
		return 0;
	update_readonly_warning(&now);
	if (!compare_dates(&now, then)) {
		maybe_add_readonly_once(&now);
		return 0;
	}
	switch_to_buffer(bufnum);
	maybe_add_readonly_once(&now);
	if ((auto_read_changed_file || _force_auto_read_changed_file)
		&& !save && maybe_auto_read(&now))
		return 1;
	tiled_only();
	switch_to_buffer(bufnum);
	maybe_ding(bell_on_date_warning);
	temp = tmp_buf();
	save_var _view_right = 0, _view_bottom = screen_lines - 22;
	save_var return_raw_buttons = 1;
	while (!user_abort) {
		show_date_warning(temp, orig, then, &now, save);
		bufnum = orig;
		pos = point;
		if (is_gui && want_gui_prompts) {
			int win, owin = window_handle;

			remove_final_view();
			save_var _doing_input = DI_VIEW;
			win = add_popup(0, 0, 75, 15, _view_border, temp);
			go_to_link = 0;
			display_dialog_box("FileDateBox2", "File has changed on disk",
							   win, 0, 0,
							   "Compare", "Read", save ? "Save" : "Ignore");
			text_color = color_class viewed_text;
			point = 0;
			view_loop(win);
			switch (key_is_button) {
				case 1:	key = 'C'; break;
				case 2:	key = 'R'; break;
				case 3:	key = save ? 'S' : 'I'; break;
			}
			window_handle = owin;
			remove_window(win);
			if (user_abort)
				break;
		} else {
			view_buf(temp, 0);
			if (user_abort)
				break;
			getkey();
		}
		key = toupper(key);
		if (key == 'C') {
			refresh();
			split_window_vertically();
			window_number--;	/* to 1st window */
			find_in_other_buf(filename, translation_type);
			point = pos;
			to_begin_line();
			set_buffer_filename("");
			error("This buffer has disk version.");
			break;		/* abort out of calling func */
		} else if (key == 'R') {
			refresh();
			if (!read_file(filename, translation_type))
				say("%s: Read from disk.", filename);
			point = pos;
			to_begin_line();
			break;
		} else if (key == (save ? 'S' : 'I')) {
			if (key == 'I')
				ignoring_file_change = 1;	// Don't check on getting focus.
			refresh();
			ret = 0;
			break;
		} else if (key == '!')
			want_warn = !want_warn;
		else if (key == 'A')
			ask_read_changed_file();
		say("");
	}
	buf_delete(temp);
	return user_abort ? 1 : ret;
}

gui_print(jobname, fname)
char *jobname, *fname;
{
	int height = print_options.height;	// Leave room for our heading.
	int win, cnt, scheme;

	if (print_heading)		// any heading takes 2 lines (one blank)
		height -= 2;
	if ((print_heading & (PRHEAD_PAGECNT | PRHEAD_DATE))
		&& (print_heading & PRHEAD_FNAME))
		height--;			// a two-line heading
	if (!start_print_job(jobname))
		error("Printing failed.");
	save_var window_handle;
	win = create_invisible_window(print_options.width, height, bufnum);
	if (print_color_scheme && (scheme = find_index(print_color_scheme))
		&& name_type(scheme) == NT_COLSCHEME)
		window_color_scheme = scheme;
	cnt = send_printed_pages(fname);
	remove_window(win);
	end_print_job();
	say("%d page%s printed.", cnt, cnt == 1 ? "" : "s");
}


find_it(fname, strip)	/* find named file (must be in absolute form) */
char *fname;
{
	if (!*fname)
		return 2;
	if (look_file(fname)) {
		save_var _force_auto_read_changed_file = 1;
		to_buffer(bufname);
		return 0;
	}
	return find_in_other_buf(fname, strip);
}

find_in_other_buf(fname, transl)
char *fname;
{
	char bname[FNAMELEN+10];
	int err;

	make_bname(fname, bname);
	to_buffer(bname);
	file_io_converter = new_file_io_converter;
	err = read_file(fname, transl);
	call_mode(filename);
	make_mode();
	return err;
}

look_up_tree(res, file, dir, stop)
char *res, *file, *dir, *stop;
{
	char subdir[FNAMELEN];
	int len, last = 1000;

	if (dir)
		strcpy(subdir, dir);
	else
		getcd(subdir);
	for (;;) {
		if (stop && *stop && fnamecmp(subdir, stop)
			&& !is_in_tree(subdir, stop))
			return 0;
		strcpy(res, file);
		absolute(res, subdir);
		if (check_file(res, NULL) == CHECK_FILE)
			return 1;
		*get_tail(subdir, 0) = 0;
		len = strlen(subdir);
		if (len > 3 && is_path_separator(subdir[len - 1]))
			subdir[--len] = 0;
		if (len >= last)
			break;
		last = len;
	}
	return 0;
}


do_grep(buf, pat, flags, filepat, inbufs)
char *buf, *pat, *filepat;
{
	int res = 0, aborted = 0, cnt = 0, start, tempbuf = 0;
	int orig, before_head, this_err;
	char *s, rel[FNAMELEN], abs[FNAMELEN], search_type[80], *(*finder)();

	create(buf);
	if (grep_empties_buffer)
		zap(buf);
	locate_window(buf, "");
	point = size();
	if (size())
		bprintf("\n");	/* separate from previous query */
	make_search_prompt(search_type, flags & SMODES);
	before_head = point;
	bprintf("Found 0 lines with %s\"%s\" in %s\n",
			search_type, pat, filepat);
	set_character_color(before_head, point, color_class grep_filename);
	start = point;
	if (display_column.default != -1)
		display_column = 0;	/* horizontally scroll this window */
	grep_mode();
	finder = give_grep_finder(inbufs, filepat, &s);	// get 1st match
	save_var readonly_warning = 0;
	orig = bufnum;
	for (; s; s = (*finder)(filepat, 0)) {
		grep_make_names(rel, abs, s, inbufs);
		noteput("%d matches, searching %s...", cnt, rel);
		if (inbufs)	// skip over grep results buffer
			this_err = !strcmp(s, buf);
		else if (!look_file(abs)) {
			this_err = find_it(abs, default_translation_type);
			if (!grep_keeps_files)
				tempbuf = bufnum;
		} else
			this_err = 0;
		if (this_err == EREADABORT || user_abort) {
			aborted = 1;
			break;
		} else if (this_err) {
			window_bufnum = orig;
			if (tempbuf)
				buf_delete(tempbuf);
			tempbuf = 0;
			continue;
		}
		res = copy_matches(name_to_bufnum(buf), flags, pat, rel);
		window_bufnum = orig;
		if (res < 0)	/* error occurred during search */
			break;
		else if (res > 0) {
			cnt += res;
			build_first = 1;
			point = start;
			delete(point, before_head);
			bprintf("Found %d lines with %s\"%s\" in %s\n",
					cnt, search_type, pat, filepat);
			start = point;
			point = size();
			refresh();
		}
		if (tempbuf)
			buf_delete(tempbuf);
		tempbuf = 0;
	}
	window_bufnum = orig;
	point = start;
	build_first = 1;
	if (tempbuf)
		buf_delete(tempbuf);
	say("");
	if (aborted)
		quick_abort();
	if (res == -DSBAD)
		error("Illegal search pattern: %s", pat);
	else if (res != -DSABORT && cnt) {
		locate_window(buf, "");
		modified = 0;
		point = start;
	}
}


do_drop_matching_lines(flags, pat, drop)
char *pat;		// keep or drop lines after pt matching pattern
{
	int res, here, there, cnt = 0;

	save_spot point;
	to_begin_line();
	for (;; cnt++) {
		here = point;
		res = do_searching(flags, pat);
		if (res != 1 || point == ((flags & REVERSE) ? narrow_start
			: size() - narrow_end))
			break;
		there = give_begin_line();
		nl_forward();
		delete(there, drop ? point : here);
	}
	if (!res && !drop)
		delete(here, size());
	if (!res)
		say("Deleted %s%d lines.", drop ? "" : "all but ", cnt);
	else if (res == DSBAD)
		error("Bad search pattern: %s", pat);
	return cnt;
}

add_help_line(s)
char *s;
{
	one_help_line(s, "api32.hlp", "Windows API (32-bit)"); // VC2
	one_help_line(s, "win32.hlp", "Windows API (32-bit)");	// Old name
	one_help_line(s, "win31wh.hlp", "Windows API (16-bit)"); // VC1
	one_help_line(s, "tcwhelp.hlp", "Windows API (16-bit)"); // BC3.1
	one_help_line(s, "mfc.hlp", "MFC v1.0"); // VC1
	one_help_line(s, "mfc20.hlp", "MFC v2.0"); // VC2
	one_help_line(s, "mfc30.hlp", "MFC v3.0"); // VC2
	one_help_line(s, "cxx20.hlp", "C/C++ Language"); // VC2
	one_help_line(s, "mscxx.hlp", "C/C++ Language (VC 1.X)"); // VC1
	one_help_line(s, "crt20.hlp", "MSVC 2.X Run Time"); // VC2
	one_help_line(s, "msvc20.hlp", "MSVC 2.X Tools"); // VC2
	one_help_line(s, "mscopts.hlp", "MSVC 1.X Build Tools"); // VC1
	one_help_line(s, "classlib.hlp", "Borland Class Library"); // BC5
	one_help_line(s, "bcpp.hlp", "Borland C/C++ Library"); // BC5

		// MSDL interface (not actually help files)
	one_help_line(s, "msdntool.exe", "Find in MSDL");
	one_help_line(s, "msdntool.exe", "Look Up Keyword in MSDL");
		// MSDL interface (not actually help files)
	one_help_line(s, "iv2tool.exe", "Find in MSDL");
	one_help_line(s, "iv2tool.exe", "Look Up Keyword in MSDL");
}

color_html_attributes(script)
{
	int len, start, java = 0;

	while (len = parse_string(1, "[-_./a-z0-9]*")) {	// An attribute?
		if (script && parse_string(1, "(language|type)[ \t\n]*=[ \t\n]*"
								   "[\"']*(text/)?(javascript|jscript)"))
			java = 1;
		set_character_color(point, point + len, color_class html_attribute);
		point += len;			// Followed by a value?
		if (len = parse_string(1, "[ \t\n]*=[ \t\n]*")) {
			set_character_color(point, point + len, color_class html_text);
							// Color the = and whitespace.
			point += len;		// Value might be quoted.
			start = point;
			if (curchar() == '"') {
				point++;
				search(1, "\"");
			} else if (curchar() == '\'') {
				point++;
				search(1, "'");
			} else	// No quotes, assume it's whitespace-delimited.
				re_search(1, "[^ \t\n<>]*");
			set_character_color(start, point, color_class html_value);
		}
		re_search(1, "[ \t\n]*");	// Parse whitespace.
		set_character_color(matchstart, matchend, color_class html_text);
	}
	start = point;
	if (script) {
		if (search(1, "</script>"))
			point = matchstart;
		if (java && html_javascript_coloring) {
			save_var narrow_end = size() - point;
			save_var c_extra_keywords |= JAVA_KEYWORDS;
			color_c_range(start, point);
		} else
			set_character_color(start, point, color_class html_attribute);
	}
}

color_html_comment()
{
	int s;

	search(-1, "<");	// Find start of comment.
	s = point;
	if (parse_string(1, "%<[ \t\n]*%![ \t\n]*-"))	// A legal comment?
		re_search(1, "-[ \t\n]*>");	// Search for end of legal comment.
	else	// Some odd flavor of comment; don't be too picky about its end.
		search(1, ">");
	set_character_color(s, point, color_class html_comment);
}

color_html_include()
{
	int s;

	search(-1, "<");	// Find start of include.
	s = point;
	search(1, "%>");
	set_character_color(s, point, color_class html_attribute);
}

color_html_move_back()
{
	int start = point;

	if (re_search(-1, "<Langle>[ \t\n]*/?script")
		&& parse_string(1, "<Langle>[ \t\n]*script"))
		return;				// Found a <script>, not a </script>.
	point = start;
	if (re_search(-1, "<Langle><Percent>|<Percent><Rangle>")
		&& curchar() == '<')
		return;				// Found a <%, not a %>.
	point = start;
	do {			// start coloring from the previous tag
		if (!search(-1, "<"))
			break;	// but ignore <'s before " or ' characters
		if (get_character_color(point, NULL, NULL)
			== color_class html_comment)	// If we're in a comment,
			re_search(-1, "%<%!--");	// go back to its start.
	} while (parse_string(-1, "[\"'].*"));
}

color_html_range(from, to) // recolor just this section
{			// last colored region may go past to
	int s, script;

	if (from >= to)
		return to;
	save_var point, matchstart, matchend;
	if (from < to)
		set_character_color(from, to, color_class html_text);
	point = from;
	save_var case_fold = 1;
	color_html_move_back();
	for (s = point; point < to && re_search(1, "[<&]"); s = point) {
		if (character(point - 1) == '&') {
			set_character_color(s, point - 1, color_class html_text);
			s = point - 1;	 // Color an entity like &amp; or &#251;
			if (parse_string(1, "([a-z]+|#[0-9]+);?"))
				point = matchend;
			set_character_color(s, point, color_class html_entity);
			continue;
		}
		re_search(1, "[ \t\n]*");	// Parse < followed by whitespace.
		set_character_color(s, point, color_class html_text);
		if (curchar() == '!')
			color_html_comment();
		else if (curchar() == '%')
			color_html_include();
		else if (s = parse_string(1, "[-_./a-z0-9]*")) { // Parse the tag.
			set_character_color(point, point + s, color_class html_tag);
			script = (s == 6 && parse_string(1, "script"));
			point += s;			// Look for javascript tag.
			re_search(1, "[ \t\n]*");	// Parse whitespace.
			set_character_color(matchstart, matchend,
								color_class html_text);
			color_html_attributes(script);
		}
	}
	return point;
}

suffix_asp()
{
	html_mode();
}

suffix_asa()
{
	html_mode();
}


pick_rectangle(copy, remove)	/* copy => push copy of rectangle */
{				/* remove => take out rectangle */
	iter = 0;		/* remove>1 => and put spaces instead */
	if (remove)
		check_modify(bufnum);
	if (copy) {
		check_num_kill_buffers();
		push_kill();
		_kill_width[_num_kill] = extract_rectangle(
			name_to_bufnum(_cur_kill_buf), remove);
		save_to_clipboard();
	} else
		extract_rectangle(0, remove);
	set_region_type(REGRECT);
}

retrieve(withpop)	/* insert text from kill buffer */
{
	char *thisbuf = bufname;
	int overwrite = over_mode;

	check_modify(bufnum);
	check_num_kill_buffers();
	if (_kill_width[_num_kill] == UNUSED)	/* no kills yet */
		return;
	if (withpop && !pop_retrieve())
		error("Must follow yank or yank-pop");
	if (_kill_width[_num_kill] == REGION_LINE)
		to_begin_line();
	_oldfrom = point;		/* record start of yank */
	undo_flag = UNDO_FLAG_KILL;	/* mark in undo list */
	bufname = _cur_kill_buf;
	if (bufname == thisbuf)		/* ignore yanking to kill buffer */
		return;
	switch (_kill_width[_num_kill]) {
		case REGION_LINE:
			set_region_type(REGLINE);
			break;
		case REGION:
			set_region_type(REGNORM);
			break;
		default:
			set_region_type(REGRECT);
			break;
	}

	if (region_type() != REGRECT) {
		xfer(thisbuf, 0, size());
		bufname = thisbuf;
		_oldto = point;		/* end of yank */
		if (iter >= 0)
			do_reindent_after_yank();
	} else {			/* yank rectangle */
		xfer_rectangle(name_to_bufnum(thisbuf),
					   _kill_width[_num_kill], overwrite);
		bufname = thisbuf;
		point = _oldfrom;	/* go to start of yank */
		_oldto = mark;		/* end of yank */
	}
	build_first = 1;		/* redisplay hint */
}

do_reindent_after_yank()
{
	int tmp, orig = bufnum, from, to, stuff_before, max;
	jmp_buf this_level;

	max = get_mode_variable("reindent_after_%s_yank");
	if (got_bad_number)
		max = reindent_after_yank;
	if (!max || max > 0 && point - mark > max)
		return;	// Text is too large.
	stuff_before = matches_at(mark, -1, "^.*[^ \n\t].*") > 0;
	if (lines_between(mark, point, 0) < 1) {
		if (parse_string(1, "[ \t]*[^ \t\n]"))
			return;
		if (stuff_before)	// Other stuff on the line, don't reindent.
			return;
	}
	save_var narrow_start = 0, narrow_end = 0;
	if (reindent_c_comments == 1)
		save_var reindent_c_comments = 0;
	if (reindent_one_line_c_comments == 1)
		save_var reindent_one_line_c_comments = 0;
	from = mark;	// Make a copy of the buffer and do indenting
	to = point;		// there, so undo records just one operation.
	tmp = tmp_buf();	// (Yank-pop requires undo.)
	buf_xfer(tmp, 0, size());
	bufnum = tmp;
	mark = from;
	point = to;
	safe_copy_buffer_variables(tmp, orig);	// Duplicate bufvars into tmp.
	save_var top_level = &this_level;
	if (!setjmp(top_level)) {
		spot end = alloc_spot(1);
		save_var iter = 1, has_arg = 0;
		if (stuff_before) {		// Don't indent the first line; 
			exchange_point_and_mark();	// there was already an indent.
			nl_forward();
			exchange_point_and_mark();
		}
		indent_region();
		if (!buffers_identical(orig, tmp)) {
			fix_region();
			if (stuff_before)	// Indent-region can expand the region.
				point = from;
			else
				from = point;
			to = size() - *end;
			delete(0, point);	// Discard all but the region.
			delete(*end, size());
			bufnum = orig;
			delete(from, size() - to);
			grab_buffer(tmp);
			_oldfrom = mark;
			_oldto = point;		/* end of yank */
		}
	}					// User aborted, just clean up.
	bufnum = orig;
	buf_delete(tmp);
}

menu_invoked()
{
	int i;

	if (_doing_input == DI_LINEINPUT && is_gui) {
		ungot_key = key;
		error_if_input(1);
	}
	if (*menu_command == '$') {		// help file
		char old[FNAMELEN], dir[FNAMELEN];
// MSVC 2 wants the current directory to be \msvc20\bin, when using the help
// file \msvc20\help\xxx.hlp.  The other help files we know about don't care.
// So temporarily set the current directory based on the help file name.
		getcd(old);
		strcpy(dir, menu_command + 1);
		*get_tail(dir, 0) = 0;
		sprintf(get_tail(dir, 0), "bin");
		chdir(dir);
		windows_help_from(menu_command + 1, winhelp_display_contents);
		chdir(old);
		return;
	} else if (*menu_command == '!') {
		run_by_pattern(menu_command + 1);
		return;
	}
	save_var run_by_mouse = 1;
	i = find_index(menu_command);
	switch (name_type(i)) {
		case NT_MACRO:
			run_by_mouse = 0;
		case NT_COMMAND:
		case NT_SUBR:
		case NT_AUTOLOAD:
		case NT_AUTOSUBR:
			add_key_to_macro(CMD_INDEX_KEY + i);
			do_command(i);
			break;
		case NT_WINVAR:
		case NT_BUFVAR:
		case NT_VAR:
		case NT_BUILTVAR:
			do_set_variable(i);
			break;
		default:
			error("Couldn't call `%s' from menu.", menu_command);
	}
}

mouse_selecting()	// using left button to select text
{
	int orig, by_words = IS_MOUSE_DOUBLE(key);

	save_var mouse_auto_on = 0;	/* movements won't show mouse */
	to_mouse_window(mouse_x, mouse_y, mouse_screen);
	orig = point;
	refresh();
	to_mouse_position(mouse_x, mouse_y);
	mouse_display = (by_words && mouse_graphic_cursor);
	if (!(mouse_shift & KB_SHIFT_DN)) {	/* not extending */
		if (is_highlight_on() && point_in_region(orig)) {
			drag_and_drop(orig);
			return;
		}
		mark = point;		/* put one end here */
		if (virtual_space >= 2)
			mark_to_column = cursor_to_column;
		highlight_off();
	}
	refresh();
	select_loop(by_words, 1);
}

command toggle_scroll_bar()	// want constant scroll bar on tiled wins?
{
	tiled_scroll_bar = has_arg ? (iter != 0) : !tiled_scroll_bar;
	border_right = (!is_gui && tiled_scroll_bar);
	full_redraw = 1;
}


command mouse_move()
{			/* maybe pop up a menu or something */
	if (!permanent_menu && is_menu_here())
		show_menu_while_over();
	else {
		if (is_gui && !mouse_screen) {
			int win = get_window_area();
			if (mouse_over_border(win, mouse_y, BBOTTOM) &&
				mouse_y + 1 != echo_line
				|| mouse_over_border(win, mouse_y, BTOP))
				mouse_cursor = &vert_arrows;
			else if (mouse_over_border(win, mouse_x, BLEFT)
					 || mouse_over_border(win, mouse_x, BRIGHT))
				mouse_cursor = &horiz_arrows;
			else
				mouse_cursor = &std_pointer;
		} else if (!is_gui && tiled_scroll_bar)
			mouse_cursor = on_scroll_bar() ? &right_pointer
										   : &std_pointer;
		else if (on_scroll_bar())
			show_scroll_bar();
		if (ungot_key == -1 || ungot_key == MOUSE_MOVE)
			invisible_cmd();
	}
}

drag_drop_handler()
{
	char buf[FNAMELEN], *s;
	int line = -1, j;

	tiled_only();
	if (mouse_screen >= 0)
		to_mouse_window(mouse_x, mouse_y, mouse_screen);
	while(drag_drop_result(buf)){
		if (*buf == '+') {			// a +linenum parameter
			line = numtoi(buf + 1);
		} else if (*buf == '-') {
			switch (buf[1]) {
				case 'd':
					s = index(buf + 2, '=');
					if (!s)		// accept either VAR=VAL or VAR!VAL
						s = index(buf + 2, '!');
					if (!s)
						break;
					*s = 0;
					if (j = find_index(buf + 2)) {
						set_var_val(j, s + 1, 1);
						continue;
					} else
						say("No such variable %s.\n", buf + 2);
					break;
				case 'l':
					load_commands(buf + 2);
					break;
				case 'r':
					try_calling(buf + 2);
					break;
			}
			continue;
		} else if (*buf) {
			absolute(buf);
			do_find(buf, default_translation_type);
			if (line >= 0) {
				go_line(line);
				line = -1;
			}
		}
	}
}

command view_process()
{
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


try_auto_show_delimiter(int dir, char *near, char *far)
{
	int orig, there;

	save_var point;
	if (dir > 0) {	// Only go one line forward, and not too far back.
		save_var narrow_start = give_begin_line();
		save_var narrow_end = size() - (point + c_look_back);
	} else {		// Only go one line back, and not too far forward.
		save_var narrow_start = ++point - c_look_back;
		save_var narrow_end = size() - give_end_line();
	}
	orig = point;
	if (!move_level(dir, near, far, 0))
		return 0;
	there = point;
	if (!move_level(-dir, far, near, 0) || point != orig)
		return 0;
	if (there < point) {
		*show_matching_start_spot = there;
		*show_matching_end_spot = point - 1;
	} else {
		*show_matching_start_spot = point;
		*show_matching_end_spot = there - 1;
	}
	return 1;
}

/* s_code: where to start searching from */
#define FHERE	1	/* from right here */
#define FORIG	2	/* from starting position */
#define FMATCH	3	/* from last match */
#define FMADD	4	/* same, but indicates we added a char this time */
#define FMREGEX	5	/* same, but don't assume too much about pattern */

search_read(trystr, prmpt, flags)
char *trystr, *prmpt;
{
	int lastok, goodchars, oldflags, mstart, origwin = window_handle;
	int editbuf, pbuf, pwin, editwin, s_code, okpoint, orig, ostart;
	int oreg_type, old_mark = -1;

	if (_doing_input == DI_SEARCH)
		error_if_input(0);
	if (is_highlight_on() && point != mark && ABS(point - mark) < 200
		&& !*trystr && typing_deletes_highlight) {
		old_mark = mark;	// Use this as the initial search string.
		highlight_off();
	}
	save_var iter, has_arg, this_cmd, prev_cmd;
	save_var _doing_input = DI_SEARCH;
	save_var last_index;
	save_var mark = point, _highlight_control;
	save_var postpone_asynchronous_notify = 1;
	oreg_type = region_type();
	set_region_type(REGNORM);
	orig = okpoint = mstart = point;
	ostart = window_start;
	goodchars = lastok = 0;	/* 2 versions of len of last good string */
				/* (only lastok is set by getting default) */

	editbuf = tmp_buf();		/* make buffer for cmd line editing */
	pwin = add_popup(0, echo_line, screen_cols - 1, 1, 0,
			pbuf = tmp_buf());	/* prompt in window */
	stuff(trystr);
	display_column = 0;
	system_window = 1;	/* don't let user switch to it */
	text_color = color_class echo_area;

	editwin = add_popup(1, echo_line, screen_cols - 1, 1,
			0, editbuf);	/* window on top of prompt window */
	text_color = color_class echo_area;
	_display_class = _echo_disp_class;
	display_column = 0;

	if (old_mark != -1) { // Start out with highlighted region.
		window_handle = origwin;
		buf_xfer(editbuf, old_mark, point);
		window_handle = editwin;
		point = 0;
		if (flags & REGEX)	// Quote special chars.
			string_replace("[[%.!#()*+|?^$<]", "%#0", REGEX);
		point = size();
		highlight_on();		// Mark it so user can delete by typing.
	}

	for (;;) {
		do {
			show_search_prompt(prmpt, flags, origwin,
					   pwin, editwin);
			getkey();
		} while (key == MOUSE_MOVE);
		if (IS_MOUSE_KEY(key))
			if (mouse_y == echo_line)
				flags &= ~INCR;
			else {
				user_abort = 1;
				goto end;
			}
		if (key == CTRL('^'))
			full_getkey("", CTRLIFY_KEY);
		window_handle = editwin;
		s_code = 0;
		oldflags = flags;
		flags &= ~(BAD | FAILING | SONCE);	/* assume ok */
		if (is_search_dir()) {
			window_handle = origwin;
			point = okpoint;
			window_handle = editwin;
			if ((key == CTRL('R')) != ((flags & REVERSE) != 0)) {
				flags ^= REVERSE;	/* switch dir */
				if (goodchars)
					flags |= SONCE;
				lastok = size();
			} else if (!size()) {
				if (flags & UNKNOWN)
					flags = known_flags(flags);
get_defaults:			stuff(default_search_string(flags & REGEX));
				lastok = size();
			} else if (oldflags & FAILING)
				flags |= FAILING; /* maybe search again */
			else
				flags |= SONCE;
			if ((flags & (INCR | SONCE)) && !(flags & FAILING))
				flags |= SONCE, s_code = FHERE;
		} else if (set_flag_modes(&flags)) {
			if ((flags & INCR) && size())
				s_code = FMATCH; /* if modes changed, search again */
		} else if (key == CTRL('O')) {
			flags ^= INCR;
			point = size();
			if (flags & INCR)
				s_code = FMATCH;
		} else if (reg_tab[key] == (short) help)
			help_on_command(help_on_search(flags));
		else if (IS_ENTER_KEY(key)) {
			if (oldflags & SONCE)
				flags |= SONCE;
			break;
		} else if (reg_tab[key] == (short) backward_delete_character
						&& (flags & INCR)) {
			run_topkey();
			window_handle = editwin;
			if (!(oldflags & FAILING) || size() <= lastok)
				s_code = FORIG;
			else		/* don't bother searching */
				flags |= FAILING;
		} else if (key == abort_key && (oldflags &
					((flags & INCR) ? FAILING : SONCE))) {
			if (flags & INCR)
				delete(goodchars, size());
		} else if (comp_tab[key] == (short) inp_recall
			   && (IS_ALT_KEY(key) || !(flags & INCR))) {
			flags = pick_prev_search(flags) & ~INCR;
			if (user_abort)
				break;
		} else if (user_abort || (flags & INCR) && exit_incr())
			break;
		else {
			flags &= ~UNKNOWN;
			if ((comp_tab[key] == (short) inp_grab_word
			     || comp_tab[key] == (short) inp_grab_line)
			    && (IS_ALT_KEY(key) /*|| !(flags & INCR) */ )) {
				if (!(oldflags & FAILING)) {
					if (grab_search_word(flags, origwin,
						(comp_tab[key] == (short) inp_grab_line))) {
						window_handle = origwin;	// Move origin
						mstart = orig = point;		// to start of word.
						window_handle = editwin;
						s_code = FORIG;
					} else
						s_code = (flags & REVERSE) ? FHERE : FMREGEX;
				}
			} else if (key == '\t')
				normal_character();
			else
				run_topkey();
			window_handle = editwin;
			if (flags & INCR)
				if (flags & (REGEX | WORD))
					s_code = FMREGEX;
				else if (oldflags & FAILING)
					flags |= FAILING;
				else
					s_code = FMADD;
		}
		_doing_input = DI_SEARCH;
		if (!is_window(origwin) || !is_window(editwin)
		    || !is_window(pwin)) {	// user deleted our window
			user_abort = 1;
			goto end;
		}
		user_abort = 0;
		grab(0, FNAMELEN - 1, trystr);
		if (!s_code)
			continue;
		window_handle = origwin;
		if (s_code == FORIG || s_code == FMREGEX)
			point = orig;
		else if (s_code >= FMATCH) {
			point = mstart;
			if (flags & REVERSE)
				point++;
		}
		_highlight_control = 0;
		switch (do_searching(flags, trystr)) {
			case DSBAD:
				flags = BAD | (flags & ~INCR);
			case 0:	flags |= FAILING;
				point = okpoint;
				if (in_macro())
					goto end;
				else if (!(oldflags & FAILING))
					maybe_ding(bell_on_search);
				break;
			case 1:	okpoint = point;
				mark = mstart = matchstart;
				highlight_on();
				window_handle = editwin;
				goodchars = lastok = size();
				break;
			case DSABORT:
				point = okpoint;
				window_handle = editwin;
				if ((flags & INCR) && s_code == FMADD)
					delete(size() - 1, size());
				break;
		}
	}
	window_handle = origwin;
	if (key == abort_key || user_abort)
		point = orig, window_start = ostart;
	else {
		window_handle = editwin;
		if (size()) {
			_last_was_regex = ((flags & REGEX) != 0);
			*(_last_was_regex ? &_default_regex_flags
					  : &_default_flags) = flags;
			grab(0, FNAMELEN - 1, trystr);
			strcpy(default_search_string(_last_was_regex), trystr);
			save_search_recall(flags, trystr);
		}
		if ((flags & INCR) && !IS_ENTER_KEY(key) && key != ESC)
			ungot_key = key;
	}
end:	if (is_window(origwin))
		window_handle = origwin;
	set_region_type(oreg_type);
	remove_window(editwin);
	remove_window(pwin);
	buf_delete(editbuf);
	buf_delete(pbuf);
	if ((flags & FAILING) && in_macro())
		error("%s: not found", trystr);
	check_abort();
	say("");
	restore_vars();
	maybe_refresh();	/* put cursor back in prev window */
	return flags;
}

save_search_recall(int flags, char *str)
{
	char srch[FNAMELEN + 30], *p;

	sprintf(srch, "%s%s%s",
			!(flags & MODFOLD) ? "" : (flags & FOLD) ? "Fold " : "Nofold ",
			(flags & WORD) ? "Word " : "",
			(flags & REGEX) ? "Regex " : "");
	p = srch + strlen(srch);
	if (p > srch)
		p--;		// move back over <Space> at end
	strcpy(p, ": ");
	strcpy(p + 2, str);
	save_recall(srch, "search");
}


struct find {
	char *find_text;
	char *replace_text;
	int flags;
} find_data;		// The find dialog looks at this variable directly.

// Set the default search string & mode, and record in list of strings.
record_search(flags, s)
char *s;
{
	_last_was_regex = ((flags & REGEX) != 0);
	*(_last_was_regex ? &_default_regex_flags : &_default_flags) = flags;
	strcpy(default_search_string(flags & REGEX), s);
	save_search_recall(flags, default_search_string(flags & REGEX));
	if (find_data.replace_text) {
		save_recall(find_data.replace_text, "replace");
		strcpy((flags & REGEX) ? _default_regex_replace : _default_replace,
			   find_data.replace_text);
	}
}

sort_region_with_settings(from, to, col, rev, buf)
{	/* sort a region in place, using case-folding from buf */
	char *temp1 = temp_buf(), *temp2 = temp_buf();
	char *this_srch_case_map;
	int this_tab_size, this_case_fold, this_sort_case_fold;
	int res = ABORT_JUMP, orig = bufnum;
	jmp_buf this_level;

	bufnum = buf;
	this_srch_case_map = _srch_case_map;
	this_case_fold = case_fold;
	this_sort_case_fold = sort_case_fold;
	this_tab_size = tab_size;

	bufnum = orig;
	save_var sort_status = 1;
	save_var top_level = &this_level;
	if (!setjmp(top_level)) {
		xfer(temp1, from, to);
		bufname = temp1;
		case_fold = this_case_fold;
		sort_case_fold = this_sort_case_fold;
		_srch_case_map = this_srch_case_map;
		tab_size = this_tab_size;
		res = do_buffer_sort(temp2, col, rev);
		if (!res) {
			bufnum = orig;
			delete(from, to);
			bufname = temp2;
			buf_xfer(orig, 0, size());
		}
	}
	bufnum = orig;
	delete_buffer(temp1);
	delete_buffer(temp2);
	return res;
}

command move_to_window()
{
	int dir, edge, row, col, max_cols = screen_cols;

	tiled_only();
	while ((dir = get_direction()) == -1) {
		say("Move to window (press an arrow key)");
		getkey();
		check_abort();
	}
	edge = get_wattrib(window_number, dir);
	get_window_pos(point, &row, &col);	/* get pt's window coords */
	row += window_top;		/* convert to screen coords */
	col += window_left;
	switch (dir) {
		case BTOP:	row = edge - 1; break;
		case BBOTTOM:	row = edge + 1; break;
		case BLEFT:	col = edge - 1; break;
		case BRIGHT:	col = edge + 1; break;
	}				/* now adjust to screen bounds */
	if (is_gui && col == screen_cols && (dir == BTOP || dir == BBOTTOM))
		col--;			// Cursor can be after all characters.
	row = (row + screen_lines - 1) % (screen_lines - 1);
	col = (col + max_cols) % max_cols;
	window_handle = window_at_coords(row, col);
	say("");
	switching_to_buffer();
	check_dates(0);
}

#include "browse.e"
#include "clipboar.e"

int color_ftp_log_range(int from, int to);

ftp_activity(int activity, int buf, int from, int to)
{
	char msg[FNAMELEN];
	int show_log = 0;

	if (!buf_exist(buf))
		return;
	save_var iter, has_arg;
	save_var bufnum = buf;
	switch (activity) {
		case NET_DONE:
			if (translation_type == FILETYPE_AUTO
				&& ftp_job->operation == FTP_RECV)
				translation_type = new_buffer_translation_type;
			if (!modified && !point) {
				save_var undo_size = 0;
				undo_mainloop();
			}
			free(ftp_job);		// Fall through.
		case NET_LOG_DONE:
			ftp_job = 0;
			set_mode_message(NULL);
			break;
		case NET_RECV:
			if (!from)
				position_in_all_windows(buf, 0);
			show_ftp_percent("got", from);
			break;
		case NET_SEND:
//			ftp_job->so_far = from;
			ftp_job->file_size = to;
			show_ftp_percent("sent", from);
			break;
		case NET_LOG_WRITE:
			save_var point = from;	// Get file size from msg.
			if (re_search(1, "^150 ") && re_search(1, "[0-9]+ bytes")) {
				char filesize[100];
				grab(matchstart, matchend, filesize);
				if (numtoi(filesize) && !got_bad_number)
					ftp_job->file_size = numtoi(filesize);
			}
			point = from;
			if (found_ftp_status("^220 "))	// Welcome msg.
				set_both_mode_message("[FTP: Sending user name] ");
			if (found_ftp_status("^331 "))	// Host wants password.
				set_both_mode_message("[FTP: Sending password] ");
			if (found_ftp_status("^230 "))	// User logged in.
				set_both_mode_message("[FTP: Working] ");
			if (found_ftp_status("^530 "))	// Bad password.
				discard_password_data();
			if (re_search(1, "^[45][0-9][0-9] ")) {
				parse_string(1, ".*", msg);		// Some error code.
				say("FTP error: %s", msg);
				// Don't go to log if we're just creating a new file.
				if (ftp_job->operation != FTP_RECV
					|| !parse_string(-1, "^550 .*"))
					show_log = 1;
			}
			break;
	}
	if (buffer_ftp_activity)	// Do some buffer-specific FTP work.
		buffer_ftp_activity(activity, buf, from, to);
	switch (activity) {		// These don't automatically refresh later.
		case NET_DONE:
		case NET_LOG_DONE:
		case NET_SEND:
			refresh();
			break;
	}
	if (show_log) {
		if (number_of_popups() > 0) {
			say("FTP errors occurred, see buffer %s.",
				buf_exist(ftp_job->log_buf) ?
				bufnum_to_name(ftp_job->log_buf) : "<deleted>");
			return;
		}
		restore_vars();
		save_var iter, has_arg;
		save_var bufnum = buf;
		if (buf_exist(ftp_job->buf)) {
			to_buffer_num(ftp_job->buf);
			if (ftp_job->operation == FTP_SEND)
				modified = 1;
		}
		if (buf_exist(ftp_job->log_buf))
			to_buffer_num(ftp_job->log_buf);
		point = size();
		refresh();
		restore_vars();
		bufnum = window_bufnum;
	}
	restore_vars();
	if (number_of_popups() > 0 && !strcmp(bufname, CONNECT_LIST_BUF)) {
		int line = lines_between(0, point, 0) + 1, col = current_column();
		make_connect_list();
		go_line(line);
		move_to_column(col);
		refresh();
	}
}


discard_password_data()
{
	char hostname[FNAMELEN], username[FNAMELEN];
	save_var point, case_fold = 1;
	if (!re_search(-1, "^000 Connecting to !"))
		return;
	parse_string(1, ".*", hostname);
	if (!re_search(1, "^user "))
		return;
	parse_string(1, ".*", username);
	get_password(NULL, hostname, username);	// Discard password.
}


command show_connections()
{
	char msg[500], *s;

	win32_only();
	make_connect_list();
	if (number_of_popups() > 0 && !strcmp(bufname, CONNECT_LIST_BUF))
		return;
	if (get_choice(name_to_bufnum(CONNECT_LIST_BUF), msg,
				   "Remote Connections", NULL, "Go to", "Close", "")) {
		s = strstr(msg, ": ");
		if (s) {
			*s = 0;
			if (exist(msg))
				to_buffer(msg);
		}
	}
	user_abort = 0;
}


int recolor_tex_from_here();

color_tex_cmd(int s)
{
	char cmd[200];
	int color = color_class tex_literal;

	cmd[0] = '|';
	if (parse_string(1, "[a-z@]*", cmd + 1)) {
		strcat(cmd, "|");
		if (strstr("|begin|end|", cmd))
			color = color_class tex_begin_end;
		else if (strstr("|chapter|section|subsection|subsubsection"
						"|appendix|bibliography|title|tableofcontents"
						"|input|include|",
						cmd))
			color = color_class tex_section;
		else
			color = color_class tex_command;
	} else if (curchar() == '[') {
		int orig = point;
		if (re_search(1, "\n[ \t]*\n|\\par![^a-z]|\\]")
			&& character(point - 1) == ']') {
			set_character_color(orig - 1, point, color_class tex_math);
			return;
		}
		point = orig + 1;
	} else
		point++;
	set_character_color(s, point, color);
}

int color_tex_range(int from, int to) // Recolor just this section.
{						// Last colored region may go past to.
	int s, talk, cnt = 0;

	if (from >= to)
		return to;
	save_var point, matchstart, matchend;

	point = to - 2;
	if (!narrowed_search(REGEX, "\n[ \t]*\n", tex_look_back / 2))
		to_end_line();		// Color entire paragraphs.
	to = point;

	point = from + 2;
	if (!narrowed_search(REGEX | REVERSE, "\n[ \t]*\n", tex_look_back / 2))
		to_begin_line();	// Look back for blank line.
	from = point;

	talk = (to - from > tex_look_back + 1000); // Show status during long delays.
	if (point < to)
		set_character_color(point, to, color_class tex_text);
	save_var case_fold = 1;
	for (s = point; point < to && re_search(1, "[][{}%\\$]"); s = point) {
		if (point > to)
			set_character_color(s, point - 1, color_class tex_text);
		s = point - 1;
		switch (character(s)) {
			case '\\':
				color_tex_cmd(s);
				if (talk)
					if (!(cnt++ % 500))
						note("Coloring TeX: %d%% complete...",
							 (point - from) * 100 / (to - from));
				break;
			case '$':
				color_tex_dollar(s);
				break;
			case '%':
				to_end_line();
				set_character_color(s, point, color_class tex_comment);
				break;
			case '{': case '}':
				set_character_color(s, point, color_class tex_curly_brace);
				break;
			case '[': case ']':
				set_character_color(s, point,
									color_class tex_square_bracket);
				break;
		}
	}
	if (talk)
		note("");
	return point;
}

command tex_left_brace()
{
	if (character(point - 1) == '\\' && !has_arg) {
		stuff("{\\}");
		point -= 2;
	} else
		tex_insert_pair("{}");
}

command tex_center_line()
{
	iter = 0;
	tex_open_new_line();
	tex_insert_cmd("\\centerline{", "}", 0);
}

tex_insert_open(int close)
{
	normal_character();
	if (tex_force_latex && character(point - 2) == '\\') {
		save_var point;
		bprintf("\\%c", close);
	}
}

command tex_inline_math()
{
	tex_insert_open(')');
}

command tex_display_math()
{
	tex_insert_open(']');
}

char *tex_env_match(char *partial, int start)
{
	tex_init_env();
	save_var bufname = TEX_ENV_BUF;
	case_fold = 0;
	if (start & STARTMATCH)
		point = 0;
	if (*partial ? !col_search(partial, 0) : (point >= size()))
		return NULL;
	to_begin_line();
	if (!grab_line(bufnum, _this_match))
		return NULL;
	return _this_match;
}

command tex_mode()
{
	mode_keys = tex_tab;		/* Use these keys. */
	compile_buffer_cmd = compile_tex_cmd;
	tex_tab['}'] = Matchdelim ? (short) show_matching_delimiter : 0;
	tex_tab[']'] = Matchdelim ? (short) show_matching_delimiter : 0;
	tex_tab[')'] = Matchdelim ? (short) show_matching_delimiter : 0;
	tex_paragraphs = 1;
	fill_mode = 1;
	if (tex_force_latex == 2){		// Determine if it's LaTeX.
		save_var point = 0;
		tex_force_latex = search(1, "\\begin{document}");
	}
	major_mode = tex_force_latex ? _latex_mode_name : _tex_mode_name;
	strcpy(comment_start, "[^\\]%%[ \t\f]*");
	strcpy(comment_pattern, "[^\\]%%.*$");
	strcpy(comment_begin, "% ");
	strcpy(comment_end, "");
	recolor_range = color_tex_range;	// set up coloring rules
	recolor_from_here = recolor_tex_from_here;
	if (want_code_coloring)		// maybe turn on coloring
		when_setting_want_code_coloring();
	if (auto_show_tex_delimiters)
		auto_show_matching_characters = tex_auto_show_delim_chars;
	try_calling("tex-mode-hook");
	make_mode();
}

when_loading()
{
	int i;

	save_var selected_color_scheme;
	for (i = 1; i <= final_index(); i++)
		if (name_type(i) == NT_COLSCHEME) {
			selected_color_scheme = i;
			if (get_foreground_color(color_class diff_removed) == black
				&& get_background_color(color_class diff_removed) == red)
				set_color_pair(color_class diff_removed, black, light_red);
		}
	restore_vars();
//	drop_name("browser_file");	// Delete unused variable.
//	drop_name("dired-isdir-simple");	// Delete unused function.
//	drop_name("ftp-show-new-file");	// Delete unused function.
//	drop_name("color-only-region");	// Delete unused function.
	drop_name("preserve-comment-indent");	// Delete unused variable.
	auto_read_changed_file.default = 0;		// New default.
//	reg_tab[NUMSHIFT(KEYDELETE)] = find_index("kill-region");

				// New default.
	if (!strcmp(anon_ftp_password, "EpsilonUser@unknown.host"))
		strcpy(anon_ftp_password, "-EpsilonUser@unknown.host");
	set_name_user(find_index("display-scroll-bar"), 0);

	sayput("Update complete, preparing to write state file...");
	delay(300, COND_KEY);	// Give the user a chance to abort.
	check_abort();
	if (!*state_file)
		write_state();		// Prompt for name.
	else
		do_save_state(state_file);	// Rewrite current state file.
	exit();
}
