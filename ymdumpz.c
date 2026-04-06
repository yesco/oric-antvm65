// read an .ym-dump file where each 14 bytes is
// an AY register dump (0-13). Output a "optimized"
// AY updates using AntVM commands.

// clang aydumpz.c -o aydumpz && ./aydumpz <war.ay-dump | wc

// raw : 294000 bytes
// dump: 315000
// diff: 183678 (just multiple 2B SETAYR.rrr= BYTE)
// opt:  170892
// OPT:  170402 (vol addded in hi if COARSE)
// CORR: 180411 CORRECTED coarse?

/////  save 42% only


#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

// max size out (individual sets) 14*2=28

#define SIZE 32

#define PC(v) (cmd[++cmd[0]]= (v))

char ay[14], last[14]={0};



char* aydump() {
  char* cmd= calloc(1, SIZE);
  
  PC(0b11101111); // AYDUMP
  for(int i=0; i<14; ++i)
    PC(ay[i]);

  return cmd;
}

char* aydiff() {
  char* cmd= calloc(1, SIZE);

  for(int i=0; i<14; ++i) {
    if (ay[i]!=last[i]) {
      PC(0b11100000 + i); // SETAYR
      PC(ay[i]);
    }
  }

  // no change?
  if (!cmd[0]) {
    cmd[0]= 1;
    cmd[1]= 0b11001111; // YIELD
  }

  assert(cmd[0]);

  return cmd;
}

char* aypdate() {

  // Shaodow ay so can modify copy
  char copy[14];
  memcpy(copy, ay, sizeof(copy));
  char* ay= copy;

  char* cmd= calloc(1, SIZE);

  // copy remaining regs (
  for(int r= 11; r<14; ++r) {
    if (ay[r]!=last[r]) {
      fprintf(stderr, "REG %d = %02x\n", r, ay[r]);
      PC(0b11100000+r); // SETAYR
      PC(ay[r]);
    }
  }

  // decide already before put out volume

  char mask= 0;
  char hidiffs= (ay[1]!=last[1]) + (ay[3]!=last[3]) || (ay[5]!=last[3]);
  int coarse= 0;

  if (hidiffs>1) coarse= ++mask;

  if (!coarse) {
    for(int r=1; r<6; r+= 2) {
      if (ay[r+1]!=last[r+1]) {
        PC(0b11100000+r); // SETAYR
        PC(ay[r]);
      }
    }
  }

  // TODO: better if more than 1 coarse diff

  PC(0b11101110); // AYPDATE

  PC(mask); // update it later
  int maskindex= cmd[0];

  // coarse A,B,C
  mask <<= 1;

  // coarse A,B,C
  for(int r=0; r<6; r+= 2) {
    if (ay[r]!=last[r] || coarse && ay[r+1]!=last[r+1]) {
      ++mask;

      PC(ay[r]);

      if (coarse) {

        // set vol
        int ivol= 8+ay[r/2];
        int vol= ay[ivol];
        if (vol && vol<16) {
          vol= ay[ivol];
          // pretend it didn't change for later...
          ay[ivol]= last[ivol];
        } else {
          vol= 0;
        }

        PC(ay[r+1] + (vol<<4));
      }
    }

    mask <<= 1;
  }

  // noise
  if (ay[6]!=last[6]) {
    ++mask;
    
    PC(ay[6]);
  }
  mask <<= 1;

  // mixer
  if (ay[6]!=last[6]) {
    ++mask;
    
    PC(ay[6]);
  }
  mask <<= 1;



  // vol (if two, then save byte)
  // TODO: isn't mask supposed so say which vols???
  int vols= (ay[8]!=last[8]) + (ay[9]!=last[9]) + (ay[10]!=last[10]);

  if ((mask && (vols >= 2)) || (!mask && (vols >= 3))) {
    ++mask;
    
    PC(ay[8]);
    PC(ay[9]);
    PC(ay[10]);
  } else {

// TODO: can't really do this here!
//   maybe should implement first to set bits,
//   then a serializer that interprets bits!

// but for now this works to estimate size)

    for(int r=8; r<=10; ++r) {
      if (ay[r]!=last[r]) {
        PC(0b11100000+r); // SETAYR
        PC(ay[6]);
      }
    }
  }

// TODO: revser bits1 LOL

  cmd[maskindex]= mask;

  // no change?
  if (!cmd[0]) {
    cmd[0]= 1;
    cmd[1]= 0b11001111; // YIELD
  }

  assert(cmd[0]);

  return cmd;
}




// TODO: possibly, if volumes changed and only 2 chan
//   might be better to encode vol in hi-pitch!
//   i.e. a FORCE COARSE




char* encode() {
  char* dump= aydump();

  char* diff= aydiff();
//  char* diff= calloc(1, SIZE); diff[0]= 255;

  char* aypd= aypdate();
//  char* aypd= calloc(1, SIZE); aypd[0]= 255;

  char* other;

  if (diff[0] < dump[0]) {
    free(dump);
    other= diff;
  } else {
    free(diff);
    other= dump;
  }
  
  if (aypd[0] < other[0]) {
    free(other);
    return aypd;
  } else {
    if (aypd[0] != other[0])
      fprintf(stderr, "YPDATE[%d] > DIFF[%d]\n", aypd[0], other[0]);
    free(aypd);
    return other;
  }
}


int main() {

  while(fread(ay, 14, 1, stdin)==1) {

    // print 14 bytes as received

    if (0) {
      printf("\n");
      for(int i=0; i<14; ++i)
        printf("%02x%c", ay[i], i==13?'\n':' ');
    }

    char* e= encode();

    // print "optimal" encoding

    if (1) {

      //printf("  ");
      //printf("%03d: ", e[0]);

      for(int i=1; i<=e[0]; ++i) {
//        if (i%2==1 || e[1]==0xee)
          printf("%02x", e[i]);

        putchar(i==e[0]?'\n':' ');
      }
    }

    free(e);

    memcpy(last, ay, sizeof(last));
  }

  return 0;
}
