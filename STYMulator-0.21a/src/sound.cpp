/*	file: sound.cpp 

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

#include "sound.h"

snd_pcm_format_t format = SND_PCM_FORMAT_S16;

int err, dir;
int resample = 1;
unsigned int rate = 44100;
unsigned int channels = 1;
unsigned int buffer_time = 500000;
unsigned int period_time = 100000;

snd_pcm_uframes_t buffer_size; //22050
snd_pcm_uframes_t period_size; //4410

int alsa_init(snd_pcm_t *pcm_handle, snd_pcm_hw_params_t *hwparams)
{
	if ((err = snd_pcm_hw_params_any(pcm_handle, hwparams)) < 0) {
		printf("Broken configuration for playback: no configurations available: %s\n", snd_strerror(err));
		return err;
	}
/*	removed snd_pcm_hw_params_set_rate_resample function that has been added to alsa-lib since 1.0.9rc2 (more portability)
	
	if ((err = snd_pcm_hw_params_set_rate_resample(pcm_handle, hwparams, resample)) < 0) {
               	printf("Resampling setup failed for playback: %s\n", snd_strerror(err));
               	return err;
        }
*/
	if ((err = snd_pcm_hw_params_set_access(pcm_handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED)) < 0) {
		printf("Access type not available for playback: %s\n", snd_strerror(err));
		return err;
	}
	if ((err = snd_pcm_hw_params_set_format(pcm_handle, hwparams, format)) < 0) {
		printf("Sample format not available for playback: %s\n", snd_strerror(err));
		return err;
	}
	if ((err = snd_pcm_hw_params_set_channels(pcm_handle, hwparams, channels)) < 0) {
		printf("Channels count (%i) not available for playbacks: %s\n", channels, snd_strerror(err));
		return err;
	}
	unsigned int rrate = rate;
	if ((err = snd_pcm_hw_params_set_rate_near(pcm_handle, hwparams, &rrate, 0)) < 0) {
		printf("Rate %iHz not available for playback: %s\n", rate, snd_strerror(err));
		return err;
	}
	if (rrate != rate) {
		printf("Rate doesn't match (requested %iHz, get %iHz)\n", rate, err);
		return -EINVAL;
	}
	if ((err = snd_pcm_hw_params_set_buffer_time_near(pcm_handle, hwparams, &buffer_time, &dir)) < 0) {
		printf("Unable to set buffer time %i for playback: %s\n", buffer_time, snd_strerror(err));
		return err;
	}
	if ((err = snd_pcm_hw_params_get_buffer_size(hwparams, &buffer_size)) < 0) {
		printf("Unable to get buffer size for playback: %s\n", snd_strerror(err));
		return err;
	}
	if ((err = snd_pcm_hw_params_set_period_time_near(pcm_handle, hwparams, &period_time, &dir)) < 0) {
		printf("Unable to set period time %i for playback: %s\n", period_time, snd_strerror(err));
               	return err;
	}
        if ((err = snd_pcm_hw_params_get_period_size(hwparams, &period_size, &dir)) < 0) {
		printf("Unable to get period size for playback: %s\n", snd_strerror(err));
               	return err;
        }
	if ((err = snd_pcm_hw_params(pcm_handle, hwparams)) < 0) {
		printf("Unable to set hw params for playback: %s\n", snd_strerror(err));
		return err;
        }
	return 0;
}
