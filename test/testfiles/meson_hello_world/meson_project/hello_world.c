#include <stdio.h>

int main() {
#ifndef NDEBUG
  printf("Running in debug mode.\n");
#endif
  printf("Hello world.\n");
  return 0;
}
