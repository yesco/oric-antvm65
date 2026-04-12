/*	file: ui.c 

	This file is a part of STYMulator - GNU/Linux YM player

	Player & ST-Sound GPL library GNU/Linux port by Grzegorz Tomasz Stanczyk
	Project Page: http://atariarea.krap.pl/stymulator
	
	Original ST-Sound GPL library by Arnaud Carre (http://leonard.oxg.free.fr)
	ALSA (Advanced Linux Sound Architecture) library (http://www.alsa-project.org/)

-----------------------------------------------------------------------------
 *   STYMulator is free software; you can redistribute it and/or modify    *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   STYMulator is distributed in the hope that it will be useful,         *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with STYMulator; if not, write to the                           *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
---------------------------------------------------------------------------*/

#if defined(__x86_64__) || defined(__alpha__) || defined(__ia64__)\
	|| defined(__ppc64__) || defined(__s390x__)
#define PLATFORM 1
#else
#define PLATFORM 0
#endif

#include "stsoundlib/StSoundLibrary.h"
#include "ui.h"
#include <stdlib.h>

extern bool digi;

int pos_x = 0, pos_y = 0;
static int height = 13;
static int width = 80;

void draw_frame(void)
{
	int y = pos_y;

	move(pos_y, pos_x+1);
	if (PLATFORM)
		addstr("---- STYMulator v0.21a (64bit) - Atari ST (16-bit) YM music files player -----");
	else
		addstr("---- STYMulator v0.21a (32bit) - Atari ST (16-bit) YM music files player -----");
	move(pos_y+8, pos_x+1);
	addstr("------------------------------------------------------------------------------");
	move(pos_y+12, pos_x+1);
	addstr("----------------------- Copyright (C) 2005-2007 by Grzegorz Tomasz Stanczyk --");
	for (y = pos_y; y < pos_y + 13; y++) {
		mvaddch(y, pos_x, '|');
		mvaddch(y, pos_x+79, '|');
  	}
	mvaddstr(pos_y+1, pos_x+5, "Filename.:");
	mvaddstr(pos_y+2, pos_x+5, "Name.....:");
	mvaddstr(pos_y+3, pos_x+5, "Author...:");
	mvaddstr(pos_y+4, pos_x+5, "Comment..:");
	mvaddstr(pos_y+5, pos_x+5, "Type.....:");
	mvaddstr(pos_y+6, pos_x+5, "Player...:");
	
	if (digi) {
		mvaddstr(pos_y+7, pos_x+5, "Duration.:");
		mvaddstr(pos_y+5, pos_x+58, "Time...:");
	}
	mvaddstr(pos_y+6, pos_x+58, "Status.:");
	mvaddstr(pos_y+7, pos_x+58, "Repeat.:");
	mvaddstr(pos_y+9, pos_x+11, "| z - play | x - pause | c - stop | r - repeat | q - quit |");
	if (digi)
		mvaddstr(pos_y+10, pos_x+27, "|   n - <<   |   m - >>   | ");
	move(0,0);
	refresh();
}

static void clearscreen(void)
{
	wclear(stdscr);
	move(0,0);
	refresh();
}

int ui_init(void)
{
	initscr();
	cbreak();
	noecho();
	curs_set(0);
	keypad(stdscr, TRUE);
	nodelay(stdscr, 1);

	if (COLS < width || LINES < height) {
		ui_end();
		printf("COLS: %d, LINES: %d\n", COLS, LINES);
		printf("Sorry, you need a terminal with at least 80 cols and 13 lines.\n");
		exit(0);
	}
	pos_y=(LINES - height) / 2;
	pos_x=(COLS - width) / 2;

	return 0;
}

void ui_end(void)
{
	clearscreen();
	move(LINES - 1, 0);
	refresh();
	nodelay(stdscr, 0);
	echo();
	nocbreak();
	endwin();
	putchar('\n');
}

void draw_info(ymMusicInfo_t &info, const char *filename)
{
	mvprintw(pos_y+1, pos_x+16, filename);
	mvprintw(pos_y+2, pos_x+16, info.pSongName);
	mvprintw(pos_y+3, pos_x+16, info.pSongAuthor);
	mvprintw(pos_y+4, pos_x+16, info.pSongComment);
	mvprintw(pos_y+5, pos_x+16, info.pSongType);
	mvprintw(pos_y+6, pos_x+16, info.pSongPlayer);
	if (digi)
		mvprintw(pos_y+7, pos_x+16, "%2d:%02d", info.musicTimeInSec/60,info.musicTimeInSec%60);
	move(0,0);
	refresh();
}		

void draw_time(int sec)
{
	mvprintw(pos_y+5, pos_x+67, "%2d:%02d  ", sec / 60, sec % 60);
	move(0,0);
	refresh();
}





