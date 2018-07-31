/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1988, 1997 Lugaru Software Ltd.  All rights reserved.	*
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

// This file contains the commands relating to tags.

#include "eel.h"
#include "tags.h"

zeroed char tags_from_bsc;
char bsc_file[FNAMELEN];

init_tags()		/* read tags if necessary */
{
	char buf[FNAMELEN];

	if (tags_from_bsc)
		return;
	if (!exist("-tags")) {
		if (!look_up_tree(buf, initial_tag_file, NULL, NULL))
			strcpy(buf, initial_tag_file);
		absolute(buf);
		sayput("Loading tags from %s...", buf);
		load_tags(buf);
	}
	if (tags_from_bsc)
		_tags_buffer = name_to_bufnum("-tags");
}

tags_header()	/* return length of tags file header */
{		/* header line says if tags file is sorted */
	point = 0;		/* also goes to top */
	return parse_string(1, "<tab>TAGS<tab>(UN)?SORTED\n", NULL);
}

are_tags_sorted()	/* -1: no header, 0=not sorted, 1=sorted */
{			/* also goes to top */
	return tags_header() ? (character(6) == 'S') : -1;
}

mark_tags(sorted)	/* update header line (adding if needed) */
{
	bufnum = _tags_buffer;
	if (are_tags_sorted() != sorted) {
		delete(0, tags_header());
		bprintf("\tTAGS\t%sSORTED\n", sorted ? "" : "UN");
	}
}

load_tags(file)
char *file;
{
	int i;

	tags_from_bsc = 0;
	*_last_tag = *_last_tag_file = 0;
	if (!strfcmp(get_extension(file), ".bsc")) {
		tags_from_bsc = 1;
		strcpy(bsc_file, file);
		absolute(bsc_file);
		return;
	}
	save_var bufnum = _tags_buffer = zap("-tags");
	i = read_file(file, FILETYPE_MSDOS);
	if (i == 2)			/* new file */
		mark_tags(0);		/* make new-fmt tags file */
	else if (i) {			/* error reading file */
		restore_vars();
		delete_buffer("-tags");
		quick_abort();
	} else if (!tags_header()) {
		if (!ask_yn("Convert", "Convert old-format tags file? ",
					"Yes", "No", 1))
			quick_abort();
		sayput("Converting old-format tags file...");
		if (!string_replace(";", "\t", 0)) {
			mark_tags(0);
			do_save_tags();
		}
	}
}

do_save_tags()		/* save tags to their file if unsaved */
{
	int oldbuf = bufnum;

	if (exist("-tags")) {
		bufnum = _tags_buffer;
		if (modified)
			do_save_file(1, 1, 1);
		bufnum = oldbuf;
	}
}

command sort_tags()	/* sort & save if needed */
{
	init_tags();
	if (tags_from_bsc)
		error("This type of tag file may not be sorted.");
	bufnum = _tags_buffer;
	if (are_tags_sorted() == 1)
		return;
	sayput("Sorting tags...");
	save_var narrow_start = tags_header();	/* don't sort header */
	save_var sort_status = 1;
	save_var abort_searching = ABORT_ERROR;
	if (sort_another("-tags", 0, 0))
		return;		/* user aborted */
	narrow_start = 0;
	delete(0, tags_header());	/* remove header */
	mark_tags(1);		/* add header saying it's sorted */
	do_save_tags();
}

char *tag_match(s, flags) 
char *s;
{
	char tmp[TAGLEN];

	if (tags_from_bsc) {
		strcpy(_this_match, s);
		return (flags & STARTMATCH) ? s : 0;
	}
	save_var bufnum;
	save_var abort_searching = 0;
	bufnum = _tags_buffer;
	save_var case_fold = !tag_case_sensitive;
	if (flags & STARTMATCH)
		point = 0;
	if (*s) {
		sprintf(tmp, "\n%s", s);
		if (!search(1, tmp))
			return 0;
		to_begin_line();
	} else if (!nl_forward() || point == size())
		return 0;
	parse_string(1, "[^\t\n]+", _this_match);
	to_end_line();
	if ((flags & EXACTONLY) && strfcmp(_this_match, s))
		return 0;
	return _this_match;
}

tag_lister(s, finder, mbuf)	/* make list of matches for s in mbuf */
char *s, *(*finder)();
{
	char pat[TAGLEN];
	int sorted;

	finder = finder;	/* silence eel's warning */
	save_var bufnum;
	save_var abort_searching = 0;
	if (tags_from_bsc) {
		buf_printf(mbuf, "%s", s);
		return;
	}
	if (want_sorted_tags && !*s)
		sort_tags();
	bufnum = _tags_buffer;
	save_var case_fold = !tag_case_sensitive;
	sorted = are_tags_sorted();	/* also goes to top */
	if (*s) {
		sprintf(pat, "\n%s", s);
		while (search(1, pat)) {
			to_end_line();
			buf_xfer(mbuf, matchstart + 1, point + 1);
		}
	} else {
		nl_forward();
		buf_xfer(mbuf, point, size());
	}
	bufnum = mbuf;
	if (want_sorted_tags && !sorted && !user_abort) {
		abort_searching = ABORT_ERROR;
		sort_another(bufnum_to_name(mbuf), 0, 0);
	}
	point = 0;
	tab_size = 30;
	goal_column = display_column = 0;
}

get_tag(res, pr)	/* do completion on tags */
char *res, *pr;		/* returns either tag, or tag <Tab> file */
{			/* or tag <Tab> file <Tab> pos */
	save_var menu_width = 60, completion_lister = tag_lister;
	comp_read(res, pr, tag_match, (tag_case_sensitive ? 0 : COMP_FOLD)
			  | MUST_MATCH | NONE_OK, "");
}

command pluck_tag() on cx_tab[',']
{		 /* read a function name at point & go there via tags */
	char tag[TAGLEN];

	tiled_only();
	init_tags();
	iter = 0;
	point--;
	re_search(1, word_pattern);
	re_search(-1, word_pattern);
	quiet_set_bookmark();
	grab(point, matchstart, tag);
	note("Going to `%s'...", tag);
	must_go_tag(tag, 1);
}

command goto_tag() on cx_tab['.'] /* asks for a tag, then goes there */
{
	char tag[TAGLEN], pr[FNAMELEN];

	tiled_only();
	init_tags();
	iter = 0;
	*tag = 0;
	if (!has_arg) {
		if (!*_last_tag)
			sprintf(pr, "Find tag: ");
		else if (tags_from_bsc)
			sprintf(pr, "Find tag [next %s]: ", _last_tag);
		else
			sprintf(pr, "Find tag [next %s of %d]: ",
					_last_tag, count_tags(_last_tag));
		get_tag(tag, pr);
	}
	quiet_set_bookmark();
	must_go_tag(tag, 1);
}

command next_tag() on reg_tab[NUMCTRL(GREYPLUS)]
{
	quiet_set_bookmark();
	next_prev_tag(iter);
	iter = 0;
}

command previous_tag() on reg_tab[NUMCTRL(GREYMINUS)]
{
	quiet_set_bookmark();
	next_prev_tag(-iter);
	iter = 0;
}


next_prev_tag(dir)
{
	init_tags();
	if (tags_from_bsc) {
		char fname[FNAMELEN];
		int linenum;

		if (!browser_find_match(fname, &linenum, dir))
			say("No %smatches.", dir ? "more " : "");
		else
			get_to_tag_match_line(fname, linenum);
		if (dir)
			say("Going to %s instance of %s",
				(dir > 0) ? "next" : "previous", _last_tag);
	} else
		must_go_tag("", dir);
}

// Get to a tag match by line number (counting from 1).

get_to_tag_match_line(char *fname, int linenum)
{
	char tdir[FNAMELEN];

	strcpy(_last_tag_file, fname);
	strcpy(tdir, bsc_file);
	*get_tail(tdir, 0) = 0;
	absolute(_last_tag_file, tdir);
	locate_window("", _last_tag_file);
	if (find_it(_last_tag_file, default_translation_type))
		return;	// Error reading the file, already reported.
	go_line(linenum);
	window_start = prev_screen_line(show_tag_line);
}

// Return nonzero if we can't find the tag.
go_bsc_tag(char *s)
{
	if (!*s) {		// Old way to go to next tag.
		next_prev_tag(1);
		return 0;
	}
	if (browser_query(bsc_file, s, 0) == -1)	// error
		return 1;
	strcpy(_last_tag, s);
	next_prev_tag(0);
	return 0;
}

/* Find this tag, complain if not found. */
/* If s is "", look for a duplicate tag.  In that case, n_fwd determines
   which one: 1==next, -1==previous, 0==same as before. */

must_go_tag(s, n_fwd)
char *s;
{
	int err = go_tag(s, n_fwd);

	if (err == 1)
		error("%s is not in the tag list", _last_tag);
	else if (err == 2)
		error("%s is not in file %s", _last_tag, _last_tag_file);
}

/* Return 0 if ok, 1 if not a tag, 2 if not in that file. */
/* If s is "", look for a duplicate tag.  In that case, n_fwd determines
   which one: 1==next, -1==previous, 0==same as before. */
/* This routine hands off to the BSC stuff if necessary, and also
   handles offering to retag and searching again. */

go_tag(s, n_fwd)
char *s;
{
	char msg[FNAMELEN];
	short err;

	if (!*s && !*_last_tag)
		error("No current tag.");
	if (tags_from_bsc)
		return go_bsc_tag(s);
	err = do_go_tag(s, n_fwd);
	if (err != 2)
		return err;
	sprintf(msg, "Tag %s has moved, retag file %s? [Y] ",
			_last_tag, _last_tag_file);
	if (ask_yn("Retag file", msg, "Yes", "No", 1)) {
		do_retag_file(_last_tag_file);
		do_save_tags();
		return do_go_tag(_last_tag, n_fwd);
	}
	return 0;
}

// Search for nth occurrence of the tag pat, wrapping if necessary.
// N may be negative (or 0 to repeat the last one).
// Return 1 if we found one, 0 if there are none.

tag_search_by_offset(char *pat, int n_fwd)
{
	int dir = RE_FORWARD;

	if (n_fwd < 0){
		dir = RE_REVERSE;
		n_fwd = -n_fwd;
		to_begin_line();
	} else if (n_fwd > 0) {
		to_end_line();
	} else {			// n_fwd == 0: return current match again
		to_begin_line();
		n_fwd = 1;
	}
	while (n_fwd-- > 0)
		if (!re_search(dir, pat)) {
			point = (dir == RE_FORWARD) ? 0 : size();
			if (!re_search(dir, pat))	// Wrap and repeat.
				return 0;
		}
	return 1;
}

// How many tags have this name?
count_tags(char *s)
{
	char pat[FNAMELEN], *p, tag[FNAMELEN];
	int cnt = 0;

	strcpy(tag, s);
	if (p = index(tag, '\t'))
		*p = 0;		/* remove file name from tag spec */
	sprintf(pat, "^%q\t", tag);
	save_var bufnum = _tags_buffer;
	save_var case_fold = !tag_case_sensitive;
	save_var point = 0;
	while (re_search(1, pat))
		cnt++;
	return cnt;
}

/* Go to tag s, return 0=ok, 1=no such tag, 2=tag moved. */
/* If s is "", look for a duplicate tag.  In that case, n_fwd determines
   which one: 1==next, -1==previous, 0==same as before. */

do_go_tag(s, n_fwd)
char *s;
{
	char pat[FNAMELEN], tdir[FNAMELEN], *file, *p;
	int pos, oldbuf = bufnum;

	bufnum = _tags_buffer;
	save_var case_fold = !tag_case_sensitive;
	if (*s) {
		if (p = index(s, '\t')) {
			strcpy(_last_tag_file, p + 1);
			*p = 0;		/* remove file name from s */
			if (p = index(_last_tag_file, '\t'))
				*p = 0;
		} else
			*_last_tag_file = 0;
		strcpy(_last_tag, s);
		if (!*_last_tag)	/* no last tag */
			return 0;
		if (*_last_tag_file)
			sprintf(pat, "^%q\t%q\t",
				_last_tag, _last_tag_file);
		else
			sprintf(pat, "^%q\t", _last_tag);
		point = 0;
		if (!re_search(1, pat))		/* look for 1st */
			return 1;
	} else {		/* find next matching tag */
		pos = point;
		sprintf(pat, "^%q\t", _last_tag);
		if (!tag_search_by_offset(pat, n_fwd))
			return 1;
	}
	grab(give_begin_line(), give_end_line(), pat);	/* tag, file, pos */
	file = index(pat, '\t');
	*file++ = 0;

	p = index(file, '\t');		/* find start of pos */
	pos = strtoi(p + 1, 10);
	*p = 0;
	p = index(p + 1, '\t');		/* if p, p+1 has line's text */
	strcpy(_last_tag_file, file);
	put_directory(tdir);
	bufnum = oldbuf;
	absolute(_last_tag_file, tdir);
	locate_window("", _last_tag_file);
	find_it(_last_tag_file, default_translation_type);
	sprintf(tdir, "%q[^a-zA-Z0-9_]", _last_tag);
	point = pos;
	if (!parse_string(1, tdir, NULL)) {
		if (!p || !prox_line_search(p + 1))	/* search by text */
			return 2;
		to_begin_line();
	}
	window_start = prev_screen_line(show_tag_line);
	return 0;
}

prox_line_search(p)	/* search for line with p on it closest to point */
char *p;		/* and go there, return 1, else 0 */
{
	int orig = point, fwd, bwd, fwdok, bwdok;

	fwdok = line_search(1, p);
	fwd = point;
	point = orig;
	bwdok = line_search(-1, p);
	bwd = point;
	point = orig;
	if (!fwdok && !bwdok)	/* neither one found it, fail */
		return 0;
	if (fwdok && bwdok)	/* if both found it, use closest */
		fwdok = (fwd - point) <= (point - bwd);
	point = fwdok ? fwd : bwd;
	return 1;
}

command select_tag_file() on cx_tab[ALT(',')]
{				/* switch to a particular tags file */
	char file[FNAMELEN], *def = initial_tag_file;
	int old = bufnum;

	do_save_tags();
	if (tags_from_bsc)
		def = bsc_file;
	else if (exist("-tags")) {
		bufname = "-tags";
		def = filename;
		bufnum = old;
	}
	save_var only_file_extensions = "|.tag|.bsc|";
	get_file(file, "Tag or browser file", def);
	load_tags(file);
	say("Tags loaded from %s", file);
}

command clear_tags()	/* erase all tags */
{
	init_tags();
	if (tags_from_bsc)
		error("Delete the .BSC file %s to remove all tags.", bsc_file);
	buf_zap(_tags_buffer);
	mark_tags(1);
	do_save_tags();
}

command tag_files() on cx_tab[ALT('.')]
{
	char pat[FNAMELEN], *s;

	init_tags();
	if (tags_from_bsc)
		error("Must tag files using the BSCMAKE program.");
	get_file(pat, "Add/update tags for files matching", filename);
	iter = 0;
	if (!(s = do_file_match(pat, FM_EXACT | FM_NO_DIRS)))
		error("No matches");
	for (; s; s = do_file_match(pat, 0))
		do_retag_file(s);
	do_save_tags();
	say("%s tagged.", pat);
}

tag_a_file(s)
char *s;
{
	int ok, err = 0, orig = bufnum, temp = 0, oldmod;

	bufnum = _tags_buffer;	/* go to right place in tags buffer */
	point = 0;
	nl_forward();
	oldmod = modified;	/* want to see if we add new tags */
	modified = 0;
	bufnum = orig;
	if (!look_file(s)) {
		if (!temp)
			temp = tmp_buf();
		bufnum = temp;
		save_var readonly_warning = 0;
		err = read_file(s, default_translation_type);
	}
	if (!err) {
		save_var point = 0;
		ok = call_by_suffix(s, "tag-suffix-%s");
	}
	bufnum = _tags_buffer;
	if (modified)		/* we added new tags, mark unsorted */
		mark_tags(0);
	else
		modified = oldmod;
	bufnum = orig;
	if (temp)
		buf_delete(temp);
	if (err)		/* couldn't read file */
		quick_abort();	/* already showed error msg */
	else if (!ok)
		error("Don't know how to tag the file %s", s);
}

tag_suffix_asm()	/* tag all labels or procs in the file */
{
	char func[TAGLEN];
	int start, ofold = case_fold;

	case_fold = 1;
	while (re_search(1, "^[ \t]*([a-z0-9@$_]+)[ \t]*:")) {
		grab(start = find_group(1, 1), find_group(1, 0), func);
		add_tag(func, start);
	}
	point = 0;
	while (re_search(1, "^[ \t]*([a-z0-9@$_]+)[ \t]+proc[ \t\n;]+")) {
		grab(start = find_group(1, 1), find_group(1, 0), func);
		add_tag(func, start);
	}
	case_fold = ofold;
}

tag_suffix_e()		{	tag_suffix_c();	}
tag_suffix_h()		{	tag_suffix_c();	}
tag_suffix_y()		{	tag_suffix_c();	}
tag_suffix_cpp()	{	tag_suffix_c();	}
tag_suffix_cxx()	{	tag_suffix_c();	}
tag_suffix_hpp()	{	tag_suffix_c();	}
tag_suffix_hxx()	{	tag_suffix_c();	}
tag_suffix_java()	{	tag_suffix_c();	}

tag_suffix_c()		/* tag all c functions in this file */
{
	int end;

	save_var case_fold = 0;	// don't confuse STRUCT with struct
	tag_extern_decl = 0;
	while (re_search(1, "([{;]|/<*|/>|[a-zA-Z0-9_]+)")) {
		end = point;		/* find {, comment open, or ident */
		point = matchstart;
		switch (curchar()) {
		case '{':	skip_c_braces();
				break;
		case ';':	tag_extern_decl = 0;	// assume next var
				point++;		// is being defined
				break;
		case '/':	if (character(point + 1) == '*') {
					point += 2;
					search(1, "*/");
				} else
					nl_forward();	/* c++ comment */
				break;
		default:	if (!good_c_tag())
					point = end;
				break;
		}
	}
}

skip_c_braces()		/* skip over c function definition */
{
	int level = 0;
	char c, buf[4];

	if (parse_string(-1, "<dquote>[ \t\n]*")
		&& !parse_string(-1, "color_scheme.*")) {
		point++;	// if C++'s extern "C" { or similar, don't skip
		return;
	}
	strcpy(buf, "X|\\");
	while (re_search(1, "[{}\"']|/<*|/>")) {
		buf[0] = c = character(point - 1);
		if (c == '\"' || c == '\'')
			while (re_search(1, buf)
					&& character(point - 1) == '\\')
				point++;
		else if (c == '*')
			search(1, "*/");
		else if (c == '/')		/* c++ comment */
			nl_forward();
		else if (c == '{')
			level++;
		else if (!--level)
			break;
	}
}

good_c_tag()	// tag name at point if a valid c tag
{		// return 0 to go back to orig point before searching again
	char func[TAGLEN];
	int start = point, i = 1;

	if (!parse_string(1, "[a-zA-Z0-9_]+", func))
		return 0;
	else if (!strcmp(func, "struct") || !strcmp(func, "union"))
		return tag_c_struct(0);		// maybe struct tag
	else if (!strcmp(func, "enum"))
		return tag_c_struct(2);		// or similar enum def
	else if (!strcmp(func, "extern")) {
		tag_extern_decl = 1;	// next vars are just declarations
		return 1;
	} else if (parse_string(-1, "^[ \t]*#[^#\n]*"))
		return tag_c_define(func);	// do preproc line
	if (parse_string(1, "[ \t\n]*%("))
		i = tag_c_func();
	else if (tag_c_variable() && ((tag_declarations & 2)
				      || !tag_extern_decl))
		i = 2;
	if (i == 2 && !isdigit(*func))
		add_tag(func, start);
	return i;
}

tag_c_func()	// tag this, if it's a function definition, or maybe decl
{		// return 0: go back & try again, 1: continue, 2: also tag
	int ret = 2;

	if (!move_level(1, "(", ")", 1))
		return 0;	/* after identifier, skip over arg list */
	c_fwd_space();
	if (parse_string(1, "on[ \t]")) {	// eel command
		search(1, "{");
		point--;
		ret = 2;
	} else if (parse_string(1, "[A-Za-z{]")) // func definition
		ret = skip_param_decls();
	else if (curchar() == ':')		// C++ initializer
		ret = skip_cpp_init();
	else if (!parse_string(1, "[,;]"))	// not even a declaration
		ret = 0;
	else if (!(tag_declarations & 1))	// a declaration, don't tag it?
		ret = 1;
	if (ret)
		tag_extern_decl = 0;
	return ret;
}

skip_cpp_init()		// found base class initializer, skip past it
{
	if (!search(1, "{"))
		return 0;
	point--;
	return 2;
}

skip_param_decls()	// move past param decls in func def to just before "{"
{		// return 0: go back & try again, 1: continue, 2: also tag
	int orig = point;	// good if no decls, or they end with ";"

	if (curchar() == '{' || search(1, "{") && semi_before(--point))
		return 2;	// had ; just before {, good decls
	point = orig;		// these weren't param decls, go back
	return 1;
}

semi_before(p)	// is there a semicolon just before p (ignoring comments)?
{
	save_var point = p;
	return !cind_try_space() && character(point - 1) == ';';
}

tag_c_struct(flavor)	// tag the following structure/enum if we're
{						// defining a tag for it
	char func[TAGLEN];
	int start;

	c_fwd_space();
	start = point;
	if (!parse_string(1, "[a-zA-Z0-9_]+", func))
		*func = 0;
	c_fwd_space();
	if (parse_string(1, "{")) {
		if (flavor == 2)
			tag_c_enum();
		if (*func)
			add_tag(func, start);
	}
	return 1;
}

tag_c_enum()	// just before { of enum list; tag them all
{
	char name[TAGLEN];

	do {
		point++;
		c_fwd_space();
		if (!parse_string(1, "[a-zA-Z0-9_]+", name))
			return;
		add_tag(name, matchstart);
		c_fwd_space();
		if (curchar() == '=') {
			do {		/* move past enum value */
				if (!re_search(1, "[,;{}]"))
					return;
			} while (in_c_comment(0));
			point--;
		}
	}  while (curchar() == ',');
}

tag_c_define(keyw)	// found a preproc line, maybe enter #define
char *keyw;		// either way, skip past line
{
	char func[TAGLEN];
	int start;

	if (!strcmp(keyw, "define")) {
		point += parse_string(1, "[ \t]*");
		start = point;
		if (parse_string(1, "[a-zA-Z0-9_]+", func))
			add_tag(func, start);
	}
	if (parse_string(1, ".*/<*>"))
		search(1, "*/");
	do {
		if (!nl_forward())
			break;
	} while (character(point - 2) == '\\');
	return 1;
}

tag_c_variable()	// is this a var definition?
{
	if (parse_string(1, "([) \t\n]|<[>[^]\n]*<]>)*[,;=]")) {	
		point = matchend;	// ordinary variable definition
		if (character(point - 1) == '=')
			skip_initializer();
	} else if (parse_string(1, "[ \t\n]*<)>+[ \t\n]*!<(>"))
		re_search(1, "![;{]");	// func ptr definition
	else
		return 0;
	return 1;
}

skip_initializer()		// move past c initializer
{		
	int level = 0;

	c_fwd_space();
	if (curchar() == '{')	// don't bother skipping over {}'s,
		return;		// caller does that anyway
	while (re_search(1, "[,;()]"))
		switch (character(point - 1)) {
			case ',':
			case ';':	if (level < 0)
						break;
					point--;
					return;
			case '(':	level--; break;
			case ')':	level++; break;
		}
}

c_fwd_space()	/* move fwd past whitespace or comments */
{
	while (point < size() - narrow_end)
		switch (curchar()) {
		case ' ': case '\t': case '\n':
			point++; break;
		case '/':
			switch (character(point + 1)) {
			case '*':	point += 2; search(1, "*/"); break;
			case '/':	nl_forward(); break;
			default:	return;
			}
			break;
		default:
			return;
		}
}

add_tag(func, pos)
char *func;
{
	char rel[FNAMELEN], *file = filename, tdir[FNAMELEN];

	if (tag_relative) {		/* use relative version instead */
		put_tag_directory(tdir);
		relative(file, rel, tdir);
		file = rel;
	}
	noteput("%s: adding %s...", file, func);
	if (tag_by_text) {
		int start;

		save_var point;
		point = pos;
		to_begin_line();
		start = point;
		to_end_line();
		buf_printf(_tags_buffer, "%s\t%s\t%d\t",
			func, file, pos);
		buf_xfer(_tags_buffer, start, point);
		buf_printf(_tags_buffer, "\n");
	} else
		buf_printf(_tags_buffer, "%s\t%s\t%d\n", func, file, pos);
}

put_tag_directory(dir)	// put directory of current tag file in dir
char *dir;
{
	save_var bufnum = _tags_buffer;
	put_directory(dir);
}

do_retag_file(file)	/* takes abs pathname, retags it */
char *file;
{
	char rel[FNAMELEN];

	relative(file, rel);
	delete_tags(file);
	noteput("%s: searching for tags...", rel);
	tag_a_file(file);
}

delete_tags(file)	/* delete all tags pointing to file (abs name) */
char *file;
{
	char rel[FNAMELEN], tdir[FNAMELEN];

	put_tag_directory(tdir);
	relative(file, rel, tdir);
	noteput("%s: deleting old tags...", rel);
	do_delete_tags(tag_relative ? rel : file);
}

do_delete_tags(file)
char *file;
{
	int start;
	char pat[FNAMELEN];

	save_var bufnum;
	bufnum = _tags_buffer;
	point = 0;
	sprintf(pat, "\t%s\t", file);
	while (search(1, pat)) {
		to_begin_line();
		start = point;
		nl_forward();
		delete(start, point);
	}
}
