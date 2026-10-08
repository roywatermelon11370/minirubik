/* Native exact oracle; full-state table is HOST ONLY, never linked on target.
 * Checks all 2644 distance-11 states using the final iterative C algorithm.
 * --all additionally runs H3 for all 3674160 states (can take a long time). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define COUNT_NODES
#include "target_core.h"

static const unsigned factorials[7] = {720,120,24,6,2,1,1};
static void input_from_rank(unsigned rank, char input[15])
{
    unsigned p = rank / 729, o = rank % 729, sum = 0;
    unsigned char available[7] = {0,1,2,3,4,5,6};
    for (unsigned i = 0; i < 7; ++i) {
        unsigned q = p / factorials[i]; p %= factorials[i];
        input[i] = (char)('1' + available[q]);
        for (unsigned j = q; j + 1 < 7-i; ++j) available[j] = available[j+1];
    }
    for (unsigned i = 6; i-- > 0;) {
        unsigned digit = o % 3; o /= 3; sum += digit;
        input[7+i] = (char)('1' + digit);
    }
    input[13] = (char)('1' + (3 - sum%3)%3); input[14] = 0;
}

int main(int argc, char **argv)
{
    enum { STATES_COUNT = 3674160 };
    clock_t start = clock();
    uint8_t *exact = malloc(STATES_COUNT);
    uint32_t *fifo = malloc(STATES_COUNT * sizeof(*fifo));
    if (!exact || !fifo) return 1;
    memset(exact, 255, STATES_COUNT);
    exact[0] = 0; fifo[0] = 0;
    unsigned head = 0, tail = 1, diameter = 0;
    while (head < tail) {
        unsigned here = fifo[head++], p = here/729, o = here%729;
        for (unsigned face = 0; face < 3; ++face) {
            unsigned np = p, no = o;
            for (unsigned turn = 0; turn < 3; ++turn) {
                np = pt[face][np]; no = ot[face][no];
                unsigned there = np*729 + no;
                if (exact[there] != 255) continue;
                exact[there] = (uint8_t)(exact[here] + 1);
                if (exact[there] > diameter) diameter = exact[there];
                fifo[tail++] = there;
            }
        }
    }
    if (tail != STATES_COUNT || diameter != 11) return 1;
    /* H1/H2 for distances to solved; group action translates these distances
     * to any requested goal. No nibble packing is used, so H4 is inapplicable. */
    if (!target_bfs(5040, pt, pd, 0) || !target_bfs(729, ot, od, 0)) return 1;
    unsigned maxp = 0, maxo = 0;
    for (unsigned i = 0; i < 5040; ++i) {
        if (pd[i] == 255) return 1;
        if (pd[i] > maxp) maxp = pd[i];
    }
    for (unsigned i = 0; i < 729; ++i) {
        if (od[i] == 255) return 1;
        if (od[i] > maxo) maxo = od[i];
    }
    if (pd[0] || od[0] || maxp != 7 || maxo != 6) return 1;
    for (unsigned rank = 0; rank < STATES_COUNT; ++rank) {
        unsigned h = pd[rank/729] > od[rank%729] ? pd[rank/729] : od[rank%729];
        if (h > exact[rank]) return 1;
    }
    printf("H1: all %u heuristic bounds admissible; H2: PDB maxima %u/%u; diameter %u\n",
           STATES_COUNT, maxp, maxo, diameter);
    FILE *tests = fopen("distance11.txt", "w");
    if (!tests) return 1;
    int all = argc == 2 && !strcmp(argv[1], "--all");
    uint64_t maximum_children = 0;
    char worst[15] = {0};
    unsigned checked = 0, hard = 0;
    for (unsigned rank = 0; rank < STATES_COUNT; ++rank) {
        if (exact[rank] != 11 && !all) continue;
        char input[15]; input_from_rank(rank, input);
        unsigned gp, go;
        if (!target_parse(input, &gp, &go) || gp*729+go != rank) return 1;
        attempted_children = accepted_children = exhausted_frames = 0;
        int length = solve_coordinates(gp, go);
        if (length != exact[rank] || !target_validate(gp, go, (unsigned)length)) return 1;
        ++checked;
        if (length == 11) {
            ++hard;
            fprintf(tests, "%s|11|", input);
            for (unsigned j = (unsigned)length; j-- > 0;) {
                unsigned move = result_path[j], face = move/3, turn = move%3;
                if (j+1 != (unsigned)length) fputc(' ', tests);
                fputc("RBD"[face], tests);
                if (turn < 2) fputc("'2"[turn], tests);
            }
            fputc('\n', tests);
            if (attempted_children > maximum_children) {
                maximum_children = attempted_children;
                memcpy(worst, input, 15);
            }
        }
        if (all && checked % 100000 == 0) { printf("H3 progress: %u/%u\n", checked, STATES_COUNT); fflush(stdout); }
    }
    if (fclose(tests) || hard != 2644) return 1;
    printf("%u searches matched exact BFS distances and replayed to solved\n", checked);
    printf("Maximum child attempts among d=11: %llu (%s)\n", (unsigned long long)maximum_children, worst);
    printf("Native elapsed CPU seconds: %.3f\n", (double)(clock()-start)/CLOCKS_PER_SEC);
    free(fifo); free(exact);
    return 0;
}
