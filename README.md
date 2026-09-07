# UVM Coverage-Driven Transaction Sequence Demo

This repository demonstrates a **coverage-driven verification (CDV)** flow in SystemVerilog using UVM. Instead of generating a fixed number of transactions, the sequence dynamically queries functional coverage metrics via `uvm_config_db` and continues driving randomized transactions until target coverpoints reach 100%.

## 🔗 Live Simulation
View and execute the testbench directly on [EDA Playground](https://www.edaplayground.com/x/DvvL).

---

## 📌 Architecture & Features

- **Transaction Model (`reg_transaction`):** Declares 4-bit `addr` and `data` fields using `randc` for uniform random generation.
- **Coverage Monitor (`reg_monitor`):**
  - Instantiates `my_cov` covergroup to track address (`cp_addr`), data (`cp_data`), and cross-coverage (`cp_addr_data`).
  - Exports its component handle to `uvm_config_db` during `connect_phase`.
- **Coverage-Driven Sequence (`reg_sequence`):**
  - Retrieves `cov_handle` from `uvm_config_db`.
  - Executes a dynamic `while` loop checking `cov_handle.my_cov.cp_addr.get_coverage() < 100.0`.
  - Terminates automatically as soon as full address coverage is achieved.

---

## 🛠️ Simulation Log Output

Upon reaching 100% address coverage, the sequence logs execution details and triggers the final report phase:

```text
UVM_INFO testbench.sv@ 310: uvm_test_top.env.agent1.monitor1 [Coverage] Data: 75.00% | Addr: 100.00% Cross CP: 10.94%
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO : 127
UVM_WARNING : 0
UVM_ERROR : 0
UVM_FATAL : 0
