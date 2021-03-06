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

// This file has commands for manipulating files.

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "epsnet.h"
#include "filter.h"

use_common_open_file_dlg(fname, title, flags, save)
char *fname, *title;
int *flags;
{
	int ret;

	ret = common_file_dlg(fname, title, flags, save,
						 filter_str, custom_filter, &filter_index);
	if (ret)
		absolute(fname);
	return ret;
}

// Should we use the GUI dialog?
use_common_file_dialog()
{
	if (!is_gui)
		return 0;
	switch (want_common_file_dialog) {
		case 0:	return 0;	// Never use.
		case 2:	return 1;	// Always use.
	}
	return run_by_mouse;	// Use if command was invoked by menu or toolbar.
}

/* Ask for a file name and save buffer to that file if one is given. */
command write_file() on cx_tab[CTRL('W')]
{
	char tmp[FNAMELEN];
	int flags = OFN_NOREADONLYRETURN | OFN_HIDEREADONLY;

	iter = 0;
	if (use_common_file_dialog()) {
		strcpy(tmp, force_save_as == FSA_NEWFILE ? "" : filename);
		if (!use_common_open_file_dlg(tmp, "Save file as", &flags, 1))
			return 0;
	} else
		get_file_dir(tmp, "Write file: ");
	if (*tmp) {
		if (warn_existing_file(tmp))
			return 0;
		set_buffer_filename(tmp);
		return do_save_file(1, 0, 1);
	}
	return 0;
}

command copy_to_file() on reg_tab[FCTRL(7)]
{
	int mod = modified;
	int flags = OFN_NOREADONLYRETURN | OFN_HIDEREADONLY;
	char tmp[FNAMELEN], orig[FNAMELEN];

	iter = 0;
	strcpy(orig, filename);
	if (use_common_file_dialog()) {
		strcpy(tmp, force_save_as == FSA_NEWFILE ? "" : filename);
		if (!use_common_open_file_dlg(tmp, "Copy to file", &flags, 1))
			return;
	} else
		get_file(tmp, "Copy to file", filename);
	if (warn_existing_file(tmp))
		return;
	filename = tmp;
	do_save_file(1, 0, 0);
	filename = orig;
	modified = mod;
}

warn_existing_file(s)	// maybe warn if file s already exists
char *s;		// return nonzero to skip writing it
{
	char msg[FNAMELEN];

	if (is_remote_file(s))
		win32_only();
	if (!warn_before_overwrite || check_file(s, NULL) != CHECK_FILE)
		return 0;
	sprintf(msg, "Overwrite %r? ", s);
	return !ask_yn("Confirm overwrite", msg, "Overwrite", "Cancel", 1);
}

command print_setup()
{
	print_options.flags = PD_PRINTSETUP;
	select_printer(&print_options);
}

// Printing helper functions for Windows.

#define FORMFEED	"\x0C"		/* a string with a Ctrl-L */

// Return start of printed page following the one that starts at pt.
next_printed_page(pt)
{			// Either go one screenful down, or till next Ctrl-L.
	int full = move_by_screen_lines(pt, text_height());
	save_var point = pt, narrow_end = size() - full;
	return search(1, FORMFEED) ? point : full;
}

next_formfeed()		// How much of this page should we print?
{					// Stop before next Ctrl-L, if any.
	save_var point;
	if (search(1, FORMFEED))	// Go to next Ctrl-L 
		return point - 1;	// and return new position.
	return point;		// Or return end of buffer.
}

// Send current page to the printer.
show_printed_page()
{
	save_var narrow_end = size() - next_formfeed();
	redisplay();	// Fill this window.
	print_window(window_handle); // Send this window to the printer.
}

// How many printed pages will this buffer generate?

count_printed_pages()
{
	int i = 0;

	window_start = 0;
	while (window_start < size() - narrow_end && !user_abort) {
		window_start = next_printed_page(window_start);
		i++;
	}
	return i;
}

print_this_page(page)	// Did the user ask to print this page number?
{
	if (print_options.flags & PD_PAGENUMS)
		if (page < print_options.frompage || page > print_options.topage)
			return 0;
	return 1;
}

// Maybe show headings at the top of the page.
print_headings(fname, page, total_pages, date)
char *fname, *date;
{
	char buf[FNAMELEN];

	if (print_heading & PRHEAD_FNAME) {
		sprintf(buf, "File %s", fname);
		print_line(buf);
	}
	if (print_heading & (PRHEAD_PAGECNT | PRHEAD_DATE)) {
		*buf = 0;
		if (print_heading & PRHEAD_PAGECNT)
			sprintf(buf, "Page %d of %d     ", page, total_pages);
		if (print_heading & PRHEAD_DATE)
			strcat(buf, date);
		print_line(buf);
	}
	if (print_heading)
		print_line("");
}

// Cycle the pages of this buffer through the printing window.
// Return # of pages we printed.

send_printed_pages(fname)
char *fname;
{
	int total_pages, page = 1, printed = 0;
	char date[FNAMELEN];
	struct time_info t;

	// Collect info we need for the page header.
	time_and_day(&t);
	format_date(date, t.year, t.month, t.day, t.hour, t.minute, t.second);
	save_var display_column = -1;		// Make sure lines wrap.
	total_pages = count_printed_pages();

	window_start = point = 0;
	while (point < size() - narrow_end) {
		if (print_this_page(page)) {
			note("Printing page %d of %d...", page, total_pages);
			print_headings(fname, page, total_pages, date);
			show_printed_page();
			if (!print_eject())
				break;
			printed++;
		}
		point = window_start = next_printed_page(window_start);
		page++;
		if (user_abort)
			break;
	}
	return printed;
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

command print_buffer() on reg_tab[FALT(9)]
{
	do_print_region(window_bufnum, !is_highlight_on());
}

command print_region() on reg_tab[FSHIFT(9)]
{
	do_print_region(window_bufnum, 0);
}

do_print_region(b, all)	// print region, or whole buffer if all nonzero
{
	int buf, err, transl, tabs;
	char to[FNAMELEN], title[FNAMELEN], *fname;
	int (*buf_recolor_range)();
	int (*buf_recolor_from_here)();
	char buf_want_code_coloring;
	char buf_c_extra_keywords;

	if (is_gui && want_gui_printing) {
		print_options.flags = all ? 0 : PD_SELECTION;
		if (!select_printer(&print_options))
			return;		// User canceled.
		all = !(print_options.flags & PD_SELECTION);
		if (*filename)
			strcpy(title, get_tail(filename, 1));
		else
			strcpy(title, bufname);
		fname = filename;
	} else {
		get_strdef(to, "Print to device (or !command)", print_destination);
		strcpy(print_destination, to);
	}
	save_var bufnum = b;
	transl = translation_type, tabs = tab_size;
	buf_recolor_range = recolor_range;
	buf_recolor_from_here = recolor_from_here;
	buf_want_code_coloring = want_code_coloring;
	buf_c_extra_keywords = c_extra_keywords;
	buf = tmp_buf();
	save_spot point, mark;
	fix_region();		// handle other types of regions
	if (all)
		buf_xfer(buf, 0, size());
	else if (region_type() == REGRECT)
		extract_rectangle(buf, 0);
	else
		buf_xfer(buf, point, mark);
	bufnum = buf;
	translation_type = transl;		/* use orig buffer's vals */
	tab_size = tabs;
	recolor_range = buf_recolor_range;
	recolor_from_here = buf_recolor_from_here;
	want_code_coloring = buf_want_code_coloring;
	c_extra_keywords = buf_c_extra_keywords;
	if (want_code_coloring)		// maybe turn on coloring
		when_setting_want_code_coloring();

	point = 0;
	if (!print_tabs)
		tab_convert(0, size(), 0);
	if (is_gui && want_gui_printing) {
		gui_print(title, fname);
		err = 0;
	} else
		err = send_to_file_or_cmd(buf, print_destination);
	bufnum = b;
	buf_delete(buf);
	if (!err && !all)
		highlight_off();
	if (!err && !(is_gui && want_gui_printing))
		say("%s printed.", all ? "Buffer" : "Region");
	return err;
}

send_to_file_or_cmd(b, file)	// copy buffer b to file, or send to cmd
char *file;
{
	int err;
	char *thisfile = file, cmdline[FNAMELEN], tempfile[FNAMELEN];

	save_var bufnum = b;
	if (*file == '!')
		make_temp_file(thisfile = tempfile, size());
	if (err = file_write(thisfile, translation_type)) {
		file_error(err, thisfile, "write error");
		maybe_ding(bell_on_write_error);
	}
	if (!err && *file == '!') {
		build_filename(cmdline, file + 1, tempfile);
		err = do_push(cmdline, 0, -1);
		delete_file(tempfile);
	}
	return err;
}

ask_save_buffer()
{
	if (!(is_gui && want_gui_prompts)) {
		int res = ask_yn("Unsaved changes", "Save buffer? ",
					  "Yes", "No", 1);
		check_abort();
		return res;
	}
	switch (button_dialog("Unsaved changes", "This buffer contains "
						  "unsaved changes.  Save first? ",
						 "Save", "Discard", "Cancel", 1)) {
		case 1:	return 1;
		case 2: return 0;
	}
	quick_abort();
}


command visit_file() on cx_tab[CTRL('V')]
{
	char tmp[FNAMELEN];

	iter = 0;
	save_var show_mouse_choices = 1;
	get_file(tmp, "Visit file", filename);
	if (!*tmp)
		return;
	if (!has_arg && modified) {	/* buffer need to be saved? */
		if (ask_save_buffer())
			do_save_file(1, 1, 1);
	}
	read_file(tmp, translation_type);
}

/* read the specified file into the current buffer */
read_file(tmp, strip)
char *tmp;
{
	int err;

	err = do_file_read(tmp, strip);
	if (err == 2) {
		zap(bufname);
		modified = 0;
		say("%s: New file.",tmp);
	} else if (err && err != EREADABORT) {
		file_error(err, tmp, "read error");
		maybe_ding(bell_on_read_error);
	} else if (file_info.check_type == CHECK_FILE
				&& (file_info.attr & ATTR_READONLY))
		do_readonly_warning();
	else
		update_readonly_warning(&file_info);
	if (window_bufnum == bufnum)
		switching_to_buffer();
	make_mode();
	return err;
}

do_readonly_warning()	// alert user: just read a read-only file
{
	if (readonly_warning & 1)
		say("%s: File is read-only.", filename);
	if (readonly_warning & 2) {
		_buf_readonly = 2;	// set from file
		call_on_modify = 1;
	}
	maybe_ding(readonly_warning & 4);
	make_mode();
}

update_readonly_warning(p)  // if file's no longer readonly, and we made
struct file_info *p;	// buffer readonly because it was, make writeable
{
	if (p->check_type == CHECK_FILE && !(p->attr & ATTR_READONLY)
	    && (_buf_readonly == 2)) {
		_buf_readonly = 0;	// if set from file, reset
		make_mode();
	}
}

command revert_file()
{
	char pr[FNAMELEN], rel[FNAMELEN];

	save_var point;
	if (!*filename)
		error("No file for this buffer.");
	iter = 0;
	if (modified) {		/* buffer need to be saved? */
		relative(filename, rel);
		sprintf(pr, "Discard changes and revert to %s? ", rel);
		if (!ask_yn("Discard changes", pr, "Discard", "Cancel", 1))
			return;
	}
	read_file(filename, translation_type);
	build_first = 1;
	fix_window_start();
}

do_file_read(s, strip)	/* read file, updating file_info */
char *s;
{
	int i;

	highlight_off();
	filename = s;
	if (is_remote_file(s))
		return find_remote_file(s, strip);
	i = new_file_read(s, strip, &file_info, -1, -1);
	_read_aborted = (i == EREADABORT);
	file_convert_read();
	return i;
}

command insert_file() on cx_tab['i']
{
	char file[FNAMELEN];
	int flags = OFN_HIDEREADONLY;

	save_var show_mouse_choices = 1;
	if (use_common_file_dialog()) {
		strcpy(file, _region_file);
		if (!use_common_open_file_dlg(file, "Insert file", &flags, 0))
			return;
	} else {
		if (!*_region_file)
			get_buffer_directory(_region_file);
		get_file(file, "Insert file", _region_file);
	}
	if (!*file)
		return;
	strcpy(_region_file, file);
	mark = point;			/* put mark before it */
	set_region_type(REGNORM);
	build_first = 1;
	do_insert_file(file, ask_line_translate());
	iter = 0;
}

do_insert_file(file, strip)	/* insert file into current buffer at pt */
char *file;
{
	int orig = bufnum, buf, err;

	bufnum = buf = tmp_buf();
	err = err_file_read(file, strip);
	if (!err)
		buf_xfer(orig, 0, size());
	bufnum = orig;
	buf_delete(buf);
	return err;
}

err_file_read(file, strip)	/* like file_read, but show error */
char *file;
{
	int err = file_read(file, strip);

	if (window_bufnum == bufnum)
		switching_to_buffer();
	_read_aborted = (err == EREADABORT);
	if (err && !_read_aborted) {
		file_error(err, file, "read error");
		maybe_ding(bell_on_read_error);
	}
	return err;
}

command write_region() on cx_tab['w']
{
	char file[FNAMELEN];
	int b = -1;
	int flags = OFN_NOREADONLYRETURN | OFN_HIDEREADONLY;

	if (use_common_file_dialog()) {
		strcpy(file, _region_file);
		if (!use_common_open_file_dlg(file, "Write region to file", &flags, 1))
			return;
	} else
		get_file(file, "Write region to file", _region_file);
	if (!*file)
		return;
	if (warn_existing_file(file))
		return;
	strcpy(_region_file, file);
	save_spot point, mark;
	fix_region();		// handle other types of regions
	highlight_off();
	if (region_type() == REGRECT) {
		b = tmp_buf();
		extract_rectangle(b, 0);
		save_var bufnum = b;
		mark = 0;
	}
	if (!write_part(file, translation_type, point, mark))
		note_written(file);
	if (b != -1)
		buf_delete(b);
}

note_written(char *fname)
{
	if (is_remote_file(fname))
		note("%s: write request queued.", fname);
	else
		note("%s written.", fname);
}

write_part(file, strip, start, end)
char *file;
{
	int orig = bufnum, buf, err;

	buf = tmp_buf();
	buf_xfer(buf, start, end);
	bufnum = buf;
	err = file_write(file, strip);
	bufnum = orig;
	buf_delete(buf);
	if (err) {
		file_error(err, file, "write error");
		maybe_ding(bell_on_write_error);
	}
	return err;
}

command save_file() on cx_tab[CTRL('S')]
{
	tiled_only();
	return do_save_file(1, 1, 1);
}

do_save_file(backup, checkdate, getdate) /* 0=ok, 1=err, 2=user canceled */
{				/* always prints status in echo area */
	struct file_info *finfo;
	char othername[FNAMELEN], msg[FNAMELEN];
	int err;

	iter = 0;
	if (!*filename || force_save_as)
		return write_file();
	if (checkdate)
		if (check_dates(1))
			return 2;
	if (_read_aborted) {
		relative(filename, othername);
		sprintf(msg, "Only part of %s was read from disk.  "
			"Save anyway? ", othername);
		if (!ask_yn("Confirm save", msg, "Save", "Cancel", 0))
			return 2;
	}
	build_filename(othername, backup_name, filename);
	if (backup && (want_backups && !already_made_backup
				   || want_backups == 2) && fnamecmp(filename, othername)) {
		make_backup(filename, othername);
		already_made_backup = 1;
	}
	finfo = getdate ? &file_info : 0;
	if (err = file_convert_write(filename, translation_type, finfo)) {
		file_error(err, filename, "write error");
		maybe_ding(bell_on_write_error);
	} else
		note_written(filename);
	return (err != 0);
}

auto_save_buffers()	/* maybe save buffers */
{
	int i;

	save_var bufnum;
	i = buf_list(0, 0);	/* start with oldest buf */
	do {
		bufnum = i;
		if (*filename != '\0' && modified && !buffer_not_saveable)
			auto_save_one();
	} while (i = buf_list(1, 1));
}

auto_save_one()
{
	char name[FNAMELEN];
	int err, origfile = !strcmp(auto_save_name, "%f");

	build_filename(name, auto_save_name, filename);
	if (_read_aborted)		// we didn't read whole file in,
		err = EREADABORT;	// so don't save it
	else if (!origfile)			// auto-save to a different file
		err = file_convert_write(name, translation_type, NULL);
	else if (check_dates(1))	// make sure other prog hasn't changed
		return;
	else				// get new time info
		err = file_convert_write(filename, translation_type, &file_info);
	if (err) {
		if (is_gui)		// Don't pop up dialog when autosave fails.
			say("Error autosaving %s", name);
		else
			file_error(err, name, "couldn't autosave");
		maybe_ding(bell_on_autosave_error);
	} else
		note("%s autosaved.", name);
	if (!origfile)
		modified = 1;
}

// Is this buffer unsaved?
int is_unsaved_buffer()
{
	if (discardable_buffer || buffer_not_saveable)
		return 0;
	if (modified && *filename && size() && !is_dired_buf())
		return 1;
	if (ftp_job && ftp_job->buf == bufnum && ftp_job->operation == FTP_SEND)
		return 1;
	return 0;
}

unsaved_buffers()	/* return 1 if any unsaved buffers exist */
{
	int i = buf_list(0, 0), ret = 0;

	save_var bufnum;
	do {
		bufnum = i;
		if (is_unsaved_buffer()) {
			ret = 1;
			break;
		}
	} while (i = buf_list(1, 1));
	return ret;
}
 
maybe_save_all()	/* possibly save all buffers, depending on variable */
{			/* returns 0 normally; 1 means don't do cmd */
	switch (save_when_making) {
		case 0:		return 0;	/* never do it */
		case 1:		break;		/* always do it */
		default:	if (!unsaved_buffers())
						return 0;
					switch (bufed_ask_save()) {
						case 0:	return 1;
						case 1: return 0;
						case 2:	break;
					}
					break;
	}
	save_all_buffers();
	return 0;
}

command save_all_buffers() on cx_tab['s']
{
	int i, count = 0;

	save_var bufnum;
	i = buf_list(0, 0);
	do {
		bufnum = i;
		if (*filename && modified && !buffer_not_saveable) {
			switch (do_save_file(1, 1, 1)) {
				case 1: quick_abort();
				case 0: count++;
			}
		}
	} while (i = buf_list(1, 1));
	if (count) {
		say("%d file%s saved.", count, (count > 1) ? "s" : "");
		if (in_bufed())
			do_bufed(0);
	} else
		say("No files needed saving.");
	return count;
}

set_buffer_filename(f)
char *f;
{
	char abs[FNAMELEN];
	char bname[FNAMELEN+10];

	if (*f) {
		strcpy(abs, f);
		absolute(abs);
		filename = abs;
		do_make_bname(abs, bname, bufname);
		if (!exist(bname))
			change_buffer_name(bname);
		force_save_as = 0;
	} else
		filename = f;
	if (window_bufnum == bufnum)
		switching_to_buffer();
}

command set_file_name()
{
	char tmp[FNAMELEN];

	get_file_dir(tmp, "Enter new output file name: ");
	if (*tmp)
		set_buffer_filename(tmp);
}

command set_want_backup_file()
{
	want_backups = has_arg? (iter != 0) : !want_backups;
	say("Epsilon will%s create a backup file for this buffer.",
	    want_backups ? "" : " not");
}

command write_files_and_exit()
{
	if (unsaved_buffers()) {
		save_all_buffers();
		refresh();
	}
	exit();
	iter = 1;
}

command find_file() on cx_tab[CTRL('F')]
{
	char fname[FNAMELEN];
	int want_readonly = 0, flags = 0;

	tiled_only();
	was_quoted = 0;
	save_var show_mouse_choices = 1;
	if (use_common_file_dialog()) {
		*fname = 0;
		if (!use_common_open_file_dlg(fname, "Open file", &flags, 0))
			return;
		if (flags & OFN_READONLY)
			want_readonly = 1;
	} else
		get_file_dir(fname, "Find file: ");
	if (!*fname)
		dired_one(fname);
	else if (was_quoted && !is_directory(fname) && !is_remote_file(fname))
		find_it(fname, ask_line_translate());
	else 
		do_find(fname, ask_line_translate());
	if (want_readonly)
		force_save_as = FSA_READONLY;
	iter = 0;
}

command new_file()
{
	iter = 0;
	tiled_only();
	make_newfile_buf();
}

make_newfile_buf()
{
	char bname[FNAMELEN], fname[FNAMELEN];
	int unique = 2;

	strcpy(bname, "New File");
	for (;;) {
		sprintf(fname, "New%d%s", unique - 1, new_file_ext);
		absolute(fname);
		if (!exist(bname) && !do_file_match(fname, FM_EXACT) || unique >= 99)
			break;
		sprintf(bname, "New File %d", unique++);
	}
	to_buffer(bname);
	force_save_as = FSA_NEWFILE;
	filename = fname;
	fundamental_mode();
	try_calling(new_file_mode);
}

// Call dired if file has wildcards or is a directory name.
// For remote files, assume it's an FTP directory name if the name
// ends in /, if there's no name at all, or if the ftp spec includes
// wildcards, otherwise assume file (or other URL).

do_find(char *file, int strip)
{
	if (is_remote_file(file) ? is_remote_dir(file)
							 : (is_pattern(file) || is_directory(file)))
		return dired_one(file);
	else
		return find_it(file, strip);
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

call_mode(f)		/* go into appropriate mode based on extension of f */
char *f;
{
	call_by_suffix(f, "suffix-%s");
}

call_by_suffix(file, pattern)	// construct a subr name from extension
char *file, *pattern;		// of file name, try to call it
{				// return 1 if we found something to call
	char *s, subr[80], def[80];

	s = get_extension(file);
	sprintf(subr, pattern, *s ? (s + 1) : "none");
	sprintf(def, pattern, "default");
	return try_calling(subr) || try_calling(def);
}

build_filename(result, template, file)	/* interpret filename templates */
char *result, *template, *file;	/* copy res to pat, replacing % */
{				/* codes with parts of filename */
	char *start;
	int len;

	for (; *result = *template; template++) {
		len = -1;
		if (template[0] == '%' && template[1]) {
			switch (*result = *++template) {
			case 'p': start = file;
				len = get_tail(start, 0) - start;
				break;
			case 'b': start = get_tail(file, 0);
				len = get_extension(start) - start;
				break;
			case 'e': start = get_extension(file);
				len = strlen(start);
				break;
			case 'f': start = file;
				len = strlen(start);
				break;
			case 'r': relative(file, result);
				result += strlen(result) - 1;
				break;
			case 'x': get_executable_directory(result);
				result += strlen(result) - 1;
				break;
			case 'X': get_executable_directory(result);
				convert_to_8_3_filename(result);
				result += strlen(result) - 1;
				break;
			}
		}
		if (len >= 0) {
			strncpy(result, start, len);
			result += strlen(result);
		} else
			result++;
	}
}

put_directory(s)		// put directory of current file in s
char *s;
{
	strcpy(s, filename);
	*get_tail(s, 0) = 0;
}

// Look in dir & its parents for a file.
// If found, put the file's name in res & return 1.
// If not found, return 0.
// If dir is null, use the current directory.
// If stop is non-null and non-empty, Epsilon will only look for
// matches within it.  (It must be in absolute form.)

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

is_in_tree(file, tree)		// is file inside this directory tree?
char *file, *tree;		// assumes both are in absolute form
{
	int rel[FNAMELEN];

	relative(file, rel, tree);
	return fnamecmp(file, rel) != 0;
}

wild_pattern(s)		/* does this filename use the {},; wildcards? */
char *s;
{
	return index(s, '{') || index(s, '}') || index(s, ',')
			|| index(s, ';');
}

char *do_file_match(s, flags)	// hook this function to change the rules
char *s;			// for matching file names
{
	char pat[FNAMELEN];

	strcpy(pat, s);
	drop_quotes(pat);
	return file_match(pat, flags);
}

command list_files()	// list files that match a pattern
{			// with num arg, include directories
	char filepat[FNAMELEN], *s;
	int count = 0;

	iter = 0;
	tiled_only();
	get_file_dir(filepat, "List files matching pattern: ");
	if (!*filepat)
		return;
	zap("file-list");
	to_buffer("file-list");
	noteput("Listing files...");
	s = f_all_match(filepat, STARTMATCH | EXACTONLY
			| (has_arg ? 0 : FM_NO_DIRS));
	for (; s; s = f_all_match(filepat, 0)) {
		if (++count % 10 == 0)
			noteput("Listing file %d... %s", count, s);
		bprintf("%s\n", s);
		check_abort();
	}
	do_sort_region(0, size(), 0, 0);
	point = modified = 0;
	say("%d files found.", count);
}

ask_line_translate()
{
	int res = -1;

	if (!has_arg)
		return default_translation_type;
	iter = 1;
	while (res == -1) {
		sayput("File translation? D=DOS, B=Binary, U=Unix, M=Mac [D] ");
		getkey();
		check_abort();
		if (IS_ENTER_KEY(key))
			res = FILETYPE_MSDOS;
		switch (toupper(key)) {
			case 'B':	res = FILETYPE_BINARY; break;
			case 'D':	res = FILETYPE_MSDOS; break;
			case 'U':	res = FILETYPE_UNIX; break;
			case 'M':	res = FILETYPE_MAC; break;
		}
	}
	say("");
	return res;
}

command set_line_translate()
{
	has_arg = 1;
	translation_type = ask_line_translate();
	switch(translation_type) {
		case FILETYPE_MSDOS:   say("Add/remove return characters"); break;
		case FILETYPE_BINARY:  say("No changes when reading or writing"); break;
		case FILETYPE_UNIX:    say("No changes when reading or writing"); break;
		case FILETYPE_MAC:     say("Read/write as Macintosh file"); break;
		default: say("Unknown translation type"); break;
	}
	make_mode();
	iter = 0;
}

command cd() on reg_tab[FKEY(7)]	/* change current directory */
{
	char resp[FNAMELEN], dir[FNAMELEN];

	save_var recall_id = "changedir";
	if (get_buffer_directory(dir))
		save_completion(dir, 0);
	getcd(dir);
	save_var show_mouse_choices = 1;
	get_file(resp, "Change to directory", dir);
	if (*resp && chdir(resp)) {
		if (errno == 2)
			error("%s: no such directory", resp);
		else
			file_error(errno, resp, "unknown error");
	} else {
		getcd(dir);
		say("Current directory: %s", dir);
	}
}

// Get default directory for this buffer and return nonzero.
// If none, set dir to current directory and return zero.

get_buffer_directory(dir)
char *dir;
{
	int ok = 1;

	if (is_dired_buf())		/* get directory name from dired */
		dired_getdir(dir);
	else if (!strcmp(bufname, PROCBUF))	// process buffer?
		strcpy(dir, process_current_directory);
	else {
		strcpy(dir, filename);
		if (!*filename)	// No file name, so use Epsilon's cur dir
			ok = 0;		// but say we couldn't find anything specific.
		absolute(dir);
		if (ok)			/* want only directory part */
			*get_tail(dir, 1) = 0;
	}
	if (*dir) {
		dir += strlen(dir);	/* ptr to end of string */
		if (!is_path_separator(dir[-1])) {
			*dir++ = path_sep; /* make sure it ends with slash */
			*dir = 0;
		}
	}
	return ok;
}

// Called whenever a window starts displaying a different buffer
// or the user switches windows.

switching_to_buffer()
{		// put "timestamp" on this buffer showing last access
	buf_accessed = ++buf_accessed_clock;
}
