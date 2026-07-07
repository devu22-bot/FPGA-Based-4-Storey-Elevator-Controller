module lift_controller(

input CLOCK_50,
input RESET,
input [3:0] KEY,
input [3:0] SW,

output reg [17:0] LEDR,
output reg [7:0] LEDG,
output reg [6:0] HEX0

);

//STATES

parameter IDLE       = 3'd0;
parameter DOOR_OPEN  = 3'd1;
parameter WAIT_OPEN  = 3'd2;
parameter DOOR_CLOSE = 3'd3;
parameter MOVE_UP    = 3'd4;
parameter MOVE_DOWN  = 3'd5;

reg [2:0] state, next_state;

// FLOOR & REQUEST

reg [1:0] current_floor = 0;
reg [3:0] req = 4'b0000; //Flag System

// DIRECTION (ONLY SEQUENTIAL)

reg direction;
parameter UP = 1'b1;
parameter DOWN = 1'b0;

// CLOCK DIVIDER

reg [25:0] clk_div = 26'd0;
reg slow_clk = 0;

always @(posedge CLOCK_50)
begin
    clk_div <= clk_div + 1;
    if(clk_div == 26'd25000000)
    begin
        clk_div <= 0;
        slow_clk <= ~slow_clk;
    end
end

// ARRIVAL FLAG

reg arrived;

// REQUEST MEMORY

always @(posedge slow_clk or posedge RESET)
begin
    if(RESET)
        req <= 0;
    else
    begin
        if(KEY[0]==0 || SW[0]) req[0] <= 1; // Active Low Button Key(Button)
        if(KEY[1]==0 || SW[1]) req[1] <= 1;
        if(KEY[2]==0 || SW[2]) req[2] <= 1;
        if(KEY[3]==0 || SW[3]) req[3] <= 1;

        if(state == DOOR_OPEN)
            req[current_floor] <= 0; // For Request Removal 
    end
end

// REQUEST CHECK

reg up_exist, down_exist;

always @(*)
begin
    up_exist = 0;
    down_exist = 0;

    case(current_floor)
    0: begin up_exist = req[1]|req[2]|req[3]; down_exist = 0; end
    1: begin up_exist = req[2]|req[3]; down_exist = req[0]; end
    2: begin up_exist = req[3]; down_exist = req[0]|req[1]; end
    3: begin up_exist = 0; down_exist = req[0]|req[1]|req[2]; end
    endcase
end

// STATE REGISTER

always @(posedge slow_clk or posedge RESET)
begin
    if(RESET)
        state <= IDLE;
    else
        state <= next_state;
end

// NEXT STATE LOGIC 

always @(*)
begin
    case(state)

    IDLE:
    begin
        if(req[current_floor])
            next_state = DOOR_OPEN;
        else if(up_exist)
            next_state = MOVE_UP;
        else if(down_exist)
            next_state = MOVE_DOWN;
        else
            next_state = IDLE;
    end

    DOOR_OPEN:  next_state = WAIT_OPEN;
    WAIT_OPEN:  next_state = DOOR_CLOSE;

    DOOR_CLOSE:
    begin
        if(direction == UP)
        begin
            if(up_exist)
                next_state = MOVE_UP;
            else if(down_exist)
                next_state = MOVE_DOWN;
            else
                next_state = IDLE;
        end
        else
        begin
            if(down_exist)
                next_state = MOVE_DOWN;
            else if(up_exist)
                next_state = MOVE_UP;
            else
                next_state = IDLE;
        end
    end

    MOVE_UP:
    begin
        if(arrived && req[current_floor])
            next_state = DOOR_OPEN;
        else if(!up_exist && arrived)
            next_state = MOVE_DOWN;
        else
            next_state = MOVE_UP;
    end

    MOVE_DOWN:
    begin
        if(arrived && req[current_floor])
            next_state = DOOR_OPEN;
        else if(!down_exist && arrived)
            next_state = MOVE_UP;
        else
            next_state = MOVE_DOWN;
    end

    default: next_state = IDLE;

    endcase
end

// OUTPUT LED 

reg [4:0] red_pos;

always @(posedge slow_clk or posedge RESET)
begin
    if(RESET)
    begin
        current_floor <= 0;
        red_pos <= 0;
        LEDR <= 0;
        LEDG <= 0;
        arrived <= 0;
        direction <= UP;
    end
    else
    begin
        arrived <= 0;

        case(state)

        IDLE:
        begin
            LEDR <= 0;
            LEDG <= 0;
            red_pos <= 0;
        end

        DOOR_OPEN:
            LEDG <= 8'hFF;

        WAIT_OPEN:
            LEDG <= 8'hFF;

        DOOR_CLOSE:
            LEDG <= 0;

        MOVE_UP:
        begin
            direction <= UP;   

            LEDR <= (18'b1 << red_pos);
            red_pos <= red_pos + 1;

            if(red_pos == 17)
            begin
                red_pos <= 0;
                current_floor <= current_floor + 1;
                arrived <= 1;
            end
        end

        MOVE_DOWN:
        begin
            direction <= DOWN; 

            LEDR <= (18'b1 << (17-red_pos));
            red_pos <= red_pos + 1;

            if(red_pos == 17)
            begin
                red_pos <= 0;
                current_floor <= current_floor - 1;
                arrived <= 1;
            end
        end

        endcase
    end
end

// 7 SEGMENT

always @(*)
begin
    case(current_floor)
        0: HEX0 = 7'b1000000;
        1: HEX0 = 7'b1111001;
        2: HEX0 = 7'b0100100;
        3: HEX0 = 7'b0110000;
        default: HEX0 = 7'b1111111;
    endcase
end


endmodule