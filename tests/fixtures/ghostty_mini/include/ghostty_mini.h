// ghostty-mini C API header
#ifndef GHOSTTY_MINI_H
#define GHOSTTY_MINI_H

void ghostty_mini_init(void);
void ghostty_mini_deinit(void);
const char* ghostty_mini_process_input(const char* input, int len);

#endif
