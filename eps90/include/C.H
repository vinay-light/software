/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*  Copyright (C) 1995, 1997 Lugaru Software Ltd.  All rights reserved.  *
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

// C/C++/EEL parsing and indenting

user char Closeback = 1;		/* select default C indenting style */
user char Topindent = 1;
user char Matchdelim = 1;
user buffer short c_indent = 0;	/* indent by this amt; 0 means use tab size */
user short c_case_offset = 0; /* alter normal indentation of case statements */
user char c_tab_always_indents = 0;	// if 1, tab fixes indentation
					// from anywhere on line
user char new_c_comments = 0;	/* insert new-style c comments */
user short c_label_indent = 0;	/* indent labels to this column */
user short c_contin_offset = 0;	/* alter normal indentation of contin lines */
user char c_align_contin_lines = 48; // line up contin lines up to this col
user short c_brace_offset = 0;	// move braces this much from usual position
user int c_look_back = 10000;	/* max # of chars to examine (for speed) */
user int c_top_braces = 0;	// indent for outer {}'s in func
user int c_top_contin = 3;	// indent for contin lines (decls) outside func
user int c_top_struct = 8;	// indent for body of outer struct/class
user int c_param_decl = 0;	// indent for old-style func param decls

	/* possible return values of in_c_comment() */
#define IN_COMMENT	0x100	// general mask for any comment
#define IN_OLD_COMMENT	0x101	// in a /* */-type comment
#define IN_NEW_COMMENT	0x102	// in a //-type comment
#define IN_STRING	0x200	// general mask for any string-like thing
#define IN_STR_CONST	0x201	// inside double quotes
#define IN_CHAR_CONST	0x202	// inside single quotes

user int reindent_after_c_yank = 10000;
	// Reindent blocks smaller than this after yanking in C-mode

	// Below variables: 0=never, 1=except when yanking, 2=always.
user char reindent_c_comments = 1;		// For /* */ comments.
user char reindent_one_line_c_comments = 1; // For // comments.

user int c_tab_override = -1;	// No C-specific setting for tab width.
keytable c_tab;			/* key table for c mode */
user char c_auto_show_delim_chars[20] = "{[()]}";
