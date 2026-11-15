module servo_dual_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        host_write,
    input  wire        host_read,
    input  wire [4:0]  host_addr,
    input  wire [7:0]  host_wdata,
    output reg  [7:0]  host_rdata,
    output wire        servo0,
    output wire        servo1,
    output reg  [7:0]  fault_status
);

    localparam integer CLK_HZ      = 100_000_000;
    localparam integer US_PER_TICK = 1; // 1 us resolution in the example model
    localparam integer FRAME_US    = 20_000;
    localparam integer PULSE_MIN_US = 500;
    localparam integer PULSE_MAX_US = 2500;
    localparam integer WATCHDOG_US = 200_000;

    reg [15:0] frame_counter_us;
    reg [15:0] ch0_shadow;
    reg [15:0] ch1_shadow;
    reg [15:0] ch0_active;
    reg [15:0] ch1_active;
    reg [15:0] min_pulse_us;
    reg [15:0] max_pulse_us;
    reg [15:0] watchdog_limit_us;
    reg        enabled;
    reg        fault_watchdog;
    reg        fault_overrange;
    reg        fault_disabled;
    reg        host_seen_recently;
    reg [15:0] watchdog_counter_us;

    function automatic [15:0] clamp_pulse;
        input [15:0] raw;
        begin
            clamp_pulse = raw;
            if (clamp_pulse < min_pulse_us)
                clamp_pulse = min_pulse_us;
            if (clamp_pulse > max_pulse_us)
                clamp_pulse = max_pulse_us;
        end
    endfunction

    wire [15:0] safe_ch0 = clamp_pulse(ch0_shadow);
    wire [15:0] safe_ch1 = clamp_pulse(ch1_shadow);

    // Servo outputs are high for the configured pulse width within each 20 ms frame.
    assign servo0 = enabled && (frame_counter_us < ch0_active);
    assign servo1 = enabled && (frame_counter_us < ch1_active);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter_us   <= 16'd0;
            ch0_shadow         <= PULSE_MIN_US;
            ch1_shadow         <= PULSE_MIN_US;
            ch0_active          <= PULSE_MIN_US;
            ch1_active          <= PULSE_MIN_US;
            min_pulse_us        <= PULSE_MIN_US;
            max_pulse_us        <= PULSE_MAX_US;
            watchdog_limit_us   <= WATCHDOG_US;
            enabled             <= 1'b0;
            fault_watchdog      <= 1'b0;
            fault_overrange     <= 1'b0;
            fault_disabled      <= 1'b0;
            host_seen_recently  <= 1'b0;
            watchdog_counter_us <= 16'd0;
            fault_status        <= 8'b00000000;
            host_rdata          <= 8'd0;
        end else begin
            // Host register access.
            if (host_write) begin
                case (host_addr)
                    5'h00: begin
                        enabled <= host_wdata[0];
                        if (host_wdata[1]) begin
                            ch0_shadow <= safe_ch0;
                            ch1_shadow <= safe_ch1;
                        end
                        if ((host_wdata[2]) && fault_watchdog) begin
                            fault_watchdog <= 1'b0;
                        end
                    end
                    5'h02: ch0_shadow[7:0]   <= host_wdata;
                    5'h03: ch0_shadow[15:8]  <= host_wdata;
                    5'h04: ch1_shadow[7:0]   <= host_wdata;
                    5'h05: ch1_shadow[15:8]  <= host_wdata;
                    5'h06: min_pulse_us[7:0] <= host_wdata;
                    5'h07: min_pulse_us[15:8] <= host_wdata;
                    5'h08: max_pulse_us[7:0] <= host_wdata;
                    5'h09: max_pulse_us[15:8] <= host_wdata;
                    5'h0A: watchdog_limit_us[7:0] <= host_wdata;
                    5'h0B: watchdog_limit_us[15:8] <= host_wdata;
                    default: begin end
                endcase
                host_seen_recently <= 1'b1;
            end

            if (host_read) begin
                case (host_addr)
                    5'h00: host_rdata <= {fault_disabled, fault_overrange, fault_watchdog, enabled, 4'b0000};
                    5'h01: host_rdata <= {3'b000, enabled, 4'b0000};
                    5'h02: host_rdata <= ch0_shadow[7:0];
                    5'h03: host_rdata <= ch0_shadow[15:8];
                    5'h04: host_rdata <= ch1_shadow[7:0];
                    5'h05: host_rdata <= ch1_shadow[15:8];
                    5'h06: host_rdata <= min_pulse_us[7:0];
                    5'h07: host_rdata <= min_pulse_us[15:8];
                    5'h08: host_rdata <= max_pulse_us[7:0];
                    5'h09: host_rdata <= max_pulse_us[15:8];
                    5'h0A: host_rdata <= watchdog_limit_us[7:0];
                    5'h0B: host_rdata <= watchdog_limit_us[15:8];
                    5'h0C: host_rdata <= fault_status;
                    default: host_rdata <= 8'h00;
                endcase
            end

            // Watchdog logic: host activity keeps the watchdog alive.
            if (host_seen_recently) begin
                watchdog_counter_us <= 16'd0;
                host_seen_recently <= 1'b0;
            end else if (watchdog_counter_us >= watchdog_limit_us) begin
                fault_watchdog <= 1'b1;
                enabled <= 1'b0;
                fault_status[0] <= 1'b1;
            end else begin
                watchdog_counter_us <= watchdog_counter_us + 16'd1;
            end

            // End-of-frame update is atomic and synchronous for both channels.
            if (frame_counter_us == FRAME_US - 1) begin
                ch0_active <= safe_ch0;
                ch1_active <= safe_ch1;
                frame_counter_us <= 16'd0;
            end else begin
                frame_counter_us <= frame_counter_us + 16'd1;
            end

            // Fault bit assembly.
            fault_status <= {fault_disabled, 1'b0, fault_overrange, fault_watchdog, 4'b0000};
        end
    end
endmodule
