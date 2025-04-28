library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity usb_speed_test is
    Port (
        clk           : in  STD_LOGIC;                     -- 12MHz clock input
        rst_n         : in  STD_LOGIC;                     -- Reset signal (active low)
        uart_txd      : out STD_LOGIC;                     -- UART TX data
        led_out       : out STD_LOGIC_VECTOR(7 downto 0);  -- LEDs for debugging
        -- Buffer interface
        buffer_data   : in  std_logic_vector(47 downto 0); -- Full 48-bit data from buffer
        buffer_wr     : in  std_logic;                     -- Buffer write signal
        buffer_rd_addr: out std_logic_vector(7 downto 0)   -- Read address to buffer
    );
end usb_speed_test;

architecture Behavioral of usb_speed_test is
    -- Constants
    constant CLK_FREQ       : integer := 12_000_000;  -- 12MHz system clock
    constant BAUD_RATE      : integer := 1152000;     -- 1.152 MBaud rate
    constant CYCLES_PER_BIT : integer := CLK_FREQ / BAUD_RATE;  -- ~10.4 cycles per bit
    
    -- State machine
    type state_type is (IDLE, BUFFER_READ, PREPARE_BYTE, SEND_START, SEND_DATA, SEND_STOP, NEXT_BYTE);
    signal state : state_type := IDLE;
    
    -- Internal signals
    signal bit_counter     : integer range 0 to 7 := 0;
    signal byte_index      : integer range 0 to 5 := 0;  -- 6 bytes (48 bits) total
    signal buffer_read_ptr : unsigned(7 downto 0) := (others => '0');
    signal buffer_sent_ptr : unsigned(7 downto 0) := (others => '0');
    signal current_data    : std_logic_vector(47 downto 0) := (others => '0');
    signal current_byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal bytes_sent      : unsigned(31 downto 0) := (others => '0');
    signal bit_timer       : integer range 0 to CYCLES_PER_BIT-1 := 0;
    signal transmitting    : std_logic := '0';
    
begin
    -- Output debug info on LEDs
    led_out <= std_logic_vector(bytes_sent(7 downto 0));
    
    -- Connect buffer read address
    buffer_rd_addr <= std_logic_vector(buffer_read_ptr);
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- Reset all signals
            state <= IDLE;
            uart_txd <= '1';  -- Idle high
            bit_counter <= 0;
            byte_index <= 0;
            buffer_read_ptr <= (others => '0');
            buffer_sent_ptr <= (others => '0');
            current_data <= (others => '0');
            current_byte <= (others => '0');
            bytes_sent <= (others => '0');
            bit_timer <= 0;
            transmitting <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    uart_txd <= '1';  -- Idle high
                    bit_timer <= 0;
                    
                    if buffer_wr = '1' and transmitting = '0' then
                        -- Prepare to read from buffer when there's new data
                        buffer_read_ptr <= buffer_sent_ptr;
                        state <= BUFFER_READ;
                        transmitting <= '1';
                    end if;
                    
                when BUFFER_READ =>
                    -- Directly latch the data from the input buffer, don't rely on memory
                    current_data <= buffer_data;
                    byte_index <= 0;
                    state <= PREPARE_BYTE;
                    
                when PREPARE_BYTE =>
                    -- Extract the current byte to send
                    -- Debug: Print the actual bytes in correct order
                    case byte_index is
                        when 0 => current_byte <= current_data(7 downto 0);    -- LSB first
                        when 1 => current_byte <= current_data(15 downto 8);
                        when 2 => current_byte <= current_data(23 downto 16);
                        when 3 => current_byte <= current_data(31 downto 24);
                        when 4 => current_byte <= current_data(39 downto 32);
                        when 5 => current_byte <= current_data(47 downto 40);  -- MSB last
                        when others => current_byte <= x"AA";  -- Changed to 0xAA for debugging
                    end case;
                    state <= SEND_START;
                    
                when SEND_START =>
                    uart_txd <= '0';  -- Start bit
                    bit_counter <= 0;
                    
                    -- Reset bit timer
                    bit_timer <= bit_timer + 1;
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        state <= SEND_DATA;
                    end if;
                    
                when SEND_DATA =>
                    uart_txd <= current_byte(bit_counter);
                    
                    -- Update bit timer
                    bit_timer <= bit_timer + 1;
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        
                        if bit_counter < 7 then
                            bit_counter <= bit_counter + 1;
                        else
                            state <= SEND_STOP;
                        end if;
                    end if;
                    
                when SEND_STOP =>
                    uart_txd <= '1';  -- Stop bit
                    
                    -- Update bit timer
                    bit_timer <= bit_timer + 1;
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        bytes_sent <= bytes_sent + 1;
                        state <= NEXT_BYTE;
                    end if;
                    
                when NEXT_BYTE =>
                    if byte_index < 5 then
                        -- Move to next byte in current data
                        byte_index <= byte_index + 1;
                        state <= PREPARE_BYTE;
                    else
                        -- All bytes from this buffer entry sent
                        buffer_sent_ptr <= buffer_sent_ptr + 1;
                        transmitting <= '0';  -- Ready for next transmission
                        state <= IDLE;
                    end if;
                    
            end case;
        end if;
    end process;
end Behavioral;