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
//  The ift2icb module convert the fetch request to ICB (Internal Chip bus) 
//  and dispatch to different targets including ITCM, ICache or Sys-MEM.
//
// ====================================================================
`include "e203_defines.v"

module e203_ifu_ift2icb(


  input  itcm_nohold,
  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // 访问存储系统（包括 ITCM 和 System Memory）的通用信号, 内部协议
  //    * IFetch REQ channel
  input  ifu_req_valid, // Handshake valid
  output ifu_req_ready, // Handshake ready
            // Note: the req-addr can be unaligned with the length indicated
            //       by req_len signal.
            //       The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
            //       will handle the unalign cases and split-and-merge works
  input  [`E203_PC_SIZE-1:0] ifu_req_pc, // Fetch PC
  input  ifu_req_seq, // This request is a sequential instruction fetch
  input  ifu_req_seq_rv32, // This request is incremented 32bits fetch
  input  [`E203_PC_SIZE-1:0] ifu_req_last_pc, // The last accessed
                                           // PC address (i.e., pc_r)
                             
  //    * IFetch RSP channel
  output ifu_rsp_valid, // Response valid 
  input  ifu_rsp_ready, // Response ready
  output ifu_rsp_err,   // Response error
            // Note: the RSP channel always return a valid instruction
            //   fetched from the fetching start PC address.
            //   The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
            //   will handle the unalign cases and split-and-merge works
  output [32-1:0] ifu_rsp_instr, // Response instruction


// 访问 ITCM 的 ICB 接口
  `ifdef E203_HAS_ITCM //{
  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // ITCM 地址范围
  input [`E203_ADDR_SIZE-1:0] itcm_region_indic,
  // 对 ITCM 的总线接口, ICB 协议
  //    * Bus cmd channel
  output ifu2itcm_icb_cmd_valid, // Handshake valid
  input  ifu2itcm_icb_cmd_ready, // Handshake ready
            // Note: The data on rdata or wdata channel must be naturally
            //       aligned, this is in line with the AXI definition
  output [`E203_ITCM_ADDR_WIDTH-1:0]   ifu2itcm_icb_cmd_addr, // Bus transaction start addr 

  //    * Bus RSP channel
  input  ifu2itcm_icb_rsp_valid, // Response valid 
  output ifu2itcm_icb_rsp_ready, // Response ready
  input  ifu2itcm_icb_rsp_err,   // Response error
            // Note: the RSP rdata is inline with AXI definition
  input  [`E203_ITCM_DATA_WIDTH-1:0] ifu2itcm_icb_rsp_rdata, 

  `endif//}


// 访问 BIU 的 ICB 接口
  `ifdef E203_HAS_MEM_ITF //{
  //////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////
  // 对 System Memory(通过BIU间接访问) 的总线接口
  //    * Bus cmd channel
  output ifu2biu_icb_cmd_valid, // Handshake valid
  input  ifu2biu_icb_cmd_ready, // Handshake ready
            // Note: The data on rdata or wdata channel must be naturally
            //       aligned, this is in line with the AXI definition
  output [`E203_ADDR_SIZE-1:0]   ifu2biu_icb_cmd_addr, // Bus transaction start addr 

  //    * Bus RSP channel
  input  ifu2biu_icb_rsp_valid, // Response valid 
  output ifu2biu_icb_rsp_ready, // Response ready
  input  ifu2biu_icb_rsp_err,   // Response error
            // Note: the RSP rdata is inline with AXI definition
  input  [`E203_SYSMEM_DATA_WIDTH-1:0] ifu2biu_icb_rsp_rdata, 
  
  //input  ifu2biu_replay,
  `endif//}


  // The holdup indicating the target is not accessed by other agents 
  // since last accessed by IFU, and the output of it is holding up
  // last value. 
  `ifdef E203_HAS_ITCM //{
  input  itcm2ifu_holdup,
  //input  ifu2itcm_replay,
  `endif//}

  input  clk,
  input  rst_n
  );


// 无存储系统
`ifndef E203_HAS_ITCM
  `ifndef E203_HAS_MEM_ITF
    !!! ERROR: There is no ITCM and no System interface, where to fetch the instructions? must be wrong configuration.
  `endif//}
`endif//}


/////////////////////////////////////////////////////////
// We need to instante this bypbuf for several reasons:
//   * The IR stage ready signal is generated from EXU stage which 
//      incoperated several timing critical source (e.g., ECC error check, .etc)
//      and this ready signal will be back-pressure to ifetch rsponse channel here
//   * If there is no such bypbuf, the ifetch response channel may stuck waiting
//      the IR stage to be cleared, and this may end up with a deadlock, becuase 
//      EXU stage may access the BIU or ITCM and they are waiting the IFU to accept
//      last instruction access to make way of BIU and ITCM for LSU to access
  wire i_ifu_rsp_valid;
  wire i_ifu_rsp_ready;
  wire i_ifu_rsp_err;
  wire [`E203_INSTR_SIZE-1:0] i_ifu_rsp_instr;
  wire [`E203_INSTR_SIZE+1-1:0]ifu_rsp_bypbuf_i_data;
  wire [`E203_INSTR_SIZE+1-1:0]ifu_rsp_bypbuf_o_data;

  assign ifu_rsp_bypbuf_i_data = {
                          i_ifu_rsp_err,
                          i_ifu_rsp_instr
                          };

  assign {
                          ifu_rsp_err,
                          ifu_rsp_instr
                          } = ifu_rsp_bypbuf_o_data;

  sirv_gnrl_bypbuf # (
    .DP(1),
    .DW(`E203_INSTR_SIZE+1) 
  ) u_e203_ifetch_rsp_bypbuf(
      .i_vld   (i_ifu_rsp_valid),
      .i_rdy   (i_ifu_rsp_ready),

      .o_vld   (ifu_rsp_valid),
      .o_rdy   (ifu_rsp_ready),

      .i_dat   (ifu_rsp_bypbuf_i_data),
      .o_dat   (ifu_rsp_bypbuf_o_data),
  
      .clk     (clk  ),
      .rst_n   (rst_n)
  );


  `ifdef E203_HAS_ITCM //{
  wire ifu_req_pc2itcm = (ifu_req_pc[`E203_ITCM_BASE_REGION] == itcm_region_indic[`E203_ITCM_BASE_REGION]); 
  `endif//}

  `ifdef E203_HAS_MEM_ITF //{
  wire ifu_req_pc2mem = 1'b1
            `ifdef E203_HAS_ITCM //{
              & ~(ifu_req_pc2itcm)
            `endif//}
              ;
  `endif//}

  // 由于设计的是32位对齐的指令流，不对非对齐情况做处理

  // The current accessing PC is begining of the lane boundry（ ITCM 为64位，其64位输出称为一个 lane ）
  wire ifu_req_lane_begin = 1'b0
                    `ifdef E203_HAS_ITCM //{
                         | (
                            ifu_req_pc2itcm   
                         `ifdef E203_ITCM_DATA_WIDTH_IS_64 //{
                            & (ifu_req_pc[2:1] == 2'b00)
                         `endif//}
                           )
                    `endif//}
                    `ifdef E203_HAS_MEM_ITF //{
                         | (
                            ifu_req_pc2mem   
                         `ifdef E203_SYSMEM_DATA_WIDTH_IS_32 //{
                            & (ifu_req_pc[1] == 1'b0)
                         `endif//}
                         `ifdef E203_SYSMEM_DATA_WIDTH_IS_64 //{
                            & (ifu_req_pc[2:1] == 2'b00)
                         `endif//}
                           )
                    `endif//}
                    ;
  

  // 当前指令是顺序指令 且 不处于 lane 的开头时，由于指令对齐，其必定处于和上一条指令相同的 lane
  wire ifu_req_lane_same = ifu_req_seq & (ifu_req_lane_begin ? 1'b0 : 1'b1);
  
  // ITCM 是否 holdup
  wire ifu_req_lane_holdup = 1'b0
            `ifdef E203_HAS_ITCM //{
            | (ifu_req_pc2itcm & itcm2ifu_holdup & (~itcm_nohold)) 
            `endif//}
            ;

  wire ifu_req_hsked = ifu_req_valid & ifu_req_ready;
  wire i_ifu_rsp_hsked = i_ifu_rsp_valid & i_ifu_rsp_ready;
  wire ifu_icb_cmd_valid;
  wire ifu_icb_cmd_ready;
  wire ifu_icb_cmd_hsked = ifu_icb_cmd_valid & ifu_icb_cmd_ready;
  wire ifu_icb_rsp_valid;
  wire ifu_icb_rsp_ready;
  wire ifu_icb_rsp_hsked = ifu_icb_rsp_valid & ifu_icb_rsp_ready;


  /////////////////////////////////////////////////////////////////////////////////
  // Implement the state machine for the ifetch req interface
  // 不可能需 2 次 ifetch request

  wire req_need_0uop_r;

  // 只有 2 个状态
  localparam ICB_STATE_WIDTH  = 1;
  // State 0: The idle state, means there is no any oustanding ifetch request
  localparam ICB_STATE_IDLE = 2'd0;
  // State 1: Issued first request and wait response
  localparam ICB_STATE_1ST  = 2'd1;
  
  wire [ICB_STATE_WIDTH-1:0] icb_state_nxt;
  wire [ICB_STATE_WIDTH-1:0] icb_state_r;
  wire icb_state_toggle_ena;
  wire [ICB_STATE_WIDTH-1:0] state_idle_nxt   ;
  wire [ICB_STATE_WIDTH-1:0] state_1st_nxt    ;
  // wire [ICB_STATE_WIDTH-1:0] state_wait2nd_nxt;
  // wire [ICB_STATE_WIDTH-1:0] state_2nd_nxt    ;
  wire state_idle_exit_ena     ;
  wire state_1st_exit_ena      ;

  // 判断当前处于的状态
  wire icb_sta_is_idle    = (icb_state_r == ICB_STATE_IDLE   );
  wire icb_sta_is_1st     = (icb_state_r == ICB_STATE_1ST    );

      // **** If the current state is idle,
          // If a new request come, next state is ICB_STATE_1ST
  assign state_idle_exit_ena = icb_sta_is_idle & ifu_req_hsked;
  assign state_idle_nxt      = ICB_STATE_1ST;

      // **** If the current state is 1st,
          // If a response come, exit this state
  assign state_1st_exit_ena  = icb_sta_is_1st & i_ifu_rsp_hsked;
  assign state_1st_nxt     = 
					ifu_req_hsked  ?  ICB_STATE_1ST 
                            		: ICB_STATE_IDLE 
               		;


  // 判断是否可以转换状态
  assign icb_state_toggle_ena = 
            state_idle_exit_ena | state_1st_exit_ena

  // 判断下一个状态
  assign icb_state_nxt = 
              ({ICB_STATE_WIDTH{state_idle_exit_ena   }} & state_idle_nxt   )
            | ({ICB_STATE_WIDTH{state_1st_exit_ena    }} & state_1st_nxt    )
              ;

  sirv_gnrl_dfflr #(ICB_STATE_WIDTH) icb_state_dfflr (icb_state_toggle_ena, icb_state_nxt, icb_state_r, clk, rst_n);

  /////////////////////////////////////////////////////////////////////////////////
  // Save the same_cross_holdup flags for this ifetch request to be used
  // 所有指令对齐，不可能跨 lane

  // 由于指令为32位对齐，不可能出现需跨界读取的情况

  // 当指令在同一个 lane 且 ITCM 的输出没变时，直接使用 ITCM 的输出，而不用重新访问 ITCM。
  wire req_need_0uop         = ifu_req_lane_same & ifu_req_lane_holdup;

  sirv_gnrl_dfflr #(1) req_need_0uop_dfflr         (ifu_req_hsked, req_need_0uop,         req_need_0uop_r,         clk, rst_n);
  /////////////////////////////////////////////////////////////////////////////////
  // 当前 ICB 事务 需用的 flags
  // 当前 PC
  wire [`E203_PC_SIZE-1:0] ifu_icb_cmd_addr;
  `ifdef E203_HAS_ITCM //{
  wire ifu_icb_cmd2itcm;
  wire icb_cmd2itcm_r;
  sirv_gnrl_dfflr #(1) icb2itcm_dfflr(ifu_icb_cmd_hsked, ifu_icb_cmd2itcm, icb_cmd2itcm_r, clk, rst_n);
  `endif//}
  `ifdef E203_HAS_MEM_ITF //{
  wire ifu_icb_cmd2biu ;
  wire icb_cmd2biu_r;
  sirv_gnrl_dfflr #(1) icb2mem_dfflr (ifu_icb_cmd_hsked, ifu_icb_cmd2biu , icb_cmd2biu_r,  clk, rst_n);
  `endif//}
  wire icb_cmd_addr_2_1_ena = ifu_icb_cmd_hsked | ifu_req_hsked;
  wire [1:0] icb_cmd_addr_2_1_r;
  sirv_gnrl_dffl #(2)icb_addr_2_1_dffl(icb_cmd_addr_2_1_ena, ifu_icb_cmd_addr[2:1], icb_cmd_addr_2_1_r, clk);

  // 无需 Leftover Buffer
  
  /////////////////////////////////////////////////////////////////////////////////
  // Generate the ifetch response channel
  // 
  // The ifetch response instr will have 1 source
  //    * Source #1: The rdata-aligned

  // 无需拼接

  // ITCM 和 BIU 分别取出数据
  `ifdef E203_HAS_ITCM //{
  wire[31:0] ifu2itcm_icb_rsp_instr = 
     `ifdef E203_ITCM_DATA_WIDTH_IS_32 //{
                    ifu2itcm_icb_rsp_rdata;
     `else//}{
        `ifdef E203_ITCM_DATA_WIDTH_IS_64
                    ({32{icb_cmd_addr_2_1_r == 2'b00}} & ifu2itcm_icb_rsp_rdata[31: 0]) 
                //   | ({32{icb_cmd_addr_2_1_r == 2'b01}} & ifu2itcm_icb_rsp_rdata[47:16]) 
                  | ({32{icb_cmd_addr_2_1_r == 2'b10}} & ifu2itcm_icb_rsp_rdata[63:32])
                     ;
        `else//}{
            !!! ERROR: There must be something wrong, we dont support the width 
            other than 32bits and 64bits, leave this message to catch this error by 
            compilation message.
        `endif//}
     `endif//}
  `endif//}

  `ifdef E203_HAS_MEM_ITF //{
  wire[31:0] ifu2biu_icb_rsp_instr = 
     `ifdef E203_SYSMEM_DATA_WIDTH_IS_32 //{
                    ifu2biu_icb_rsp_rdata;
     `else//}{
        `ifdef E203_SYSMEM_DATA_WIDTH_IS_64//{
                    ({32{icb_cmd_addr_2_1_r == 2'b00}} & ifu2biu_icb_rsp_rdata[31: 0]) 
                    // ({32{icb_cmd_addr_2_1_r == 2'b01}} & ifu2biu_icb_rsp_rdata[47:16]) 
                    ({32{icb_cmd_addr_2_1_r == 2'b10}} & ifu2biu_icb_rsp_rdata[63:32])
                     ;
        `else//}{
            !!! ERROR: There must be something wrong, we dont support the width 
            other than 32bits and 64bits, leave this message to catch this error by 
            compilation message.
        `endif//}
     `endif//}
  `endif//}

  // 取出的 32 位指令
  wire [32-1:0] ifu_icb_rsp_instr = 32'b0
                     `ifdef E203_HAS_ITCM //{
                       | ({32{icb_cmd2itcm_r}} & ifu2itcm_icb_rsp_instr)
                     `endif//}
                     `ifdef E203_HAS_MEM_ITF //{
                       | ({32{icb_cmd2biu_r}}  & ifu2biu_icb_rsp_instr)
                     `endif//}
                        ;

  wire ifu_icb_rsp_err = 1'b0
                     `ifdef E203_HAS_ITCM //{
                       | (icb_cmd2itcm_r & ifu2itcm_icb_rsp_err)
                     `endif//}
                     `ifdef E203_HAS_MEM_ITF //{
                       | (icb_cmd2biu_r  & ifu2biu_icb_rsp_err)
                     `endif//}
                        ;

  assign i_ifu_rsp_instr = ifu_icb_rsp_instr;
  assign i_ifu_rsp_err = ifu_icb_rsp_err;

            
  // The ifetch response valid will have 2 sources
  //    Source #1: Did not issue ICB CMD request, and just use last holdup values, then
  //               we generate a fake response valid
  wire holdup_gen_fake_rsp_valid = icb_sta_is_1st & req_need_0uop_r;
  //    Source #2: Did issue ICB CMD request, use ICB response valid. 
  // 不可能需2次 ifetch request
  wire ifu_icb_rsp2ir_ready;
  wire ifu_icb_rsp2ir_valid = ifu_icb_rsp_valid;
  assign ifu_icb_rsp_ready  = ifu_icb_rsp2ir_ready;

  assign i_ifu_rsp_valid = holdup_gen_fake_rsp_valid | ifu_icb_rsp2ir_valid;
  assign ifu_icb_rsp2ir_ready = i_ifu_rsp_ready;


  /////////////////////////////////////////////////////////////////////////////////
  // Generate the ICB response channel
  //
  // The ICB response valid to ifetch generated in 1 cases:
  //    * Case #2: The itf need only one uop, and it is in 1ND state response
  assign ifu_icb_rsp_valid = 1'b0
                     `ifdef E203_HAS_ITCM //{
                       | (icb_cmd2itcm_r & ifu2itcm_icb_rsp_valid)
                     `endif//}
                     `ifdef E203_HAS_MEM_ITF //{
                       | (icb_cmd2biu_r  & ifu2biu_icb_rsp_valid)
                     `endif//}
                        ;
 

  /////////////////////////////////////////////////////////////////////////////////
  // Generate the ICB command channel
  //
  // The ICB cmd valid will be generated in 1 case:
  //   * Case #1: When the new ifetch-request is coming, and it is not "need zero 
  //              uops"
  wire ifu_req_valid_pos;
  assign ifu_icb_cmd_valid = 
                  (ifu_req_valid_pos & (~req_need_0uop))
                     
  // The ICB cmd address will be generated in 1 cases:
  //   * Case #1: Use current ifetch address in 1st uop, when 
  wire [`E203_PC_SIZE-1:0] nxtalgn_plus_offset = 
               ifu_req_seq_rv32        ? `E203_PC_SIZE'd6 :
                                         `E203_PC_SIZE'd4;
  // Since we always fetch 32bits
  wire [`E203_PC_SIZE-1:0] icb_algn_nxt_lane_addr = ifu_req_last_pc + nxtalgn_plus_offset;

  assign ifu_icb_cmd_addr = ifu_req_pc;

  /////////////////////////////////////////////////////////////////////////////////
  // Generate the ifetch req channel ready signal
  //
  // Ifu req channel will be ready when the ICB CMD channel is ready and 
  //    * the itf-state is idle
  //    * or only need zero or one uop, and in 1ST state response is backing
  wire ifu_req_ready_condi = 
                (
                    icb_sta_is_idle 
                  | icb_sta_is_1st & i_ifu_rsp_hsked);

  assign ifu_req_ready     = ifu_icb_cmd_ready & ifu_req_ready_condi; 
  assign ifu_req_valid_pos = ifu_req_valid     & ifu_req_ready_condi; // Handshake valid




  ///////////////////////////////////////////////////////
  // 判断访问地址区间是否落在 ITCM 区间（以在 ITCM 和 BIU 间 调度 ICB 信号）
  `ifdef E203_HAS_ITCM //{
  // 是否落在 ITCM区间
  assign ifu_icb_cmd2itcm = (ifu_icb_cmd_addr[`E203_ITCM_BASE_REGION] == itcm_region_indic[`E203_ITCM_BASE_REGION]);
  // 若落在，则修改相应 ICB 信号
  assign ifu2itcm_icb_cmd_valid = ifu_icb_cmd_valid & ifu_icb_cmd2itcm;
  assign ifu2itcm_icb_cmd_addr = ifu_icb_cmd_addr[`E203_ITCM_ADDR_WIDTH-1:0];

  assign ifu2itcm_icb_rsp_ready = ifu_icb_rsp_ready;
  `endif//}

  `ifdef E203_HAS_MEM_ITF //{
  // 若不落在 ITCM 区间，则访问 BIU（修改相应 ICB 信号）
  assign ifu_icb_cmd2biu = 1'b1
            `ifdef E203_HAS_ITCM //{
              & ~(ifu_icb_cmd2itcm)
            `endif//}
              ;
  wire ifu2biu_icb_cmd_valid_pre  = ifu_icb_cmd_valid & ifu_icb_cmd2biu;
  wire [`E203_ADDR_SIZE-1:0]   ifu2biu_icb_cmd_addr_pre = ifu_icb_cmd_addr[`E203_ADDR_SIZE-1:0];

  assign ifu2biu_icb_rsp_ready = ifu_icb_rsp_ready;

  wire ifu2biu_icb_cmd_ready_pre;
  `endif//}

  assign ifu_icb_cmd_ready = 1'b0
    `ifdef E203_HAS_ITCM //{
        | (ifu_icb_cmd2itcm & ifu2itcm_icb_cmd_ready) 
    `endif//}
    `ifdef E203_HAS_MEM_ITF //{
        | (ifu_icb_cmd2biu  & ifu2biu_icb_cmd_ready_pre ) 
    `endif//}
        ;

    `ifdef E203_HAS_MEM_ITF //{
     assign ifu2biu_icb_cmd_addr      = ifu2biu_icb_cmd_addr_pre;
     assign ifu2biu_icb_cmd_valid     = ifu2biu_icb_cmd_valid_pre;
     assign ifu2biu_icb_cmd_ready_pre = ifu2biu_icb_cmd_ready;
    `endif//}


endmodule

