`include "uvm_macros.svh"
import uvm_pkg::*;

typedef class reg_monitor;

class reg_transaction extends uvm_sequence_item;
  
  randc bit [3:0] data;
  randc bit [3:0] addr;
  
  `uvm_object_utils_begin(reg_transaction)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_object_utils_end
  
  function new(string name = "reg_transaction");
    super.new(name);
  endfunction 
endclass

class reg_sequence extends uvm_sequence #(reg_transaction);
  
  `uvm_object_utils(reg_sequence)
  
  reg_monitor cov_handle;
  
  function new(string name = "reg_sequence");
    super.new(name);
  endfunction
  
  task body();
    
    if(!uvm_config_db#(reg_monitor)::get(null, "*", "mon_handle", cov_handle)) begin
      `uvm_fatal("SeQ", "Failed to get")
    end  
    
    while (cov_handle.my_cov.cp_addr.get_coverage() < 100.0)  begin
      req = reg_transaction::type_id::create("id");
      start_item(req);
      //#10;
      if(!req.randomize()) begin
        `uvm_info("SEQQ","Did not randomize", UVM_LOW);
        end else begin
          `uvm_info(get_name(), $sformatf("Data %d , Addr %d", req.data, req.addr), UVM_LOW);
        end
      finish_item(req);
      #10;
      end
  endtask
endclass

class reg_sequencer extends uvm_sequencer #(reg_transaction);
  
  `uvm_component_utils(reg_sequencer)
  
  function new(string name = "reg_sequencer", uvm_component parent = null);
    super.new(name,parent);
  endfunction

endclass

class reg_driver extends uvm_driver #(reg_transaction);
  
  `uvm_component_utils(reg_driver)
  
  uvm_analysis_port #(reg_transaction) driver;
  
  function new(string name = "reg_driver", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = new("driver", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    reg_transaction tr;
    forever begin
      seq_item_port.get_next_item(tr);      
      driver.write(tr);
      seq_item_port.item_done(tr);
    end
  endtask
endclass

class reg_monitor extends uvm_monitor;
  
  `uvm_component_utils(reg_monitor)

  uvm_analysis_port #(reg_transaction) item_collected_port;
  reg_transaction tr;
  
  covergroup my_cov();
    option.per_instance = 1;
    cp_addr: coverpoint tr.addr;
    cp_data: coverpoint tr.data;
    
    cp_addr_data: cross cp_addr, cp_data;
  endgroup
  
  function new(string name = "reg_monitor", uvm_component parent = null);
    super.new(name,parent);
    my_cov = new();
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_port = new("monitor",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_config_db#(reg_monitor)::set(null,"*", "mon_handle",this);
  endfunction
  
  task run_phase(uvm_phase phase);
    forever begin
      #10;
      tr = reg_transaction::type_id::create("tr");
      void'(tr.randomize());
      my_cov.sample();
      item_collected_port.write(tr);
    end
  endtask 

    function void report_phase(uvm_phase phase);
    super.report_phase(phase);
      `uvm_info("Coverage", $sformatf("Data: %0.2f%% | Addr: %0.2f%% Cross CP: %0.2f%%", my_cov.cp_data.get_coverage(), my_cov.cp_addr.get_coverage(), my_cov.cp_addr_data.get_coverage()), UVM_LOW);    
      
  endfunction
  
endclass

class reg_agent extends uvm_agent;
  
  `uvm_component_utils(reg_agent)
  
  reg_sequencer sequencer1;
  reg_driver    driver1;
  reg_monitor   monitor1;
  
  function new(string name = "reg_agent", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer1 = reg_sequencer::type_id::create("seq1",this);
    driver1 = reg_driver::type_id::create("driver1", this);
    monitor1 = reg_monitor::type_id::create("monitor1",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver1.seq_item_port.connect(sequencer1.seq_item_export);
  endfunction 
endclass

class reg_scoreboard extends uvm_scoreboard;
  
  uvm_analysis_imp #(reg_transaction, reg_scoreboard) scoreboard;
  
  `uvm_component_utils(reg_scoreboard)
  
  function new(string name = "reg_scoreboard", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    scoreboard = new("scoreboard_imp",this);
  endfunction
                                    
  virtual function void write(reg_transaction tr);
    `uvm_info("Scoreboard", $sformatf("Data: %d", tr.data),  UVM_LOW);
  endfunction  
  
endclass

class reg_env extends uvm_env;
  
  `uvm_component_utils(reg_env);
  
  reg_agent agent1;
  reg_scoreboard scoreboard1;
   
  function new(string name = "reg_env", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent1 = reg_agent::type_id::create("agent1",this);
    scoreboard1 = reg_scoreboard::type_id::create("scoreboard",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent1.driver1.driver.connect(scoreboard1.scoreboard);
  endfunction
endclass   

class reg_test extends uvm_test;
      
  `uvm_component_utils(reg_test)
      
  reg_env env;
  reg_sequence seq1;
  reg_sequence seq2;
      
  function new(string name, uvm_component parent = null);
     super.new(name,parent);
   endfunction
        
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env  = reg_env::type_id::create("env",this);
  endfunction    
      
  task run_phase(uvm_phase phase);
        
    phase.raise_objection(this);    
    seq1 = reg_sequence::type_id::create("seq1");
    seq2 = reg_sequence::type_id::create("seq2");
    fork
      seq1.start(env.agent1.sequencer1);
      seq2.start(env.agent1.sequencer1);
    join
    
    phase.drop_objection(this);
  endtask    
endclass

module tb_top;
  initial begin
  run_test("reg_test");
  end
endmodule


/*
UVM_INFO @ 0: reporter [RNTST] Running test reg_test...
UVM_INFO testbench.sv(45) @ 0: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  4 , Addr  4
UVM_INFO testbench.sv(177) @ 0: uvm_test_top.env.scoreboard [Scoreboard] Data:  4
UVM_INFO testbench.sv(45) @ 0: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 14 , Addr  6
UVM_INFO testbench.sv(177) @ 0: uvm_test_top.env.scoreboard [Scoreboard] Data: 14
UVM_INFO testbench.sv(45) @ 10: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  9 , Addr 12
UVM_INFO testbench.sv(177) @ 10: uvm_test_top.env.scoreboard [Scoreboard] Data:  9
UVM_INFO testbench.sv(45) @ 10: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  7 , Addr 15
UVM_INFO testbench.sv(177) @ 10: uvm_test_top.env.scoreboard [Scoreboard] Data:  7
UVM_INFO testbench.sv(45) @ 20: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 11 , Addr  1
UVM_INFO testbench.sv(177) @ 20: uvm_test_top.env.scoreboard [Scoreboard] Data: 11
UVM_INFO testbench.sv(45) @ 20: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  6 , Addr  5
UVM_INFO testbench.sv(177) @ 20: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 30: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  0 , Addr  0
UVM_INFO testbench.sv(177) @ 30: uvm_test_top.env.scoreboard [Scoreboard] Data:  0
UVM_INFO testbench.sv(45) @ 30: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 10 , Addr 14
UVM_INFO testbench.sv(177) @ 30: uvm_test_top.env.scoreboard [Scoreboard] Data: 10
UVM_INFO testbench.sv(45) @ 40: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  5 , Addr 13
UVM_INFO testbench.sv(177) @ 40: uvm_test_top.env.scoreboard [Scoreboard] Data:  5
UVM_INFO testbench.sv(45) @ 40: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  3 , Addr  9
UVM_INFO testbench.sv(177) @ 40: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 50: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 10 , Addr  6
UVM_INFO testbench.sv(177) @ 50: uvm_test_top.env.scoreboard [Scoreboard] Data: 10
UVM_INFO testbench.sv(45) @ 50: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  5 , Addr  4
UVM_INFO testbench.sv(177) @ 50: uvm_test_top.env.scoreboard [Scoreboard] Data:  5
UVM_INFO testbench.sv(45) @ 60: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr  3
UVM_INFO testbench.sv(177) @ 60: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 60: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  8 , Addr  6
UVM_INFO testbench.sv(177) @ 60: uvm_test_top.env.scoreboard [Scoreboard] Data:  8
UVM_INFO testbench.sv(45) @ 70: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  8 , Addr  1
UVM_INFO testbench.sv(177) @ 70: uvm_test_top.env.scoreboard [Scoreboard] Data:  8
UVM_INFO testbench.sv(45) @ 70: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 13 , Addr  7
UVM_INFO testbench.sv(177) @ 70: uvm_test_top.env.scoreboard [Scoreboard] Data: 13
UVM_INFO testbench.sv(45) @ 80: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  4 , Addr 15
UVM_INFO testbench.sv(177) @ 80: uvm_test_top.env.scoreboard [Scoreboard] Data:  4
UVM_INFO testbench.sv(45) @ 80: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  2 , Addr  1
UVM_INFO testbench.sv(177) @ 80: uvm_test_top.env.scoreboard [Scoreboard] Data:  2
UVM_INFO testbench.sv(45) @ 90: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  3 , Addr  9
UVM_INFO testbench.sv(177) @ 90: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 90: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  3 , Addr  5
UVM_INFO testbench.sv(177) @ 90: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 100: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr  7
UVM_INFO testbench.sv(177) @ 100: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 100: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  1 , Addr 14
UVM_INFO testbench.sv(177) @ 100: uvm_test_top.env.scoreboard [Scoreboard] Data:  1
UVM_INFO testbench.sv(45) @ 110: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  0 , Addr 15
UVM_INFO testbench.sv(177) @ 110: uvm_test_top.env.scoreboard [Scoreboard] Data:  0
UVM_INFO testbench.sv(45) @ 110: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 13 , Addr  4
UVM_INFO testbench.sv(177) @ 110: uvm_test_top.env.scoreboard [Scoreboard] Data: 13
UVM_INFO testbench.sv(45) @ 120: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  6 , Addr  0
UVM_INFO testbench.sv(177) @ 120: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 120: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  3 , Addr  7
UVM_INFO testbench.sv(177) @ 120: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 130: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  9 , Addr  9
UVM_INFO testbench.sv(177) @ 130: uvm_test_top.env.scoreboard [Scoreboard] Data:  9
UVM_INFO testbench.sv(45) @ 130: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 15 , Addr 13
UVM_INFO testbench.sv(177) @ 130: uvm_test_top.env.scoreboard [Scoreboard] Data: 15
UVM_INFO testbench.sv(45) @ 140: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  6 , Addr 15
UVM_INFO testbench.sv(177) @ 140: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 140: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 11 , Addr  4
UVM_INFO testbench.sv(177) @ 140: uvm_test_top.env.scoreboard [Scoreboard] Data: 11
UVM_INFO testbench.sv(45) @ 150: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  0 , Addr  6
UVM_INFO testbench.sv(177) @ 150: uvm_test_top.env.scoreboard [Scoreboard] Data:  0
UVM_INFO testbench.sv(45) @ 150: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 14 , Addr 14
UVM_INFO testbench.sv(177) @ 150: uvm_test_top.env.scoreboard [Scoreboard] Data: 14
UVM_INFO testbench.sv(45) @ 160: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 13 , Addr  0
UVM_INFO testbench.sv(177) @ 160: uvm_test_top.env.scoreboard [Scoreboard] Data: 13
UVM_INFO testbench.sv(45) @ 160: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  6 , Addr  7
UVM_INFO testbench.sv(177) @ 160: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 170: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  7 , Addr 14
UVM_INFO testbench.sv(177) @ 170: uvm_test_top.env.scoreboard [Scoreboard] Data:  7
UVM_INFO testbench.sv(45) @ 170: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 13 , Addr 13
UVM_INFO testbench.sv(177) @ 170: uvm_test_top.env.scoreboard [Scoreboard] Data: 13
UVM_INFO testbench.sv(45) @ 180: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  3 , Addr 10
UVM_INFO testbench.sv(177) @ 180: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 180: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  5 , Addr  5
UVM_INFO testbench.sv(177) @ 180: uvm_test_top.env.scoreboard [Scoreboard] Data:  5
UVM_INFO testbench.sv(45) @ 190: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 13 , Addr  8
UVM_INFO testbench.sv(177) @ 190: uvm_test_top.env.scoreboard [Scoreboard] Data: 13
UVM_INFO testbench.sv(45) @ 190: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 14 , Addr  8
UVM_INFO testbench.sv(177) @ 190: uvm_test_top.env.scoreboard [Scoreboard] Data: 14
UVM_INFO testbench.sv(45) @ 200: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr  0
UVM_INFO testbench.sv(177) @ 200: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 200: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  4 , Addr  4
UVM_INFO testbench.sv(177) @ 200: uvm_test_top.env.scoreboard [Scoreboard] Data:  4
UVM_INFO testbench.sv(45) @ 210: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr 11
UVM_INFO testbench.sv(177) @ 210: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 210: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 15 , Addr 14
UVM_INFO testbench.sv(177) @ 210: uvm_test_top.env.scoreboard [Scoreboard] Data: 15
UVM_INFO testbench.sv(45) @ 220: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  9 , Addr  4
UVM_INFO testbench.sv(177) @ 220: uvm_test_top.env.scoreboard [Scoreboard] Data:  9
UVM_INFO testbench.sv(45) @ 220: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 14 , Addr  5
UVM_INFO testbench.sv(177) @ 220: uvm_test_top.env.scoreboard [Scoreboard] Data: 14
UVM_INFO testbench.sv(45) @ 230: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr 13
UVM_INFO testbench.sv(177) @ 230: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 230: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  6 , Addr 11
UVM_INFO testbench.sv(177) @ 230: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 240: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  4 , Addr 13
UVM_INFO testbench.sv(177) @ 240: uvm_test_top.env.scoreboard [Scoreboard] Data:  4
UVM_INFO testbench.sv(45) @ 240: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  9 , Addr  6
UVM_INFO testbench.sv(177) @ 240: uvm_test_top.env.scoreboard [Scoreboard] Data:  9
UVM_INFO testbench.sv(45) @ 250: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  8 , Addr  1
UVM_INFO testbench.sv(177) @ 250: uvm_test_top.env.scoreboard [Scoreboard] Data:  8
UVM_INFO testbench.sv(45) @ 250: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  3 , Addr 14
UVM_INFO testbench.sv(177) @ 250: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 260: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr  5
UVM_INFO testbench.sv(177) @ 260: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 260: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  5 , Addr  3
UVM_INFO testbench.sv(177) @ 260: uvm_test_top.env.scoreboard [Scoreboard] Data:  5
UVM_INFO testbench.sv(45) @ 270: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  8 , Addr 13
UVM_INFO testbench.sv(177) @ 270: uvm_test_top.env.scoreboard [Scoreboard] Data:  8
UVM_INFO testbench.sv(45) @ 270: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  9 , Addr  0
UVM_INFO testbench.sv(177) @ 270: uvm_test_top.env.scoreboard [Scoreboard] Data:  9
UVM_INFO testbench.sv(45) @ 280: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data 12 , Addr  4
UVM_INFO testbench.sv(177) @ 280: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(45) @ 280: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  6 , Addr  2
UVM_INFO testbench.sv(177) @ 280: uvm_test_top.env.scoreboard [Scoreboard] Data:  6
UVM_INFO testbench.sv(45) @ 290: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  3 , Addr  2
UVM_INFO testbench.sv(177) @ 290: uvm_test_top.env.scoreboard [Scoreboard] Data:  3
UVM_INFO testbench.sv(45) @ 290: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data  7 , Addr  9
UVM_INFO testbench.sv(177) @ 290: uvm_test_top.env.scoreboard [Scoreboard] Data:  7
UVM_INFO testbench.sv(45) @ 300: uvm_test_top.env.agent1.seq1@@seq1 [seq1] Data  2 , Addr  8
UVM_INFO testbench.sv(177) @ 300: uvm_test_top.env.scoreboard [Scoreboard] Data:  2
UVM_INFO testbench.sv(45) @ 300: uvm_test_top.env.agent1.seq1@@seq2 [seq2] Data 12 , Addr  5
UVM_INFO testbench.sv(177) @ 300: uvm_test_top.env.scoreboard [Scoreboard] Data: 12
UVM_INFO testbench.sv(130) @ 310: uvm_test_top.env.agent1.monitor1 [Coverage] Data: 75.00% | Addr: 100.00% Cross CP: 10.94%
*/
