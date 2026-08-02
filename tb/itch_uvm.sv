import uvm_pkg::*;
`include "uvm_macros.svh"

class itch_seq_item extends uvm_sequence_item;

  bit [7:0] msg_type;
  bit [7:0]  side;
  bit [31:0] shares;
  bit [31:0] price;
  bit [1:0] expected_signal;

  `uvm_object_utils_begin(itch_seq_item)
    `uvm_field_int(msg_type,  UVM_ALL_ON)
    `uvm_field_int(side,  UVM_ALL_ON)
    `uvm_field_int(shares,   UVM_ALL_ON)
  	`uvm_field_int(price,  UVM_ALL_ON)
  	`uvm_field_int(expected_signal,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "itch_seq_item");
    super.new(name);
  endfunction

endclass

class itch_sequence extends uvm_sequence #(itch_seq_item);

  `uvm_object_utils(itch_sequence)

  function new(string name = "itch_sequence");
    super.new(name);
  endfunction

  
 //similar to tb, run through all sequences
  virtual task body();
    // BUY
    req = itch_seq_item::type_id::create("req");
    start_item(req);
    req.side = 8'h42; req.price = 32'd1_700_000; req.shares = 32'd100;
    finish_item(req);

    // SELL
    req = itch_seq_item::type_id::create("req");
    start_item(req);
    req.side = 8'h53; req.price = 32'd2_100_000; req.shares = 32'd100;
    finish_item(req);

    // HOLD
    req = itch_seq_item::type_id::create("req");
    start_item(req);
    req.side = 8'h42; req.price = 32'd1_900_000; req.shares = 32'd100;
    finish_item(req);
  endtask
endclass

//Interface class
interface my_int (input bit clk);
  logic rst;
  logic [511:0] data_in;
  logic data_valid;
  logic [1:0] signal;
  
endinterface

//Driver class
class itch_driver extends uvm_driver #(itch_seq_item);

  `uvm_component_utils(itch_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function [7:0] unscramble_byte;
	input [7:0] raw;
	begin
		unscramble_byte = {raw[1], raw[0], raw[3], raw[2], raw[5], raw[4], raw[7], raw[6]};
	end
  endfunction

  
  virtual my_int vif;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual my_int)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface reg_if")
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    itch_seq_item tr;
    logic [511:0] data_in_packed =512'd0;
	
    //Only go into run phase @reset
    vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    #1;
    vif.rst <= 1'b0;
    
    
    forever begin
      // 1. Get next item from the sequencer
      seq_item_port.get_next_item(tr);

      // 2. Drive request signals, then wait for the DUT to act on them
      @(posedge vif.clk);
      data_in_packed[399:392] = unscramble_byte(tr.msg_type);
      data_in_packed[391:384] = unscramble_byte(tr.side);

      data_in_packed[383:376] = unscramble_byte(tr.shares[31:24]); 
      data_in_packed[375:368] = unscramble_byte(tr.shares[23:16]); 
      data_in_packed[367:360] = unscramble_byte(tr.shares[15:8]); 
      data_in_packed[359:352] = unscramble_byte(tr.shares[7:0]);  

      data_in_packed[351:344] = unscramble_byte(tr.price[31:24]);  
      data_in_packed[343:336] = unscramble_byte(tr.price[23:16]);  
      data_in_packed[335:328] = unscramble_byte(tr.price[15:8]);   
      data_in_packed[327:320] = unscramble_byte(tr.price[7:0]); 
      
      vif.data_in <= data_in_packed;
      vif.data_valid <= 1'b1;
      
      @(posedge vif.clk);
      vif.data_valid <= 1'b0;
      
      // 4. Tell the sequencer this item is done
      seq_item_port.item_done();
    end
  endtask
endclass


class itch_monitor extends uvm_monitor;

  `uvm_component_utils(itch_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual my_int vif;

  uvm_analysis_port #(itch_seq_item) mon_analysis_port;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon_analysis_port = new("mon_analysis_port", this);

    if (!uvm_config_db #(virtual my_int)::get(this, "", "vif", vif)) begin
      `uvm_error(get_type_name(), "Didn't get handle to virtual interface reg_if")
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    itch_seq_item tr;

    forever begin
      @(posedge vif.clk);
      if (vif.data_valid) begin
        tr = itch_seq_item::type_id::create("tr", this);

        //wait 3 clock cycles, due to my pipeline delay
        repeat(3) @(posedge vif.clk);
        tr.expected_signal = vif.signal;

        mon_analysis_port.write(tr);
      end 
    end
  endtask
endclass

class itch_scoreboard extends uvm_scoreboard;
  int idx = 0;
  bit [1:0] expected_q[3] = '{1, 1, 2}; 
  `uvm_component_utils(itch_scoreboard)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  uvm_analysis_imp #(itch_seq_item, itch_scoreboard) ap_imp;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction
  
  virtual function void write(itch_seq_item tr);
    if (expected_q[idx] !== tr.expected_signal) begin
      `uvm_error(get_type_name(), $sformatf("Mismatch at index=%0d: expected=0x%0h 					actual=0x%0h", idx, expected_q[idx], tr.expected_signal))
    end else begin
      `uvm_info(get_type_name(), $sformatf("Signals Matched"), UVM_HIGH)
    end 
    idx++;
  endfunction
  
endclass


class itch_agent extends uvm_agent;
  //declare driver, monitor, and sequencer
  itch_driver driver;
  uvm_sequencer #(itch_seq_item) sequencer;
  itch_monitor monitor;

  `uvm_component_utils(itch_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer#(itch_seq_item)::type_id::create("sequencer", this);
    driver    = itch_driver::type_id::create("driver", this);
    monitor  = itch_monitor::type_id::create("monitor", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass

class itch_env extends uvm_env;
  itch_agent agent;
  itch_scoreboard scoreboard;
  
  `uvm_component_utils(itch_env)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = itch_agent::type_id::create("agent", this);
    scoreboard = itch_scoreboard::type_id::create("scoreboard", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.mon_analysis_port.connect(scoreboard.ap_imp);
  endfunction
  
endclass

class itch_test extends uvm_test;
  itch_env env;
  `uvm_component_utils(itch_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = itch_env::type_id::create("env", this);
  endfunction
  
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    itch_sequence seq = itch_sequence::type_id::create("sequence", this);
    phase.raise_objection(this);
    seq.start(env.agent.sequencer);
    #100;
    phase.drop_objection(this);
  endtask
  
endclass

module tb_top;
  bit clk;
  always #5 clk = ~clk;
  
  my_int v_if0(clk);
  itch_parser dut(
    .clk(v_if0.clk),
    .rst(v_if0.rst),
    .data_in(v_if0.data_in),
    .data_valid(v_if0.data_valid),
    .signal(v_if0.signal)
  );
  
  initial begin
    uvm_config_db#(virtual my_int)::set(null, "*", "vif", v_if0);
    run_test("itch_test");
  end 
  
endmodule
