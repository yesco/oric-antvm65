/*	file: sound.h 

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

#ifndef SOUND_H
#define SOUND_H

#include <alsa/asoundlib.h>

int alsa_init(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams);

#endif
