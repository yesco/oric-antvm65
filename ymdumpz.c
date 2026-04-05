// read an .ym-dump file where each 14 bytes is
// an AY register dump (0-13). Output a "optimized"
// AY updates using AntVM commands.

// clang aydumpz.c -o aydumpz && ./aydumpz <war.ay-dump | wc

// raw : 294000 bytes
// dump: 315000
// diff: 183678
// opt:  170892

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
  char* cmd= calloc(1, SIZE);

  for(int r= 11; r<14; ++r) {
    if (ay[r]!=last[r]) {
      PC(0b11100000+r); // SETAYR
      PC(ay[r]);
    }
  }

  PC(0b11101110); // AYPDATE
  char mask= 0;

  PC(mask); // update it later
  int maskindex= cmd[0];

  // coarse A,B,C
  char coarse= 0;
  if (ay[1]!=last[1] || ay[3]!=last[3] || ay[5]!=last[3]) coarse= ++mask;
  mask <<= 1;

  // coarse A,B,C
  for(int r=0; r<6; r+= 2) {
    if (ay[r]!=last[r] || ay[r+1]!=last[r+1]) {
      ++mask;

      PC(ay[r]);
      if (coarse) PC(ay[r+1]);
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

  // vol (all three)?
  // TODO: isn't mask supposed so say which vols???
  int vols= (ay[8]!=last[8]) + (ay[9]!=last[9]) + (ay[10]!=last[10]);
  if (vols >= 2) {
    ++mask;
    
    PC(ay[8]);
    PC(ay[9]);
    PC(ay[10]);
  } else {
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
    if (0) {
      printf("\n");
      for(int i=0; i<14; ++i)
        printf("%02x%c", ay[i], i==13?'\n':' ');
    }

    char* e= encode();

    if (1) {

      //printf("  ");
      //printf("%03d: ", e[0]);

      for(int i=1; i<=e[0]; ++i)
        printf("%02x%c", e[i], i==e[0]?'\n':' ');
    }

    free(e);

    memcpy(last, ay, sizeof(last));
  }

  return 0;
}
