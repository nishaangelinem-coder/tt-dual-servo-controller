module tt_um_dual_servo_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    output wire [7:0] uo_out,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);

    wire        host_write = uio_in[0];
    wire        host_read  = uio_in[1];
    wire [4:0]  host_addr  = uio_in[7:3];
    wire [7:0]  host_wdata = ui_in;
    wire [7:0]  host_rdata;
    wire        servo0;
    wire        servo1;
    wire [7:0]  fault_status;

    servo_dual_controller u_core (
        .clk(clk),
        .rst_n(rst_n),
        .host_write(host_write),
        .host_read(host_read),
        .host_addr(host_addr),
        .host_wdata(host_wdata),
        .host_rdata(host_rdata),
        .servo0(servo0),
        .servo1(servo1),
        .fault_status(fault_status)
    );

    assign uo_out[0] = servo0;
    assign uo_out[1] = servo1;
    assign uo_out[2] = fault_status[0];
    assign uo_out[7:3] = 5'b00000;

    assign uio_out[0] = host_rdata[0];
    assign uio_out[1] = host_rdata[1];
    assign uio_out[2] = host_rdata[2];
    assign uio_out[3] = host_rdata[3];
    assign uio_out[4] = host_rdata[4];
    assign uio_out[5] = host_rdata[5];
    assign uio_out[6] = host_rdata[6];
    assign uio_out[7] = host_rdata[7];

    assign uio_oe = 8'hFF;
endmodule
