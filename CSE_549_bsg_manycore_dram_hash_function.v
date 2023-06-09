/**
 *    bsg_manycore_dram_hash_function.
 *
 *    EVA to dram NPA
 */

  // DRAM hash function
  // DRAM space is striped across vcaches at a cache line granularity.
  // Striping starts from the north vcaches, and alternates between north and south from inner layers to outer layers.

  // ungroup this module for synthesis.

`include "bsg_defines.v"

module bsg_manycore_dram_hash_function 
  #(`BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)

    , `BSG_INV_PARAM(x_subcord_width_p)
    , `BSG_INV_PARAM(y_subcord_width_p)

    , `BSG_INV_PARAM(num_vcache_rows_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
  )
  (
    input [data_width_p-1:0] eva_i // 32-bit byte address
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

    , output logic [addr_width_p-1:0] epa_o // word address
    , output logic [x_cord_width_p-1:0] x_cord_o
    , output logic [y_cord_width_p-1:0] y_cord_o
  );

  localparam vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);
  localparam vcache_row_id_width_lp = `BSG_SAFE_CLOG2(2*num_vcache_rows_p);
  localparam dram_index_width_lp = data_width_p-1-2-vcache_word_offset_width_lp-x_subcord_width_p-vcache_row_id_width_lp;

  // UNCOMMENT FOR NORMAL WORKING
  wire [vcache_row_id_width_lp-1:0] vcache_row_id = eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+:vcache_row_id_width_lp];
  
  
  // UNCOMMENT ONLY FOR XCORD + YCORD LSB INVERT
  //wire [vcache_row_id_width_lp-1:0] vcache_row_id = ~eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+:vcache_row_id_width_lp];

  
  wire [x_subcord_width_p-1:0] dram_x_subcord = eva_i[2+vcache_word_offset_width_lp+:x_subcord_width_p];
  wire [y_subcord_width_p-1:0] dram_y_subcord;
  wire [pod_y_cord_width_p-1:0] dram_pod_y_cord = vcache_row_id[0]
    ? pod_y_cord_width_p'(pod_y_i+1)
    : pod_y_cord_width_p'(pod_y_i-1);

  if (num_vcache_rows_p == 1) begin
    assign dram_y_subcord = {y_subcord_width_p{~vcache_row_id[0]}};
  end
  else begin
    assign dram_y_subcord = {
      {(y_subcord_width_p+1-vcache_row_id_width_lp){~vcache_row_id[0]}},
      (vcache_row_id[0]
        ?  vcache_row_id[vcache_row_id_width_lp-1:1]
        : ~vcache_row_id[vcache_row_id_width_lp-1:1])
    };
  end

  wire [dram_index_width_lp-1:0] dram_index = eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+vcache_row_id_width_lp+:dram_index_width_lp];

//////////////////////////////////// UNCOMMENT FOR BSG ORIGINAL HASHING - STARTS ///////////////

/*

  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, dram_x_subcord};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp] // to select the exact set of 16 words or 64 bytes to write
  };

*/

//////////////////////////////////// UNCOMMENT FOR BSG ORIGINAL HASHING - ENDS ///////////////


//////////////////////////////////// XCORD + YCORD LSB INVERT - STARTS ///////////////

/*

  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, dram_x_subcord[3:1], ~dram_x_subcord[0]};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp] 
  };

*/

//////////////////////////////////// XCORD + YCORD LSB INVERT  ENDS ///////////////

/////////////////////////// XCORD HASHED WITH DRAM INDEX STARTS ///////////////////////////////

/*

	wire [3:0] xcord_tmp = dram_x_subcord^dram_index[3:0];
  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, xcord_tmp};

 
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp] 
  };

*/

/////////////////////////// XCORD HASHED WITH DRAM INDEX ENDS ///////////////////////////////


//////////////////////  XXHASH CONSTANTS BASED MATRIX HASHING for XCORD STARTS  ////////////////////

/*

  logic [31:0] PRIME1 = 32'h9E3779B1;
  logic [31:0] PRIME2 = 32'h85EBCA77;
  logic [31:0] PRIME3 = 32'hC2B2AE3D;
  logic [31:0] PRIME4 = 32'h27D4EB2F;  
  logic [3:0] xcord_tmp;
	
  wire [3:0] and_index_1 = dram_index & PRIME1;
  wire [3:0] and_index_2 = dram_index & PRIME2;
  wire [3:0] and_index_3 = dram_index & PRIME3;
  wire [3:0] and_index_4 = dram_index & PRIME4;
  
  always@*
  begin
		xcord_tmp[0] = and_index_1[0] ^ dram_x_subcord[0];
		xcord_tmp[1] = and_index_2[1] ^ dram_x_subcord[1];
		xcord_tmp[2] = and_index_3[2] ^ dram_x_subcord[2];
		xcord_tmp[3] = and_index_4[3] ^ dram_x_subcord[3];
			
  end

  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, xcord_tmp};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp] 
  };

*/

//////////////////////  XXHASH CONSTANTS BASED MATRIX HASHING for XCORD ENDS   ////////////////////


///////////////////////////// PEARSON DRAM HASHING STARTS ////////////////////////////////////////



  logic [7:0] ptable[255:0];
	wire [7:0]hash_const = 8'd7;	
	logic [7:0] hash_tmp_1, hash_tmp_2;
	logic [7:0] dram_idx_mod_1, dram_idx_mod_2;	
	logic [dram_index_width_lp-1:0] dram_index_fin;		
	logic [addr_width_p-1:0] epa_o_og; 
	
	generate
	genvar i;

		for(i=0;i <256; i++)
		begin
			assign ptable[i] = i^8'b10001001;		
		end
	endgenerate
	
	always@*
	begin
	
		dram_idx_mod_1 = dram_index[7:0];
		dram_idx_mod_2 = dram_index[15:8];	
		hash_tmp_1 = ptable[dram_idx_mod_1 ^ hash_const];
		hash_tmp_2 = ptable[dram_idx_mod_2 ^ hash_const];
				
	end

	assign dram_index_fin = { dram_index[19:16], hash_tmp_2, hash_tmp_1 };

  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, dram_x_subcord};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index_fin,
    eva_i[2+:vcache_word_offset_width_lp] 
  }; 



///////////////////////////// PEARSON DRAM HASHING ENDS ////////////////////////////////////////



endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_dram_hash_function)