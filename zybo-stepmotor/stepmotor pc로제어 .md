
   
# Zybo Z7-020 PL GPIO를 이용한 stepmotor 제어 가이드

# Zybo_StepMotor 모듈 설

<details>
<summary>펼치기/접기 **Zybo_StepMotor 설명** </summary>  
   
## Standalone Step Motor Controller : StepMotor(28BYJ-48) 5V - ULN2003

### ⚙️ 1.회로

<img width="357" height="241" alt="002" src="https://github.com/user-attachments/assets/e3528fc4-6645-4929-b022-2307864cf76e" />
<br>
<img width="608" height="186" alt="003" src="https://github.com/user-attachments/assets/e3575f39-af0e-401a-8ddc-dfcf0dacb800" />
<br>

---
https://cookierobotics.com/042/

<img width="284" height="185" alt="001" src="https://github.com/user-attachments/assets/a0466c38-e394-4f88-85ea-c284e5b2f055" />
<img width="384" height="185" alt="002" src="https://github.com/user-attachments/assets/1b102543-878c-488b-a975-708d9e810989" />
<br>
<img width="296" height="134" alt="003" src="https://github.com/user-attachments/assets/c6bcccd2-034f-4bcf-b247-cc0b3bcb0c4e" />
<img width="292" height="201" alt="004" src="https://github.com/user-attachments/assets/471f5e82-0914-4f7d-a2f8-f7d2527c72af" />
<br>

---

### ⚙️ 2. Full-Step (풀스텝) 구동

한 번에 두 코일씩(예: A + B, B + C, C + D, D + A) 에 전류를 흘립니다.

|스텝 순서	|코일 상태	|출력 비트 (A,B,C,D)|
|:----:|:----:|:----:|
|1	|A+B	|1100|
|2	|B+C	|0110|
|3	|C+D	|0011|
|4	|D+A	|1001|

* 특징
  * ✅ 장점
     * 두 코일이 동시에 자력을 내므로 토크가 크다.
     * 단순한 제어(4패턴).
   * ⚠️ 단점
     * 스텝 각도가 큼 → 해상도 낮음.
     * 진동이 커서 소음이 날 수 있음.

* 28BYJ-48의 풀스텝 모터 기준 기계적 스텝각 ≈ 11.25°,
* 기어비(64:1) 적용 시 출력축 1스텝 ≈ 0.1758°

### ⚙️ 3. Half-Step (하프스텝) 구동

* 한 코일만 켜는 스텝과 두 코일을 동시에 켜는 스텝을 교대로 실행합니다.

|스텝 순서	|코일 상태	|출력 비트 (A,B,C,D)|
|:----:|:----:|:----:|
|1	|A	|1000|
|2	|A+B	|1100|
|3	|B	|0100|
|4	|B+C	|0110|
|5	|C	|0010|
|6	|C+D	|0011|
|7	|D	|0001|
|8	|D+A	|1001|

* 특징
   * ✅ 장점
      * 스텝 해상도 2배 증가 (Full-Step의 절반 각도).
      * 움직임이 부드럽고 진동 적음.
    * ⚠️ 단점
      * 단일 코일 구간에서는 토크가 조금 떨어짐.
      * 제어가 약간 복잡(8패턴).

* 28BYJ-48의 하프스텝 스텝각 ≈ 5.625°,
* 기어비(64:1) 적용 시 출력축 1스텝 ≈ 0.0879°

### 🧩 디바운스

* 1)카운트 기준 계산 → 2)입력 신호 동기화 (메타스테이블 방지) → 3)안정 상태 판정 로직

* 🔍 동작 예시 (파형으로 이해)

| 시간	|din (입력)	|din_q2 (동기화)|	cnt	|dout (출력)	|설명|
|:---:|:---:|:---:|:---:|:---:|:---:| 
| t0	|0	|0	|0	|0	|초기 상태|
| t1	|1	|1	|↑	|0	|입력이 변해서 카운트 시작|
| t2~t3	|1	|1	|→ CNT_MAX 도달|	0→1|	10ms 이상 유지 → 출력 반영|
| t4	|1→0 (노이즈)	|0	|리셋	|1	|노이즈 순간은 무시됨|
| t5	|0	|0	|↑	|1	|10ms 이상 유지 시 다음 반전 허용|

### ⚙️ 4. 타이밍 설정 팁
| 목표	| 설정 예시| 
|:---:|:---:| 
| 버튼	| 10~20ms| 
| 토글 스위치	| 5~10ms| 
| 리셋 신호	| 1ms 이하 (빠르게 반응)|   

</details>

---

## 1. Vivado에서 하드웨어 설계 (Windows)

<details>
<summary>펼치기/접기 **개발환경** </summary>  

Zybo Z7-020에서 PL(Programmable Logic) 영역의 GPIO를 사용하여 stepmotor 를 제어하는 전체 프로세스를 단계별로 설명합니다.

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


---


## 1️⃣ GPIO 이용해서 stepmotor제어 Vivado에서 하드웨어 설계 (Windows)

### 1.1 새 프로젝트 생성

1. Vivado 2022.2 실행
2. "Create Project" 클릭
3. 프로젝트 이름: `stepmotor`
4. 프로젝트 위치 지정
5. "RTL Project" 선택, "Do not specify sources at this time" 체크
6. Board 선택: **Digilent Zybo Z7-20** 선택
   - 보드가 목록에 없으면 [Digilent Board Files](https://github.com/Digilent/vivado-boards) 설치 필요

### 1.2 Block Design 생성

1. "Create Block Design" 클릭
2. Design 이름: `stepper`


### 1.3 IP 추가 및 연결

#### Step 0: zybo_z720_stepper_top IP로 만들기

add source  
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
2. clk는 zynq의 fclk_clk1 125Mhz 만들어서 연결 (혹은 새로 하나 만들어서 125M로 설정가능)  
  

#### Step 5:  stepmotor 포트를 외부로 연결
1. stepmotor IP 포트를 우클릭
2. "Make External" 선택
3. 생성된 포트 이름: `coils` (또는 유사한 이름)

<br>

<img width="995" height="484" alt="002" src="https://github.com/user-attachments/assets/a9de87aa-6fda-4716-ac66-10f6feb62b9b" />
<br>
입력을 한번에 받아서 zybo-z720-stepper-top-0모듈 내부 verilog 코드에서 4개로 나누어서 할당해줌
<br>
<img width="1461" height="500" alt="001" src="https://github.com/user-attachments/assets/280f59ff-1195-457e-b728-81e9364a7c7e" />
<br>
이렇게 4개를 나눠서 받아주면 정상작동 안함 xslice해서 나누어서 받거나 하나로 받아서 내부에서 나눠주거나 해야함
<br>
<img width="1209" height="448" alt="image" src="https://github.com/user-attachments/assets/f984f7b9-f1d6-4de9-acf7-f99a6b0d21b6" />
<br>


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

</details>

  
## 2️⃣ PetaLinux 프로젝트 생성 (Ubuntu 22.04)

<details>
<summary>펼치기/접기 **개발환경** </summary>  

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


</details>  

## 3. shell script로 제어,  C파일을 arm용으로 컴파일 해서 제어


<details>  
   
<summary>펼치기/접기 **개발환경** </summary>  



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

그러면 GPIO 번호는 **496, 497, 498, 499**입니다

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

## 3.3 C파일을 arm용으로 컴파일 해서 제어

### stepctl.c (ARM Compile)

```
arm-linux-gnueabihf-gcc -o stepctl stepctl.c
//arm용으로 컵파일 우분투에서 그다음 share 폴더에 컴파일된 stepctl 복사  
terater으로 ZMODEM으로 수신후에 chmod 설정후 실행  
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
arm-linux-gnueabihf-gcc -o stepctl stepctl.c
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

</details>


---

=============================================================
# 4. AXI4 Peripheral IP 생성 과정
=============================================================  

<details>
<summary>펼치기/접기 **오류 참조용 다시 할거임** </summary>  


<img width="1154" height="452" alt="006" src="https://github.com/user-attachments/assets/40d6decf-b090-468d-95ad-401d186e5da3" />

### 1. Create and Package New IP 시작
Vivado에서 프로젝트 만든후 : ip만들기 위한 add source

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
`timescale 1 ns / 1 ps

module stepper_motor_ctrl_v1_0_S00_AXI #
(
    // Users to add parameters here
    parameter integer CLK_HZ = 125_000_000,
    // User parameters ends
    // Do not modify the parameters beyond this line

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    // Users to add ports here
    output wire [3:0] coils_out,
    // User ports ends
    // Do not modify the ports beyond this line

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input wire  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output wire  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave) 
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.    
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire  S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output wire  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input wire  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output wire  S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output wire  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire  S_AXI_RREADY
);

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg     axi_awready;
    reg     axi_wready;
    reg [1 : 0]     axi_bresp;
    reg     axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg     axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
    reg [1 : 0]     axi_rresp;
    reg     axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 1;
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    //-- Number of Slave Registers 4
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg0;  // Control Register
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg1;  // Status Register (read-only)
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg2;  // Speed Register
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg3;  // Reserved
    wire     slv_reg_rden;
    wire     slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0]     reg_data_out;
    integer  byte_index;
    reg  aw_en;

    // I/O Connections assignments

    assign S_AXI_AWREADY    = axi_awready;
    assign S_AXI_WREADY = axi_wready;
    assign S_AXI_BRESP  = axi_bresp;
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_ARREADY    = axi_arready;
    assign S_AXI_RDATA  = axi_rdata;
    assign S_AXI_RRESP  = axi_rresp;
    assign S_AXI_RVALID = axi_rvalid;
    
    // Implement axi_awready generation
    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awready <= 1'b0;
          aw_en <= 1'b1;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              axi_awready <= 1'b1;
              aw_en <= 1'b0;
            end
            else if (S_AXI_BREADY && axi_bvalid)
                begin
                  aw_en <= 1'b1;
                  axi_awready <= 1'b0;
                end
          else           
            begin
              axi_awready <= 1'b0;
            end
        end 
    end       

    // Implement axi_awaddr latching
    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awaddr <= 0;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              axi_awaddr <= S_AXI_AWADDR;
            end
        end 
    end       

    // Implement axi_wready generation
    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_wready <= 1'b0;
        end 
      else
        begin    
          if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
            begin
              axi_wready <= 1'b1;
            end
          else
            begin
              axi_wready <= 1'b0;
            end
        end 
    end       

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          slv_reg0 <= 0;
          slv_reg1 <= 0;
          slv_reg2 <= 600;  // Default speed: 600 steps/sec
          slv_reg3 <= 0;
        end 
      else begin
        if (slv_reg_wren)
          begin
            case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
              2'h0:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              2'h1:
                // slv_reg1 is read-only (status register updated by hardware)
                slv_reg1 <= slv_reg1;
              2'h2:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              2'h3:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              default : begin
                          slv_reg0 <= slv_reg0;
                          slv_reg1 <= slv_reg1;
                          slv_reg2 <= slv_reg2;
                          slv_reg3 <= slv_reg3;
                        end
            endcase
          end
      end
    end    

    // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_bvalid  <= 0;
          axi_bresp   <= 2'b0;
        end 
      else
        begin    
          if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
            begin
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b0; // 'OKAY' response 
            end                   // work error responses in future
          else
            begin
              if (S_AXI_BREADY && axi_bvalid) 
                begin
                  axi_bvalid <= 1'b0; 
                end  
            end
        end
    end   

    // Implement axi_arready generation
    // axi_arready is asserted for one S_AXI_ACLK clock cycle when
    // S_AXI_ARVALID is asserted. axi_awready is 
    // de-asserted when reset (active low) is asserted. 
    // The read address is also latched when S_AXI_ARVALID is 
    // asserted. axi_araddr is reset to zero on reset assertion.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_arready <= 1'b0;
          axi_araddr  <= 32'b0;
        end 
      else
        begin    
          if (~axi_arready && S_AXI_ARVALID)
            begin
              axi_arready <= 1'b1;
              axi_araddr  <= S_AXI_ARADDR;
            end
          else
            begin
              axi_arready <= 1'b0;
            end
        end 
    end       

    // Implement axi_arvalid generation
    // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
    // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
    // data are available on the axi_rdata bus at this instance. The 
    // assertion of axi_rvalid marks the validity of read data on the 
    // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
    // is deasserted on reset (active low). axi_rresp and axi_rdata are 
    // cleared to zero on reset (active low).  
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rvalid <= 0;
          axi_rresp  <= 0;
        end 
      else
        begin    
          if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
            begin
              axi_rvalid <= 1'b1;
              axi_rresp  <= 2'b0; // 'OKAY' response
            end   
          else if (axi_rvalid && S_AXI_RREADY)
            begin
              axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    
    always @(*)
    begin
          // Address decoding for reading registers
          case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            2'h0   : reg_data_out <= slv_reg0;
            2'h1   : reg_data_out <= slv_reg1;
            2'h2   : reg_data_out <= slv_reg2;
            2'h3   : reg_data_out <= slv_reg3;
            default : reg_data_out <= 0;
          endcase
    end

    // Output register or memory read data
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rdata  <= 0;
        end 
      else
        begin    
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;
            end   
        end
    end    

    // ============================================================
    // Add user logic here
    // ============================================================
    
    // Register Map:
    // 0x00: Control Register
    //       [0] - motor_run (1=run, 0=stop)
    //       [1] - motor_dir (1=CW, 0=CCW)
    //       [2] - half_full (1=half-step, 0=full-step)
    // 0x04: Status Register (read-only)
    //       [3:0] - coils output state
    // 0x08: Speed Register (future use)
    // 0x0C: Reserved
    
    // Extract control signals directly from AXI registers
    wire motor_run    = slv_reg0[1];
    wire motor_dir    = slv_reg0[2];
    wire half_full    = slv_reg0[3];
    
    // Build input signal for stepper controller
    wire [3:0] in_signal = {half_full, motor_dir, motor_run, S_AXI_ARESETN};
    
    // Instantiate stepper motor controller
    zybo_z720_stepper_top #(
        .CLK_HZ(CLK_HZ),
        .STEPS_PER_SEC(600)
    ) stepper_inst (
        .clk(S_AXI_ACLK),
        .in_signal(in_signal),
        .coils(coils_out)
    );
    
    // Update status register with current coil states
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            slv_reg1 <= 0;
        else
            slv_reg1 <= {28'h0, coils_out};
    end

    // User logic ends

endmodule
```

### 5. Top-level Wrapper 수정
stepper_motor_ctrl_v1_0.v 파일에 외부 포트 추가:
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

    // ��ٿ
    wire run_clean, dir_clean;
    debounce #(.CLK_HZ(CLK_HZ), .MS(10)) u_db_run (
        .clk(clk), .rst_n(rst_n), .din(sw_run), .dout(run_clean)
    );
    debounce #(.CLK_HZ(CLK_HZ), .MS(10)) u_db_dir (
        .clk(clk), .rst_n(rst_n), .din(sw_dir), .dout(dir_clean)
    );

    // ���� Ÿ�̸�
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

    // ���� �ε���
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

    // ������ ROM
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

<!--
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

-->

<img width="1121" height="629" alt="image" src="https://github.com/user-attachments/assets/c99d497f-5045-4dd7-86a7-e74ce80baa5e" />
<br>
업데이트후 repackage하기
<br>

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


</details>





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


</details>
