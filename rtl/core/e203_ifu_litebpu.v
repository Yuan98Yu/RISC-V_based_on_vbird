/*
 Copyright 2018 Nuclei System Technology, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */



// ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  = 
// Designer   : Bob Hu
//
// Description:
//  The Lite-BPU module to handle very simple branch predication at IFU
//
// ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == 
`include "e203_defines.v"

module e203_ifu_litebpu(input [`E203_PC_SIZE-1:0] pc,                  // 当前的 PC

						// mini-decoded 输出
                        input dec_jal,                                 // 是否是 jal 指令
                        input dec_jalr,                                // 是否是 jalr 指令
                        input dec_bxx,                                 // 是否是 条件跳转指令
                        input [`E203_XLEN-1:0] dec_bjp_imm,            // 零扩展得到的32位立即数表示的偏移量
                        input [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx, // jalr 使用的基地址寄存器索引

						// IR，无 OITF
						// input  oitf_empty,
                        input ir_empty,                                // IR 是否为空（是否有指令处于EXU）
                        input ir_rs1en,                                // IR 是否使用 rs1读端口
                        input jalr_rs1idx_cam_irrdidx,                 // 处于 IR 的指令的写回目标寄存器索引是否为x1

						// 用于 PC 生成的输出
                        output bpu_wait,                               // bpu 是否处于 wait
                        output prdt_taken,                             // 是否采取分支预测
                        output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,    // 分支预测的 op1
                        output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,    // 分支预测的 op2

						// 读寄存器组（x1 和 读端口1）
						output bpu2rf_rs1_ena,                         // 寄存器读端口1 的使能
                        input ir_valid_clr,                            // IR 正处于 clear
                        input [`E203_XLEN-1:0] rf2bpu_x1,              // 寄存器x1的数据直接拉出（x1常被用为link寄存器，因此做特别加速）
                        input [`E203_XLEN-1:0] rf2bpu_rs1,             // 其它寄存器的数据，统一从寄存器读端口1 读出

						input dec_i_valid,                             // 指令是否合法

						// SoC
                        input clk,
                        input rst_n);
    
    
    // BPU of E201 utilize very simple static branch prediction logics
    //   * JAL: The target address of JAL is calculated based on current PC value
    //          and offset, and JAL is unconditionally always jump
    //   * JALR with rs1 == x0: The target address of JALR is calculated based on
    //          x0+offset, and JALR is unconditionally always jump
    //   * JALR with rs1 = x1: The x1 register value is directly wired from regfile
    //          when the x1 have no dependency with ongoing instructions by checking
    //          two conditions:
    //            ** (1) The OTIF in EXU must be empty
    //            ** (2) The instruction in IR have no x1 as destination register
    //          * If there is dependency, then hold up IFU until the dependency is cleared
    //   * JALR with rs1 ! = x0 or x1: The target address of JALR need to be resolved
    //          at EXU stage, hence have to be forced halted, wait the EXU to be
    //          empty and then read the regfile to grab the value of xN.
    //          This will exert 1 cycle performance lost for JALR instruction
    //   * Bxxx: Conditional branch is always predicted as taken if it is backward
    //          jump, and not-taken if it is forward jump. The target address of JAL
    //          is calculated based on current PC value and offset
    
    // The JAL and JALR is always jump, bxxx backward is predicted as taken
    assign prdt_taken = (dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN-1]));
    // The JALR with rs1 == x1 have dependency or xN have dependency
    wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd0);
    wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd1);
    wire dec_jalr_rs1xn = (~dec_jalr_rs1x0) & (~dec_jalr_rs1x1);
    
    wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & jalr_rs1idx_cam_irrdidx;
    wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn &               ~ir_empty;
    
    // if IR is under clearing, or it does not use RS1 index, then we can also treat it as non-dependency
    wire jalr_rs1xn_dep_ir_clr = (jalr_rs1xn_dep &  (~ir_empty)) & (ir_valid_clr | (~ir_rs1en));
    
    wire rs1xn_rdrf_r;
    wire rs1xn_rdrf_set = (~rs1xn_rdrf_r) & dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~jalr_rs1xn_dep) | jalr_rs1xn_dep_ir_clr);
    wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
    wire rs1xn_rdrf_ena = rs1xn_rdrf_set |   rs1xn_rdrf_clr;
    wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | (~rs1xn_rdrf_clr);
    
    sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena, rs1xn_rdrf_nxt, rs1xn_rdrf_r, clk, rst_n);
    
    assign bpu2rf_rs1_ena = rs1xn_rdrf_set;
    
    assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;
    
    assign prdt_pc_add_op1 = (dec_bxx | dec_jal) ? pc[`E203_PC_SIZE-1:0]
    : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'b0
    : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
    : rf2bpu_rs1[`E203_PC_SIZE-1:0];
    
    assign prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];
    
endmodule
