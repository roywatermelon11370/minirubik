/* Host-only generator for stage3_coordinates.c. Native C arithmetic is
 * permitted here; the linked target contains data and pure RV32I instructions. */
#define main coordinates_cli_main
#include "../stage3_tutorial/stage3_coordinates.c"
#undef main

static void emit_table(const char *name, const uint16_t *values, unsigned count)
{
    printf(".align 2\n.globl %s\n%s:\n", name, name);
    for (unsigned i = 0; i < count; ++i) {
        if (i % 16 == 0) printf("    .half ");
        printf("%u", values[i]);
        if (i % 16 == 15 || i + 1 == count) putchar('\n');
        else printf(", ");
    }
}

static void emit_renderer_tables(void)
{
    /* Slot order is cyclic at every corner, matching the solver's twist sign.
     * Physical positions: FUL,FUR,FDR,FDL,BUR,BDR,BDL,BUL.
     * Colors: U=white, D=yellow, F=green, R=red, B=blue, L=orange. */
    static const unsigned colors[6] = {0xffffff,0xffdc00,0x00c853,0xff3030,0x2979ff,0xff8c00};
    static const unsigned char corner_faces[8][3] = {
        {0,2,5},{0,3,2},{1,2,3},{1,5,2},
        {0,4,3},{1,3,4},{1,4,5},{0,5,4}
    };
    /* Each record: corner position, cyclic slot, LED x, LED y.
     * Net: U above F; L F R B across; D below F. Facelets are 4x3 LEDs. */
    static const unsigned char facelets[24][4] = {
        {7,0,9,0},{4,0,13,0},{0,0,9,3},{1,0,13,3},
        {7,1,0,7},{0,2,4,7},{6,2,0,10},{3,1,4,10},
        {0,1,9,7},{1,2,13,7},{3,2,9,10},{2,1,13,10},
        {1,1,18,7},{4,2,22,7},{2,2,18,10},{5,1,22,10},
        {4,1,27,7},{7,2,31,7},{5,2,27,10},{6,1,31,10},
        {3,0,9,14},{2,0,13,14},{6,0,9,17},{5,0,13,17}
    };
    puts(".ifndef RENDER\n.equ RENDER, 0\n.endif\n.if RENDER\n.align 2");
    puts(".globl led_corner_colors\nled_corner_colors:");
    for (unsigned p = 0; p < 8; ++p)
        printf("    .word 0x%06x, 0x%06x, 0x%06x\n",
               colors[corner_faces[p][0]], colors[corner_faces[p][1]], colors[corner_faces[p][2]]);
    puts(".globl led_facelets\nled_facelets:");
    for (unsigned i = 0; i < 24; ++i)
        printf("    .byte %u, %u, %u, %u\n",facelets[i][0],facelets[i][1],facelets[i][2],facelets[i][3]);
    puts(".globl led_source\nled_source:");
    for (unsigned f = 0; f < 3; ++f) {
        printf("    .byte 0");
        for (unsigned i = 0; i < 7; ++i) printf(", %u", source[f][i] + 1);
        putchar('\n');
    }
    puts(".globl led_twist\nled_twist:");
    for (unsigned f = 0; f < 3; ++f) {
        printf("    .byte 0");
        for (unsigned i = 0; i < 7; ++i) printf(", %u", twist[f][i]);
        putchar('\n');
    }
    puts(".endif");
}

int main(void)
{
    if (!build_patterns(0, 0)) return 1;
    puts("# Generated only from stage3_coordinates.c; do not edit entries.");
    puts("# Quarter-turn transitions only. Goal-specific distances are built on target.");
    puts(".section .rodata\n.globl tables_begin\ntables_begin:");
    emit_table("permutation_turns", &permutation[0][0], 3 * PERMUTATIONS);
    emit_table("orientation_turns", &orientation[0][0], 3 * ORIENTATIONS);
    emit_renderer_tables();
    puts(".align 2\n.globl tables_end\ntables_end:");
    return ferror(stdout) != 0;
}
