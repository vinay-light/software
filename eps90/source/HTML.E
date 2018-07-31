/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1996, 1997 Lugaru Software Ltd.  All rights reserved.  *
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "c.h"
#include "html.h"

// HTML syntax highlighting.

html_recolor_from_here(safe)
{
	int start = point;

	safe = safe;			// avoid compiler warning
	if (re_search(-1, "%<%!--|-[ \t\n]*>"))
		return point;
	return start;
}

// We've just parsed "<tagname ", now color any attributes before the ">".
// Script is nonzero if tag name was "script".

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

// An HTML comment starts here.  Color it appropriately.
// HTML comments start with <!.  If there's a - immediately after,
// then this is probably a legal HTML comment like <!-- Comment -->
// so search for -> (this allows commenting out HTML code).
// Otherwise, it's not a "standard" comment (might be a legal DOCTYPE
// spec, or a valid <!>, or an illegal comment).  In any case,
// assume it ends at the next >.

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

// Color text delimited by <% and %>.

color_html_include()
{
	int s;

	search(-1, "<");	// Find start of include.
	s = point;
	search(1, "%>");
	set_character_color(s, point, color_class html_attribute);
}

// Don't start coloring from inside <>'s or in script sections,
// since we won't do it right.  Move point back to a good place.
// Look back for openers <script, or <% or closers </script or %>.
// If we found an opener, start from there.  Otherwise, move back
// before the nearest good <.

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

/*
Move in direction dir past a matched pair of characters in HTML buffers.
On success, or if the end of the buffer is encountered before the
first character is found, return the new buffer position.
Otherwise return -1.
Maybe this routine should consider <a> and </a> to be delimiters,
instead of < and >.
*/

html_move_level(dir)
{
	char *findch = (dir > 0) ? "<" : ">";
	char *otherch = (dir < 0) ? "<" : ">";

	return default_move_level(dir, findch, otherch);
}

command html_mode()
{
	mode_keys = html_tab;		/* Use these keys. */
	major_mode = _html_mode_name;

	strcpy(comment_start, "%<%!-- *");
	strcpy(comment_pattern, "%<%!--(.|<newline>)*--%><FirstEnd>");
	strcpy(comment_begin, "<!-- ");
	strcpy(comment_end, " -->");
	mode_move_level = html_move_level;
	if (auto_show_html_delimiters)
		auto_show_matching_characters = html_auto_show_delim_chars;
	recolor_range = color_html_range;	// set up coloring rules
	recolor_from_here = html_recolor_from_here;
	if (want_code_coloring)		// maybe turn on coloring
		when_setting_want_code_coloring();
	try_calling("html-mode-hook");
	make_mode();
}

// Automatically go into HTML mode on .htm, .html files.

suffix_htm()
{
	html_mode();
}

suffix_html()
{
	html_mode();
}

// .cfm and .cfml are HTML variants for Cold Fusion by Allaire.

suffix_cfml()
{
	html_mode();
}

suffix_cfm()
{
	html_mode();
}

// .htx is an HTML variant for Microsoft's Internet Database Connector.

suffix_htx()
{
	html_mode();
}

// .asp and .asa are HTML variants for Microsoft's web server.

suffix_asp()
{
	html_mode();
}

suffix_asa()
{
	html_mode();
}
