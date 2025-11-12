// alu_test.c — Zybo Z7-20 PetaLinux: /dev/mem으로 AXI-ALU 테스트
// 빌드:   gcc -O2 -Wall -o alu_test alu_test.c
// 실행 예:
//   ./alu_test 0x43C00000 write  a=0x12 b=0x34 opcode=0x0 ena=1
//   ./alu_test 0x43C00000 read
//
// 레지스터 맵(32-bit):
//  REG0 @ +0x00  = { a[31:24], b[23:16], ...[15:4]=0, ena[3], opcode[2:0] }
//  REG1 @ +0x04  = { 16'h0000, result[15:0] }   (읽기 전용: ALU 결과 래치)
//  REG2 @ +0x08  = 사용자 정의(옵션)
//  REG3 @ +0x0C  = 사용자 정의(옵션)
//
// 주의: REG1은 AXI 쓰기 금지(읽기 전용). 결과는 REG0의 ena=1일 때 REG1에 래치됨.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/types.h>

#define REG0_OFF   0x00u
#define REG1_OFF   0x04u
#define REG2_OFF   0x08u
#define REG3_OFF   0x0Cu

// REG0 구성 매크로
static inline uint32_t pack_reg0(uint8_t a, uint8_t b, uint8_t opcode, uint8_t ena) {
    return ((uint32_t)a << 24) |
           ((uint32_t)b << 16) |
           ((uint32_t)(!!ena) << 3) |
           ((uint32_t)(opcode & 0x7));
}

static void usage(const char* prog) {
    fprintf(stderr,
        "Usage:\n"
        "  %s <baseaddr_hex> write a=<0xAA|dec> b=<0xBB|dec> opcode=<0..7> ena=<0|1>\n"
        "  %s <baseaddr_hex> read\n"
        "\n"
        "Examples:\n"
        "  %s 0x43C00000 write a=0x12 b=0x34 opcode=0 ena=1\n"
        "  %s 0x43C00000 read\n",
        prog, prog, prog, prog);
}

static int parse_kv_u32(const char* arg, const char* key, uint32_t* out) {
    // arg 형태: key=value (value는 0x.. 또는 십진수)
    size_t klen = strlen(key);
    if (strncmp(arg, key, klen) != 0 || arg[klen] != '=')
        return 0;
    const char* v = arg + klen + 1;
    char* endp = NULL;
    uint32_t val = (uint32_t)strtoul(v, &endp, 0);
    if (endp == v || *endp != '\0') {
        fprintf(stderr, "Invalid numeric for %s: %s\n", key, v);
        exit(1);
    }
    *out = val;
    return 1;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        usage(argv[0]);
        return 1;
    }

    // 1) 베이스 주소
    char* endp = NULL;
    uint32_t base = (uint32_t)strtoul(argv[1], &endp, 0);
    if (endp == argv[1] || *endp != '\0') {
        fprintf(stderr, "Invalid base address: %s\n", argv[1]);
        return 1;
    }

    // 2) 모드
    int do_write = 0;
    if (strcmp(argv[2], "write") == 0) do_write = 1;
    else if (strcmp(argv[2], "read") == 0) do_write = 0;
    else {
        usage(argv[0]);
        return 1;
    }

    // 3) /dev/mem mmap
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) page_size = 4096;

    off_t page_base = (off_t)(base & ~((uint32_t)page_size - 1));
    off_t page_off  = (off_t)(base - page_base);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        fprintf(stderr, "open(/dev/mem) failed: %s\n", strerror(errno));
        return 1;
    }

    // AXI-Lite는 보통 4KB 정렬/맵이면 충분. 안전하게 한 페이지 매핑
    void* map = mmap(NULL, (size_t)page_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, page_base);
    if (map == MAP_FAILED) {
        fprintf(stderr, "mmap failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    volatile uint32_t* vbase = (volatile uint32_t*)((uint8_t*)map + page_off);

    // 4) 동작
    if (do_write) {
        // 파라미터 파싱
        uint32_t a=0, b=0, opcode=0, ena=0;
        for (int i = 3; i < argc; ++i) {
            if (parse_kv_u32(argv[i], "a", &a)) continue;
            if (parse_kv_u32(argv[i], "b", &b)) continue;
            if (parse_kv_u32(argv[i], "opcode", &opcode)) continue;
            if (parse_kv_u32(argv[i], "ena", &ena)) continue;
            fprintf(stderr, "Unknown arg: %s\n", argv[i]);
            return 1;
        }

        if (opcode > 7) {
            fprintf(stderr, "opcode must be 0..7\n");
            return 1;
        }

        uint32_t reg0 = pack_reg0((uint8_t)a, (uint8_t)b, (uint8_t)opcode, (uint8_t)ena);
        // 쓰기: REG0
        vbase[REG0_OFF/4] = reg0;

        // 간단한 타이밍 여유(필요시). ALU가 조합/동기 구조라도 문제 없게 약간 대기
        // (대부분 즉시 래치되지만, 안전하게 몇 사이클 대기)
        usleep(100);  // 100us

        // 읽기: REG1(결과)
        uint32_t r1 = vbase[REG1_OFF/4];
        uint16_t result = (uint16_t)(r1 & 0xFFFFu);

        printf("[WRITE] BASE=0x%08X REG0=0x%08X (a=0x%02X b=0x%02X opcode=%u ena=%u)\n",
               base, reg0, (unsigned)a & 0xFFu, (unsigned)b & 0xFFu, (unsigned)opcode, (unsigned)ena);
        printf("[READ ] REG1=0x%08X  -> result=0x%04X (%u)\n", r1, result, (unsigned)result);
    } else {
        // 단순 읽기 덤프
        uint32_t r0 = vbase[REG0_OFF/4];
        uint32_t r1 = vbase[REG1_OFF/4];
        uint32_t r2 = vbase[REG2_OFF/4];
        uint32_t r3 = vbase[REG3_OFF/4];

        uint8_t a      = (uint8_t)((r0 >> 24) & 0xFFu);
        uint8_t b      = (uint8_t)((r0 >> 16) & 0xFFu);
        uint8_t opcode = (uint8_t)(r0 & 0x7u);
        uint8_t ena    = (uint8_t)((r0 >> 3) & 0x1u);
        uint16_t res   = (uint16_t)(r1 & 0xFFFFu);

        printf("[DUMP] BASE=0x%08X\n", base);
        printf("  REG0=0x%08X  (a=0x%02X b=0x%02X opcode=%u ena=%u)\n", r0, a, b, opcode, ena);
        printf("  REG1=0x%08X  (result=0x%04X / %u)\n", r1, res, (unsigned)res);
        printf("  REG2=0x%08X\n", r2);
        printf("  REG3=0x%08X\n", r3);
    }

    // 5) 정리
    munmap((void*)map, (size_t)page_size);
    close(fd);
    return 0;
}
