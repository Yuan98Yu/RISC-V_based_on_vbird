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
                                                                         
                                                                         
                                                                         
//=====================================================================
//
// Designer   : Bob Hu
//
// Description:
//  The IFU to implement entire instruction fetch unit.
//
// ====================================================================
`include "e203_defines.v"

module e203_ifu(
  output[`E203_PC_SIZE-1:0] inspect_pc,		// 下一条指令的 PC
  output ifu_active,						// IFU 是否在工作，永真
  input  itcm_nohold,						// 来源存疑，用于判断 ITCM 的输出值是否不变

  input  [`E203_PC_SIZE-1:0] pc_rtvec,  	// reset 指定的 PC
  `ifdef E203_HAS_ITCM //{
  input  ifu2itcm_holdup,							// ITCM 的输出值是否保持不变
  input [`E203_ADDR_SIZE-1:0] itcm_region_indic,	// ITCM地址范围

  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // 对 ITCM 的总线接口，ICB 协议
  //    * Bus cmd channel
  output ifu2itcm_icb_cmd_valid, // Handshake valid
  input  ifu2itcm_icb_cmd_ready, // Handshake ready
            // Note: The data on rdata or wdata channel must be naturally
            //       aligned, this is in line with the AXI definition
  output [`E203_ITCM_ADDR_WIDTH-1:0]   ifu2itcm_icb_cmd_addr,	// 总线访问地址

  //    * Bus RSP channel
  input  ifu2itcm_icb_rsp_valid, // Response valid 
  output ifu2itcm_icb_rsp_ready, // Response ready
  input  ifu2itcm_icb_rsp_err,   // Response error
            // Note: the RSP rdata is inline with AXI definition
  input  [`E203_ITCM_DATA_WIDTH-1:0] ifu2itcm_icb_rsp_rdata,	// 取得的数据（一个 lane）
  `endif//}

  `ifdef E203_HAS_MEM_ITF //{
  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // 对 BIU 的总线接口，ICB 协议
  //    * Bus cmd channel
  output ifu2biu_icb_cmd_valid, // Handshake valid
  input  ifu2biu_icb_cmd_ready, // Handshake ready
            // Note: The data on rdata or wdata channel must be naturally
            //       aligned, this is in line with the AXI definition
  output [`E203_ADDR_SIZE-1:0]   ifu2biu_icb_cmd_addr, 		  // 总线访问地址

  //    * Bus RSP channel
  input  ifu2biu_icb_rsp_valid, // Response valid 
  output ifu2biu_icb_rsp_ready, // Response ready
  input  ifu2biu_icb_rsp_err,   // Response error
            // Note: the RSP rdata is inline with AXI definition
  input  [`E203_SYSMEM_DATA_WIDTH-1:0] ifu2biu_icb_rsp_rdata, // 取得的数据

  `endif//}

  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // 对 EXU 的接口，包含 IR 和对应指令的 PC 及其它信息
  output [`E203_INSTR_SIZE-1:0] ifu_o_ir,// The instruction register
  output [`E203_PC_SIZE-1:0] ifu_o_pc,   // The PC register along with
  output ifu_o_pc_vld,
  output ifu_o_misalgn,                  // The fetch misalign 
  output ifu_o_buserr,                   // The fetch bus error
  output [`E203_RFIDX_WIDTH-1:0] ifu_o_rs1idx,
  output [`E203_RFIDX_WIDTH-1:0] ifu_o_rs2idx,
  output ifu_o_prdt_taken,               // The Bxx is predicted as taken
  output ifu_o_muldiv_b2b,               
  output ifu_o_valid, // Handshake signals with EXU stage
  input  ifu_o_ready,

  // 处理 流水线冲刷
  output  pipe_flush_ack,
  input   pipe_flush_req,
  input   [`E203_PC_SIZE-1:0] pipe_flush_add_op1,  
  input   [`E203_PC_SIZE-1:0] pipe_flush_add_op2,
  `ifdef E203_TIMING_BOOST//}
  input   [`E203_PC_SIZE-1:0] pipe_flush_pc,  
  `endif//}

  // 来源存疑，用于停止 IFU 取新的指令而只处理正在处理的指令，当 IFU 对当前指令处理完成时 通过 ifu_halt_ack 响应
  input  ifu_halt_req,
  output ifu_halt_ack,

  无 OITF
  input  oitf_empty,
  // RF 的状态，上条指令的类型
  input  [`E203_XLEN-1:0] rf2ifu_x1,
  input  [`E203_XLEN-1:0] rf2ifu_rs1,
  input  dec2ifu_rden,
  input  dec2ifu_rs1en,
  input  [`E203_RFIDX_WIDTH-1:0] dec2ifu_rdidx,
  input  dec2ifu_mulhsu,
  input  dec2ifu_div   ,
  input  dec2ifu_rem   ,
  input  dec2ifu_divu  ,
  input  dec2ifu_remu  ,

  input  clk,
  input  rst_n
  );

  
  wire ifu_req_valid; 
  wire ifu_req_ready; 
  wire [`E203_PC_SIZE-1:0]   ifu_req_pc; 
  wire ifu_req_seq;
  wire ifu_req_seq_rv32;
  wire [`E203_PC_SIZE-1:0] ifu_req_last_pc;
  wire ifu_rsp_valid; 
  wire ifu_rsp_ready; 
  wire ifu_rsp_err;   
  //wire ifu_rsp_replay;   
  wire [`E203_INSTR_SIZE-1:0] ifu_rsp_instr; 

  e203_ifu_ifetch u_e203_ifu_ifetch(
    .inspect_pc   (inspect_pc),
    .pc_rtvec      (pc_rtvec),  
    .ifu_req_valid (ifu_req_valid),
    .ifu_req_ready (ifu_req_ready),
    .ifu_req_pc    (ifu_req_pc   ),
    .ifu_req_seq     (ifu_req_seq     ),
    .ifu_req_seq_rv32(ifu_req_seq_rv32),
    .ifu_req_last_pc (ifu_req_last_pc ),
    .ifu_rsp_valid (ifu_rsp_valid),
    .ifu_rsp_ready (ifu_rsp_ready),
    .ifu_rsp_err   (ifu_rsp_err  ),
    .ifu_rsp_instr (ifu_rsp_instr),
    .ifu_o_ir      (ifu_o_ir     ),
    .ifu_o_pc      (ifu_o_pc     ),
    .ifu_o_pc_vld  (ifu_o_pc_vld ),
    .ifu_o_misalgn (ifu_o_misalgn),
    .ifu_o_buserr  (ifu_o_buserr ),
    .ifu_o_rs1idx  (ifu_o_rs1idx),
    .ifu_o_rs2idx  (ifu_o_rs2idx),
    .ifu_o_prdt_taken(ifu_o_prdt_taken),
    .ifu_o_muldiv_b2b(ifu_o_muldiv_b2b),
    .ifu_o_valid   (ifu_o_valid  ),
    .ifu_o_ready   (ifu_o_ready  ),
    .pipe_flush_ack     (pipe_flush_ack    ), 
    .pipe_flush_req     (pipe_flush_req    ),
    .pipe_flush_add_op1 (pipe_flush_add_op1),     
  `ifdef E203_TIMING_BOOST//}
    .pipe_flush_pc      (pipe_flush_pc),  
  `endif//}
    .pipe_flush_add_op2 (pipe_flush_add_op2), 
    .ifu_halt_req  (ifu_halt_req ),
    .ifu_halt_ack  (ifu_halt_ack ),

    .oitf_empty    (oitf_empty   ),
	// 上一条指令的译码信息
    .rf2ifu_x1     (rf2ifu_x1    ),
    .rf2ifu_rs1    (rf2ifu_rs1   ),
    .dec2ifu_rden  (dec2ifu_rden ),
    .dec2ifu_rs1en (dec2ifu_rs1en),
    .dec2ifu_rdidx (dec2ifu_rdidx),
    .dec2ifu_mulhsu(dec2ifu_mulhsu),
    .dec2ifu_div   (dec2ifu_div   ),
    .dec2ifu_rem   (dec2ifu_rem   ),
    .dec2ifu_divu  (dec2ifu_divu  ),
    .dec2ifu_remu  (dec2ifu_remu  ),

    .clk           (clk          ),
    .rst_n         (rst_n        ) 
  );



  e203_ifu_ift2icb u_e203_ifu_ift2icb (
    .ifu_req_valid (ifu_req_valid),
    .ifu_req_ready (ifu_req_ready),
    .ifu_req_pc    (ifu_req_pc   ),
    .ifu_req_seq     (ifu_req_seq     ),
    .ifu_req_seq_rv32(ifu_req_seq_rv32),
    .ifu_req_last_pc (ifu_req_last_pc ),
    .ifu_rsp_valid (ifu_rsp_valid),
    .ifu_rsp_ready (ifu_rsp_ready),
    .ifu_rsp_err   (ifu_rsp_err  ),
    .ifu_rsp_instr (ifu_rsp_instr),
    .itcm_nohold   (itcm_nohold),

  `ifdef E203_HAS_ITCM //{
    .itcm_region_indic (itcm_region_indic),
    .ifu2itcm_icb_cmd_valid(ifu2itcm_icb_cmd_valid),
    .ifu2itcm_icb_cmd_ready(ifu2itcm_icb_cmd_ready),
    .ifu2itcm_icb_cmd_addr (ifu2itcm_icb_cmd_addr ),
    .ifu2itcm_icb_rsp_valid(ifu2itcm_icb_rsp_valid),
    .ifu2itcm_icb_rsp_ready(ifu2itcm_icb_rsp_ready),
    .ifu2itcm_icb_rsp_err  (ifu2itcm_icb_rsp_err  ),
    .ifu2itcm_icb_rsp_rdata(ifu2itcm_icb_rsp_rdata),
  `endif//}


  `ifdef E203_HAS_MEM_ITF //{
    .ifu2biu_icb_cmd_valid(ifu2biu_icb_cmd_valid),
    .ifu2biu_icb_cmd_ready(ifu2biu_icb_cmd_ready),
    .ifu2biu_icb_cmd_addr (ifu2biu_icb_cmd_addr ),
    .ifu2biu_icb_rsp_valid(ifu2biu_icb_rsp_valid),
    .ifu2biu_icb_rsp_ready(ifu2biu_icb_rsp_ready),
    .ifu2biu_icb_rsp_err  (ifu2biu_icb_rsp_err  ),
    .ifu2biu_icb_rsp_rdata(ifu2biu_icb_rsp_rdata),
  `endif//}

  `ifdef E203_HAS_ITCM //{
    .ifu2itcm_holdup (ifu2itcm_holdup),
  `endif//}

    .clk           (clk          ),
    .rst_n         (rst_n        ) 
  );

  assign ifu_active = 1'b1;// Seems the IFU never rest at block level
  
endmodule

