# Zybo Z7-020 PL GPIO를 이용한 stepmotor 제어 가이드

Zybo Z7-020에서 PL(Programmable Logic) 영역의 GPIO를 사용하여 LED를 제어하는 전체 프로세스를 단계별로 설명합니다.

<img width="495" height="488" alt="023" src="https://github.com/user-attachments/assets/a28c80bb-bb28-4b34-8b94-fa75e9859d27" />


## 📋 목차
1. [Vivado에서 하드웨어 설계](#1️⃣-vivado에서-하드웨어-설계-windows)
2. [PetaLinux 프로젝트 생성 및 빌드](#2️⃣-petalinux-프로젝트-생성-ubuntu-2204)
3. [쉘스크립트로 LED 제어](#3️⃣-쉘스크립트로-led-제어)
4. [C 언어로 LED 제어](#4️⃣-c-언어로-led-제어)
5. [문제 해결](#-문제-해결-troubleshooting)
6. [추가 개선 사항](#-추가-개선-사항)

## 🛠️ 개발 환경

- **FPGA 보드**: Digilent Zybo Z7-020
- **Vivado**: 2022.2 (Windows)
- **PetaLinux**: 2022.2 (Ubuntu 22.04.5 LTS)
- **제어 대상**: PL GPIO 4개 → LED 4개

---

## 1️⃣ Vivado에서 하드웨어 설계 (Windows)

### 1.1 새 프로젝트 생성

1. Vivado 2022.2 실행
2. "Create Project" 클릭
3. 프로젝트 이름: `zybo_gpio_led`
4. 프로젝트 위치 지정
5. "RTL Project" 선택, "Do not specify sources at this time" 체크
6. Board 선택: **Digilent Zybo Z7-20** 선택
   - 보드가 목록에 없으면 [Digilent Board Files](https://github.com/Digilent/vivado-boards) 설치 필요

### 1.2 Block Design 생성

1. "Create Block Design" 클릭
2. Design 이름: `system`

### 1.3 IP 추가 및 연결

#### Step 0: zybo_z720_stepper_top IP로 만들기
tools -> create and packege new ip  
<img width="545" height="97" alt="image" src="https://github.com/user-attachments/assets/f03b4514-1abe-4024-956c-725a6322cf8e" />


#### Step 1: ZYNQ7 Processing System 추가
1. IP Catalog에서 "ZYNQ7 Processing System" 검색
2. 블록 다이어그램에 추가
3. "Run Block Automation" 클릭하여 자동 설정 적용

#### Step 2: AXI GPIO 추가
1. IP Catalog에서 "AXI GPIO" 검색
2. 블록 다이어그램에 추가
3. AXI GPIO를 더블클릭하여 설정:
   - **GPIO Width**: 4 (LED 4개 사용)
   - **All Outputs** 체크
   - **Enable Dual Channel**: 비활성화

#### Step 3: 연결하기
1. "Run Connection Automation" 클릭
2. 모든 옵션 체크하고 OK
   - AXI GPIO가 ZYNQ PS의 M_AXI_GP0에 자동 연결됨
   - AXI Interconnect와 Processor System Reset이 자동 추가됨

#### Step 4: stepmotor ip 추가
1. 새로 만들었던 ip 추가후 gpio_io_o out put 을 stepmotor ip 입력에 연결
2. clk는 zynq의 fclk_clk0로 연결 (혹은 새로 하나 만들어서 125M로 설정가능)
3. 이전에 코드의 파라미터 50M로 바꿔주기(업데이트)
  

#### Step 5:  stepmotor 포트를 외부로 연결
1. stepmotor IP 포트를 우클릭
2. "Make External" 선택
3. 생성된 포트 이름: `coils` (또는 유사한 이름)

<img width="1209" height="448" alt="image" src="https://github.com/user-attachments/assets/f984f7b9-f1d6-4de9-acf7-f99a6b0d21b6" />



### 1.4 주소 할당 확인

1. "Address Editor" 탭 클릭
2. `axi_gpio_0`의 주소 확인 (예: `0x41200000`)
   - ⚠️ 이 주소는 나중에 소프트웨어에서 사용됩니다

### 1.5 제약 파일(Constraints) 생성

#### Step 1: XDC 파일 생성
1. Sources 창에서 "Add Sources" 클릭
2. "Add or create constraints" 선택
3. "Create File" 클릭
4. 파일명: `zybo_constraints.xdc`

#### Step 2: coils[3:0] 핀 매핑 작성


**`zybo_constraints.xdc` 파일 내용:**
```tcl##Pmod Header JE                                                                                                                  
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { coils[0] }]; #IO_L4P_T0_34 Sch=je[1]						 
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { coils[1] }]; #IO_L18N_T2_34 Sch=je[2]                     
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { coils[2] }]; #IO_25_35 Sch=je[3]                          
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { coils[3] }]; #IO_L19P_T3_35 Sch=je[4]                     
#set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { je[4] }]; #IO_L3N_T0_DQS_34 Sch=je[7]                  
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { je[5] }]; #IO_L9N_T1_DQS_34 Sch=je[8]                  
#set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { je[6] }]; #IO_L20P_T3_34 Sch=je[9]                     
#set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { je[7] }]; #IO_L7N_T1_34 Sch=je[10]   
```

> ⚠️ **주의**: 실제로 Block Design에서 생성된 포트 이름을 확인하고 위의 `gpio_rtl_0_tri_o`를 실제 이름으로 변경하세요.

### 1.6 HDL Wrapper 생성 및 비트스트림 생성

1. Sources 창에서 Block Design (`system.bd`) 우클릭
2. "Create HDL Wrapper" 선택
3. "Let Vivado manage wrapper..." 선택
4. "Generate Bitstream" 클릭
5. 합성 및 구현이 완료될 때까지 대기 (⏱️ 10-20분 소요)

### 1.7 하드웨어 내보내기

1. File → Export → Export Hardware 클릭
2. "Include bitstream" 선택
3. 파일 저장: `stepmotor_top_wrapper.xsa`
4. 이 파일을 Ubuntu로 전송 (USB, 네트워크 등)

---

## 2️⃣ PetaLinux 프로젝트 생성 (Ubuntu 22.04)

### 2.1 PetaLinux 환경 설정

```bash
# XSA 파일 준비
cp /mnt/share/`stepmotor_top_wrapper.xsa ~/projects/

# PetaLinux 설치 확인 (2022.2 버전)
source ~/petalinux/2022.2/settings.sh

# 작업 디렉토리 이
cd ~/projects/myproject
```

### 2.3 하드웨어 정보 가져오기

```bash
# Vivado에서 export한 XSA 파일 경로 지정
petalinux-config --get-hw-description=~/projects/
```

### 2.4 Device Tree 수정 (중요!)

PL GPIO를 사용하려면 Device Tree에 GPIO 컨트롤러를 등록해야 합니다.

```bash
# Device Tree 편집
vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

**`system-user.dtsi` 내용:**
```dts
/include/ "system-conf.dtsi"
/ {
};

&axi_gpio_0 {
    compatible = "xlnx,xps-gpio-1.00.a";
    gpio-controller;
    #gpio-cells = <2>;
    xlnx,all-inputs = <0x0>;
    xlnx,all-outputs = <0x1>;
    xlnx,dout-default = <0x0>;
    xlnx,gpio-width = <0x4>;
    xlnx,tri-default = <0xFFFFFFFF>;
    xlnx,is-dual = <0>;
};
```

**설명:**
- `gpio-controller`: 이 디바이스가 GPIO 컨트롤러임을 선언
- `#gpio-cells = <2>`: GPIO 참조 시 2개의 셀 사용 (핀 번호, 플래그)
- `xlnx,gpio-width = <0x4>`: GPIO 폭 4비트 (LED 4개)
- `xlnx,all-outputs = <0x1>`: 모든 핀이 출력

### 2.5 커널 설정 확인

```bash
petalinux-config -c kernel
```

다음 옵션들이 활성화되어 있는지 확인:
```
Device Drivers --->
    [*] GPIO Support --->
        <*> Memory mapped GPIO drivers --->
            <*> Xilinx GPIO support
        <*> /sys/class/gpio/... (sysfs interface)
```

저장하고 종료 (Save → Exit)
<br>
<br>

stepmotor_top_wrapper.xsa 압출풀고  
design_1_wrapper.bit -> cd ~/projects/myproject/images/linux 경로에 복사



### 2.6 PetaLinux 빌드

```bash
cd ~/projects/myproject

# PetaLinux 환경 확인
source ~/petalinux/2022.2/settings.sh

# 빌드 시작
petalinux-build

petalinux-package --boot \
    --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/design_1_wrapper.bit \
    --u-boot images/linux/u-boot.elf \
    --force

# WIC 이미지 생성
petalinux-package --wic \
    --bootfiles "BOOT.BIN image.ub boot.scr" \
    --images-dir images/linux/
```

---
```
petalinux-build -c kernel

빌드 후 설정 확인
bash# GPIO 설정이 제대로 적용되었는지 확인
grep "CONFIG_GPIO" build/tmp/work/zynq_generic-xilinx-linux-gnueabi/linux-xlnx/*/linux-zynq_generic-standard-build/.config | grep "=y"


**예상 출력:**
CONFIG_GPIOLIB=yㅇ
CONFIG_GPIO_SYSFS=y
CONFIG_GPIO_XILINX=y
CONFIG_OF_GPIO=y
CONFIG_GPIO_GENERIC=y
```
---


=================================================
## 해결안 1
=================================================

<img width="995" height="484" alt="002" src="https://github.com/user-attachments/assets/a9de87aa-6fda-4716-ac66-10f6feb62b9b" />
<br>
<img width="1461" height="500" alt="001" src="https://github.com/user-attachments/assets/280f59ff-1195-457e-b728-81e9364a7c7e" />
<br>

```verilog
// zybo_z720_stepper_top.v
module zybo_z720_stepper_top #(
    parameter integer CLK_HZ        = 125_000_000,
    parameter integer STEPS_PER_SEC = 600
)(
    input  wire clk,
    input  wire [3:0] in_signal,
    output wire [3:0] coils
);

    wire rst_n     = in_signal[0];  // Active-Low Reset
    wire sw_run    = in_signal[1];
    wire sw_dir    = in_signal[2];
    wire half_full = in_signal[3];

    // 디바운스
    wire run_clean, dir_clean;
    debounce #(.CLK_HZ(CLK_HZ), .MS(10)) u_db_run (
        .clk(clk), .rst_n(rst_n), .din(sw_run), .dout(run_clean)
    );
    debounce #(.CLK_HZ(CLK_HZ), .MS(10)) u_db_dir (
        .clk(clk), .rst_n(rst_n), .din(sw_dir), .dout(dir_clean)
    );

    // 스텝 타이머
    localparam integer TICKS_PER_STEP = (CLK_HZ / STEPS_PER_SEC);
    reg [31:0] tick_cnt;
    wire step_pulse = (tick_cnt == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tick_cnt <= TICKS_PER_STEP - 1;
        else if (run_clean)
            tick_cnt <= (tick_cnt == 0) ? (TICKS_PER_STEP - 1) : (tick_cnt - 1);
        else
            tick_cnt <= TICKS_PER_STEP - 1;
    end

    // 스텝 인덱스
    reg [2:0] step_idx;
    reg [2:0] max_idx;
    always @(*) max_idx = (half_full) ? 3'd7 : 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            step_idx <= 0;
        else if (run_clean && step_pulse) begin
            if (dir_clean) begin
                if (step_idx == max_idx) step_idx <= 0;
                else                     step_idx <= step_idx + 1'b1;
            end else begin
                if (step_idx == 0) step_idx <= max_idx;
                else               step_idx <= step_idx - 1'b1;
            end
        end
    end

    // 시퀀스 ROM
    reg [3:0] patt;
    always @(*) begin
        if (half_full) begin
            case (step_idx)
                3'd0: patt = 4'b1000;
                3'd1: patt = 4'b1100;
                3'd2: patt = 4'b0100;
                3'd3: patt = 4'b0110;
                3'd4: patt = 4'b0010;
                3'd5: patt = 4'b0011;
                3'd6: patt = 4'b0001;
                3'd7: patt = 4'b1001;
                default: patt = 4'b0000;
            endcase
        end else begin
            case (step_idx[1:0])
                2'd0: patt = 4'b1100;
                2'd1: patt = 4'b0110;
                2'd2: patt = 4'b0011;
                2'd3: patt = 4'b1001;
                default: patt = 4'b0000;
            endcase
        end
    end

    assign coils = run_clean ? patt : 4'b0000;

endmodule

// ---------------------- debounce ----------------------
module debounce #(
    parameter integer CLK_HZ = 125_000_000,
    parameter integer MS     = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    localparam integer CNT_MAX = (CLK_HZ/1250)*MS;
    reg din_q1, din_q2;
    reg [31:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_q1 <= 1'b0;
            din_q2 <= 1'b0;
        end else begin
            din_q1 <= din;
            din_q2 <= din_q1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= 0;
            dout <= 0;
        end else if (din_q2 == dout) begin
            cnt <= 0;
        end else begin
            if (cnt >= CNT_MAX) begin
                dout <= din_q2;
                cnt  <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end
endmodule

```


```xdc
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { coils[0] }]; #IO_L4P_T0_34 Sch=je[1]						 
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { coils[1] }]; #IO_L18N_T2_34 Sch=je[2]                     
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { coils[2] }]; #IO_25_35 Sch=je[3]                          
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { coils[3] }]; #IO_L19P_T3_35 Sch=je[4]
```


```shc
# GPIO export (LED0 = GPIO 1020 가정)
echo 1020 > /sys/class/gpio/export
echo 1021 > /sys/class/gpio/export
echo 1022 > /sys/class/gpio/export
echo 1023 > /sys/class/gpio/export

# 출력 모드 설정
echo out > /sys/class/gpio/gpio1020/direction
echo out > /sys/class/gpio/gpio1021/direction
echo out > /sys/class/gpio/gpio1022/direction
echo out > /sys/class/gpio/gpio1023/direction


# LED 켜기
echo 1 > /sys/class/gpio/gpio1020/value
echo 1 > /sys/class/gpio/gpio1021/value
echo 1 > /sys/class/gpio/gpio1022/value
echo 1 > /sys/class/gpio/gpio1023/value

# LED 끄기
echo 0 > /sys/class/gpio/gpio1020/value
echo 0 > /sys/class/gpio/gpio1021/value
echo 0 > /sys/class/gpio/gpio1022/value
echo 0 > /sys/class/gpio/gpio1023/value

# GPIO unexport
echo 1020 > /sys/class/gpio/unexport


1020 - reset (0 : reset, 1 : unreset)
1021 - run (0 : stop, 1: run)
1022 - dir (0:frw, 1:back)
1023 - half_full (0:half, 1: full)
```

### stepctl.c (ARM Compile)

```
arm-linux-gnueabihf-gcc -o stepctl stepctl.c
```

```c
// stepctl.c — Zybo Z7-20 + PetaLinux에서 sysfs GPIO(1020~1023)로 스텝모터 제어
// 사용법: 보드의 UART 콘솔(ttyPS0)에서 ./stepctl 실행 후 명령 입력
// 명령 예시: show / set run 1 / toggle dir / pulse reset 100 / watch 500 / quit

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <sys/stat.h>

typedef struct {
    const char *name; // 논리명
    int gpio;         // sysfs 번호
    const char *desc; // 설명
} gpio_map_t;

static gpio_map_t gmap[] = {
    {"reset",     1020, "0: reset(assert), 1: unreset(deassert)"},
    {"run",       1021, "0: stop, 1: run"},
    {"dir",       1022, "0: forward, 1: backward"},
    {"half_full", 1023, "0: half-step, 1: full-step"},
};
static const int GMAP_N = sizeof(gmap)/sizeof(gmap[0]);

static volatile sig_atomic_t g_stop = 0;
static void on_sigint(int sig){ (void)sig; g_stop = 1; }

static int write_str(const char *path, const char *s){
    int fd = open(path, O_WRONLY);
    if (fd < 0) return -errno;
    ssize_t n = write(fd, s, strlen(s));
    int rc = (n < 0) ? -errno : 0;
    close(fd);
    return rc;
}
static int read_str(const char *path, char *buf, size_t cap){
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -errno;
    ssize_t n = read(fd, buf, cap-1);
    if (n < 0){ int e = -errno; close(fd); return e; }
    buf[n] = '\0';
    close(fd);
    return 0;
}
static int path_exists(const char *path){
    struct stat st;
    return stat(path, &st) == 0;
}

static int gpio_export_if_needed(int gpio){
    char dirpath[128];
    snprintf(dirpath, sizeof(dirpath), "/sys/class/gpio/gpio%d", gpio);
    if (path_exists(dirpath)) return 0;
    char num[16]; snprintf(num, sizeof(num), "%d", gpio);
    int rc = write_str("/sys/class/gpio/export", num);
    if (rc < 0 && rc != -EBUSY) return rc;
    // sysfs가 생성될 때까지 잠깐 대기
    for (int i=0; i<50; ++i){
        if (path_exists(dirpath)) return 0;
        usleep(20000);
    }
    return -ETIMEDOUT;
}
static int gpio_set_dir_out(int gpio){
    char path[128];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio);
    return write_str(path, "out");
}
static int gpio_set_value(int gpio, int value){
    char path[128], v[4];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio);
    snprintf(v, sizeof(v), "%d", value ? 1 : 0);
    return write_str(path, v);
}
static int gpio_get_value(int gpio, int *value){
    char path[128], buf[16];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio);
    int rc = read_str(path, buf, sizeof(buf));
    if (rc < 0) return rc;
    *value = (buf[0] == '1') ? 1 : 0;
    return 0;
}

static gpio_map_t* find_gpio(const char *name){
    for (int i=0;i<GMAP_N;i++)
        if (strcmp(gmap[i].name, name)==0) return &gmap[i];
    return NULL;
}

static void msleep(unsigned ms){
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (long)(ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

static void print_header(void){
    printf("\n=== Step Motor GPIO Control (sysfs) ===\n");
    for (int i=0;i<GMAP_N;i++)
        printf(" - %-9s : gpio%d  (%s)\n", gmap[i].name, gmap[i].gpio, gmap[i].desc);
    printf("\n명령:\n");
    printf("  show                      : 현재 상태 출력\n");
    printf("  set <name> <0|1>          : 값 설정 (예: set run 1)\n");
    printf("  toggle <name>             : 0/1 토글\n");
    printf("  pulse <name> <ms> [level] : <level>(기본 1)로 <ms>ms 펄스\n");
    printf("  watch <ms>                : <ms>주기로 상태 갱신 (Ctrl+C 종료)\n");
    printf("  help                      : 도움말\n");
    printf("  quit/exit                 : 종료\n\n");
}

static void cmd_show(void){
    printf("\n[GPIO 상태]\n");
    for (int i=0;i<GMAP_N;i++){
        int v=-1;
        int rc = gpio_get_value(gmap[i].gpio, &v);
        if (rc==0) printf("  %-9s(gpio%-4d) = %d\n", gmap[i].name, gmap[i].gpio, v);
        else printf("  %-9s(gpio%-4d) = <error %d>\n", gmap[i].name, gmap[i].gpio, rc);
    }
    printf("\n");
}

static int ensure_all_ready(void){
    for (int i=0;i<GMAP_N;i++){
        int rc = gpio_export_if_needed(gmap[i].gpio);
        if (rc<0) {
            fprintf(stderr, "gpio%d export 실패: %s\n", gmap[i].gpio, strerror(-rc));
            return rc;
        }
        rc = gpio_set_dir_out(gmap[i].gpio);
        if (rc<0) {
            fprintf(stderr, "gpio%d direction=out 실패: %s\n", gmap[i].gpio, strerror(-rc));
            return rc;
        }
    }
    return 0;
}

int main(void){
    signal(SIGINT, on_sigint);
    signal(SIGTERM, on_sigint);

    if (ensure_all_ready() < 0){
        fprintf(stderr, "초기화 실패. root 권한 또는 디바이스 트리/퍼미션 확인 필요.\n");
        return 1;
    }

    print_header();
    cmd_show();

    char line[256];
    while (1){
        printf("stepctl> ");
        fflush(stdout);
        if (!fgets(line, sizeof(line), stdin)) break;

        // 공백/개행 정리
        char *p = line;
        while (*p==' '||*p=='\t') p++;
        size_t L = strlen(p);
        while (L>0 && (p[L-1]=='\n'||p[L-1]=='\r'||p[L-1]==' '||p[L-1]=='\t')) p[--L]=0;
        if (L==0) continue;

        if (!strcmp(p,"quit") || !strcmp(p,"exit")) break;
        if (!strcmp(p,"help")) { print_header(); continue; }
        if (!strcmp(p,"show")) { cmd_show(); continue; }

        if (!strncmp(p,"set ",4)){
            char name[32]; int val; 
            if (sscanf(p+4, "%31s %d", name, &val)==2){
                gpio_map_t *gm = find_gpio(name);
                if (!gm){ printf("알 수 없는 name: %s\n", name); continue; }
                if (val!=0 && val!=1){ printf("값은 0 또는 1\n"); continue; }
                int rc = gpio_set_value(gm->gpio, val);
                if (rc<0) printf("설정 실패: %s\n", strerror(-rc));
                else cmd_show();
            } else {
                printf("형식: set <name> <0|1>\n");
            }
            continue;
        }

        if (!strncmp(p,"toggle ",7)){
            char name[32];
            if (sscanf(p+7, "%31s", name)==1){
                gpio_map_t *gm = find_gpio(name);
                if (!gm){ printf("알 수 없는 name: %s\n", name); continue; }
                int v=0; int rc = gpio_get_value(gm->gpio, &v);
                if (rc<0){ printf("읽기 실패: %s\n", strerror(-rc)); continue; }
                rc = gpio_set_value(gm->gpio, !v);
                if (rc<0) printf("설정 실패: %s\n", strerror(-rc));
                else cmd_show();
            } else {
                printf("형식: toggle <name>\n");
            }
            continue;
        }

        if (!strncmp(p,"pulse ",6)){
            char name[32]; int ms=0; int level=1;
            int n = sscanf(p+6, "%31s %d %d", name, &ms, &level);
            if (n>=2){
                gpio_map_t *gm = find_gpio(name);
                if (!gm){ printf("알 수 없는 name: %s\n", name); continue; }
                if (ms<=0){ printf("ms는 양수여야 합니다\n"); continue; }
                if (level!=0 && level!=1) level = 1;
                int v_backup=0; 
                if (gpio_get_value(gm->gpio, &v_backup)<0) v_backup=0;
                if (gpio_set_value(gm->gpio, level)<0){ printf("설정 실패\n"); continue; }
                msleep((unsigned)ms);
                gpio_set_value(gm->gpio, v_backup);
                cmd_show();
            } else {
                printf("형식: pulse <name> <ms> [level]\n");
            }
            continue;
        }

        if (!strncmp(p,"watch ",6)){
            int period_ms = 0;
            if (sscanf(p+6, "%d", &period_ms)==1 && period_ms>=50){
                printf("watch 시작 — %d ms 주기 (Ctrl+C 종료)\n", period_ms);
                g_stop = 0;
                while (!g_stop){
                    cmd_show();
                    msleep((unsigned)period_ms);
                }
                printf("watch 종료\n");
            } else {
                printf("형식: watch <ms>  (권장: >= 100)\n");
            }
            continue;
        }

        printf("알 수 없는 명령입니다. help 를 입력해 보세요.\n");
    }

    printf("종료합니다.\n");
    return 0;
}

```

```
root@myproject:~# ./stepctl

=== Step Motor GPIO Control (sysfs) ===
 - reset     : gpio1020  (0: reset(assert), 1: unreset(deassert))
 - run       : gpio1021  (0: stop, 1: run)
 - dir       : gpio1022  (0: forward, 1: backward)
 - half_full : gpio1023  (0: half-step, 1: full-step)

명령:
  show                      : 현재 상태 출력
  set <name> <0|1>          : 값 설정 (예: set run 1)
  toggle <name>             : 0/1 토글
  pulse <name> <ms> [level] : <level>(기본 1)로 <ms>ms 펄스
  watch <ms>                : <ms>주기로 상태 갱신 (Ctrl+C 종료)
  help                      : 도움말
  quit/exit                 : 종료


[GPIO 상태]
  reset    (gpio1020) = 0
  run      (gpio1021) = 0
  dir      (gpio1022) = 0
  half_full(gpio1023) = 0
```

<br>

```text
# 시리얼 파일 전송 사용법 (TeraTerm)

lrzsz 패키지 설치 후, TeraTerm을 통해 파일을 전송할 수 있습니다.


보드에서 파일 수신 (PC → 보드):

# 보드 콘솔에서
cd /home/root

# ZMODEM으로 수신 대기 (가장 권장)
rz

# 또는 YMODEM으로 수신
ry

TeraTerm에서 파일 전송:

File → Transfer → ZMODEM → Send 클릭
전송할 파일 선택 (예: gpio_test 실행파일)
전송 완료 후 실행 권한 부여:

chmod +x gpio_test
./gpio_test


보드에서 파일 송신 (보드 → PC):

# 보드 콘솔에서
cd /home/root

# ZMODEM으로 송신
sz filename

TeraTerm에서 파일 수신:

File → Transfer → ZMODEM → Receive 클릭
저장 위치 선택

프로토콜 비교:

XMODEM: 느림, 단일 파일만 (rx/sx)
YMODEM: 중간, 배치 전송 가능 (ry/sy)
ZMODEM: 빠름, 오류 복구, 이어받기 지원 (rz/sz) ← 권장
```


---

=============================================================
# AXI4 Peripheral IP 생성 과정
=============================================================

<img width="1154" height="452" alt="006" src="https://github.com/user-attachments/assets/40d6decf-b090-468d-95ad-401d186e5da3" />

### 1. Create and Package New IP 시작
Vivado에서:
```
Tools → Create and Package New IP...
→ Create a new AXI4 peripheral 선택
→ Next
```

### 2. Peripheral Details 설정
```
Name: stepper_motor_ctrl (또는 원하는 이름)
Version: 1.0
Display name: Stepper Motor Controller
Description: ULN2003 Stepper Motor Controller with AXI4-Lite interface
```

### 3. Add Interfaces
```
Interface Type: AXI4-Lite
Interface Mode: Slave
Data Width: 32
Number of Registers: 4 (최소한 필요)
```

추천 레지스터 맵:
* Offset 0x00: Control Register (run, dir, half_full, enable)
* Offset 0x04: Status Register (현재 step_idx, coils 상태)
* Offset 0x08: Speed Register (STEPS_PER_SEC 설정)
* Offset 0x0C: Reserved

<img width="842" height="572" alt="004" src="https://github.com/user-attachments/assets/dcbb97ff-0f82-4658-9496-09764785ba2b" />
<br>
<img width="842" height="572" alt="005" src="https://github.com/user-attachments/assets/109a677f-2991-4562-8b52-2a7c1dc8ddc5" />
<br>
<img width="842" height="572" alt="007" src="https://github.com/user-attachments/assets/ac712f1d-8ef3-4dc8-91ab-1f5f9815998a" />
<br>
<img width="842" height="572" alt="008" src="https://github.com/user-attachments/assets/49a313c0-b29a-4c6c-970a-2b527c70bf0c" />
<br>
<img width="842" height="572" alt="009" src="https://github.com/user-attachments/assets/58fcd524-f69e-4c13-9eea-f4b4aa9f1cb0" />
<br>
<img width="842" height="572" alt="010" src="https://github.com/user-attachments/assets/28b3842d-7169-49b3-9bd4-801bb6897fca" />
<br>
<img width="842" height="572" alt="011" src="https://github.com/user-attachments/assets/2108e12f-9342-4be1-915f-b82da6645ba0" />
<br>
<img width="1080" height="657" alt="012" src="https://github.com/user-attachments/assets/301d7c4f-fac9-4cb0-b415-a6fdcb65766b" />
<br>
<img width="1077" height="655" alt="013" src="https://github.com/user-attachments/assets/63413475-cbfc-4413-bda9-00fe96b3642c" />
<br>


### 4. IP 구조 제안

IP를 생성하면 <ip_name>_v1_0_S00_AXI.v 파일이 생성됩니다. 이 파일을 수정해야 합니다:

```verilog
// stepper_motor_ctrl_v1_0_S00_AXI.v 수정 예시

module stepper_motor_ctrl_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4,
    parameter integer CLK_HZ = 125_000_000
)(
    // AXI ports...
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,
    // ... (standard AXI signals)
    
    // User ports - Stepper Motor Interface
    output wire [3:0] coils_out
);

    // AXI4-Lite signals (기존 생성된 코드 유지)
    // ...

    // User registers
    reg [31:0] control_reg;  // slv_reg0
    reg [31:0] status_reg;   // slv_reg1  
    reg [31:0] speed_reg;    // slv_reg2
    
    // Control signals extraction
    wire motor_enable = control_reg[0];
    wire motor_run    = control_reg[1];
    wire motor_dir    = control_reg[2];
    wire half_full    = control_reg[3];
    
    // Speed parameter
    wire [15:0] steps_per_sec = speed_reg[15:0];
    
    // Instantiate your stepper controller
    wire [3:0] in_signal = {half_full, motor_dir, motor_run, S_AXI_ARESETN};
    
    zybo_z720_stepper_top #(
        .CLK_HZ(CLK_HZ),
        .STEPS_PER_SEC(600)  // or use speed_reg value
    ) stepper_inst (
        .clk(S_AXI_ACLK),
        .in_signal(in_signal),
        .coils(coils_out)
    );
    
    // Update status register
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            status_reg <= 0;
        else
            status_reg <= {28'h0, coils_out};
    end

    // AXI write/read logic (기존 템플릿 코드 활용)
    // slv_reg0 → control_reg
    // slv_reg1 → status_reg (read-only)
    // slv_reg2 → speed_reg
    
endmodule
```

### 5. Top-level Wrapper 수정
stepper_motor_ctrl_v1_0.v 파일에 외부 포트 추가:
```verilog
module stepper_motor_ctrl_v1_0 #(
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 4
)(
    // AXI ports
    input wire s00_axi_aclk,
    input wire s00_axi_aresetn,
    // ... (standard AXI ports)
    
    // User ports - add this!
    output wire [3:0] coils
);

    stepper_motor_ctrl_v1_0_S00_AXI #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) stepper_motor_ctrl_v1_0_S00_AXI_inst (
        // AXI connections...
        .coils_out(coils)  // Connect user port
    );

endmodule
```
### 5. 확인하기

```
C:\Users\Administrator\ip_repo\stepper_motor_ctrl_1_0\hdl
C:\Users\Administrator\zybo_z720_stepper_top\zybo_z720_stepper_top.gen\sources_1\bd\design_1\ipshared\8bbb\hdl
```
#### 5.1. IP 소스 파일 확인
* IP 디렉토리로 가서 필요한 파일들이 모두 있는지 확인:
```
<ip_repo>/stepper_motor_ctrl_1.0/hdl/
```
다음 파일들이 반드시 있어야 합니다:
   * stepper_motor_ctrl_v1_0.v (top wrapper)
   * stepper_motor_ctrl_v1_0_S00_AXI.v (AXI interface)
   * zybo_z720_stepper_top.v (당신의 stepper 로직)
   * debounce.v

#### 5.2. IP를 다시 패키징 (권장 방법)
   * IP Catalog에서 생성한 IP를 수정하는 방법:
   * Step 1: IP를 Edit 모드로 열기
```
IP Catalog → 생성한 IP 우클릭 → Edit in IP Packager
```
   * 또는 원래 IP 프로젝트를 다시 열기
   * Step 2: 소스 파일 추가
   * IP Packager가 열리면:
   * Tools → Create and Package New IP 창에서:
```
Packaging Steps → File Groups
→ Merge changes from File Groups Wizard 클릭
```
또는 직접 추가:
```
Add Files → Add File or Add Directory
```
다음 파일들을 추가:
   * zybo_z720_stepper_top.v
   * debounce.v

   * Step 3: component.xml 확인
   * component.xml 파일에서 파일 그룹 확인:

```xml
<spirit:fileSet>
  <spirit:name>xilinx_anylanguagesynthesis</spirit:name>
  <spirit:file>
    <spirit:name>hdl/stepper_motor_ctrl_v1_0_S00_AXI.v</spirit:name>
    <spirit:fileType>verilogSource</spirit:fileType>
  </spirit:file>
  <spirit:file>
    <spirit:name>hdl/stepper_motor_ctrl_v1_0.v</spirit:name>
    <spirit:fileType>verilogSource</spirit:fileType>
  </spirit:file>
  <spirit:file>
    <spirit:name>hdl/zybo_z720_stepper_top.v</spirit:name>
    <spirit:fileType>verilogSource</spirit:fileType>
  </spirit:file>
  <spirit:file>
    <spirit:name>hdl/debounce.v</spirit:name>
    <spirit:fileType>verilogSource</spirit:fileType>
  </spirit:file>
</spirit:fileSet>
```

### 6. Constraints 파일 준비
IP 패키징 후 Block Design에서 사용할 때 외부 포트로 연결:

```tcl
# coils[0-3] → Pmod JE 등에 연결
set_property PACKAGE_PIN V12 [get_ports {coils[0]}]
set_property PACKAGE_PIN W16 [get_ports {coils[1]}]
set_property PACKAGE_PIN J15 [get_ports {coils[2]}]
set_property PACKAGE_PIN H15 [get_ports {coils[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {coils[*]}]
```

### 7. IP Packaging 완료

```
Review and Package → Re-Package IP
```

### 8. Block Design에서 사용

* IP Catalog에서 생성한 IP 추가
* ZYNQ PS의 M_AXI_GP0와 연결 (Run Connection Automation)
* coils 포트를 "Make External"로 외부 포트 생성
* Address Editor에서 적절한 주소 할당 (예: 0x43C0_0000)

### 9. Software에서 제어 (Bare-metal : Vitisc)

```c
#define STEPPER_BASE_ADDR 0x43C00000
#define CTRL_REG   (*(volatile uint32_t *)(STEPPER_BASE_ADDR + 0x00))
#define STATUS_REG (*(volatile uint32_t *)(STEPPER_BASE_ADDR + 0x04))
#define SPEED_REG  (*(volatile uint32_t *)(STEPPER_BASE_ADDR + 0x08))

// Motor control
void stepper_start(void) {
    CTRL_REG |= 0x02;  // Set run bit
}

void stepper_stop(void) {
    CTRL_REG &= ~0x02; // Clear run bit
}

void stepper_set_direction(int cw) {
    if (cw)
        CTRL_REG |= 0x04;
    else
        CTRL_REG &= ~0x04;
}
```

### 9. Software에서 제어 (Peta Linux)

```c
// stepper_test.c (PetaLinux User Application)
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define STEPPER_BASE_ADDR 0x43C00000
#define MAP_SIZE 0x1000  // 4KB

// Global pointer
volatile uint32_t *stepper_regs = NULL;

int stepper_init(void) {
    int fd;
    void *mapped_base;
    
    // Open /dev/mem
    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd == -1) {
        perror("Cannot open /dev/mem");
        return -1;
    }
    
    // Memory map
    mapped_base = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, 
                       MAP_SHARED, fd, STEPPER_BASE_ADDR);
    
    if (mapped_base == MAP_FAILED) {
        perror("mmap failed");
        close(fd);
        return -1;
    }
    
    stepper_regs = (volatile uint32_t *)mapped_base;
    close(fd);  // Can close fd after mmap
    
    return 0;
}

void stepper_cleanup(void) {
    if (stepper_regs != NULL) {
        munmap((void *)stepper_regs, MAP_SIZE);
        stepper_regs = NULL;
    }
}

// Control functions
void stepper_start(void) {
    stepper_regs[0] |= 0x02;  // CTRL_REG (offset 0x00)
}

void stepper_stop(void) {
    stepper_regs[0] &= ~0x02;
}

void stepper_set_direction(int cw) {
    if (cw)
        stepper_regs[0] |= 0x04;
    else
        stepper_regs[0] &= ~0x04;
}

void stepper_set_half_step(int enable) {
    if (enable)
        stepper_regs[0] |= 0x08;
    else
        stepper_regs[0] &= ~0x08;
}

uint32_t stepper_get_status(void) {
    return stepper_regs[1];  // STATUS_REG (offset 0x04)
}

int main(int argc, char **argv) {
    printf("Stepper Motor Test (PetaLinux)\n");
    
    // Initialize
    if (stepper_init() < 0) {
        fprintf(stderr, "Failed to initialize stepper\n");
        return 1;
    }
    
    // Stop motor first
    stepper_stop();
    
    // Start motor CW, full-step
    printf("Starting motor (CW, Full-step)...\n");
    stepper_set_direction(1);
    stepper_set_half_step(0);
    stepper_start();
    
    sleep(3);  // Run for 3 seconds
    
    // Change to CCW, half-step
    printf("Changing to CCW, Half-step...\n");
    stepper_set_direction(0);
    stepper_set_half_step(1);
    
    sleep(3);
    
    // Stop
    printf("Stopping motor...\n");
    stepper_stop();
    
    // Read status
    printf("Final status: 0x%08X\n", stepper_get_status());
    
    // Cleanup
    stepper_cleanup();
    
    return 0;
}
```

```
arm-linux-gnueabihf-gcc stepper_test.c -o stepper_test
```

50MHz Motor controller

```verilog
// zybo_z720_stepper_top.v - 50MHz version
// ULN2003 Stepper Motor Controller for Zybo Z7-20
// Clock: 50MHz (modified from 125MHz)

module zybo_z720_stepper_top #(
    parameter integer CLK_HZ        = 50_000_000,  // 50MHz
    parameter integer STEPS_PER_SEC = 600
)(
    input  wire clk,
    input  wire [3:0] in_signal,
    output wire [3:0] coils
);
    // Input signal mapping
    wire rst_n     = in_signal[0];  // Active-Low Reset
    wire sw_run    = in_signal[1];  // Run/Stop control
    wire sw_dir    = in_signal[2];  // Direction: 1=CW, 0=CCW
    wire half_full = in_signal[3];  // Step mode: 1=half-step, 0=full-step
    
    // Debounced signals
    wire run_clean, dir_clean;
    
    // Debounce for run signal
    debounce #(
        .CLK_HZ(CLK_HZ), 
        .MS(10)
    ) u_db_run (
        .clk(clk), 
        .rst_n(rst_n), 
        .din(sw_run), 
        .dout(run_clean)
    );
    
    // Debounce for direction signal
    debounce #(
        .CLK_HZ(CLK_HZ), 
        .MS(10)
    ) u_db_dir (
        .clk(clk), 
        .rst_n(rst_n), 
        .din(sw_dir), 
        .dout(dir_clean)
    );
    
    // Step timer calculation
    // At 50MHz with 600 steps/sec: TICKS_PER_STEP = 83,333 ticks
    // Step period = 1.667ms
    localparam integer TICKS_PER_STEP = (CLK_HZ / STEPS_PER_SEC);
    
    reg [31:0] tick_cnt;
    wire step_pulse = (tick_cnt == 0);
    
    // Step timer counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tick_cnt <= TICKS_PER_STEP - 1;
        else if (run_clean)
            tick_cnt <= (tick_cnt == 0) ? (TICKS_PER_STEP - 1) : (tick_cnt - 1);
        else
            tick_cnt <= TICKS_PER_STEP - 1;
    end
    
    // Step index (0-7 for half-step, 0-3 for full-step)
    reg [2:0] step_idx;
    reg [2:0] max_idx;
    
    // Maximum index based on step mode
    always @(*) 
        max_idx = (half_full) ? 3'd7 : 3'd3;
    
    // Step index counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            step_idx <= 0;
        else if (run_clean && step_pulse) begin
            if (dir_clean) begin
                // Clockwise rotation
                if (step_idx == max_idx) 
                    step_idx <= 0;
                else                     
                    step_idx <= step_idx + 1'b1;
            end else begin
                // Counter-clockwise rotation
                if (step_idx == 0) 
                    step_idx <= max_idx;
                else               
                    step_idx <= step_idx - 1'b1;
            end
        end
    end
    
    // Coil pattern ROM
    reg [3:0] patt;
    
    always @(*) begin
        if (half_full) begin
            // Half-step sequence (8 steps)
            case (step_idx)
                3'd0: patt = 4'b1000;  // A
                3'd1: patt = 4'b1100;  // AB
                3'd2: patt = 4'b0100;  // B
                3'd3: patt = 4'b0110;  // BC
                3'd4: patt = 4'b0010;  // C
                3'd5: patt = 4'b0011;  // CD
                3'd6: patt = 4'b0001;  // D
                3'd7: patt = 4'b1001;  // DA
                default: patt = 4'b0000;
            endcase
        end else begin
            // Full-step sequence (4 steps)
            case (step_idx[1:0])
                2'd0: patt = 4'b1100;  // AB
                2'd1: patt = 4'b0110;  // BC
                2'd2: patt = 4'b0011;  // CD
                2'd3: patt = 4'b1001;  // DA
                default: patt = 4'b0000;
            endcase
        end
    end
    
    // Output coil pattern (0 when stopped)
    assign coils = run_clean ? patt : 4'b0000;

endmodule

// ---------------------- debounce ----------------------
// Input debounce module for switch signals
// Filters out mechanical bounce noise

module debounce #(
    parameter integer CLK_HZ = 50_000_000,  // 50MHz
    parameter integer MS     = 10           // 10ms debounce time
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    // Counter max value calculation
    // At 50MHz with 10ms: CNT_MAX = 400,000
    // Actual debounce time = 8ms (close enough)
    localparam integer CNT_MAX = (CLK_HZ/1250)*MS;
    
    // Double synchronizer for metastability prevention
    reg din_q1, din_q2;
    reg [31:0] cnt;
    
    // Input synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_q1 <= 1'b0;
            din_q2 <= 1'b0;
        end else begin
            din_q1 <= din;
            din_q2 <= din_q1;
        end
    end
    
    // Debounce counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= 0;
            dout <= 0;
        end else if (din_q2 == dout) begin
            // Input stable, reset counter
            cnt <= 0;
        end else begin
            // Input changed, count up
            if (cnt >= CNT_MAX) begin
                // Counter reached max, update output
                dout <= din_q2;
                cnt  <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

endmodule
```





## 3️⃣ 쉘스크립트로 LED 제어

### 3.1 Zybo 부팅 및 로그인

1. SD 카드를 Zybo에 삽입
2. UART 연결 (115200 8N1)
3. 전원 켜기
4. 로그인: `root` / `root`

### 3.2 GPIO sysfs 인터페이스 확인

```bash
# GPIO 컨트롤러 확인
ls /sys/class/gpio/

# gpiochip이 보이면 정상 (예: gpiochip496)
# 번호는 시스템마다 다를 수 있음

# GPIO 베이스 번호 확인
cat /sys/class/gpio/gpiochip*/base
cat /sys/class/gpio/gpiochip*/ngpio
```

예를 들어:
- base: 496
- ngpio: 4

그러면 GPIO 번호는 **496, 497, 498, 499**입니다.

### 3.3 수동으로 LED 테스트

```bash
# GPIO export (LED0 = GPIO 496 가정)
echo 496 > /sys/class/gpio/export

# 출력 모드 설정
echo out > /sys/class/gpio/gpio496/direction

# LED 켜기
echo 1 > /sys/class/gpio/gpio496/value

# LED 끄기
echo 0 > /sys/class/gpio/gpio496/value

# GPIO unexport
echo 496 > /sys/class/gpio/unexport
```

### 3.4 LED 제어 쉘스크립트 작성

**`led_control.sh`:**
```bash
#!/bin/bash

# GPIO 베이스 번호 (시스템에 맞게 수정)
GPIO_BASE=496

# LED 번호 (0-3)
LED_NUM=$1
ACTION=$2

# GPIO 번호 계산
GPIO_NUM=$((GPIO_BASE + LED_NUM))

# 사용법 출력
if [ $# -ne 2 ]; then
    echo "사용법: $0 <LED 번호(0-3)> <on|off>"
    exit 1
fi

# GPIO export (이미 export된 경우 무시)
if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
    echo ${GPIO_NUM} > /sys/class/gpio/export
    sleep 0.1
fi

# 출력 모드 설정
echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction

# LED 제어
case $ACTION in
    on)
        echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
        echo "LED${LED_NUM} ON"
        ;;
    off)
        echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
        echo "LED${LED_NUM} OFF"
        ;;
    *)
        echo "잘못된 동작: on 또는 off를 사용하세요"
        exit 1
        ;;
esac
```

### 3.5 LED 순차 점멸 스크립트

**`led_blink.sh`:**
```bash
#!/bin/bash

GPIO_BASE=496

# 모든 LED export
for i in {0..3}; do
    GPIO_NUM=$((GPIO_BASE + i))
    if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
        echo ${GPIO_NUM} > /sys/class/gpio/export
        sleep 0.1
    fi
    echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction
done

echo "LED 순차 점멸 시작 (Ctrl+C로 종료)"

# 무한 루프
while true; do
    # 순차적으로 켜기
    for i in {0..3}; do
        GPIO_NUM=$((GPIO_BASE + i))
        echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
        sleep 0.2
    done
    
    # 순차적으로 끄기
    for i in {0..3}; do
        GPIO_NUM=$((GPIO_BASE + i))
        echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
        sleep 0.2
    done
done
```

### 3.6 실행 방법

```bash
# 실행 권한 부여
chmod +x led_control.sh
chmod +x led_blink.sh

# LED 제어 테스트
./led_control.sh 0 on   # LED0 켜기
./led_control.sh 0 off  # LED0 끄기
./led_control.sh 1 on   # LED1 켜기

# LED 순차 점멸
./led_blink.sh
```

---

## 4️⃣ C 언어로 LED 제어

### 4.1 C 프로그램 작성

**`led_control.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define GPIO_BASE 496  // 시스템에 맞게 수정
#define MAX_BUF 64

// GPIO export
int gpio_export(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/export", O_WRONLY);
    if (fd < 0) {
        perror("GPIO export 열기 실패");
        return -1;
    }
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    
    usleep(100000);  // 100ms 대기
    return 0;
}

// GPIO unexport
int gpio_unexport(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/unexport", O_WRONLY);
    if (fd < 0) {
        perror("GPIO unexport 열기 실패");
        return -1;
    }
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    
    return 0;
}

// GPIO 방향 설정
int gpio_set_direction(int gpio_num, const char *direction) {
    int fd;
    char path[MAX_BUF];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio_num);
    
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("GPIO direction 열기 실패");
        return -1;
    }
    
    write(fd, direction, strlen(direction));
    close(fd);
    
    return 0;
}

// GPIO 값 설정
int gpio_set_value(int gpio_num, int value) {
    int fd;
    char path[MAX_BUF];
    char val_str[2];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("GPIO value 열기 실패");
        return -1;
    }
    
    snprintf(val_str, sizeof(val_str), "%d", value);
    write(fd, val_str, 1);
    close(fd);
    
    return 0;
}

// GPIO 값 읽기
int gpio_get_value(int gpio_num) {
    int fd;
    char path[MAX_BUF];
    char value;
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("GPIO value 읽기 실패");
        return -1;
    }
    
    read(fd, &value, 1);
    close(fd);
    
    return (value == '0') ? 0 : 1;
}

int main(int argc, char *argv[]) {
    int led_num, gpio_num;
    char action[10];
    
    if (argc != 3) {
        printf("사용법: %s <LED 번호(0-3)> <on|off>\n", argv[0]);
        return 1;
    }
    
    led_num = atoi(argv[1]);
    strcpy(action, argv[2]);
    
    if (led_num < 0 || led_num > 3) {
        printf("LED 번호는 0-3 사이여야 합니다.\n");
        return 1;
    }
    
    gpio_num = GPIO_BASE + led_num;
    
    // GPIO export
    gpio_export(gpio_num);
    
    // 출력 모드 설정
    gpio_set_direction(gpio_num, "out");
    
    // LED 제어
    if (strcmp(action, "on") == 0) {
        gpio_set_value(gpio_num, 1);
        printf("LED%d ON\n", led_num);
    } else if (strcmp(action, "off") == 0) {
        gpio_set_value(gpio_num, 0);
        printf("LED%d OFF\n", led_num);
    } else {
        printf("잘못된 동작: on 또는 off를 사용하세요\n");
        return 1;
    }
    
    return 0;
}
```

### 4.2 LED 순차 점멸 C 프로그램

**`led_blink.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

#define GPIO_BASE 496
#define NUM_LEDS 4
#define MAX_BUF 64

volatile sig_atomic_t stop = 0;

void sigint_handler(int sig) {
    stop = 1;
}

int gpio_export(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/export", O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    usleep(100000);
    return 0;
}

int gpio_unexport(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/unexport", O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    return 0;
}

int gpio_set_direction(int gpio_num, const char *direction) {
    int fd;
    char path[MAX_BUF];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio_num);
    fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    
    write(fd, direction, strlen(direction));
    close(fd);
    return 0;
}

int gpio_set_value(int gpio_num, int value) {
    int fd;
    char path[MAX_BUF];
    char val_str[2];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(val_str, sizeof(val_str), "%d", value);
    write(fd, val_str, 1);
    close(fd);
    return 0;
}

int main() {
    int gpio_nums[NUM_LEDS];
    int i;
    
    // 시그널 핸들러 등록
    signal(SIGINT, sigint_handler);
    
    // GPIO 초기화
    for (i = 0; i < NUM_LEDS; i++) {
        gpio_nums[i] = GPIO_BASE + i;
        gpio_export(gpio_nums[i]);
        gpio_set_direction(gpio_nums[i], "out");
        gpio_set_value(gpio_nums[i], 0);
    }
    
    printf("LED 순차 점멸 시작 (Ctrl+C로 종료)\n");
    
    while (!stop) {
        // 순차적으로 켜기
        for (i = 0; i < NUM_LEDS && !stop; i++) {
            gpio_set_value(gpio_nums[i], 1);
            usleep(200000);  // 200ms
        }
        
        // 순차적으로 끄기
        for (i = 0; i < NUM_LEDS && !stop; i++) {
            gpio_set_value(gpio_nums[i], 0);
            usleep(200000);
        }
    }
    
    // 정리: 모든 LED 끄고 unexport
    printf("\n정리 중...\n");
    for (i = 0; i < NUM_LEDS; i++) {
        gpio_set_value(gpio_nums[i], 0);
        gpio_unexport(gpio_nums[i]);
    }
    
    printf("종료\n");
    return 0;
}
```

### 4.3 컴파일 및 실행

#### 방법 1: Zybo에서 직접 컴파일 (rootfs에 gcc 포함된 경우)

```bash
gcc -o led_control led_control.c
gcc -o led_blink led_blink.c

# 실행
./led_control 0 on
./led_control 1 on
./led_blink
```

#### 방법 2: 크로스 컴파일 (Ubuntu에서)

```bash
# PetaLinux SDK 설정
cd ~/petalinux_projects/zybo_gpio_led
petalinux-build --sdk
petalinux-package --sysroot

# SDK 설치
cd images/linux
./sdk.sh -d ~/petalinux_sdk

# SDK 환경 설정
source ~/petalinux_sdk/environment-setup-cortexa9t2hf-neon-xilinx-linux-gnueabi

# 크로스 컴파일
$CC led_control.c -o led_control
$CC led_blink.c -o led_blink

# Zybo로 파일 전송 (scp 또는 SD 카드)
scp led_control led_blink root@<zybo_ip>:/home/root/
```

---

## 🔧 문제 해결 (Troubleshooting)

### 1. GPIO가 보이지 않는 경우

```bash
# Device Tree 확인
cat /proc/device-tree/amba_pl@0/gpio@*/compatible

# 드라이버 로드 확인
lsmod | grep gpio
dmesg | grep gpio

# GPIO 컨트롤러 찾기
find /sys/class/gpio -name "gpiochip*"
```

### 2. GPIO 베이스 번호 찾기

```bash
# 모든 GPIO 칩 정보 확인
for chip in /sys/class/gpio/gpiochip*; do
    echo "Chip: $chip"
    echo "  Base: $(cat $chip/base)"
    echo "  Ngpio: $(cat $chip/ngpio)"
    echo "  Label: $(cat $chip/label)"
done
```

### 3. Permission denied 오류

```bash
# root로 실행하거나 udev 규칙 추가
sudo su
# 또는
sudo ./led_control 0 on
```

### 4. Device Tree 다시 확인

```bash
# Vivado Address Editor에서 확인한 주소와 매칭되는지 확인
cat /proc/device-tree/amba_pl@0/gpio@*/reg
```

---

## 📝 추가 개선 사항

### 1. UIO (Userspace I/O) 사용

더 빠른 성능이 필요하면 UIO 드라이버 사용:

**`led_control_uio.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define GPIO_BASE_ADDR 0x41200000  // Vivado Address Editor에서 확인
#define GPIO_DATA_OFFSET 0x0
#define GPIO_TRI_OFFSET 0x4

int main() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Cannot open /dev/mem");
        return -1;
    }
    
    void *gpio_addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                          MAP_SHARED, fd, GPIO_BASE_ADDR);
    
    if (gpio_addr == MAP_FAILED) {
        perror("mmap failed");
        close(fd);
        return -1;
    }
    
    volatile unsigned int *gpio_data = (unsigned int *)(gpio_addr + GPIO_DATA_OFFSET);
    volatile unsigned int *gpio_tri = (unsigned int *)(gpio_addr + GPIO_TRI_OFFSET);
    
    *gpio_tri = 0x0;  // 모두 출력으로 설정
    
    // LED 순차 점멸
    for (int i = 0; i < 10; i++) {
        *gpio_data = 0xF;  // 모든 LED ON
        usleep(500000);    // 500ms
        *gpio_data = 0x0;  // 모든 LED OFF
        usleep(500000);
    }
    
    munmap(gpio_addr, 4096);
    close(fd);
    
    return 0;
}
```

### 2. 부팅 시 자동 실행

```bash
# systemd 서비스 생성
nano /etc/systemd/system/led-blink.service
```

**`led-blink.service`:**
```ini
[Unit]
Description=LED Blink Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/home/root/led_blink
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# 서비스 활성화
systemctl enable led-blink.service
systemctl start led-blink.service

# 상태 확인
systemctl status led-blink.service
```

### 3. PWM을 이용한 LED 밝기 조절

쉘스크립트로 간단한 소프트웨어 PWM 구현:

**`led_pwm.sh`:**
```bash
#!/bin/bash

GPIO_BASE=496
LED_NUM=$1
BRIGHTNESS=$2  # 0-100

if [ $# -ne 2 ]; then
    echo "사용법: $0 <LED 번호(0-3)> <밝기(0-100)>"
    exit 1
fi

GPIO_NUM=$((GPIO_BASE + LED_NUM))

# GPIO export
if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
    echo ${GPIO_NUM} > /sys/class/gpio/export
    sleep 0.1
fi

echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction

# PWM 시뮬레이션
while true; do
    echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
    sleep 0.$(printf "%02d" $BRIGHTNESS)
    
    echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
    sleep 0.$(printf "%02d" $((100 - BRIGHTNESS)))
done
```

---

## ✅ 체크리스트

- [ ] Vivado에서 Block Design 완성
- [ ] XDC 파일에 LED 핀 할당
- [ ] 비트스트림 생성 및 XSA export
- [ ] PetaLinux 프로젝트 생성
- [ ] Device Tree에 GPIO 추가
- [ ] PetaLinux 빌드 성공
- [ ] SD 카드에 이미지 복사
- [ ] Zybo 부팅 확인
- [ ] GPIO sysfs 인터페이스 확인
- [ ] 쉘스크립트로 LED 제어 성공
- [ ] C 프로그램으로 LED 제어 성공

---

## 📚 참고 자료

- [Xilinx Zynq-7000 Technical Reference Manual](https://www.xilinx.com/support/documentation/user_guides/ug585-Zynq-7000-TRM.pdf)
- [Digilent Zybo Z7 Reference Manual](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual)
- [PetaLinux Tools Documentation](https://docs.xilinx.com/r/en-US/ug1144-petalinux-tools-reference-guide)
- [Linux GPIO Sysfs Interface](https://www.kernel.org/doc/Documentation/gpio/sysfs.txt)

---

## 📄 라이선스

이 가이드는 교육 목적으로 자유롭게 사용할 수 있습니다.

---

## 🤝 기여

개선 사항이나 오류 발견 시 Issue 또는 Pull Request를 환영합니다!

---

**작성일**: 2024  
**테스트 환경**: Zybo Z7-020, Vivado 2022.2, PetaLinux 2022.2, Ubuntu 22.04.5 LTS
