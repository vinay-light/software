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

// This file has C mode.

#include "eel.h"
#include "c.h"
#include "kill.h"
#include "colcode.h"
#include "proc.h"

/*
Automatic indentation for C and EEL code.  Several indenting styles
are supported, selected by the following variables.

                        *       *       *       *

The position of the closing brace is controlled by the Closeback
variable, 1 by default:

Closeback = 0;                  Closeback = 1;
if (foo) {                      if (foo) {
        bar();                          bar();
        baz();                          baz();
        }                       }

By placing the opening brace on the following line, these styles
may be also used:

Closeback = 0;                  Closeback = 1;
if (foo)                        if (foo)
        {                       {
        bar();                          bar();
        baz();                          baz();
        }                       }


                        *       *       *       *

The Topindent variable controls whether top-level statements in a function
are indented.  It is 1 by default.

Topindent = 0;                  Topindent = 1;
foo()                           foo()
{                               {
if (bar)                                if (bar)
        baz();                                  baz();
}                               }

                        *       *       *       *

The Matchdelim variable controls whether typing ), ], or } displays the
corresponding (, [, or { when the former is typed.  It uses the
show-matching-delimiter command.
*/

c_indenter()		/* replace surrounding indentation with new */
{
	if (!(in_c_comment(c_look_back) & IN_COMMENT))
		indent_to_column(c_compute_indent());
	else if (reindent_c_comments)
		indent_c_comment();
}

/*
Move in direction dir past a matched pair of characters in C-mode buffers.
On success, or if the end of the buffer is encountered before the
first character is found, return the new buffer position.
Otherwise return -1.
Ignore delimiters inside of comments or strings.  (However, if we began
inside a comment or string, then accept such delimiters.)
*/

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

char _c_mode_name[] = "C";

command c_mode()
{
	mode_keys = c_tab;		/* use these keys */
	c_tab[']'] = Matchdelim ? (short) show_matching_delimiter : 0;
	indenter = c_indenter;
	auto_indent = 1;
	major_mode = _c_mode_name;
	strcpy(comment_start, "(/</|*>)[ \t\f]*");
	strcpy(comment_pattern, "//.*$|/<*>(.|<newline>)*<*>/<FirstEnd>");
	if (new_c_comments) {
		strcpy(comment_begin, "// ");
		strcpy(comment_end, "");
	} else {
		strcpy(comment_begin, "/* ");
		strcpy(comment_end, " */");
	}
	mode_move_level = c_move_level;
	recolor_range = color_c_range;	// set up coloring rules
	recolor_from_here = color_c_from_here;
	if (want_code_coloring)		// maybe turn on coloring
		when_setting_want_code_coloring();
	if (auto_show_c_delimiters)
		auto_show_matching_characters = c_auto_show_delim_chars;
	if (c_mode_mouse_to_tag)
		mouse_goes_to_tag = 1;
	if (c_tab_override > 0)
		tab_size = c_tab_override;
	try_calling("c-mode-hook");
	make_mode();
}

c_mode_hook()
{
}

/* make c mode the default mode for .c, .h, .e, etc. files,
 with slight modifications for each */

suffix_c()
{
	c_mode();
	compile_buffer_cmd = compile_c_cmd;	// can compile this
	c_extra_keywords = 0;	// don't recognize C++ or EEL keywords in .c
}

suffix_h()
{
	c_mode();
	c_extra_keywords = CPP_KEYWORDS | EEL_KEYWORDS;
}	// recognize all keywords; can't tell if it's C/C++/EEL from extension

suffix_cpp()
{
	c_mode();
	compile_buffer_cmd = compile_cpp_cmd;	// can compile this
	c_extra_keywords = CPP_KEYWORDS;	// recognize only C++, not EEL
}

suffix_hpp()
{
	c_mode();
	c_extra_keywords = CPP_KEYWORDS;	// recognize only C++, not EEL
}

suffix_e()
{
	c_mode();
	concurrent_compile = 0;	// we want to load it after, so no concur
	compile_buffer_cmd = compile_eel_cmd;		// can compile this
	post_compile_hook = load_this_bytecode_file;	// and load it after
	pre_compile_hook = compile_via_dll;	 // maybe compile internally
	c_extra_keywords = EEL_KEYWORDS;	// recognize only EEL, not C++
}

suffix_java()
{
	c_mode();
	compile_buffer_cmd = compile_java_cmd;	// can compile this
	c_extra_keywords = JAVA_KEYWORDS;	// recognize Java keywords
}

// other file extensions are synonymous with the ones above
suffix_y()	{ suffix_c(); }
suffix_cxx()	{ suffix_cpp(); }
suffix_hxx()	{ suffix_hpp(); }

jmp_buf c_indent_giveup;	/* come here when we hit narrowed edge */


/*  Look at the last two lines and return the correct indentation
    for the current line, assuming C source (or similar).  At start,
    we must be at the end of a line's indentation.
*/

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

cind_search(pat)	/* search back for pattern */
char *pat;		/* if we reach start of (examinable) buffer, give up */
{			/* call this only from c_compute_indent */
	int res = re_search(-1, pat);

	if (point == narrow_start)
		longjmp(&c_indent_giveup, 1);
	return res;
}

cind_space()		/* move back over any whitespace or comments */
{			/* give up if we hit start */
	if (cind_try_space())
		longjmp(&c_indent_giveup, 1);
}

cind_try_space()	/* move back over whitespace, comments, preproc */
{			/* lines, and return 0, or 1 if we hit start */
	for (;;) {
		if (index(" \t\n\f", character(point - 1)))
			point--;
		else if (cind_skip_new_comment() || cind_skip_preproc_line())
			;
		else if (character(point - 1) == '/'
					&& character(point - 2) == '*') {
			point -= 2;
			if (!search(-1, "/*") || point == narrow_start)
				return 1;
		} else
			return point == narrow_start;
	}
}

cind_skip_new_comment()	/* move before // comment on line */
{			/* return 1 if there was one */
	int old = point;

	save_var narrow_start = give_begin_line();
	while (search(-1, "//"))
		if (at_c_comment(point + 2, 0) == IN_NEW_COMMENT) {
			point -= parse_string(-1, "/+");
			return 1;
		}
	point = old;
	return 0;
}

cind_skip_preproc_line()	/* move back past any preproc line */
{				/* return 1 if there was one */
	int old = point;

	for (;;) {
		to_begin_line();
		if (character(point - 2) != '\\')
			break;
		point -= 2;	/* prev might be preproc contin line */
	}
	if (parse_string(1, "[ \t\f]*#"))
		return (point > narrow_start);
	point = old;
	return 0;
}

c_line_before()		/* retrieve last character of prev line of c code */
{			/* (ignoring comments, blank lines, etc.) */
	save_var point;		/* assumes we're in this line's indentation */
	return cind_try_space() ? ';' : character(point - 1);
}

fix_narrowing(p)	// return p, limited by narrowing, and at line's start
{
	save_var point = p;
	to_begin_line();
	return point;
}

indent_after_backslash()	// assume we're at start of line
{				// after the one ending w/ backslash
	save_var narrow_end = size() - point;	// only look back
	do {				// find last line w/o backslash
		if (!nl_reverse())
			break;
	} while (character(point - 1) == '\\');
	if (!parse_string(1, "\n[ \t\f]*#define[ \t\f]+[a-z0-9_]+"))
		return 0;	// not a big #define, so use no indentation
	point = matchend;	// get past ident being defined
	if (curchar() == '(')	// maybe skip fwd past param list
		if (!c_skip_level('(', ')'))
			return 0;
	point += parse_string(1, "[ \t\f]+");	// indent with start of def
	return current_column();
}



/*  Look at the last two lines and guess at the correct indentation,
    assuming C source (or similar).  If we're not in this line's
    indentation, though, or our new indentation matches the old,
    just indent one more level.
*/

command do_c_indent() on c_tab['\t']
{
	int orig = point, ind = get_c_indent();
	int orig_column = current_column();

	if (maybe_indent_rigidly(0))
		return;
	to_indentation();
	if (!c_tab_always_indents && orig_column > current_column()) {
					/* if not in indentation */
		point = orig;
		to_column(orig_column + tab_size - orig_column % tab_size);
	} else if (prev_cmd == C_INDENT)	/* repeated, make bigger */
		to_column(orig_column + ind);
	else
		c_indenter();
	this_cmd = C_INDENT;
}

/*
Tell if more indent is required.
Assumes last line had no indent and point is at its start.
The hard case is distinguishing between these when Topindent is zero:

	foo();				foo();
}				}
func(bar)			if (bar)

When point is just after these examples, we must examine the word
at "func" to distinguish the left example (the end of a function and
beginning of the next, requiring no indentation) from the right (the
end of a block and start of a conditional, requiring indentation).
*/
top_indent(prev_end)
{
	if (Topindent)
		return (prev_end == '{');
	switch (prev_end) {
		case ';':
		case '}':	return 0;
		default:	return 1;
		case '{':	if (parse_string(1, "[ \t\f]*{")) {
					cind_try_space();
					to_indentation();
				}
		case ')':	break;
	}
	return c_statement_start();
}

/*
Tell if the last line begins a statement (rather than a function
declaration or the continuation of a previous statement).
Assumes point is at the start of the last line.
*/
c_statement_start()
{
	return parse_string(1, "[{} \t\f]*(if|else|while|do|for)[^a-zA-Z0-9]");
}

just_open(p)
{
	save_var point = p;
	return parse_string(1, "[ \t\f]*{[ \t\f]*($|//|/<*>)");
}

move_before_labels()
{
	int p;

	while ((p = parse_string(-1, "^[ \t\f]*![a-zA-Z0-9_]+[ \t\f]*:"))
		   && !is_case(point - p)) {
		to_begin_line();
		cind_space();			/* skip whitespace and comments */
	}
}

is_label(p)	/* does line at p contain only case: or label? */
{
	save_var point = p;
	while (parse_label())	/* go past any labels */
		point = matchend;
	return parse_string(1, "[ \t\f]*\n|/<*>|//");
}

is_case(p)	/* is there a case-like statement at position p? */
{
	if (!index("cdp", character(p)))
		return 0;
	save_var point = p;
	return parse_string(1, "(case|default|public|private|protected)"
			    "[^a-zA-Z0-9_]");
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

is_switch(p)	/* is there a switch-like statement at position p? */
{
	if (!index("scu", character(p)))
		return 0;
	save_var point = p;
	return parse_string(1, "(switch|struct|union|class)[^a-zA-Z0-9_]");
}

is_else(p)	/* is there an else keyword at position p? */
{
	if (character(p) != 'e')
		return 0;
	save_var point = p;
	return parse_string(1, "else[^a-zA-Z0-9_]");
}

in_c_comment(lookback)		// is point inside a c comment, string, etc?
{
	int i = scan_for_string();

	if (i || !lookback)	// check this line first
		return i;
	save_var narrow_start = point - lookback;
	save_var point;
	while (re_search(RE_REVERSE | RE_FASTEST, "/<*>|<*>/")) {
		point++;
		i = scan_for_string();
		if (curchar() == '/')		// found */ sequence
			return 0;
		else if (!i || i == IN_OLD_COMMENT)	// did we find "/*"?
			return IN_OLD_COMMENT;
	}
	return 0;		// not found, assume we're not in comment
}

scan_for_string()	// check current line to see if we're in
{			// string or new-style comment
	int c;

	save_var point;
	save_var narrow_end = size() - point;
	to_begin_line();		// scan this line before point
	while (parse_string(-1, ".*\\\n"))
		point = matchend;	// Go back past this continuation line.
	while (re_search(1, "<squote|dquote>|//|/<*>")) {
		point = matchstart;
		c = curchar();
		if (c == '/' && character(point + 1) == '/')  // found "//"
			return IN_NEW_COMMENT;
		else if (!c_skip_item(c, RE_FORWARD))
			return c == '/' ? IN_OLD_COMMENT
			     : c == '"' ? IN_STR_CONST : IN_CHAR_CONST;
	}
	return 0;
}

at_c_comment(pos, lookback)
{
	save_var point = pos;
	return in_c_comment(lookback);
}

indent_c_comment()		/* indenter when inside a comment */
{
	int prev_indent;
	int orig, has_star, no_star = 0;

	has_star = parse_string(1, "[ \t\f]*<*>");
	orig = point;
	re_search(-1, "[^ \t\f\n]");	/* find previous non-blank line */
	to_indentation();
	if (has_star && parse_string(1, "[/ \t\f]*<*>"))
		point = matchend - 1;	// line up star under prev star
	else
		no_star = 1;
	prev_indent = current_column();
	point = orig;
	if (no_star && parse_string(1, "<*>/"))
		prev_indent = 0;
	to_column(prev_indent);		/* indentation as previous */
}

int indent_just_open(ind)		// Indent a line with just { on it.
{
	int extra = 0;

	if (!Topindent && !ind && c_statement_start())
		extra = get_c_indent();
	if (ind && !Closeback)
		extra = get_c_indent();
	return ind + c_brace_offset + extra;
}

/* We are at the beginning of a statement, which may be part of a larger
 * statement because it has "if ()" or similar before it.  Find the
 * biggest statement that the current line could be the tail end of,
 * and return its indentation.  We assume the statement starts at the
 * beginning of a line. */

indent_after_statement(orig) // orig is place needing indentation, for toplevel
{
	int lastcont, i, c, atparen = -1;

	for (;;) { /* was only the end of a larger statement, find start */
		do {	/* look back for line that ends with ;{}: */
			lastcont = point;
			to_begin_line();
			if (cind_try_space())
				break;
			if ((c = character(point - 1)) == ')') {
				atparen = lastcont;
				if (!c_rev_skip_level('(', ')'))
					break;
				to_begin_line();
			}
		} while (!index(";{}:", c));
		point = lastcont;	/* use indentation of line */
		to_c_indentation();	/* just after it */
		if (!parse_string(RE_FORWARD, "(}[ \t\f]*)?e!lse[^a-zA-Z0-9_]"))
			break;
		point = matchend;
		if (!to_matching_if())
			break;
	}
	i = current_column();
	if (!i && atparen != -1 && (Topindent || !c_statement_start()))
		i = get_indentation(atparen);	// 2nd func param decl
	if ((atparen = parse_string(1, "for[ \t\f]*%([ \t\f]*"))
	    && for_unclosed(point, orig))
		i = get_column(point + atparen); // part of "for" statement
	if (i <= c_top_braces)
		return 0;	// 1st line of new func
	return i;
}

for_unclosed(start, end)	// does this region have unmatched )?
{
	save_var point = start;
	save_var narrow_end = size() - end;
	return !c_skip_level('(', ')');
}

/* Return new indentation, when the previous line ended with a } character.
 * We are now just after the } character. */

indent_after_block(orig)
{
	c_rev_skip_level('{', '}');	/* find matching { */
	to_begin_line();
	if (Topindent && get_indentation(point) == 0)
		return 0;	// found a func def block
	return indent_after_statement(orig);
}

func_start_block(p)	// are these lines arg decls of func, not statements?
{
	int c;

	save_var point = p;
	for (;;) {
		if (cind_try_space())
			return 0;
		if ((c = character(point - 1)) != ';')
			break;
		to_begin_line();
	}
	if (c != ')' || !c_rev_skip_level('(', ')'))
		return 0;
	to_begin_line();
	return !c_statement_start();
}

indent_c_contin(ind, orig, lastl)	/* indent continuation line */
{
	int c, plevel = 0, qlevel = 0, findc;

	if (!c_align_contin_lines)	// never line up
		return c_default_indent(ind, orig, 1);
	to_begin_line();
	save_var narrow_start = point;
	point = orig;
	findc = character(orig);
	while (re_search(-1, "[()?:\"'\n]|[=!<>]?=")) {
		switch (c = curchar()) {
			case '(':	/* indent after unmatched lparen */
				if (plevel-- > 0)
					break;
indhere:			if (findc != ')')
					point++;
				if (!parse_string(1, "[ \t\f]*/[*/]"))
					point += parse_string(1, "[ \t\f]*![^ \t\f\n]");
				return limit_c_contin_indent(ind);
			case ')':
				plevel++;
				break;
			case '?':	/* indent : to matching ? */
				if (qlevel-- > 0 || plevel > 0 || findc != ':')
					break;
				point--;
				goto indhere;
			case ':':
				qlevel++;
				break;
			case '=': case '!':
				if (character(point + 1) == '=' || plevel > 0
				    || character(lastl - 1) == ',')
					break;
				goto indhere;
			case '\n':		 // skip over comments
				cind_try_space(); // at ends of lines
				break;
			case '"': case '\'':
				point++;
				c_skip_item(c, RE_REVERSE);
				break;
		}
	}
	if (character(lastl - 1) == ',') {
		point = lastl;
		to_begin_line();
		point += parse_string(1, "(.*[ \t\f]on)?[ \t\f]+");
		if (in_c_comment(200))
			to_indentation();
		return limit_c_contin_indent(ind);
	}
	return c_default_indent(ind, orig, 2);
}

c_default_indent(ind, orig, defmult)
{
	if (ind)
		return ind + defmult * get_c_indent() + c_contin_offset;
	if (parse_string(1, "[ \t\f]*(struct|union|class)[ \t\f\n]+"
			 "[a-zA-Z0-9_]*[ \t\f\n]*{[ \t\f\n]*[\n/]"))
		return ind + c_top_struct;
	if (just_open(orig))
		return c_top_braces;
	point = orig;
	cind_space();
	return is_contin_statement(point, 0, orig)
			? c_top_contin : c_param_decl;
}

limit_c_contin_indent(ind)	// if lining up under something would put us
{				// too far to right, just use std indent
	int std, i = current_column();	// get lining-up indent

	if (i > c_align_contin_lines) {
		std = ind + get_c_indent() + c_contin_offset;
		i = MIN(std, i);
	}
	return i;
}

indent_else(def)	/* indent a line that starts with "else" */
{			/* by finding matching "if" */
	if (!to_matching_if())
		return def;
	to_c_indentation();
	return current_column();
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

parse_label()	/* parse for a case:, default: or label construct at point */
{		/* return nonzero if found, setting matchend to end */
	return have_colon() && parse_string(1,
		"(case[^a-zA-Z0-9_\n]([^:\n]*|.*':'.*)"
		"|[a-zA-Z0-9_]+[ \t\f]*):[ \t\f]*![^:]");
}

have_colon()		/* is there a colon later on this line? */
{
	save_var narrow_end = size() - give_end_line();
	save_var point;
	return search(1, ":");
}

have_label(pt)	/* is there a label here? */
{
	save_var point = pt;
	return have_colon() && parse_string(1,"[a-zA-Z0-9_]+[ \t\f]*:[^:]");
}

to_c_indentation()	/* go to end of indentation, ignoring any */
{			/* case : or label-like constructs */
	to_indentation();
	past_labels();
}

past_labels()	/* move past labels or case statements at point */
{
	while (parse_label() && character(matchend) != '\n')
		point = matchend;
}

/* If this line appears to be a continuation line, back up until we find
 * one that doesn't.  (We assume it's a continuation line if the previous
 * line doesn't end with one of the five characters ; { } ) : or a
 * keyword like "else".)  Then go to end of indentation.
*/

to_statement_start()
{
	int lastcont, count = 20;	/* give up after this many lines */
	int orig = point;

	to_begin_line();
	if (parse_string(1, "[ \t\f]*}")) {
		search(1, "}");
		c_rev_skip_level('{', '}');
	}
	do {
		to_begin_line();
		lastcont = point;
	} while (!cind_try_space() && is_contin_statement(point, 0, orig)
			&& count-- > 0);
	point = lastcont;
	to_indentation();
}

unmatched_rparen(from, to)	// is there an unmatched ")" in range?
{
	save_var narrow_start = from;
	save_var point = to;
	if (!search(-1, ")"))	// find last ")" in range
		return 0;
	point++;		// return 1 if unmatched
	return !c_rev_skip_level('(', ')');
}

is_contin_statement(p, fd, orig) // would line after p be a continuation line?
{			// assumes p is just after last interesting char
	// if fd, pretend func param decls are a "continuation" of func decl
	// orig is later position in buffer, for unclosed "for" scan
	switch (character(p - 1)) {
		case ';':		// check for multi-line "for" statemnt
			if (unmatched_rparen(p, orig))
				return 1;
		case '{':
		case '}':
			return 0;
		case ')':
			save_var point = p;
			save_var narrow_start = p - 500;
			if (!c_rev_skip_level('(', ')'))
				return 1;
			return !parse_string(-1, "[^a-z0-9_](if|while|for"
					     "|switch)[ \t\f]*") && (fd
				|| !Topindent || get_indentation(point));
		case 'e':
			return !is_else(p - 4);
		case 'o':
			save_var point = p;
			return !parse_string(-1, "[^a-z0-9_]do");
		case ':':
			save_var point = p;
			to_indentation();
			return !is_label(point);
		default:
			return 1;
	}
}

cind_close()	/* indent a line that starts with a } character */
{		/* find matching { and indent based on that one */
	int ind, solitary;

	point++;		/* go past } char */
	c_rev_skip_level('{', '}');	/* find matching { */
	solitary = parse_string(-1, "\n[ \t\f]*");	/* stuff before? */
	if (solitary)
		to_indentation();
	else
		to_statement_start();
	past_labels();
	ind = current_column();
	if (!Closeback && !solitary)
		ind += get_c_indent() + c_brace_offset;
	return ind;
}

	/* dquote "(" snormal OR bslash anything ")" STAR dquote */
#define C_STRING "\"([^\"\\\n]|\\(.|\n))*\""

	/* squote "(" cnormal OR bslash anything ")" STAR squote */
#define C_CCONST "'([^'\\\n]|\\(.|\n))*'"

/* Skip past a string, character-constant, or comment,
   depending on "item".
*/

c_skip_item(item, flags)
{
	char *s; int m;

	switch (item) {
		case '/':	m = (flags & RE_REVERSE) ? -1 : 1;
				return search(m, (m < 0) ? "*/" : "/*")
					&& search(m, (m < 0) ? "/*" : "*/");
		case '"':	s = C_STRING; break;
		case '\'':	s = C_CCONST; break;
	}
	return re_search(flags, s);
}

/* look backward for a matching pair of delimiters, ignoring
 * delimiters inside strings, character constants, or comments
 */

int c_rev_skip_level(left_d, right_d)
char left_d, right_d;
{
	char pattern[40], ch;
	int level = 0;

	sprintf(pattern, "<*>/|[%c%c'\"]|//.*\n", right_d, left_d);

bgn:	do {
		if (!re_search(RE_REVERSE, pattern))
			return 0;
		switch (ch = curchar()) {
			case '/':
				if (at_c_comment(point + 2, 100) & IN_STRING)
					to_end_line();
				break;
			case '\'': case '"': case '*':
				point = matchstart;
				c_skip_item(character(point - 1), RE_REVERSE);
				goto bgn;
			default:
				if (ch == right_d)
					level++;
				else if (ch == left_d)
					level--;
		}
	} while (level > 0);
	return 1;
}

/* look forward for a matching pair of delimiters, ignoring
 * delimiters inside strings, character constants, or comments
 */

int c_skip_level(left_d, right_d)
char left_d, right_d;
{
	char pattern[40], ch;
	int level = 0;

	sprintf(pattern, "/[/*]|[%c%c'\"]", right_d, left_d);

bgn:	do {
		if (!re_search(RE_FORWARD, pattern))
			return 0;
		switch (ch = character(matchstart)) {
			case '/':
				search(1, character(matchstart + 1) == '/'
				       ? "\n" : "*/");
				break;
			case '\'': case '"':
				point = matchstart;
				c_skip_item(ch, RE_FORWARD);
				goto bgn;
			default:
				if (ch == right_d)
					level++;
				else if (ch == left_d)
					level--;
		}
	} while (level < 0);
	return 1;
}


#define PREPROC_LINE	"^[ \t]*#[ \t]*(if|else|endif|elif)"
#define PREPROC_IF		"^[ \t]*#[ \t]*(if)"
#define PREPROC_ELSE	"^[ \t]*#[ \t]*(else|elif)"
#define PREPROC_ENDIF	"^[ \t]*#[ \t]*(endif)"

// Try to scroll the window so the entire scope of this directive
// is visible.

position_on_ifdef()
{
	to_begin_line();
	if (point < window_start || point > window_end) {
		int line = text_height() - 1;
		if (parse_string(1, PREPROC_IF))
			line = 0;
		else if (parse_string(1, PREPROC_ELSE))
			line /= 2;
		window_start = prev_screen_line(line);
	}
}

// Move forward or backward stopping at #if, #else, or #endif (or similar)
// but skipping over inner nested preprocessor lines.

move_by_ifdef(dir)
{
	int level = 0;

	to_begin_line();
	if (!parse_string(1, PREPROC_LINE) ||
		parse_string(1, (dir > 0) ? PREPROC_ENDIF : PREPROC_IF)) {

// If we're not starting from a preprocessor line, or we're moving out of
// the scope of the current line's directive, just move to the next.

		if (dir > 0)
			to_end_line();
		re_search(dir, PREPROC_LINE);
		position_on_ifdef();
		return;
	}
	if (dir > 0)
		to_end_line();
	for (;;) {		// Look for a preprocessor line at the right level.
		if (!re_search(dir, PREPROC_LINE))
			error("Unmatched preprocessor line.");
		if (parse_string(-dir, PREPROC_IF)) {
			if ((dir > 0) ? (++level <= 0) : (++level > 0))
				break;
		} else if (parse_string(-dir, PREPROC_ENDIF)) {
			if ((dir > 0) ? (--level < 0) : (--level >= 0))
				break;
		} else if (parse_string(-dir, PREPROC_ELSE)) {
			if ((dir > 0) ? (level <= 0) : (level >= 0))
				break;
		}
	}
	position_on_ifdef();
}

command forward_ifdef() on c_tab[ALT(']')], c_tab[NUMALT(KEYDOWN)]
{
	to_begin_line();
	if (in_c_comment(c_look_back * 2))
		forward_paragraph();
	else
		move_by_ifdef(1);
}

command backward_ifdef() on c_tab[ALT('[')], c_tab[NUMALT(KEYUP)]
{
	to_begin_line();
	if (in_c_comment(c_look_back * 2))
		backward_paragraph();
	else
		move_by_ifdef(-1);
}

fix_c_indentation()		/* recompute this line's indentation */
{				/* without moving point */
	save_spot point;
	to_indentation();
	c_indenter();
}


/*  fix indentation if necessary when { is typed */
command c_open() on c_tab['{']
{
	normal_character();
	if (current_column() - 1 <= get_indentation(point)
			&& !in_c_comment(c_look_back))
		fix_c_indentation();
}

/*  fix indentation if necessary when } or ) is typed */
command c_close() on c_tab['}'], c_tab[')']
{		/* only if typed inside indentation, & it might need fixup */
	normal_character();
	if (current_column() - 1 <= get_indentation(point)
			&& !in_c_comment(c_look_back))
		fix_c_indentation();
	if (Matchdelim)
		find_delimiter();
}

/*  fix indentation if necessary when : is typed */
command c_colon() on c_tab[':']
{
	normal_character();
	if (parse_string(-1, "^[ \t\f]*(case[^a-zA-Z0-9_\n][^:\n]*"
				"|[a-zA-Z0-9_]+[ \t\f]*:?):")
			&& !in_c_comment(c_look_back))
		fix_c_indentation();
}

/*  fix indentation if necessary when # is typed */
command c_hash_mark() on c_tab['#']
{
	normal_character();
	if (parse_string(-1, "^[ \t\f]*#"))
		fix_c_indentation();
}

get_c_indent()	/* indent this many spaces for each level */
{			/* if c_indent is 0, use tab_size instead */
	return (c_indent > 0) ? c_indent : tab_size;
}
