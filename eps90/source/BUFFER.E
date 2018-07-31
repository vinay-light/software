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

// This file has miscellaneous commands that deal with buffers.

#include "eel.h"
#include "proc.h"

command change_modified() on reg_tab[ALT('~')]
{
	modified = has_arg? (iter != 0) : !modified;
	iter = 0;
}

command change_read_only() on cx_tab[CTRL('Q')]
{
	set_read_only(has_arg? (iter != 0) : !_buf_readonly);
	iter = 0;
}

set_read_only(val)
{
	_buf_readonly = val;
	if (_buf_readonly)
		call_on_modify = 1;
	make_mode();
}

on_modify()	/* called when you try to modify a buffer with */
{ /* call-on-modify set.  if it returns, buffer will be modified anyway */
	highlight_off();
	if (_buf_readonly)
		error("Buffer is read-only.");
	call_on_modify = 0;	/* don't call us next time */
	if (virtual_space && bufnum == window_bufnum)
		virtual_to_real_column();
}

virtual_to_real_column()	/* if we're in a virtual column, try to */
{				/* convert characters so we're really there */
	int col;

	if ((col = cursor_to_column) >= 0) {
		cursor_to_column = -1;
		force_to_column(col);
	}
}

// Build unique buffer name from file name for find-file.

make_bname(fname, bname)
char *fname, *bname;
{
	do_make_bname(fname, bname, NULL);
}

// Build buffer name from file name.
// Must not match any existing buffer (except dup_ok, if non-null).

do_make_bname(char *fname, char *bname, char *dup_ok)
{
	int uniq = 1, ok;
	char *to, *oldbuf;

	strcpy(bname, get_tail(fname, 0));
#if FOLDFILE
	if ((filename_rules(fname) & FSYS_CASE_MASK) != FSYS_CASE_SENSITIVE)
		for (to = bname; *to; to++)
			*to = tolower(*to);
#endif
	to = bname + strlen(bname);
	while (exist(bname) && (!dup_ok || strcmp(bname, dup_ok))) {
		oldbuf = bufname;
		bufname = bname;
		ok = (size() == 0);
		bufname = oldbuf;
		if (ok) return;
		sprintf(to, "<%d>", uniq++);
	}
}

look_file(fname)	/* is there a buffer with this file? */
char *fname;		/* if so, switch to it */
{
	int i, orig = bufnum;

	if (!fnamecmp(filename, fname))	/* already in it */
		return 1;
	i = buf_list(0, 2);	/* start with most recently created buf */
	do {
		bufnum = i;
		if (!fnamecmp(filename, fname))
			return 1;
	} while ((i = buf_list(-1, 1)) > 0);
	bufnum = orig;
	return 0;
}

fnamecmp(f1, f2) /* compare two file names like strcmp, maybe folding */
char *f1, *f2;
{
#if FOLDFILE
	save_var case_fold = 1;
	if ((filename_rules(f1) & FSYS_CASE_MASK) == FSYS_CASE_SENSITIVE)
		return strcmp(f1, f2);
	else
		return strfcmp(f1, f2);
#else
	return strcmp(f1, f2);
#endif	
}

command count_lines() on cx_tab['l']
{
	int count, here, disksize;

	noteput("Counting...");
	here = lines_between(0, point, 1);
	check_abort();
	noteput("Counting... point on line %d...", here + 1);
	count = here + lines_between(point, size(), 1);
	check_abort();
	disksize = size();
	if (translation_type == FILETYPE_MSDOS)
		disksize += count;
	say("%d lines, point on line %d.  %d bytes on disk.",
		count + 1, here + 1, disksize);
	iter = 0;
}

command show_point() on cx_tab['=']
{
	char msg[130], c;

	sprintf(msg, "Column=%d, point=%d, size=%d", virtual_column(),
			point, size());
	if (point < size())
		if (c = curchar())
			sprintf(msg + strlen(msg),
				", char %d is '%c'=%d decimal=%02x hex",
				point, c, c, c);
		else
			sprintf(msg + strlen(msg), ", char %d is '\\0'",
				point);
	say("%s", msg);
	iter = 0;
}

grab_buffer(buf)	/* insert buffer buf into this buffer */
{
	int cur = bufnum;
	bufnum = buf;
	buf_xfer(cur, 0, size());
	bufnum = cur;
}

grab_full_line(b, str)	/* put current line (not incl newline) in string */
char *str;		/* don't change point */
{
	int begin;

	save_var bufnum = b;
	save_var point;
	to_begin_line();
	begin = point;
	to_end_line();
	grab(begin, point, str);
	return point - begin;
}

grab_line(b, s)	/* read next line of input from buffer b into string s */
char *s;	/* & move past it */
{		/* remove any \n from end of line, & return length */
	int opt, found;
	save_var bufnum = b;

	opt = point;
	found = nl_forward();
	grab(opt, point - found, s);
	return point - found - opt;
}

grab_numbers(b, nums)		/* read next line of input & break up into */
int *nums;			/* numbers, returning # found */
{
	char line[150], *p = line;
	int count = 0;

	grab_line(b, line);
	for (;;) {
		while (isspace(*p))
			p++;
		if (!*p)
			break;
		nums[count++] = numtoi(p);
		while (*p && !isspace(*p))
			p++;
	}
	return count;
}

grab_string(b, s, endmark)	/* read from b until endmark, put in s */
char *s, *endmark;		/* return 1 if found, else 0 & clear s */
{
	int opt, res;
	save_var bufnum = b;
	
	opt = point;
	if (res = search(1, endmark))
		grab(opt, matchstart, s);
	else
		*s = 0;
	return res;
}

// See if text at pos matches pattern.
matches_at(int pos, int dir, char *pat)
{
	save_var point = pos;
	return parse_string(dir, pat);
}

buffers_identical(a, b)		// do buffers a and b have the same text?
{
	int i;
	if (!a || !b)			// one or both buffers don't exist
		return !a == !b;	// if both don't, they're "same"
	save_var bufnum = a;
	i = size();
	bufnum = b;
	if (i != size())		// different sizes => mismatch
		return 0;
	return compare_buffer_text(a, 0, b, 0, 0) == size();
}				// were all the characters the same?

buffer_size(char *buf)
{
	save_var bufname = buf;
	return size();
}

command widen_buffer()
{
	narrow_start = narrow_end = 0;
	make_mode();
}

command narrow_to_region()
{
	fix_region();
	narrow_start = point;
	narrow_end = size() - mark;
	highlight_off();
	make_mode();
}

narrow_position(p)		/* return p, adjusting to be inside */
{				/* any narrowed region */
	save_var point = p;
	return point;
}

/* Act like C-x b using supplied prompt */
ask_which_buffer(pr)
char *pr;
{
	char bfname[FNAMELEN];
	int prev = give_prev_buf();

	get_buf(bfname, pr, prev ? bufnum_to_name(prev) : "");
	if (!*bfname)
		return;
	to_buffer(bfname);
}

command select_buffer() on cx_tab['b']
{
	tiled_only();
	ask_which_buffer("Buffer name");
	iter = 1;
}

command kill_buffer() on cx_tab['k']
{
	char bname[FNAMELEN];

	tiled_only();
	save_var show_mouse_choices = 1;
	get_buf(bname, "Buffer to delete", bufname);
	drop_buffer(bname);
}

command kill_current_buffer() on cx_tab[CTRL('K')]
{
	tiled_only();
	drop_buffer(bufname);
}

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

drop_buffer(bname)	/* delete a buffer, asking user if questionable */
char *bname;		/* return 1 if done, 0 if user said don't */
{
	if (!check_drop_buffer(bname))
		return 0;
	delete_user_buffer(bname);
	return 1;
}

delete_user_buffer(bname)	/* delete a buffer that might have coloring */
char *bname;
{
	if (!exist(bname))
		return;
	drop_coloring(name_to_bufnum(bname));
	highlight_off();
	delete_buffer(bname);
}

check_drop_buffer(bname) /* check if buffer can be deleted safely */
char *bname;		/* ask user if questionable */
{			/* return 1 if done, 0 if user said don't */
	char msg[80], *origbuf = bufname;
	int mod, newbuf;

	if (!exist(bname))
		error("No buffer %s.", bname);
	if (another_process() && !strcmp(bname, PROCBUF))
		error("A process is running.");
	bufname = bname;
	mod = modified && size() > 0 && !discardable_buffer;
	bufname = origbuf;
	if (!another_process() && !strcmp(bname, PROCBUF))
		mod = 0;
	if (mod) {
		sprintf(msg, "Buffer %.40s not saved.  Delete it? ", bname);
		if (!ask_yn("Delete buffer", msg, "Delete", "Cancel", 2))
			return 0;
	}
	if (!strcmp(bname, bufname)) {
		if (newbuf = give_prev_buf())
			to_buffer_num(newbuf);
		else
			make_newfile_buf();
	}
	return 1;
}


to_buffer(buf)		/* switch window to buffer, check file date */
char *buf;		/* create buffer if necessary */
{
	switch_to_buffer(create(buf));
	highlight_off();
	switching_to_buffer();
	check_dates(0);
}

to_buffer_num(num)	/* switch window to buffer by number */
{
	switch_to_buffer(num);
	switching_to_buffer();
	check_dates(0);
}

switch_to_buffer(num)	/* switch without checking date */
{
	int i;

	if (num != window_bufnum) {
		for (i = 0; i < _prev_num; i++)
			if (_prev_old_buffers[i] == window_bufnum)
				prev_forget(i);
		if (_prev_num >= MAXOLDBUFS)
			prev_forget(0);		/* no room, forget oldest */
		_prev_old_buffers[_prev_num++] = _prev_buffer = window_bufnum;
	}
	window_bufnum = num;
}

// Return the most recently accessed user buffer, ignoring buffers
// accessed at or after "time" t.  T is a buf_accessed_clock value,
// incremented each time a window switches to a buffer.

newest_before(t)
{
	int i, newest_time = 0, newest = 0;

	save_var bufnum;
	i = buf_list(0, 2);	/* start with most recently created buf */
	do {
		bufnum = i;
		if (buf_accessed >= t || *bufname == '-')
			continue;
		if (!newest || buf_accessed > newest_time) {
			newest_time = buf_accessed;
			newest = i;
		}
	} while ((i = buf_list(-1, 1)) > 0);
	return newest;
}

prev_forget(i)	/* forget old buffer # at index i */
{
	int j;

	for (j = i; j < _prev_num - 1; j++)
		_prev_old_buffers[j] = _prev_old_buffers[j + 1];
	_prev_num--;
}

get_buf_accessed(i)
{
	save_var bufnum = i;
	return buf_accessed;
}

give_prev_buf()		/* return buf # of previous buffer, or 0 if none */
{
	int i, j;

	if (_prev_buffer != bufnum && buf_exist(_prev_buffer))
		return _prev_buffer;
	for (i = _prev_num; --i >= 0; ) {	/* start with oldest at end */
		j = _prev_old_buffers[i];
		if (buf_exist(j) && j != bufnum && buf_in_window(j) < 0)
			return j;
	}
	for (i = buf_accessed_clock; j = newest_before(i);
		 i = get_buf_accessed(j))
		if (j != bufnum)
			return j;
	return 0;
}

// Copy this buffer's characters in the specified range to buffer num.
// Also copy character coloring.

buf_xfer_colors(num, from, to)
{
	int orig = bufnum, pos, color, colstart, colend;

	if (to < from)
		{ pos = from; from = to; to = pos; }
	buf_xfer(num, from, to);
	for (pos = from; pos < to;) {
		color = get_character_color(pos, &colstart, &colend);
		bufnum = num;
		if (colstart < from)	// Only change the part we just copied.
			colstart = from;
		if (colend > to)
			colend = to;
		set_character_color(mark + colstart - from,
							mark + colend - from, color);
		bufnum = orig;
		pos = colend;
	}
}

xfer(buf, from, to)
char *buf;
{
	buf_xfer(name_to_bufnum(buf), from, to);
}

buf_xfer(num, from, to)		/* copy from..to in current buffer to */
{				/* buffer num, setting mark before it */
	int orig = bufnum;

	bufnum = num;
	do_set_mark(point);
	set_region_type(REGNORM);
	bufnum = orig;
	raw_xfer(num, from, to);	/* insert at point */
}

command next_buffer() on reg_tab[FKEY(12)], cx_tab['>']
{
	n_or_p_buf(1);
}

command previous_buffer() on reg_tab[FKEY(11)], cx_tab['<']
{
	n_or_p_buf(0);
}

char *get_int_buf(start)	/* return name of "interesting" buffer */
{
	char *p;

	do {
		p = buffer_list(start);
		start = 0;
	} while (p && *p == '-');
	return p;
}

n_or_p_buf(next)
{
	char *prev = 0, *s;

	tiled_only();
	s = get_int_buf(1);
	do {
		if (bufname == s)
			break;
		prev = s;
	} while (s = get_int_buf(0));
	if (next)
		s = get_int_buf(0);
	else if (prev)
		s = prev;
	else
		do {
			s = prev;
		} while (prev = get_int_buf(0));
	if (!s)
		s = get_int_buf(1);
	if (!s)
		s = buffer_list(1);
	to_buffer(s);
}
