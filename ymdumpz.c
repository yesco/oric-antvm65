// read an .ym-dump file where each 14 bytes is
// an AY register dump (0-13). Output a "optimized"
// AY updates using AntVM commands.

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


char* encode() {
  char* dump= aydump();
  char* diff= aydiff();

  if (dump[0] < diff[0]) {
    free(diff);
    return dump;
  } else {
    free(dump);
    return diff;
  }
}


int main() {

  while(fread(ay, 14, 1, stdin)==1) {
    if (0) {
      for(int i=0; i<14; ++i)
        printf("%02x ", ay[i]);
      putchar('\n');
    }

    char* e= encode(ay);

    if (1) {

      //printf("  ");
      //printf("%03d: ", e[0]);

      for(int i=1; i<=e[0]; ++i)
        printf("%02x ", e[i]);
      putchar('\n');
    }

    free(e);

    memcpy(last, ay, sizeof(last));
  }

  return 0;
}
