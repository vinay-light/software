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
#include "tex.h"

// Functions for coloring TeX.

recolor_tex_from_here(int safe)
{
	if (!narrowed_search(REGEX | REVERSE, "\n[ \t]*\n", 10000))
		to_begin_line();			// Look for empty line.
	if (point < safe)
		point = safe;
	return point;
}

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

color_tex_dollar(int s)
{
	char pat[30];
	int orig;

	strcpy(pat, "\n[ \t]*\n|\\par![^a-z]|%$");
	if (curchar() == '$') {	// A $$ that signals displayed math?
		point++;			// Get to after $$.
		strcat(pat, "%$");
	}
	orig = point;
	if (re_search(1, pat) && character(point - 1) == '$')
		set_character_color(s, point, color_class tex_math);
	else
		point = orig;
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

// Insert a command, position inside its braces, and optionally
// add an italic correction after.  If a region's highlighted,
// put it inside the command and move after it.

tex_insert_cmd(char *before, char *after, int italic_correction)
{
	iter = 0;
	if (is_highlight_on()) {
		fix_region();
		stuff(before);
		exchange_point_and_mark();
		if (italic_correction && !index(",.", curchar()))	// Add italic
			stuff("\\/");		// correction except before punctuation.
		stuff(after);
	} else {
		stuff(before);
		save_var point;		// Stay here after.
		if (italic_correction && !index(",.", curchar()))	// Add italic
			stuff("\\/");		// correction except before punctuation.
		stuff(after);
	}
}

command tex_italic() on tex_tab[ALT('i')]
{
	tex_insert_cmd("{\\it ", "}", 1);
}

command tex_slant() on tex_tab[ALT('I')]
{
	tex_insert_cmd("{\\sl ", "}", 1);
}

command tex_typewriter() on tex_tab[ALT('T')]
{
	tex_insert_cmd("{\\tt ", "}", 0);
}

command tex_boldface() on tex_tab[ALT('B')]
{
	tex_insert_cmd("{\\bf ", "}", 0);
}

// Insert a pair of characters, position between them.
// But if quoted or repeated, just insert normally.
tex_insert_pair(char *pair)
{
	if (character(point - 1) == '\\' || has_arg)
		normal_character();
	else {
		stuff(pair);
		point--;
	}
}

command tex_left_brace() on tex_tab['{']
{
	if (character(point - 1) == '\\' && !has_arg) {
		stuff("{\\}");
		point -= 2;
	} else
		tex_insert_pair("{}");
}

command tex_math_escape() on tex_tab['$']
{
	tex_insert_pair("$$");
}

// Maybe delete an italic correction \/.

command tex_rm_correction() on tex_tab[','], tex_tab['.']
{
	if (parse_string(-1, "\\/}"))
		delete(matchend, matchstart - 1);
	normal_character();
}

// Convert " to TeX's quote sequences of `` or '' as appropriate.

command tex_quote() on tex_tab['"']
{
	if (character(point - 1) == '\\' || has_arg)
		normal_character();		// quoted (\" is an umlaut)
	else if (point <= narrow_start || index(" \t\n([{",
											character(point - 1)))
		stuff("``");	// use opening quote
	else
		stuff("''");	// closing quote
}

// An alternative to typing Ctrl-Q ".
command tex_force_quote() on tex_tab[ALT('"')], tex_tab[ALT('\'')]
{
	insert('"');
}

// Insert appropriate footnote cmd (TeX's takes two parameters).

command tex_footnote() on tex_tab[ALT('F')]
{
	tex_insert_cmd("\\footnote{",
				   tex_force_latex ? "}" : "}{}", 0);
}

// Make sure there's a \n before and after point.
tex_open_new_line()
{
	if (point > 0 && character(point - 1) != '\n')
		insert('\n');			// Make new lines before or after?
	if (curchar() != '\n')
		insert('\n'), point--;
}

command tex_center_line() on tex_tab[ALT('s')]
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

command tex_inline_math() on tex_tab['(']
{
	tex_insert_open(')');
}

command tex_display_math() on tex_tab['[']
{
	tex_insert_open(']');
}

tex_init_env()		// Load the list of environments.
{
	char *s;

	if (exist(TEX_ENV_BUF))
		return;
	save_var bufnum = create(TEX_ENV_BUF);
	s = lookpath("latex.env");
	if (!s)
		error("Can't find latex.env");
	err_file_read(s, FILETYPE_MSDOS);
	do_sort_region(0, size(), 0, 0);
	delete_final_newlines();
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

command tex_environment() on tex_tab[ALT('E')]
{
	char res[FNAMELEN];

	iter = 0;				// Ask which environment to use.
	comp_read(res, "Environment name: ", tex_env_match, 0,
			  tex_environment_name);
	strcpy(tex_environment_name, res);
	if (is_highlight_on()) {	// Surround highlighted region.
		fix_region();
		if (point > 0 && character(point - 1) != '\n')
			insert('\n');			// Make new line before?
		bprintf("\\begin{%s}\n", tex_environment_name);
		exchange_point_and_mark();
		if (point > 0 && character(point - 1) != '\n')
			insert('\n');			// Make new line before?
		bprintf("\\end{%s}\n", tex_environment_name);
	} else {
		tex_open_new_line();
		bprintf("\\begin{%s}\n", tex_environment_name);
		save_var point;		// Stay here afterwards.
		bprintf("\n\\end{%s}", tex_environment_name);
	}
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

// Automatically go into TeX mode on .tex, .ltx, .sty files.

suffix_tex()
{
	tex_mode();
}

suffix_ltx()
{
	tex_force_latex = 1;
	tex_mode();
}

suffix_sty()
{
	tex_mode();
}
