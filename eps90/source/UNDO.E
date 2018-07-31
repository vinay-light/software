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

// This file has commands for undoing other commands.

#include "eel.h"

command undo() on reg_tab[FKEY(9)], cx_tab['u']
{
	undo_it(1, 0);
}

command redo() on reg_tab[FKEY(10)], cx_tab['r']
{
	undo_it(0, 0);
}

command undo_changes() on reg_tab[FCTRL(9)], cx_tab[CTRL('U')]
{		/* undo changes consisting only of movement as a unit */
	undo_it(1, 1);
}

command redo_changes() on reg_tab[FCTRL(10)], cx_tab[CTRL('R')]
{
	undo_it(0, 1);
}

undo_it(is_undo, group_movements)
{
	int ret, i, cnt, last, orig_modif = modified;
	char msg[80], *name = is_undo ? "un" : "re";
	int orig_nar_start = narrow_start;
	int orig_nar_end = narrow_end;

	narrow_start = 0;
	narrow_end = 0;
	*name = tolower(*name);
	if (undo_count(is_undo) < 1)
		error("Nothing to %sdo.", name);
	if (group_movements) {
		ret = last = 0;
		for (; i = undo_op(is_undo) & ~UNDO_FLAG; ret |= last = i) {
			if (i & (UNDO_CHANGES | UNDO_END))
				break;	/* repeat until buffer changes */
			orig_modif = modified;
			cnt = undo_count(!is_undo);
		}
		if (!ret)
			ret = i;
		if (last && (i & UNDO_CHANGES)) {
			do {		/* then reverse change */
				undo_op(!is_undo);
			} while (undo_count(!is_undo) > cnt);
			modified = orig_modif;
		}
	} else					/* plain undo */
		ret = undo_op(is_undo);
	if (point < orig_nar_start || point > size() - orig_nar_end)
		say("Undoing outside narrowed region, removing narrowing.");
	else {
		narrow_start = orig_nar_start;
		narrow_end = orig_nar_end;
	}
	*name = toupper(*name);
	if (ret & (UNDO_CHANGES | UNDO_MOVE | UNDO_REDISP | UNDO_MAINLOOP))
		sprintf(msg, "%sdid %s%s%s%s%s%s%s",
			name,
			(ret & UNDO_END ? "Partial " : ""),
			(ret & UNDO_MAINLOOP ? "Command, " : ""),
			(ret & UNDO_REDISP ? "Display, " : ""),
			(ret & UNDO_MOVE ? "Move, " : ""),
			(ret & UNDO_INSERT ? "Insert, " : ""),
			(ret & UNDO_DELETE ? "Delete, " : ""),
			(ret & UNDO_REPLACE ? "Replace, " : ""));
	else
		sprintf(msg, "%sdid, ", name);
	note("%s%d bytes remain", msg, undo_count(is_undo));
	return ret;
}
