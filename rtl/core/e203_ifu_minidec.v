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
//  The mini-decode module to decode the instruction in IFU
//
// ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == 
`include "e203_defines.v"

module e203_ifu_minidec(input [`E203_INSTR_SIZE-1:0] instr,             // 32位指令（刚由ITCM或BIU取出，还未存入 IR
                        output dec_rs1en,                               // 是否使用源寄存器1
                        output dec_rs2en,                               // 是否使用源寄存器2
                        output [`E203_RFIDX_WIDTH-1:0] dec_rs1idx,      // 源寄存器1的索索引
                        output [`E203_RFIDX_WIDTH-1:0] dec_rs2idx,      // 源寄存器2的索索引
                        output dec_mulhsu,                              // 是否是 mulhsu 指令
                        output dec_mul,                                 // 是否是 mul 指令
                        output dec_div,                                 // 是否是 div 指令
                        output dec_rem,                                 // 是否是 rem 指令
                        output dec_divu,                                // 是否是 无符号除法
                        output dec_remu,                                // 是否是 remu 指令
                        output dec_bjp,                                 // 是否是 条件跳转指令
                        output dec_jal,                                 // 是否是 jal
                        output dec_jalr,                                // 是否是 jalr
                        output dec_bxx,                                 // 是否是 其它的分支跳转指令
                        output [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx, // jalr 使用的基地址寄存器索索引
                        output [`E203_XLEN-1:0] dec_bjp_imm);           // 由指令中的12位或20位立即数零扩展得到的32位立即数
    
    e203_exu_decode u_e203_exu_decode(
    
    .i_instr(instr),
    .i_pc(`E203_PC_SIZE'b0),
    .i_prdt_taken(1'b0),
    .i_muldiv_b2b(1'b0),
    
    .i_misalgn (1'b0),
    .i_buserr  (1'b0),
    
    .dbg_mode  (1'b0),
    
    .dec_misalgn(),
    .dec_buserr(),
    .dec_ilegl(),
    
    .dec_rs1x0(),
    .dec_rs2x0(),
    .dec_rs1en(dec_rs1en),
    .dec_rs2en(dec_rs2en),
    .dec_rdwen(),
    .dec_rs1idx(dec_rs1idx),
    .dec_rs2idx(dec_rs2idx),
    .dec_rdidx(),
    .dec_info(),
    .dec_imm(),
    .dec_pc(),
    
    
    .dec_mulhsu(dec_mulhsu),
    .dec_mul   (dec_mul),
    .dec_div   (dec_div),
    .dec_rem   (dec_rem),
    .dec_divu  (dec_divu),
    .dec_remu  (dec_remu),
    
    .dec_rv32(),
    .dec_bjp (dec_bjp),
    .dec_jal (dec_jal),
    .dec_jalr(dec_jalr),
    .dec_bxx (dec_bxx),
    
    .dec_jalr_rs1idx(dec_jalr_rs1idx),
    .dec_bjp_imm    (dec_bjp_imm)
    );
    
    
endmodule
