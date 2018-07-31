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

// This file interprets Epsilon's command line switches.

#include "eel.h"
#include "menu.h"

when_restoring()
{
	int tflag = 0, i, j;
	char *s;

	after_loading(); /* call early, so we can display errors, etc. */
	putenv("EPSRUNS=Y");	/* for catching nested Epsilons */
	if (opsys == OS_DOS)
		putenv("PKNOFASTCHAR=Y"); //make PKZIP, UNZIP output capturable
	root_keys = reg_tab;
		/* now set buffer-specific variables */
	word_pattern.default = is_gui ? default_word : default_oem_word;
	_char_class.default = _def_char_class;
	_case_map.default = _def_case_map;
	_srch_case_map.default = _def_srch_case_map;
	_display_class.default = _std_disp_class;
	_echo_display_class = _echo_disp_class;
	i = is_gui ? _our_gui_scheme
		   : monochrome ? _our_mono_scheme : _our_color_scheme;
	if (name_type(i) != NT_COLSCHEME)
		i = find_index(is_gui ? "standard-gui" : monochrome
			       ? "standard-mono" : "standard-color");
	selected_color_scheme = i;
	use_default = 1;		/* default is fundamental mode */
	fundamental_mode();
	use_default = 0;
	apply_defaults();	/* apply defaults to init buffer & window */
	{
		char fname[FNAMELEN];
		force_save_as = FSA_NEWFILE;	// make startup buffer prompt
		strcpy(fname, "startup.txt");	// for filename
		absolute(fname);
		filename = fname;
	}
	strcpy(_docname, "edoc");
	early_init();

	for (i = 1; i < argc && argv[i][0] == '-'; i++)
		switch (argv[i][1]) {
		case 'f':
			switch (argv[i][2]) {
			case 's':
				set_swapname(argv[i] + 3);
				break;
			case 'h':
				set_shrinkname(argv[i] + 3);
				break;
			case 'd':
				strcpy(_docname, argv[i] + 3);
				break;
			default:
				bad_flag(argv[i]);
			}
			break;
		case 't':
			tflag = 1;
			break;
		case 'r':
		case 'l': break;
		case 'h': case '?': usage();
		case 'p':
			if (!argv[i][2])
				preserve_session = preserve_session ? 0 : 1;
			else if (isdigit(argv[i][2]))
				preserve_session = numtoi(argv[i] + 2);
			else
				cmd_line_session_file = argv[i] + 2;
			break;
		case 'd':
			s = index(argv[i] + 2, '=');
			if (!s)		// accept either VAR=VAL or VAR!VAL
				s = index(argv[i] + 2, '!');
			if (s) {
				*s = 0;
				if (j = find_index(argv[i] + 2)) {
					set_var_val(j, s + 1, 1);
					break;
				}
				bprintf("No such variable %s.\n", argv[i] + 2);
				init_help_abort();
			}		/* fall through on error */
		default:
			bad_flag(argv[i]);
		}			/* i is 1st file argument */
	term_init();
#include "keyext.h"
	try_calling("key-setup");
	middle_init();
	init_menu();
	term_cmd_line();
	if (tflag) {
		tutorial();
		preserve_session = 0;
	} else {
		if (load_from_state && (i >= argc || session_always_restore)) {
			if (session_restore_files == 2 && i < argc)	// Have cmdline files,
				save_var session_restore_files = 0;	// skip session files.
			load_session();
		}
		if (i < argc)
			load_cmd_line_files(i);
		delete_dull_buffer("startup");
	}
	switching_to_buffer();
	set_toolbar();
	note("Epsilon Programmer's Editor %s", version);
	try_calling("start-up");
	for (i = 1; i < argc && argv[i][0] == '-'; i++)
		switch (argv[i][1]) {
			case 'l': load_commands(argv[i] + 2); break;
			case 'r': try_calling(argv[i] + 2); break;
		}
}

load_cmd_line_files(i)	/* start at argv[i] */
{
	int wins = 0, tot_size = window_height, line;
	char fname[FNAMELEN], *s, first = 1;

	one_window();			// Don't use windows specified by session
	line = -1;
	for (; i < argc; i++) {
		if (argv[i][0] == '+')
			line = strtoi(argv[i] + 1, 10);
		else {
			strcpy(fname, argv[i]);
			absolute(fname);
			if ((directory_flags & DIR_CWD_FROM_FILE) && first) {
				char dir[FNAMELEN];
				strcpy(dir, fname);
				*get_tail(dir, 1) = 0;
				chdir(dir);
				first = 0;
			}
			s = expand_wildcards ? do_file_match(fname, FM_EXACT)
				: fname;
			if (!s)		/* new file */
				s = fname;
			do {
				if (wins < max_initial_windows && wins++ > 0) {
					window_split(HORIZONTAL);
					window_height = 1000;
				}
				do_find(s, default_translation_type);
				if (line > 0)
					go_line(line);
			} while (expand_wildcards
				&& (s = do_file_match(fname, 0)));
			line = -1;
		}
	}
	for (; window_number > 0; window_number--)
		window_height = tot_size / number_of_user_windows();
}

delete_dull_buffer(buf)		/* delete if no file & not in window */
char *buf;
{
	int orig, keep;

	orig = bufnum;
	bufname = buf;
	keep = (*filename && force_save_as != FSA_NEWFILE)
		   || buf_in_window(bufnum) > 0;
	bufnum = orig;
	if (!keep)
		delete_buffer(buf);
}

usage()
{
	int win, buf = zap("usage");
	save_var bufnum = buf;
	bprintf("\n");
	bprintf("Usage: epsilon [flags...] [files...]\n");
	bprintf("A file name may have +linenum before it.\n\n");

	bprintf("Flags:\n");
	bprintf("-sFILE   Load state from FILE.sta (default: epsilon.sta).\n");
	bprintf("-bFILE   Build new system from FILE.b, not .sta file "
			"(default: epsilon.b).\n");
	bprintf("-quickup Load quickup.b after loading state.\n\n");

	bprintf("-lFILE   Load FILE.b after loading files. ");
	bprintf("-rCMD    Run command or macro CMD.\n");
	bprintf("-teach   Run the tutorial.                ");
	bprintf("-dVAR!VAL Set variable to value.\n");
	bprintf("-p[VAL]  Set/toggle session-preserving.   ");
	bprintf("-pFILE    Load session from FILE.\n\n");

	bprintf("-fsDIRS  Swap/shrink to directories DIRS. ");
	bprintf("-fdFILE  Documentation in file FILE.\n");
	bprintf("-fhDIRS  Shrink to directories in DIRS.\n\n");

	bprintf("-vmono   Use monochrome color scheme.     ");
	bprintf("-vlNUM   Screen has NUM lines.\n");
	bprintf("-vcolor  Use colors.                      ");
	bprintf("-vcNUM   Screen has NUM columns.\n");
	if (opsys == OS_DOS) {
		bprintf("-vclean  Fast video mode.                 ");
		bprintf("-vsnow   Slow video mode.\n");
		bprintf("-vmNUM   Screen memory is at NUM (hex).\n");
	}

	if (!is_gui) {
		bprintf("\nPress any key for more flags.");
		file_write(TERMINAL, 1);
		leave_blank = 1;
		getkey();

		buf_zap(bufnum);
		bprintf("\n\n");
	}

	if (opsys == OS_DOS) {
		bprintf("-kw      Run inside GUI window.           ");
		bprintf("-kaNUM   Kbd compatibility flags.\n");
	}
	if (opsys == OS_DOS || opsys == OS_OS2) {
		bprintf("-kcNUM   Mouse graphic cursor/block/off.  ");
		bprintf("-kmNUM   Mouse relative/absolute/off.\n");
	}
	if (opsys == OS_DOS)
		bprintf("-kt      Don't take over system timer.    ");
	else if (opsys == OS_OS2)
		bprintf("-kpNUM   Wait NUM secs starting process.  ");
	bprintf("-ke      Extended key support.\n");
	if (opsys == OS_OS2) {
		bprintf("-ksNUM   Speed (>100) vs. abort response. ");
		bprintf("-ka      Kbd alternate mode.\n");
		bprintf("-kdNUM   Mouse delay in .001 secs [50].\n");
	}

	bprintf("\n");
	bprintf("-mNUM    Use NUM bytes of main memory.    ");
	bprintf("-m0      Use minimum memory.\n");
	bprintf("-mNUM    Use NUM kbytes (if NUM < 1000)   ");
	bprintf("-m       Use as needed.\n\n");
	if (opsys == OS_DOS) {
		bprintf("-xNUM    Like -m; sets max XMS (extended) ");
		bprintf("-eNUM    Sets maximum EMS (expanded).\n");
		bprintf("-xiNUM   Initial allocation of XMS.       ");
		bprintf("-eiNUM   Initial allocation of EMS.\n");
		bprintf("-xfNUM   Allocation for EEL funcs in XMS. ");
		bprintf("-efNUM   Alloc. for EEL funcs in EMS.\n");
		bprintf("-xuNUM   Maximum use of upper memory blocks.\n\n");
	}
	bprintf("  NUMk means kilobytes, NUMm means megabytes.\n");
	bprintf("  Without suffix, NUM is in kilobytes if < 1000, "
			"otherwise bytes.\n");
	if (is_gui) {
		restore_vars();
		save_var _doing_input = DI_VIEW, paging_retains_view = 1;
		win = add_popup(0, 0, screen_cols, screen_lines, 0, buf);
		point = 0;
		go_to_link = 0;
		display_dialog_box("UsageBox", "Usage", win, 0, 0, "OK", "", "");
		view_loop(win);
		leave();
	} else
		init_abort();
}

bad_flag(s)
char *s;
{
	bprintf("\n");
	bprintf("Unrecognized flag %s on command line.\n", s);
	init_help_abort();
}

init_help_abort()
{
	bprintf("For help, type \"epsilon -?\".\n\n");
	init_abort();
}

init_abort()	/* show current buffer, then abort */
{
	file_write(TERMINAL, 1);
	leave_blank = 1;
	leave();
}

early_init()
{
}

middle_init()
{
}
