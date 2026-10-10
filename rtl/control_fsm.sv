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
    localparam int IMAGE_PIXELS = 28*28;
    localparam int CONV1_OUTPUTS = 26*26;
    localparam int POOL_OUTPUTS = 13*13*4;
    localparam int CONV2_OUTPUTS = 11*11;


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
    int stage_count;


    //sequential part of the fsm (state register update and counters)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stage_count <= 0;
        end 
        
        else begin
            state <= next_state;

            //stage_count is cleared on every state change, so other states hold 0
            if(state != next_state) begin
                stage_count <= 0;
            end

            else begin

                case (state)

                    LOAD_IMAGE: if(pixel_valid) stage_count <= stage_count + 1;
                    CONV1: if(conv1_valid)  stage_count <= stage_count + 1;
                    RELU1:                  stage_count <= stage_count + 1;
                    POOL: if(pool_valid)    stage_count <= stage_count + 1;
                    CONV2: if(conv2_valid)  stage_count <= stage_count + 1;
                    RELU2:                  stage_count <= stage_count + 1;

                    IDLE, CLEAR_CONV1, CLEAR_CONV2, FLATTEN, DENSE_START, DENSE, DONE: ;
                    default: ;
                endcase
            end
        
        end
    end


    //combinational part of the fsm (next state logic)
    always_comb begin

        //default assignment is below
        next_state = state;
        
        ready = 1'b0;
        done = 1'b0;
        load_image = 1'b0;
        enable_conv1 = 1'b0;
        enable_relu1 = 1'b0;
        enable_pool = 1'b0;
        enable_conv2 = 1'b0;
        enable_relu2 = 1'b0;
        enable_flatten = 1'b0;
        start_dense = 1'b0;
        enable_dense = 1'b0;
        clear_window = 1'b0;

        //next state logic is below
        case (state)

            IDLE: begin
                if (start) begin
                    next_state = LOAD_IMAGE;
                end
            end

            LOAD_IMAGE: begin
                load_image = 1'b1;
                ready = 1'b1; //the FSM leaves LOAD_IMAGE on the 784th pixel
                if ((stage_count == IMAGE_PIXELS -1) && pixel_valid) begin
                    next_state = CLEAR_CONV1;
                end
            end

            CLEAR_CONV1: begin
                clear_window = 1'b1;
                next_state = CONV1; 
            end

            CONV1: begin

                enable_conv1 = 1'b1;
                
                if (conv1_valid && stage_count == CONV1_OUTPUTS -1) begin
                    next_state = RELU1;
                end
            end


            RELU1: begin

                enable_relu1 = 1'b1;

                if(stage_count == CONV1_OUTPUTS -1) begin
                    next_state = POOL;
                end
            end

            POOL: begin

                enable_pool = 1'b1;

                if (pool_valid && stage_count == POOL_OUTPUTS -1) begin
                    next_state = CLEAR_CONV2;
                end
            end

            CLEAR_CONV2: begin
                clear_window = 1'b1;
                next_state = CONV2;
            end

            CONV2: begin

                enable_conv2 =1'b1;
                if (conv2_valid && stage_count == CONV2_OUTPUTS -1) begin
                    next_state = RELU2;
                end
            end

            RELU2: begin
                
                enable_relu2 = 1'b1;
                if (stage_count == CONV2_OUTPUTS -1) begin
                    next_state = FLATTEN;
                end
            end

            FLATTEN: begin
                enable_flatten = 1'b1;
                if (flatten_done) begin
                    next_state = DENSE_START;
                end
            end

            DENSE_START: begin                
                start_dense = 1'b1;
                next_state = DENSE;
            end

            DENSE: begin
                
                enable_dense = 1'b1;
                if (dense_done) begin
                    
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;


        endcase
    end

endmodule
