// read an .ym-dump file where each 14 bytes is
// an AY register dump (0-13). Output a "optimized"
// AY updates using AntVM commands.

#include <stdio.h>

int main() {
  char ay[14];

  while(fread(ay, 14, 1, stdin)==1) {
    for(int i=0; i<14; ++i)
      printf("%02x ", ay[i]);
    putchar('\n');
  }
}
