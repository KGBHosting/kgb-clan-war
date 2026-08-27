// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>

int main(int argc, char **argv)
{
    if (argc != 3)
    {
        fprintf(stderr, "usage: %s OLD NEW\n", argv[0]);
        return 2;
    }
    if (rename(argv[1], argv[2]) != 0)
    {
        perror("rename");
        return 1;
    }
    return 0;
}
