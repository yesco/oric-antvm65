#define MAIN
#include "../../simple6502js/65lisp/hires-raw.c"

int main() {
  hires();
  gclear();
  GXY(120, 100);
  circle(90, 1);
  gfill(0, 0, 1, 200, 3+16);
  gfill(1, 0, 1, 200, 0);
}
