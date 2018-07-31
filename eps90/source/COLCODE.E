/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1995, 1997 Lugaru Software Ltd.  All rights reserved.	*
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

// This file has Epsilon's code coloring functions.
// There are routines that handle code coloring in general, and
// routines specific to code coloring in C-mode buffers.

#include "eel.h"
#include "c.h"
#include "colcode.h"

init_color_code()
{
	if (!precol) {
		precol = (struct precol *) malloc(sizeof(struct precol));
		precol->num = 0;
	}
}

// On each refresh, recolor_partial_code() will be called with the
// buffer range that was modified since the last redisplay.

recolor_partial_code(from, to)	// recolors during refresh
{			// params give range of buffer modified
	init_color_code();
	if (!precol->in_progress) {
		precol->in_progress = 1; // ensure errors don't restart us
		if (precol->minimal != minimal_coloring) {
			drop_all_colored_regions();
			precol->minimal = minimal_coloring;
		}
		save_var point, matchstart, matchend, abort_searching = 0;
//		maybe_auto_show_delimiter();
		if (first_window_refresh && !buffer_unchanged()) // shrink list
			shrink_colored_area(from, to);		// of regions
		if (size() < color_whole_buffer) // now expand list of regions
			color_for_area(0, size());
		else
			color_for_area(window_start,
				       MIN(window_end + 1, size()));
		precol->in_progress = 0;	// no errors aborted us,
	}					// let us run next time
}

// Return whether this particular call to wait_for_key()
// should call us again.

when_idle_coloring(cnt)	// Called when idle, waiting for a key.
{			// Cnt increases while waiting for same key.
	int last = 0;

	if (idle_coloring_delay < 0)
		return 0;
	if (cnt < 1)
		time_begin(&idle_color_time, idle_coloring_delay);

	if( !precol || precol->in_progress || !precol->num
	    || *precol->from[0] == 0 && *precol->to[0] == size())
		return 0;
	if (!time_done(&idle_color_time))
		return 1;

	save_var point, matchstart, matchend, abort_searching = 0;
	save_var narrow_start = 0, narrow_end = 0;
	precol->in_progress = 1; // ensure errors don't restart us
	if (*precol->from[0] == 0)
		last = *precol->to[0];
	color_for_area(last, last + 100);
	precol->in_progress = 0;	// no errors aborted us, do more
	return 1;
}

/*
On each refresh, first invalidate regions on the list.  Go through
the precol list.  If the range of the buffer that was modified is
within a precolored region, split it into two.  Otherwise, if it
touches either endpoint of the precolored region, shrink it.  If that
makes the precol region empty, delete it.
*/

shrink_colored_area(from, to)	// area betw from & to is no longer
{				// correctly colored
	int i, j, adjfrom, adjto;

	// expand modified region to include whole colored regions
	// e.g. when we add a letter in a comment, recolor whole comment
	// begin with entire line(s), then expand
	point = from - 1;
	get_character_color(give_begin_line(), &adjfrom, (int *) 0);
	point = to;
	get_character_color(give_end_line(), (int *) 0, &adjto);

	for (i = 0; i < precol->num; ) {
		if (*precol->from[i] < from && to < *precol->to[i]) {
			// invalid region lies within colored region, split
			if (precol->num == NUMPRECOL - 1) {
				j = drop_smallest_region();
				if (j == i)	// smallest was one we planned
					continue; // to split (gone now)
				i -= (j < i);	// adjust place in list
			}
			add_colored_region(i);	// split off i from i+1
			*precol->from[i] = *precol->from[i + 1];
			*precol->to[i] = adjfrom;
			*precol->from[i + 1] = adjto;
		}
		if (from <= *precol->from[i] && *precol->from[i] <= to)
			*precol->from[i] = adjto;	// adjust each end
		if (from <= *precol->to[i] && *precol->to[i] <= to)
			*precol->to[i] = adjfrom;
		if (*precol->to[i] - *precol->from[i] <= 0)
			drop_colored_region(i); // adjusted to empty
		else
			i++;
	}
}

/*
Now deal with the buffer range we have to color (typically the current window).
Look for a region in our list that ends after the start of the region
  to be colored.  Does it include the start of our region?
If so, we'll expand that region.
If not, find a starting point for the region.  If it touches a
  previous region, we'll expand the previous region, otherwise insert
  a new empty region in the list and expand it.
Expand the chosen region to either the end of the region to be
  colored, or the start of the nextx region.
If the latter, merge regions, then repeat expanding.
*/

color_for_area(from, to)	// we need to color region in this range
{
	int i, j;

	save_var point, abort_searching = 0;
	init_color_code();
	i = choose_expander(from);
	while (i + 1 < precol->num && *precol->from[i + 1] < to) {
		// color between regions, then merge
		recolor_range(*precol->to[i], *precol->from[i + 1]);
		*precol->to[i] = *precol->to[i + 1];
		drop_colored_region(i + 1);
	}
	if (to > *precol->to[i]) {	// color after this region
		j = *precol->to[i] = recolor_range(*precol->to[i], to);
		while (i + 1 < precol->num && j >= *precol->from[i + 1]) {
			*precol->to[i] = *precol->to[i + 1];
			drop_colored_region(i + 1); // hit next region, merge
		}
	}
}

choose_expander(from)	// return index of region containing
{				// from (or before it)
	int i, last;

	for (i = 0; i < precol->num; i++) {
		if (*precol->to[i] < from)	// too early in list
			continue;
		if (*precol->from[i] <= from)	// continue from end of region
			return i;
		break;
	}
	last = (i > 0) ? *precol->to[i - 1] : 0;
	point = from;
	nl_reverse();	// color a few extra lines before
	nl_reverse();	// to speed up scrolling
	nl_reverse();		// next, find starting place guaranteed to be
	from = recolor_from_here(last); // on the edge of a colored region
	if (i > 0 && from <= last)
		return i - 1;
	if (precol->num == NUMPRECOL - 1)	// adding new region to list
		i -= (drop_smallest_region() < i);
	add_colored_region(i);
	*precol->from[i] = from;
	*precol->to[i] = from;
	return i;
}

drop_all_colored_regions()
{
	if (precol)
		while (precol->num > 0)
			drop_colored_region(precol->num - 1);
}

drop_smallest_region()	// delete smallest region from list
{
	int i, isize, smallest, smallsize;

	smallsize = size();
	for (i = smallest = 0; i < precol->num; i++) {
		isize = *precol->to[i] - *precol->from[i];
		if (isize < smallsize)
			smallest = i, smallsize = isize;
	}
	drop_colored_region(smallest);
	return smallest;
}

drop_colored_region(i)	// delete region i from list
{
	free_spot(precol->to[i]);
	free_spot(precol->from[i]);
	for (; i + 1 < precol->num; i++) {
		precol->to[i] = precol->to[i + 1];
		precol->from[i] = precol->from[i + 1];
	}
	precol->num--;
}

add_colored_region(i)	// insert region in list before pos i
{
	int j;

	for (j = precol->num; --j >= i; ) {
		precol->to[j + 1] = precol->to[j];
		precol->from[j + 1] = precol->from[j];
	}
	precol->from[i] = alloc_spot(1);
	precol->to[i] = alloc_spot(0);
	precol->num++;
}

// A recolor_from_here function good for line-based buffers.
recolor_by_lines(safe)
{
	safe = safe;		// eliminate compiler warning
	return give_begin_line();
}

// A recolor_from_here function for always coloring from start of buffer.
recolor_from_top(safe)
{
	return safe;
}

// functions for coloring C/C++/EEL code

color_c_from_here(safe)	// Move backward to the nearest line guaranteed
{			// to start outside any colored region, return pos.
	int pos, limit; // We know safe is ok value to return.

	limit = point - safe;
	if (color_look_back && color_look_back < limit)
		limit = color_look_back;
	to_begin_line();
	pos = point;
	while ((in_c_comment(limit) & IN_OLD_COMMENT)
				       && search(-1, "/*")) {
		to_begin_line(); // move back out of an old-style comment
		pos = point;
	}
	point = pos;
	while (character(point - 2) == '\\') {	// don't stay on contin line
		point--;
		to_begin_line();
	}
	return point;
}

color_c_range(from, to) // recolor just this section
{			// last colored region may go past to
	int t = -1, talk, s;
	char pat[200];

	if (from >= to)
		return to;
	save_var point, matchstart, matchend;
	c_init_color(from, to);
	point = from;
	talk = (to - from > 2000);	// show status during long delays
	save_var case_fold = 0;
	strcpy(pat, "/<*>|//|^[ \t]*#|[\"']");
	if (!minimal_coloring)
		strcat(pat, "|[A-Za-z_][A-Za-z0-9_]*"
		       "|-?%.?[0-9]([A-Za-z0-9._]|[Ee]-)*");
	while (point < to) {
		if (!re_search(1, pat)) {
			t = size();
			break;
		}
		t = matchstart;
		switch (character(point - 1)) {		// check last char
		case '/':			// found // one-line comment
			while (nl_forward() && character(point - 2) == '\\')
				;		// Continued // comment.
			set_character_color(t, point, color_class c_comment);
			break;
		case '*':			// found /* starting comment
			search(1, "*/");
			set_character_color(t, point, color_class c_comment);
			break;
		case '#':			// found preproc line
			c_preproc_color();	// move past correct part
			set_character_color(t, point,
					    color_class c_preprocessor);
			break;
		case '"':		// found a string literal
			point = t;
			re_search(1, "\"([^\"\\\n]|\\(.|\n))*[\"\n]");
			set_character_color(t, point, color_class c_string);
			if (get_character_color(point, (int *) 0, &s) == 
			    color_class c_string && s > to)  // fix up after
				c_init_color(point, to = s); // quoted "'s
			break;
		case '\'':		// found a char const
			point = t;
			re_search(1, "\'([^\'\\\n]|\\(.|\n))*[\'\n]");
			set_character_color(t, point, color_class c_charconst);
			break;
		default:		// found identifier, kywd, or number
			set_character_color(t, point, c_keyword_color(t));
			break;
		}
		if (talk)
			note("Coloring C program: %d%% complete...",
			     (point - from) * 100 / (to - from));
	}
	c_init_color(to, t);
	if (talk)
		note("");
	return point;
}

c_init_color(from, to)
{
	if (from < to)
		set_character_color(from, to, minimal_coloring
				    ? color_class c_identifier
				    : color_class c_punctuation);
}

c_keyword_color(from)	// return color for "identifier" from here to point
{			// (something with alpha or digits)
	char buf[500];

	if (point - from > sizeof(buf) - 10)
		save_var point = from + sizeof(buf) - 10;
	buf[0] = '|';		// get identifier, between | chars
	grab(from, point, buf + 1);
	if (index("0123456789-.", buf[1]))
		return c_number_color(buf + 1);
	strcpy(buf + point - from + 1, "|");
	if (is_c_keyword(buf))
		return color_class c_keyword;
	if (color_class c_function != color_class c_identifier
	    && paren_follows())
		return color_class c_function;
	return color_class c_identifier;
}

is_c_keyword(p)		// is text in p (must be surrounded by |'s) a keyword?
char *p;
{
	if (strstr("|if|else|for|do|while|return|break|continue|switch|"
		   "case|default|goto|char|short|int|static|volatile|const|"
		   "float|double|long|void|", p))
		return 1;
	if (p[1] == '_' &&
	    strstr("|_asm|_based|_cdecl|_emit|_except|_export|_far|_fastcall|"
		   "_fortran|_huge|_interrupt|_loadds|_near|_pascal|_saveregs|"
		   "_segment|_segname|_stdcall|_syscall|_try|", p))
		return 1;
	if ((c_extra_keywords & EEL_KEYWORDS) &&
	    strstr("|keytable|buffer|window|command|on|color_class|"
		   "spot|save_spot|save_var|on_exit|user|zeroed|", p))
		return 1;
	if ((c_extra_keywords & CPP_KEYWORDS) &&
	    strstr("|asm|catch|class|delete|friend|inline|new|operator|"
			   "private|protected|public|template|try|this|virtual|"
			   "throw|_self|and|and_eq|bitand|bitor|bool|compl|const_cast|"
			   "dynamic_cast|explicit|false|mutable|namespace|not|not_eq|"
			   "or|or_eq|reinterpret_cast|static_cast|true|typeid|typename|"
			   "using|wchar_t|xor|xor_eq|", p))
		return 1;
	if ((c_extra_keywords & JAVA_KEYWORDS) &&
	    strstr("|abstract|boolean|byte|catch|class|extends|false|final|"
			   "finally|function|implements|import|in|instanceof|"
			   "interface|native|new|null|package|private|protected|"
			   "public|super|synchronized|this|throw|throws|transient|"
			   "true|try|var|with|", p))
		return 1;
	if (!(c_extra_keywords & JAVA_KEYWORDS) &&
	    strstr("|auto|enum|extern|register|unsigned|signed|sizeof|"
			   "struct|union|typedef|", p))
		return 1;		// C keywords not in Java.
	return 0;
}

paren_follows() // is there whitespace followed by a "(" at point in buffer?
{		// if so, we assume it's a function name
	for (;; point++) {
		switch (curchar()) {
			case ' ': case '\t':	continue;
			case '(':		return 1;
			default:		return 0;
		}
	}
}

c_number_color(s)	// return color for number in s
char *s;		// redefine to distinguish different bases
{
	s = s;		// silence eel's warning
	return color_class c_number;
}

c_preproc_color()	// color from t to end of preprocessor text
{
	int orig = point;

	re_search(1, "[ \t]*");
	if (parse_string(1, "include")) {
		while (nl_forward() && character(point - 2) == '\\')
			;			// color contin lines
		save_var narrow_end = size() - point;
		point = orig;
		while (re_search(1, "/[*/]"))	// stop before comment
			if (!(in_c_comment(c_look_back) & IN_STRING)) {
				point -= 2;
				break;
			}
	} else if (parse_string(1, "(define|undef)[ \t]+[A-Za-z0-9_]+")) {
		point = matchend;
		point += parse_string(1, "%([A-Za-z0-9_, \t]*%)");
	} else
		re_search(1, "[A-Za-z_0-9]*");
}


drop_coloring(b)
{
	save_var bufnum = b;
	set_character_color(0, size(), -1);
	if (precol && !precol->in_progress) {
		drop_all_colored_regions();
		full_redraw = 1;
		free(precol);
		precol = 0;
	}
}

command change_code_coloring()
{
	want_code_coloring = has_arg ? (iter != 0) : !want_code_coloring;
	iter = 0;
	say("Code coloring %sabled for this buffer.",
	    want_code_coloring ? "en" : "dis");
	when_setting_want_code_coloring();
}

// always call the following after setting want_code_coloring variable
// set-variable calls this automatically
when_setting_want_code_coloring()
{
	when_displaying = 0;
	if (want_code_coloring)
		want_code_coloring = 1;
	if (!want_code_coloring)
		drop_coloring(bufnum);
	if (want_code_coloring && recolor_range && recolor_from_here)
		when_displaying = recolor_partial_code;
	if (precol) {	// reset after code-coloring eel error
		precol->in_progress = 0;
		precol->minimal = -100;	// force reset
	}
}
