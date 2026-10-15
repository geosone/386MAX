/*
 * memwatch.c - QEMU TCG plugin:  log every guest write (or access) to a
 * linear address range with the program counter and the value, for
 * finding who corrupts a variable (gdb watchpoints do not trigger under
 * TCG here).
 *
 *   qemu-system-i386 -plugin linux/test/memwatch/memwatch.so,addr=0x3f70a60,len=4
 *        [,reads=on] [,max=1000] [,value=0xc0000000] -d plugin -D log.txt
 *
 * value= logs only accesses that read or write exactly that value,
 * pc= only those of the instruction at that address.
 * low=on logs only writes below the lowest address written so far (the
 * low-water mark of a stack growing down in the range).
 *
 * Copyright (C) 2026 Open 386MAX.  GNU General Public License version 3.
 */
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include <qemu-plugin.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

static uint64_t lo, hi;                 /* watched range [lo, hi) */
static bool reads;
static long count, maxcount = 1000;
static bool usevalue;
static uint64_t wantvalue;
static bool usepc;
static uint64_t wantpc;
static bool lowmark;
static uint64_t lowest = UINT64_MAX;

static void mem_cb(unsigned int vcpu, qemu_plugin_meminfo_t info,
                   uint64_t vaddr, void *udata)
{
    uint64_t pc = (uint64_t)(uintptr_t)udata;
    bool st = qemu_plugin_mem_is_store(info);
    unsigned size = 1u << qemu_plugin_mem_size_shift(info);
    qemu_plugin_mem_value v;
    char line[160];

    if (vaddr + size <= lo || vaddr >= hi || (!st && !reads)
        || count >= maxcount)
        return;
    if (lowmark) {
        if (vaddr >= lowest)
            return;
        lowest = vaddr;
    }
    v = qemu_plugin_mem_get_value(info);
    if (usevalue) {
        uint64_t x = size == 1 ? v.data.u8 : size == 2 ? v.data.u16 :
                     size == 4 ? v.data.u32 : v.data.u64;
        if (x != wantvalue)
            return;
    }
    count++;
    snprintf(line, sizeof(line),
             "memwatch %s pc=%08" PRIx64 " addr=%08" PRIx64 " size=%u value=%08" PRIx64 "\n",
             st ? "W" : "R", pc, vaddr, size,
             size == 1 ? v.data.u8 : size == 2 ? v.data.u16 :
             size == 4 ? v.data.u32 : v.data.u64);
    qemu_plugin_outs(line);
}

static void tb_trans(qemu_plugin_id_t id, struct qemu_plugin_tb *tb)
{
    size_t n = qemu_plugin_tb_n_insns(tb);

    for (size_t i = 0; i < n; i++) {
        struct qemu_plugin_insn *insn = qemu_plugin_tb_get_insn(tb, i);
        uint64_t pc = qemu_plugin_insn_vaddr(insn);
        if (usepc && pc != wantpc)
            continue;
        qemu_plugin_register_vcpu_mem_cb(insn, mem_cb, QEMU_PLUGIN_CB_NO_REGS,
                                         reads ? QEMU_PLUGIN_MEM_RW : QEMU_PLUGIN_MEM_W,
                                         (void *)(uintptr_t)pc);
    }
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info,
                                           int argc, char **argv)
{
    uint64_t len = 4;

    for (int i = 0; i < argc; i++) {
        char *p = argv[i];
        if (!strncmp(p, "addr=", 5))
            lo = strtoull(p + 5, NULL, 0);
        else if (!strncmp(p, "len=", 4))
            len = strtoull(p + 4, NULL, 0);
        else if (!strncmp(p, "max=", 4))
            maxcount = strtol(p + 4, NULL, 0);
        else if (!strncmp(p, "value=", 6)) {
            wantvalue = strtoull(p + 6, NULL, 0);
            usevalue = true;
        } else if (!strncmp(p, "pc=", 3)) {
            wantpc = strtoull(p + 3, NULL, 0);
            usepc = true;
        } else if (!strcmp(p, "low=on"))
            lowmark = true;
        else if (!strcmp(p, "reads=on"))
            reads = true;
        else {
            fprintf(stderr, "memwatch: unknown option %s\n", p);
            return -1;
        }
    }
    hi = lo + len;
    qemu_plugin_register_vcpu_tb_trans_cb(id, tb_trans);
    return 0;
}
