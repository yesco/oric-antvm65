/*	file: ymplayer.cpp 

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
#include "sound.h"
#include <alsa/asoundlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

extern snd_pcm_uframes_t period_size;
bool digi;

int main(int argc, char **argv)
{
bool quit = false;
bool repeat = false;
bool rmode = true;
bool stop = false;
bool pmode = true;
bool paused = false;
bool playing;
bool ff = false;
bool rew = false;
	
char *platform;

	if (PLATFORM)
		platform = "64bit";
	else
		platform = "32bit";

	if (argc != 2) {
		printf("STYMulator v0.21a (%s) - Copyright (C) 2005-2007 by Grzegorz Tomasz Stanczyk\n", platform);
		printf("http://atariarea.krap.pl/stymulator\n");
		printf("\nUsage: ymplayer <ym music file>\n\n");
		return -1;
	}

	snd_pcm_t *pcm_handle;
	snd_pcm_hw_params_t *hwparams;
	snd_pcm_hw_params_alloca(&hwparams);

	int err;
	unsigned int buf;

	snd_output_t *output = NULL;
	char pcm_name[] = "default";

	YMMUSIC *pMusic = ymMusicCreate();

	if (ymMusicLoad(pMusic,argv[1])) {

		if ((err = snd_output_stdio_attach(&output, stdout, 0)) < 0) {
			printf("Output failed: %s\n", snd_strerror(err));
			return 0;
		}
		if ((err = snd_pcm_open(&pcm_handle, pcm_name, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
			printf("Playback open error: %s\n", snd_strerror(err));
			return 0;
		}
		if ((err = alsa_init(pcm_handle, hwparams)) < 0) {
			printf("Setting of hwparams failed: %s\n", snd_strerror(err));
			exit(EXIT_FAILURE);
		}

		buf = period_size;
		ymsample *convertBuffer = new ymsample[buf];

		ymMusicInfo_t info;
		ymMusicGetInfo(pMusic,&info);	

		digi = strncmp(info.pSongType,"MIX1",4);
	
		ui_init();
		draw_frame();
		draw_info(info, argv[1]);
	
		while(!quit) {
			playing = ymMusicCompute(pMusic,convertBuffer, buf);
			if (digi)
				draw_time(ymMusicGetPos(pMusic) / 1000);

			if ((err = snd_pcm_writei(pcm_handle, convertBuffer, buf)) == -EPIPE) {
				err = snd_pcm_prepare(pcm_handle);
			} else if (err == -ESTRPIPE) {
				while ((err = snd_pcm_resume(pcm_handle)) == -EAGAIN)
				sleep(1);
				if (err < 0) {
					err = snd_pcm_prepare(pcm_handle);
				}
			}
			switch(getch()) {
				case 27: case 'q':	quit = true; break;
				case 'z':	pmode = true;	break; //play
				case 'x':	paused = true;	break; //pause
				case 'c':	pmode = false;	break; //stop
				case 'r':	rmode = true;	break;
				case 'm':	ff = true; break;
				case 'n':	rew = true; break;
			}
			if (rmode)
				if (repeat) {
					ymMusicSetLoopMode(pMusic,YMTRUE);
					mvaddstr(pos_y+7,pos_x+67,"Yes");
					rmode = false;
					repeat = false;
				} else {
					ymMusicSetLoopMode(pMusic,YMFALSE);
					mvaddstr(pos_y+7,pos_x+67,"No ");
					rmode = false;
					repeat = true;
				}

			if (!stop && playing) {
				if (pmode && !paused)
					mvaddstr(pos_y+6,pos_x+67,"Play");	//play
				else if (pmode && paused) {
					ymMusicPause(pMusic);		//pause
					mvaddstr(pos_y+6,pos_x+67,"Pause");
					stop = true;
					pmode = false;
				
				} else if (!pmode) {		//stop
					ymMusicStop(pMusic);
					mvaddstr(pos_y+6,pos_x+67,"Stop ");
					stop = true;
				}
			}  else if (pmode && playing) {
				ymMusicPlay(pMusic);
				mvaddstr(pos_y+6,pos_x+67,"Play ");
				stop = false;
				paused = false;
			}  else if (!playing) {
				ymMusicLoad(pMusic,argv[1]); // hmmm :/
				pmode = false;
			}

			if (ymMusicIsSeekable(pMusic) && digi) 
				if (ff) {
				ymMusicSeek(pMusic, ymMusicGetPos(pMusic) + 1000);
				ff = false;
			} else if (rew) {
				ymMusicSeek(pMusic, ymMusicGetPos(pMusic) - 1000);
				rew = false;
			}
		}	
	
		ymMusicStop(pMusic);
		snd_pcm_close(pcm_handle);
		delete convertBuffer;
		ui_end();

	} else {
		printf("Error in loading file %s: %s\n", argv[1], ymMusicGetLastError(pMusic));
	}

	ymMusicDestroy(pMusic);

	return 0;
}
