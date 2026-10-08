/* Measure inside one process, excluding process startup and self-test.
 * Each of the existing eight inputs is solved 100 times.
 * These are host CPU times, not Ripes instruction counts. */
#define STRINGIFY_INNER(x) #x
#define STRINGIFY(x) STRINGIFY_INNER(x)
#define main solver_cli_main
#include STRINGIFY(VARIANT)
#undef main
#include <time.h>

int main(void)
{
    static const char *inputs[] = {
        "12345671111111", "62345713133111", "24316572122213",
        "25713642221111", "24513763133333", "43752611332133",
        "25416373331111", "21345671111111"
    };
    const unsigned repetitions = 100;
    clock_t initialization = 0, searching = 0;
    for (unsigned repetition = 0; repetition < repetitions; ++repetition) {
        for (size_t i = 0; i < sizeof inputs / sizeof inputs[0]; ++i) {
            state_t state;
            uint8_t path[MAX_DEPTH];
            if (!parse_state(inputs[i], &state))
                return 1;
            uint32_t rank = rank_state(&state);
            uint16_t p = (uint16_t) (rank / ORIENTATIONS);
            uint16_t o = (uint16_t) (rank % ORIENTATIONS);
            clock_t before = clock();
            if (!build_patterns(p, o))
                return 1;
            clock_t ready = clock();
            uint8_t first = permutation_distance[0] > orientation_distance[0]
                ? permutation_distance[0] : orientation_distance[0];
            int found = 0;
            for (uint8_t bound = first; bound <= MAX_DEPTH; ++bound) {
                if (search(0, 0, p, o, 0, bound, 3, path)) {
                    found = 1;
                    break;
                }
            }
            clock_t after = clock();
            if (!found || before == (clock_t) -1 ||
                ready == (clock_t) -1 || after == (clock_t) -1)
                return 1;
            initialization += ready - before;
            searching += after - ready;
        }
    }
    double runs = repetitions * (sizeof inputs / sizeof inputs[0]);
    printf("Mean initialization CPU time: %.3f ms\n",
           1000.0 * initialization / CLOCKS_PER_SEC / runs);
    printf("Mean search CPU time:         %.3f ms\n",
           1000.0 * searching / CLOCKS_PER_SEC / runs);
    printf("Mean combined CPU time:       %.3f ms\n",
           1000.0 * (initialization + searching) / CLOCKS_PER_SEC / runs);
    return output_failed();
}
