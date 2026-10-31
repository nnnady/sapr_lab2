vlib work
vlog -sv apb_master.sv apb_and_acc.sv tb_top.sv
vsim -voptargs=+acc work.tb_top
add wave -radix hex /tb_top/pclk /tb_top/presetn
add wave -radix hex /tb_top/psel /tb_top/penable /tb_top/pwrite /tb_top/paddr /tb_top/pwdata
add wave -radix hex /tb_top/prdata /tb_top/pready /tb_top/pslverr
add wave -radix hex /tb_top/DUT/apb_st /tb_top/DUT/data_reg /tb_top/DUT/auto_mode /tb_top/DUT/result_reg
run -all
