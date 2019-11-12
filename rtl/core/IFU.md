# IFU

## 1. IFU设计与模块划分





## 2. ifetch

- 功能：产生下条指令的PC，以及产生总线操作请求；
- 本模块内实例化了两个子模块 Mini-Decode、Simple-BPU，依次完成预译码、静态分支预测功能；
- 

### 2.1 ifetch说明



#### 2.1.1 输出输出信号说明

### 2.2 Mini-Decode

- 该模块仅需译出部分信息，因而为 mini 译码器，具体需译出信息如下：
  1. 是否是长指令（乘除法、访存）
  2. 是否是分支跳转指令（jal, jalr, beq, bne等）
  3. 直接传出 操作数1、操作数2的寄存器索引， jalr指令的寄存器索引

- 该模块内部通例化调用一个完整的 Decode 模块，但是将其不相关的输入信号接零、输出信号悬空不连接，从而使得综合工具将完整 Decode 模块中无关逻辑优化掉，成为一个 Mini-Decode；

#### 2.2.1 输入输出信号说明

- 输入信号 

```  verilog
input  [`E203_INSTR_SIZE-1:0] instr,  // 32位指令（刚由ITCM或BIU取出，还未存入IR）
```

- 输出信号

```verilog
  output dec_rs1en,       // 是否使用源寄存器1
  output dec_rs2en,       // 是否使用源寄存器2
  output [`E203_RFIDX_WIDTH-1:0] dec_rs1idx,   // 源寄存器1的索引
  output [`E203_RFIDX_WIDTH-1:0] dec_rs2idx,   // 源寄存器2的索引

  output dec_mulhsu,      // 是否是 mulhsu 指令
  output dec_mul   ,      // 是否是 mul 指令
  output dec_div   ,      // 是否是 div 指令
  output dec_rem   ,      // 是否是 rem 指令
  output dec_divu  ,      // 是否是 无符号除法
  output dec_remu  ,      // 是否是 remu 指令

  // output dec_rv32,     // 指令皆为32位
  output dec_bjp,         // 是否是 条件跳转指令
  output dec_jal,         // 是否是 jal
  output dec_jalr,        // 是否是 jalr
  output dec_bxx,         // 是否是 其它的分支跳转指令
  output [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,     // jalr 使用的基地址寄存器索引
  output [`E203_XLEN-1:0] dec_bjp_imm                 // 由12位或20位立即数零扩展得到的32位立即数
```

### 2.3 Simple-BPU

- 该模块的功能是：对Mini-Decode发现的条件跳转指令进行分支预测；
- 该模块采用静态分支预测策略；

#### 2.3.1 输入输出信号说明

- 输入信号

```verilog
  input  [`E203_PC_SIZE-1:0] pc,                  // 当前的 PC

  input  dec_i_valid,                             // 指令是否合法
	
  // The mini-decoded info 
  input  dec_jal,                                 // 是否是 jal 指令
  input  dec_jalr,                                // 是否是 jalr 指令
  input  dec_bxx,                                 // 是否是 条件跳转指令
  input  [`E203_XLEN-1:0] dec_bjp_imm,            // 零扩展得到的32位立即数表示的偏移量
  input  [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx, // jalr 使用的基地址寄存器索引

  // The IR index and status to be used for checking dependency
  input  ir_empty,                                // IR 是否为空（是否有指令处于EXU）
  input  ir_rs1en,                                // IR 是否使用 rs1读端口
  input  jalr_rs1idx_cam_irrdidx,                 // 处于 IR 的指令的写回目标寄存器索引是否为xx1
  input  ir_valid_clr,                            // IR 正处于 clear
  input  [`E203_XLEN-1:0] rf2bpu_x1,              // 寄存器x1的数据 直接拉出（x1常被用为link寄存器，因而做特别加速）
input  [`E203_XLEN-1:0] rf2bpu_rs1,             // 其它寄存器的数据，统一从寄存器读端口1 读出


  input  clk,
  input  rst_n
```

- 输出信号

```verilog
 // The add op to next-pc adder
  output bpu_wait,                                // bpu 是否处于 wait
  output prdt_taken,                              // 是否采取分支预测
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,     // 分支预测的 op1
  output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,     // 分支预测的 op2

  output bpu2rf_rs1_ena,                          // 寄存器读端口1 的使能
```

## 3. ift2icb

​	