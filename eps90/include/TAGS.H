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

user char initial_tag_file[FNAMELEN] = "default.tag";
user char want_sorted_tags = 1;	/* want tags sorted when you press '?'? */
user short show_tag_line = 0; /* put tag on this line of window when finding */
user char tag_by_text = 1;	// record text of each tag line, not position
user char tag_relative = 1;	// if nonzero, use relative pathname for tags
user char tag_declarations = 0;	// 1: tag func declarations, 2: vars, 3: both
char tag_extern_decl;	// is this just a var declaration, or a definition?
char _last_tag[TAGLEN];
char _last_tag_file[FNAMELEN];	/* file last tag appeared in */
zeroed short _tags_buffer;	/* buffer number, for speed */
user char tag_case_sensitive = 0; /* Are tags case-sensitive? */
