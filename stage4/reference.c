#include "target_core.h"
#ifndef INPUT_STATE
#define INPUT_STATE "21345671111111"
#endif
#ifndef EXPECTED_LENGTH
#define EXPECTED_LENGTH 11
#endif
static const char input[] = INPUT_STATE;
static void print_char(unsigned ch)
{
    register unsigned a0 __asm__("a0") = ch;
    register unsigned a7 __asm__("a7") = 11;
    __asm__ volatile("ecall" : "+r"(a0), "+r"(a7) : : "memory");
}
void reference_main(void)
{
    unsigned gp, go;
    int status = 2;
    if (target_parse(input, &gp, &go)) {
        int length = solve_coordinates(gp, go);
        status = 1;
        if (length >= 0 && (EXPECTED_LENGTH < 0 || length == EXPECTED_LENGTH) &&
            target_validate(gp, go, (unsigned)length)) {
            static const char faces[] = "RBD", suffix[] = "'2";
            unsigned remaining = (unsigned)length;
            while (remaining) {
                unsigned move = result_path[--remaining], face = 0;
                if (remaining + 1 != (unsigned)length) print_char(' ');
                while (move >= 3) { move -= 3; ++face; }
                print_char((unsigned)faces[face]);
                if (move < 2) print_char((unsigned)suffix[move]);
            }
            print_char('\n');
            print_char('P'); print_char('A'); print_char('S'); print_char('S'); print_char('\n');
            status = 0;
        }
    }
    register int a0 __asm__("a0") = status;
    register unsigned a7 __asm__("a7") = 93;
    __asm__ volatile("ecall" : "+r"(a0), "+r"(a7) : : "memory");
    for (;;) {}
}
