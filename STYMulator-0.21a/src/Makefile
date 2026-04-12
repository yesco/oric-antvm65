RM = rm -f
CC = g++
CFLAGS = -Wall

LZH = stsoundlib/lzh
STLIB = stsoundlib

INCLUDE = -L$(LZH) -L$(STLIB)

INSTALL = /usr/bin/install -c

all: libs ymplayer ym2wav

libs:
	@for subdir in $(STLIB) $(LZH); do \
	(cd $$subdir && make) || exit 1; \
	done

ymplayer: ymplayer.o sound.o ui.o
	$(CC) -o ymplayer $(INCLUDE) ymplayer.o sound.o ui.o -lasound -lym -llzh -lncurses

ym2wav: ym2wav.o
	$(CC) -o ym2wav $(INCLUDE) ym2wav.o -lym -llzh	

ymplayer.o: ymplayer.cpp $(STLIB)/StSoundLibrary.h ui.h sound.h
	$(CC) $(INLCUDE) -c ymplayer.cpp

ym2wav.o: ym2wav.cpp $(STLIB)/StSoundLibrary.h
	$(CC) $(INCLUDE) -c ym2wav.cpp

sound.o: sound.cpp sound.h
	$(CC) -c sound.cpp

ui.o: ui.c ui.h $(STLIB)/StSoundLibrary.h
	$(CC) -c ui.c

install: all
	$(INSTALL) ymplayer /usr/bin
	$(INSTALL) ym2wav /usr/bin

clean:

	@for subdir in $(LZH) $(STLIB); do \
	(cd $$subdir && make $@) || exit 1; \
	done

	$(RM)  *.o ymplayer ym2wav *~
	
