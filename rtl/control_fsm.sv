//Control FSM for the top-level classifier

module control_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic pixel_valid,
    input  logic conv1_valid,
    input  logic pool_valid,
    input  logic conv2_valid,
    input  logic flatten_done,
    input  logic dense_done,
    output logic ready,
    output logic done,
    output logic load_image,
    output logic enable_conv1,
    output logic enable_relu1,
    output logic enable_pool,
    output logic enable_conv2,
    output logic enable_relu2,
    output logic enable_flatten,
    output logic start_dense,
    output logic enable_dense,
    output logic clear_window
);

    //constant sizes
    localparam int unsigned IMAGE_PIXELS = 28*28;
    localparam int unsigned CONV1_output = 26*26;
    localparam int unsigned POOL_output = 13*13*4;
    localparam int unsigned CONV2_output = 11*11;


    //states

    typedef enum logic [3:0] {

        IDLE,
        LOAD_IMAGE,
        CLEAR_CONV1, //clear the convolution 1 window
        CONV1,
        RELU1,
        POOL,
        CLEAR_CONV2, //clear the convolution 2 window
        CONV2,
        RELU2,
        FLATTEN,
        DENSE_START, //start the dense layer
        DENSE, //dense layer processing (1 cycle delay, so 2 dense states)
        DONE
    } state_t;

    //fsm state register and next state logic
    state_t state;
    state_t next_state;
    int pixel_count;
    int stage_count;


    //sequential part of the fsm (state register update and counters)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_count <= 0;
            stage_count <= 0;
        end 
        
        else begin
            state <= next_state;
            
            if(state == LOAD_IMAGE) begin
                if (pixel_valid) pixel_count <= pixel_count + 1;
        //when not in LOAD_IMAGE just set pixel_count to 0
            end else begin
                pixel_count <= 0;
            end

            //increment stage_count if staying in the same state
            if(state != next_state) begin
                stage_count <= 0;
            end

            else begin

                case (state)

                    CONV1: if(conv1_valid)  stage_count <= stage_count + 1;
                    RELU1:                  stage_count <= stage_count + 1;
                    POOL: if(pool_valid)    stage_count <= stage_count + 1;
                    CONV2: if(conv2_valid)  stage_count <= stage_count + 1;
                    RELU2:                  stage_count <= stage_count + 1;
                    IDLE, LOAD_IMAGE, CLEAR_CONV1, CLEAR_CONV2, FLATTEN, DENSE_START, DENSE, DONE: stage_count <= 0;

                    default: stage_count <=0;
                endcase
            end
        
        end
    end


//combinational part of the fsm (next state logic)
always_comb begin




end


endmodule
