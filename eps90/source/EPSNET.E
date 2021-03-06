/************************************************************************
* "Epsilon" is a registered trademark licensed to Lugaru Software, Ltd. *
*		"EEL" and "Lugaru" are trademarks of Lugaru Software, Ltd.		*
*																		*
*	   Copyright (C) 1997 Lugaru Software Ltd.  All rights reserved.	*
*																		*
* Limited permission is hereby granted to reproduce and modify this		*
* copyrighted material provided that the resulting code is used only in *
* conjunction with Lugaru products and that this notice is retained in	*
* any such reproduction or modification.								*
************************************************************************/

#include "eel.h"
#include "epsnet.h"
#include "proc.h"
#include "colcode.h"

win32_only()
{
	if (is_gui != IS_NT && is_gui != IS_WIN95)
		error("Internet features are only available in "
			  "Epsilon for Windows 95/NT.");
}


finger_activity(int activity, int buf, int from, int to)
{
	to = to;	// Suppress warning.
	if (buf_exist(buf) && activity == NET_RECV && !from) {
		save_var bufnum = buf;
		point = from;
	}
}

command finger()
{
	char response[FNAMELEN], username[FNAMELEN], hostname[FNAMELEN], *p;
	char finger_bufname[FNAMELEN];

	win32_only();
	get_str_auto_def(response, "Finger user@host");	// Prompt for a string.

	if ((p = rindex(response, '@')) == 0){		// Parse the string.
		strcpy(hostname, response);		// List users.
		*username = 0;
	} else {
		strcpy(hostname, p+1);			// Show details for one user.
		strncpy(username, response, p - response);
	}

	sprintf(finger_bufname, "Finger %s", response);
	zap(finger_bufname);
	to_buffer(finger_bufname);
	discardable_buffer = 1;
	buffer_not_saveable = 1;
	when_net_activity = finger_activity;
	finger_user(username, hostname, finger_bufname);
}

// Put a message at the end of the current buffer's mode line.
// Pass NULL to show no message.

set_mode_message(char *s)
{
	if (mode_extra) {
		free(mode_extra);
		mode_extra = 0;
	}
	if (s)
		mode_extra = strsave(s);
	make_mode();
}

// Show a message (or erase) for this buffer and the one linked to it.
// Buffers with active ftp sessions are linked to their Ftp Log
// buffers, and vice versa.

set_both_mode_message(char *s)
{
	save_var bufnum;
	if (buf_exist(ftp_job->buf)) {
		bufnum = ftp_job->buf;
		set_mode_message(s);
	}
	if (buf_exist(ftp_job->log_buf)) {
		bufnum = ftp_job->log_buf;
		set_mode_message(s);
	}
}

// Does the status message appear after here in the log?
found_ftp_status(char *pat)
{
	save_var point;
	return re_search(1, pat);
}

show_ftp_percent(char *op, int so_far)
{				 
	char msg[FNAMELEN];

	ftp_job->so_far = so_far;
	if (ftp_job->file_size)
		sprintf(msg, "[FTP: %s %d%%%%] ", op,
				so_far * 100 / ftp_job->file_size);
	else		// We don't know how big the file is.
		sprintf(msg, "[FTP: %s %d Kb] ", op, so_far / 1000);
	set_both_mode_message(msg);
}

// Set point in all windows displaying this buffer.

position_in_all_windows(buf, pos)
{
	int orig = window_number;
	save_var bufnum;
	do {
		if (window_bufnum == buf)
			point = pos;
	} while (++window_number != orig);
}

// The DLL calls this whenever any FTP-related activity occurs.

ftp_activity(int activity, int buf, int from, int to)
{
	char msg[FNAMELEN];
	int show_log = 0;

	if (!buf_exist(buf))
		return;
	save_var iter, has_arg;
	save_var bufnum = buf;
	switch (activity) {
		case NET_DONE:
			if (translation_type == FILETYPE_AUTO
				&& ftp_job->operation == FTP_RECV)
				translation_type = new_buffer_translation_type;
			if (!modified && !point) {
				save_var undo_size = 0;
				undo_mainloop();
			}
			free(ftp_job);		// Fall through.
		case NET_LOG_DONE:
			ftp_job = 0;
			set_mode_message(NULL);
			break;
		case NET_RECV:
			if (!from)
				position_in_all_windows(buf, 0);
			show_ftp_percent("got", from);
			break;
		case NET_SEND:
//			ftp_job->so_far = from;
			ftp_job->file_size = to;
			show_ftp_percent("sent", from);
			break;
		case NET_LOG_WRITE:
			save_var point = from;	// Get file size from msg.
			if (re_search(1, "^150 ") && re_search(1, "[0-9]+ bytes")) {
				char filesize[100];
				grab(matchstart, matchend, filesize);
				if (numtoi(filesize) && !got_bad_number)
					ftp_job->file_size = numtoi(filesize);
			}
			point = from;
			if (found_ftp_status("^220 "))	// Welcome msg.
				set_both_mode_message("[FTP: Sending user name] ");
			if (found_ftp_status("^331 "))	// Host wants password.
				set_both_mode_message("[FTP: Sending password] ");
			if (found_ftp_status("^230 "))	// User logged in.
				set_both_mode_message("[FTP: Working] ");
			if (found_ftp_status("^530 "))	// Bad password.
				discard_password_data();
			if (re_search(1, "^[45][0-9][0-9] ")) {
				parse_string(1, ".*", msg);		// Some error code.
				say("FTP error: %s", msg);
				// Don't go to log if we're just creating a new file.
				if (ftp_job->operation != FTP_RECV
					|| !parse_string(-1, "^550 .*"))
					show_log = 1;
			}
			break;
	}
	if (buffer_ftp_activity)	// Do some buffer-specific FTP work.
		buffer_ftp_activity(activity, buf, from, to);
	switch (activity) {		// These don't automatically refresh later.
		case NET_DONE:
		case NET_LOG_DONE:
		case NET_SEND:
			refresh();
			break;
	}
	if (show_log) {
		if (number_of_popups() > 0) {
			say("FTP errors occurred, see buffer %s.",
				buf_exist(ftp_job->log_buf) ?
				bufnum_to_name(ftp_job->log_buf) : "<deleted>");
			return;
		}
		restore_vars();
		save_var iter, has_arg;
		save_var bufnum = buf;
		if (buf_exist(ftp_job->buf)) {
			to_buffer_num(ftp_job->buf);
			if (ftp_job->operation == FTP_SEND)
				modified = 1;
		}
		if (buf_exist(ftp_job->log_buf))
			to_buffer_num(ftp_job->log_buf);
		point = size();
		refresh();
		restore_vars();
		bufnum = window_bufnum;
	}
	restore_vars();
	if (number_of_popups() > 0 && !strcmp(bufname, CONNECT_LIST_BUF)) {
		int line = lines_between(0, point, 0) + 1, col = current_column();
		make_connect_list();
		go_line(line);
		move_to_column(col);
		refresh();
	}
}

// Is this line in an FTP log part of a response?
// Otherwise, it must be a valid FTP server command like RETR.

is_ftp_log_response_line()
{
	save_var point;
	to_begin_line();
	if (isdigit(curchar()))
		return 1;
	if (re_search(-1, "^[0-9][0-9][0-9]!"))	// Look for prev response line.
		if (curchar() == '-')	// Found a continuation line.
			return 1;
	return 0;
}

color_ftp_log_range(from, to)
{
	int color;

	if (from >= to)
		return to;
	save_var point = from, matchstart, matchend;
	to_begin_line();
	do {
		if (is_ftp_log_response_line())
			color = color_class process_output;
		else
			color = color_class process_input;
		set_character_color(point, give_end_line() + 1, color);
	} while (point < to && nl_forward());
	return to;
}

do_ftp_op(char *dest, char *host, char *usr, char *pwd,
		  char *fname, int cmd)
{
	char log[FNAMELEN], *p;
	int id, i = 1;
	struct ftp_job *job;

	save_var bufnum;
	bufname = dest;
	if (ftp_job)
		error("This buffer's FTP job has not yet completed.");
	strcpy(log, "FTP Log");
	p = log + strlen(log);
	for (;;) {
		if (!exist(log))
			break;
		bufname = log;
		if (!ftp_job)
			break;
		sprintf(p, " %d", i++);
	}
	if (ftp_compatible_dirs)
		cmd |= FTP_USE_CWD;
	id = ftp_op(dest, log, host, usr, pwd, fname, cmd);
	if (id) {

		bufname = dest;
		job = (struct ftp_job *) malloc(sizeof(struct ftp_job));
		job->id = id;
		job->operation = cmd & FTP_OP_MASK;
		job->buf = bufnum;
		job->log_buf = name_to_bufnum(log);
		job->file_size = 0;
		job->time_started = time_ms();
		ftp_job = job;
		when_net_activity = ftp_activity;

		bufname = log;
		ftp_job = job;
		discardable_buffer = 1;
		when_net_activity = ftp_activity;
		recolor_range = color_ftp_log_range;	// set up coloring rules
		recolor_from_here = recolor_by_lines;
		when_setting_want_code_coloring();	// maybe turn on coloring
		set_both_mode_message("[FTP: Connecting] ");
	}
}

int find_remote_file(char *file, int transl)
{
	int op = FTP_RECV;

	win32_only();
	buf_zap(bufnum);
	type_point = 0;
	_read_aborted = 0;
	modified = 0;
	filename = file;
	translation_type = transl;
	if (ftp_ascii_transfers && transl != FILETYPE_BINARY)
		op |= FTP_ASCII;
	return url_operation(file, op);
}

int save_remote_file(char *fname, int trans, struct file_info *finfo)
{
	int op = FTP_SEND;

	win32_only();
	if (finfo)
		finfo->check_type = 0;		// Don't check file dates.
	translation_type = trans;
	modified = 0;
	if (ftp_ascii_transfers && trans != FILETYPE_BINARY)
		op |= FTP_ASCII;
	return url_operation(fname, op);
}

// Prompt for password for this usr@host, unless we already did.
// Remember previous responses to each usr/host combo, and send it back
// without prompting (but never save this info in a state file).
// Call with res==NULL to discard a particular password and prompt
// again next time it's needed.

get_password(char *res, char *host, char *usr)
{
	char msg[FNAMELEN];
	struct password_data *p;
	int use_old;

	for (p = password_data; p; p = p->next)
		if (!strcmp(p->host, host) && !strcmp(p->usr, usr)) {
			if (p->invalid)
				break;
			if (res)
				strcpy(res, p->pwd);
			else				// Mark it invalid so we prompt next time.
				p->invalid = 1;
			return;
		}
	if (!res)		// Told to discard a pwd, but it's not there.
		return;
	use_old = (p != 0);		// Replace existing pwd if it was refused.
	sprintf(msg, "Password for %s@%s: ", usr, host);
	comp_read(res, msg, (int (*)()) 0, POP_UP_PROMPT | PASSWORD_PROMPT, "");
	if (!use_old)
		p = (struct password_data *) malloc(sizeof(struct password_data));
	strcpy(p->host, host);
	strcpy(p->usr, usr);
	strcpy(p->pwd, res);
	p->invalid = 0;
	if (!use_old) {		// If we're not replacing an invalid pwd,
		p->next = password_data;	// add to the list.
		password_data = p;
	}
}

// Look in this log file for the host and username, then discard
// any saved password data.
discard_password_data()
{
	char hostname[FNAMELEN], username[FNAMELEN];
	save_var point, case_fold = 1;
	if (!re_search(-1, "^000 Connecting to !"))
		return;
	parse_string(1, ".*", hostname);
	if (!re_search(1, "^user "))
		return;
	parse_string(1, ".*", username);
	get_password(NULL, hostname, username);	// Discard password.
}

// Parse and check a URL, filling in its component parts.

prepare_url_operation(char *file, int op, struct url_parts *parts)
{
	char *p;

	save_var case_fold = 1;
	if (!parse_url(file, parts))
		error("Bad URL %s", file);
	if (!strstr(" ftp http telnet ", parts->service)
		|| strfcmp(parts->service, "ftp") && (op & FTP_OP_MASK) != FTP_RECV)
		error("Can't do that with %s buffers.", parts->service);

	if (!parts->have_usr)		// No user specified.
		strcpy(parts->usr, "anonymous");
	else if (strcmp(parts->service, "ftp"))
		error("User name not supported in %s URL's", parts->service);
	if (!strfcmp(parts->usr, "anonymous") || !strfcmp(parts->usr, "guest"))
		strcpy(parts->pwd, anon_ftp_password);
	else if (!parts->have_password)
		get_password(parts->pwd, parts->host, parts->usr);

	while (p = index(parts->fname, '\\'))
		*p = '/';			// Convert all \'s to /'s.
}

// Parse the URL and begin remote activity with this buffer.
// If the URL specifies ftp://, the op may be FTP_RECV, FTP_LIST, or
// FTP_SEND, but only FTP_RECV is allowed for other types of URL.
// Takes a URL, possibly prompts for a password.  Can modify the URL
// in place.

int url_operation(char *file, int op)
{
	struct url_parts parts;
	int port;

	prepare_url_operation(file, op, &parts);
	port = numtoi(parts.port);
	if (!strfcmp(parts.service, "http")) {
		char fname[FNAMELEN];
		if (got_bad_number)
			port = 80;
		if ((op & FTP_OP_MASK) != FTP_RECV)
			error("Can't do that with HTTP files.");
		html_mode();
		sprintf(fname, "/%s", parts.fname);
		http_retrieve(fname, parts.host, port, bufname, 0);
	} else if (!strfcmp(parts.service, "telnet")) {
		if (got_bad_number)
			port = 23;
		if ((op & FTP_OP_MASK) != FTP_RECV)
			error("Can't do that with telnet buffers.");
		do_telnet(parts.host, port, bufname);
	} else
		do_ftp_op(bufname, parts.host, parts.usr, parts.pwd,
				  parts.fname, op);
	return 0;		// No error possible yet (asynchronous).
}


/*************************/
/*     Telnet stuff      */
/*************************/


buffer int telnet_id;

telnet_activity(int activity, int buf, int from, int to)
{
	if (!buf_exist(buf))
		return;
	save_var iter, has_arg;
	save_var bufnum = buf;
	switch (activity) {
		case NET_DONE:
			stuff("Connection closed.\n");
			refresh();
			telnet_id = 0;
			break;
		case NET_RECV:
			set_character_color(from, to, color_class process_output);
			break;
	}
}

void do_telnet(char *host, int port, char *bname)
{
	zap(bname);
	to_buffer(bname);
	type_point = 0;
	telnet_mode();
	discardable_buffer = 1;
	buffer_not_saveable = 1;
	when_net_activity = telnet_activity;
	telnet_id = telnet_host(host, port, bname);
}

command telnet()
{
	char hostname[FNAMELEN], buf[FNAMELEN], *p;
	int port = 23, i = 1;

	win32_only();
	if (has_arg){
		port = iter;
		iter = 0;
	}
	*hostname = 0;
	get_str_auto_def(hostname, "Host");
	sprintf(buf, "%s", hostname);
	p = buf + strlen(buf);
	for (;;) {		// Find an unused buffer.
		if (!exist(buf))
			break;
		bufname = buf;
		if (!telnet_id)
			break;
		sprintf(p, " %d", i++);
	}
	do_telnet(hostname, port, buf);
}

keytable telnet_tab;

telnet_send_line() on telnet_tab['\n'], telnet_tab['\r']
{
	char telnet_cbuf[200];

	if (point < type_point || !telnet_id) {
		enter_key();
		return;
	}
	save_var point;
	while (point > type_point) {
		int i = MIN(point - type_point, sizeof(telnet_cbuf) - 1);
		grab(type_point, type_point + i, telnet_cbuf);
		delete(type_point, type_point + i);
		telnet_send(telnet_id, telnet_cbuf);
	}
	telnet_send(telnet_id, "\r");
}


telnet_send_interrupt() on telnet_tab[CTRL('c')]
{
#if 0
	telnet_send(telnet_id, "\03");

#else
	char p[10];
// This is a bad hack.
	p[0] = 242;	// TCDM
	p[1] = 0;
	telnet_send(telnet_id, p);
#endif
}


telnet_send_literal() on telnet_tab[CTRL('o')]
{
	char p[10];
	sprintf(p, "%c", key);
	telnet_send(telnet_id, p);
}



char _telnet_mode_name[] = "Telnet";

telnet_mode()
{
	mode_keys = telnet_tab;
	major_mode = _telnet_mode_name;
	tab_size = 8;
	make_mode();
}


/*************************/
/** End of telnet stuff **/
/*************************/


/* Scan part1 looking for the first character that's a member of the
character set cs.  If found, set part2 to the section of part1
following that character, remove the character and everything after
from part1, and return the character.  If no character in cs occurs
in part1, set part2 to "", don't modify part1, and return 0. */

int split_string(char *part1, char *cs, char *part2)
{
	int i, c;

	for (i = 0; part1[i]; i++)
		if (index(cs, part1[i])) {
			c = part1[i];
			part1[i] = 0;
			strcpy(part2, part1 + i + 1);
			return c;
		}
	*part2 = 0;
	return 0;
}

/* Scan part1 looking for the last character that's a member of the
character set cs.  If found, set part2 to the section of part1
following that character, remove the character and everything after
from part1, and return the character.  If no character in cs occurs
in part1, set part2 to "", don't modify part1, and return 0. */

int reverse_split_string(char *part1, char *cs, char *part2)
{
	int i, c;

	for (i = strlen(part1) - 1; i >= 0; i--)
		if (index(cs, part1[i])) {
			c = part1[i];
			part1[i] = 0;
			strcpy(part2, part1 + i + 1);
			return c;
		}
	*part2 = 0;
	return 0;
}

/* Parse a "full URL": one that starts with "service:\\".  Return
nonzero if it's valid.

To apply a default service to a URL, see if is_remote_file() returns
1 (indicating it's a full URL already).  If not, prepend service: or
service:\\ to the URL. */

int parse_url(char *url, struct url_parts *p)
{
	memset(p, 0, sizeof(*p));
	strcpy(p->service, url);			// Parse service:\\ part.
	if (!split_string(p->service, ":", p->usr) || !*p->service
		|| is_path_separator(p->usr[0]) != 1
		|| is_path_separator(p->usr[1]) != 1)	// It's not valid.
		return 0;
	strcpy(p->usr, p->usr + 2);		// Split off the service part.
	split_string(p->usr, "/\\", p->fname);		// Remove the file name.

	if (!reverse_split_string(p->usr, "@", p->host)) {
										// Do we have a user part?
		strcpy(p->host, p->usr);		// No, so this must be the
		*p->usr = 0;					// host part.
	} else
		p->have_usr = 1;

	if (split_string(p->usr, ":", p->pwd))	// User part could have a pwd.
		p->have_password = 1;		// Pwd could be specified but empty.
	if (split_string(p->host, ":", p->port))
		if (!*p->port)	// Host part could have a port (must be nonempty).
			return 0;
	return *p->host != 0;		// Host name must be nonempty.
}

// Given a full FTP URL, try to remove any . or .. components from the
// file name part.  Also convert \ to /.

standardize_remote_pathname(char *url)
{
	char after[FNAMELEN], *s = url, *t;

	win32_only();
	while (s = index(url, '\\'))
		*s = '/';			// Convert all \'s to /'s.
	s = get_url_file_part(url, 1);
	if (!s[0])
		strcpy(s, "/");
	else if (s[0] == '/' && s[1] == '.' && s[2] == '.') {
		strcpy(after, s);	// If relative path starts with ..,
		s[1] = 0;			// insert the expanded home dir before it.
		remote_dirname_absolute(url);
		strcat(url, after);
	} else if (s[0] == '/' && s[1] == '~' && (t = index(s + 1, '/'))
			   && t[1] == '.' && t[2] == '.') {
		strcpy(after, t);	// If relative path starts with ~<any>/..,
		t[1] = 0;			// replace with the expanded home dir.
		remote_dirname_absolute(url);
		strcat(url, after);
	}
	if (*s)
		drop_dots(s);
}

// Change a relative remote directory name to an absolute one in place.

remote_dirname_absolute(char *s)
{
	char *t1 = temp_buf(), *t2 = temp_buf(), cmd[FNAMELEN], *name;
	struct url_parts parts;

	prepare_url_operation(s, FTP_MISC | FTP_WAIT, &parts);
	noteput("Expanding home directory, please wait...");
	name = get_url_file_part(s, 0);
	if (*parts.fname)
		sprintf(cmd, "CWD %s\nPWD\n", parts.fname);
	else
		sprintf(cmd, "CWD\nPWD\n");
	ftp_op(t1, t2, parts.host, parts.usr, parts.pwd, cmd,
		   FTP_MISC | FTP_WAIT);
	save_var bufname = t2;
	point = 0;
	if (re_search(1, "^257 \"(.*)\"")) {
		grab(find_group(1, 1), find_group(1, 0), name);
		restore_vars();
		delete_buffer(t1);
		delete_buffer(t2);
		note("");
	} else {
		say("Can't expand pathname %s, log %s is %d",
			s, t2, size());
		buffer_printf("Epsnet-Debug", "Can't expand pathname %s,"
					  " log %s is %d\n", s, t2, size());
	}
}

// Return a pointer in this URL to the start of the filename part
// (which follows the / after the host name or port number).
// If separator is nonzero, point to the / itself.
// If not a URL, return a pointer to the start of the file name.

char *get_url_file_part(char *url, int separator)
{
	if (!is_remote_file(url))
		return url;
	while (*url && is_path_separator(*url) != 1)
		url++;			// Move past the service.
	while (*url && is_path_separator(*url) == 1)
		url++;			// Move past the :// part.
	while (*url && is_path_separator(*url) != 1)
		url++;			// The next \ or / should start the file name.
	if (!separator && is_path_separator(*url) == 1)
		url++;
	return url;
}

ftp_misc_operation(char *url, char *cmd)
{
	char *t1 = temp_buf();
	struct url_parts parts;

//	noteput("Working, please wait...");
	prepare_url_operation(url, FTP_MISC, &parts);
	do_ftp_op(t1, parts.host, parts.usr, parts.pwd, cmd,
		   FTP_MISC);
	delete_buffer(t1);
}

// Interpret . and .. in a pathname and remove them, modifying s.
// A .. sequence with nothing before it is simply removed.

drop_dots(char *s)
{
	int i, j, slashes[30], numslashes = 0, t;
	char buf[FNAMELEN], *p;

	while (is_path_separator(*s) == 1)	// Never change /'s at the start.
		s++;
	if (!*s)
		return;
	slashes[numslashes++] = 0;
	for (i = 0; s[i]; i++)		// Locate all / or \ chars.
		if (is_path_separator(s[i]) == 1)	// Each starts a "component".
			slashes[numslashes++] = i;
	slashes[numslashes] = i;
	for (i = j = 0; j < numslashes; i++, j++) {
		slashes[i] = slashes[j];
		t = slashes[j];
		if (is_path_separator(s[t]) == 1)
			t++;
		if (s[t] == '.')	// If it starts with a "." ...
			if (slashes[j + 1] == t + 1)
				i--;						// Found "."
			else if (slashes[j + 1] == t + 2 && s[t + 1] == '.')
				i -= (i > 0) ? 2 : 1;		// Found ".."
	}
	numslashes = i;			// Collect desired path components.
	if (is_path_separator(s[slashes[0]]) == 1)
		slashes[0]++;
	for (p = buf, i = 0; i < numslashes; i++) {
		j = slashes[i];		// Component starts here.
		do {
			*p++ = s[j++];	// Copy this component.
		} while (s[j] && is_path_separator(s[j]) != 1);
	}
	*p = 0;
	strcpy(s, buf);
}

// Should this URL be passed to dired?

is_remote_dir(char *file)
{
	struct url_parts parts;
	char *s;

	save_var case_fold = 1;
	if (!is_remote_file(file) || !parse_url(file, &parts))
		return 0;
	if (strfcmp(parts.service, "ftp"))
		return 0;
	if (!*parts.fname || (is_pattern(parts.fname) & 2))
		return 1;		// Use dired if it has * or ? chars.
	if (is_path_separator(parts.fname[strlen(parts.fname) - 1]))
		return 1;
	s = index(parts.fname, '~');	// a user's home dir
	if (s && !index(s, '/') && !index(s, '\\'))
		return 1;
	return 0;
}

// Take a time in seconds, display in 3:12:34 format.

ftp_format_time(char *res, int seconds)
{
	int hours, minutes;

	minutes = (seconds / 60) % 60;
	hours = minutes / 3600;
	seconds %= 60;
	if (hours)
		sprintf(res, "%d:%02d:%02d", hours, minutes, seconds);
	else
		sprintf(res, "%d:%02d", minutes, seconds);
}

ftp_connection_list(char *msg)
{
	char elapsed_msg[40], remaining_msg[40], *s;
	int elapsed = (time_ms() - ftp_job->time_started) / 1000;

	ftp_format_time(elapsed_msg, elapsed);
	switch (ftp_job->operation) {
		case FTP_RECV:		s = "got"; break;
		case FTP_SEND:		s = "sent"; break;
		default:			sprintf(msg, "FTP job, %s elapsed",
									elapsed_msg);
							return;
	}
	if (ftp_job->file_size) {	// time remaining = bytes to go
		if (ftp_job->so_far)	//    * time so far / bytes so far
			ftp_format_time(remaining_msg,
							(ftp_job->file_size - ftp_job->so_far)
							* elapsed / ftp_job->so_far);
		else
			strcpy(remaining_msg, "?:?");
		sprintf(msg, "%s %d%%, %s elapsed, %s remains",
				s, ftp_job->so_far * 100 / ftp_job->file_size,
				elapsed_msg, remaining_msg);
	} else
		sprintf(msg, "%s %d bytes, %s elapsed",
				s, ftp_job->so_far, elapsed_msg);
}

// Build a buffer containing a list of connections.

make_connect_list()
{
	int i;
	char msg[500], con[200], *type;

	save_var bufnum;
	zap(CONNECT_LIST_BUF);
	i = active_callbacks();
	if (i == 1)
		sprintf(con, "There is 1 active connection.");
	else
		sprintf(con, "There are %d active connections.", i);
	buffer_printf(CONNECT_LIST_BUF, "%s\n", con);

	i = buf_list(0, 2);		// First list active FTP/Telnet buffers
	do {
		bufnum = i;
		if (telnet_id)
			type = "Telnet session";
		else if (ftp_job && ftp_job->buf == bufnum) {
			ftp_connection_list(msg);
			type = msg;
		} else
			continue;
		buffer_printf(CONNECT_LIST_BUF, "%s: %s\n", bufname, type);
	} while ((i = buf_list(-1, 1)) > 0);

	i = buf_list(0, 2);		// Now list all log files, active or not.
	do {
		bufnum = i;
		if (strncmp(bufname, "FTP Log", 7))
			continue;
		if (!ftp_job)				// The job finished already.
			sprintf(msg, "Inactive");
		else if (ftp_job->operation == FTP_MISC)	// No assoc. buffer.
			sprintf(msg, "Active");
		else				// It's got an associated buffer.
			sprintf(msg, "for %s", buf_exist(ftp_job->buf)
					? bufnum_to_name(ftp_job->buf) : "deleted buffer");
		buffer_printf(CONNECT_LIST_BUF, "%s: %s\n", bufname, msg);
	} while ((i = buf_list(-1, 1)) > 0);
	bufname = CONNECT_LIST_BUF;
	delete_final_newlines();
	point = 0;
}

command show_connections() on reg_tab[ALT(CTRL('C'))]
{
	char msg[500], *s;

	win32_only();
	make_connect_list();
	if (number_of_popups() > 0 && !strcmp(bufname, CONNECT_LIST_BUF))
		return;
	if (get_choice(name_to_bufnum(CONNECT_LIST_BUF), msg,
			   "Remote Connections", NULL, "Go to", "Close", "")) {
		s = strstr(msg, ": ");
		if (s) {
			*s = 0;
			if (exist(msg))
				to_buffer(msg);
		}
	}
	user_abort = 0;
}
