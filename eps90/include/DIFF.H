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

user short diff_mismatch_lines = 500;	// give up after looking # lines ahead
user short diff_match_lines = 3;  // # of identical lines to consider a match
user short resynch_match_chars = 15;	// same, but chars: for compare-windows

char _diff_buffer[80] = "diff";	/* put diff listing here */
int _diff_line1, _diff_line2;	/* current line numbers */

// Diff styles
#define LISTING_DIFF_STYLE	0	/* Original style. */
#define VISUAL_DIFF_STYLE	1
#define MERGE_DIFF_STYLE	2

// #ifdef variable name for merge-diff.
user char merge_diff_var[30] = "DIFFVAR";

keytable visual_diff_tab;
char _visual_diff_mode_name[] = "Visual-Diff";
color_class diff_added;
color_class diff_removed;
