library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_tb is
-- Empty entity for testbench
end spi_tb;

architecture Behavioral of spi_tb is
    -- Component declaration for the Unit Under Test (UUT)
    component spi
        Port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            sclk        : in  std_logic;
            miso        : in  std_logic;
            mosi        : in  std_logic;
            cs          : in  std_logic;
            led_miso    : out std_logic;
            led_mosi    : out std_logic;
            led_cs      : out std_logic;
            buffer_data     : out std_logic_vector(7 downto 0);
            buffer_timestamp: out std_logic_vector(31 downto 0);
            buffer_addr     : out std_logic_vector(7 downto 0);
            buffer_wr       : out std_logic
        );
    end component;
    
    -- Testbench constants
    constant CLK_PERIOD : time := 20 ns;        -- 50 MHz system clock
    constant SCLK_PERIOD : time := 200 ns;      -- 5 MHz SPI clock (typical)
    
    -- Testbench signals
    signal clk_tb          : std_logic := '0';
    signal reset_tb        : std_logic := '0';
    signal sclk_tb         : std_logic := '0';
    signal miso_tb         : std_logic := '0';
    signal mosi_tb         : std_logic := '0';
    signal cs_tb           : std_logic := '1';  -- CS active low, initially inactive
    
    -- Output signals
    signal led_miso_tb     : std_logic;
    signal led_mosi_tb     : std_logic;
    signal led_cs_tb       : std_logic;
    signal buffer_data_tb  : std_logic_vector(7 downto 0);
    signal buffer_timestamp_tb : std_logic_vector(31 downto 0);
    signal buffer_addr_tb  : std_logic_vector(7 downto 0);
    signal buffer_wr_tb    : std_logic;
    
    -- SPI test data
    type test_data_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant test_data : test_data_array := (
        X"A5",  -- 10100101
        X"3C",  -- 00111100
        X"F0"   -- 11110000
    );
    
    -- Function to convert std_logic_vector to hex string
    function to_hex_string(slv: std_logic_vector) return string is
        variable result: string(1 to slv'length/4);
        variable v: std_logic_vector(3 downto 0);
        variable c: character;
    begin
        for i in result'range loop
            v := slv((i*4)-1 downto (i-1)*4);
            case v is
                when "0000" => c := '0';
                when "0001" => c := '1';
                when "0010" => c := '2';
                when "0011" => c := '3';
                when "0100" => c := '4';
                when "0101" => c := '5';
                when "0110" => c := '6';
                when "0111" => c := '7';
                when "1000" => c := '8';
                when "1001" => c := '9';
                when "1010" => c := 'A';
                when "1011" => c := 'B';
                when "1100" => c := 'C';
                when "1101" => c := 'D';
                when "1110" => c := 'E';
                when "1111" => c := 'F';
                when others => c := 'X';
            end case;
            result(i) := c;
        end loop;
        return result;
    end function;
    
    -- Simulation control
    signal sim_done : boolean := false;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: spi
    port map (
        clk => clk_tb,
        reset => reset_tb,
        sclk => sclk_tb,
        miso => miso_tb,
        mosi => mosi_tb,
        cs => cs_tb,
        led_miso => led_miso_tb,
        led_mosi => led_mosi_tb,
        led_cs => led_cs_tb,
        buffer_data => buffer_data_tb,
        buffer_timestamp => buffer_timestamp_tb,
        buffer_addr => buffer_addr_tb,
        buffer_wr => buffer_wr_tb
    );
    
    -- Clock generation process for system clock
    clk_process: process
    begin
        while not sim_done loop
            clk_tb <= '0';
            wait for CLK_PERIOD/2;
            clk_tb <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- SPI Clock generation process
    spi_clk_process: process
    begin
        while not sim_done loop
            sclk_tb <= '0';
            wait for SCLK_PERIOD/2;
            sclk_tb <= '1';
            wait for SCLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initial reset
        reset_tb <= '0';  -- Active low reset
        wait for 100 ns;
        reset_tb <= '1';  -- Release reset
        wait for 100 ns;
        
        -- Test Case 1: Send multiple bytes through SPI
        for byte_idx in test_data'range loop
            -- Start SPI transaction (CS active low)
            cs_tb <= '0';
            wait for SCLK_PERIOD;
            
            -- Send 8 bits MSB first
            for bit_idx in 7 downto 0 loop
                -- Set MOSI based on test data
                mosi_tb <= test_data(byte_idx)(bit_idx);
                
                -- Set MISO to inverse of MOSI for simple test pattern
                miso_tb <= not test_data(byte_idx)(bit_idx);
                
                -- Wait for a full SCLK cycle
                wait for SCLK_PERIOD;
            end loop;
            
            -- End transaction with CS high
            cs_tb <= '1';
            wait for SCLK_PERIOD * 2;
        end loop;
        
        -- Test Case 2: Check CS signal behavior
        -- Quick toggle of CS
        cs_tb <= '0';
        wait for SCLK_PERIOD/2;
        cs_tb <= '1';
        wait for SCLK_PERIOD;
        
        -- Test Case 3: Continuous data stream
        cs_tb <= '0';
        
        for i in 0 to 15 loop
            -- Alternate MOSI for a simple pattern
            mosi_tb <= not mosi_tb;
            
            -- MISO with a different pattern - FIXED SYNTAX
            if i mod 2 = 0 then
                miso_tb <= not miso_tb;
            end if;
            
            wait for SCLK_PERIOD;
        end loop;
        
        cs_tb <= '1';
        wait for SCLK_PERIOD * 2;
        
        -- Test Case 4: Reset during transfer
        cs_tb <= '0';
        mosi_tb <= '1';
        miso_tb <= '0';
        wait for SCLK_PERIOD * 3;
        
        -- Apply reset in the middle of transaction
        reset_tb <= '0';
        wait for SCLK_PERIOD * 2;
        reset_tb <= '1';
        wait for SCLK_PERIOD * 2;
        
        -- Continue with transfer
        for i in 0 to 7 loop
            mosi_tb <= not mosi_tb;
            wait for SCLK_PERIOD;
        end loop;
        
        cs_tb <= '1';
        wait for SCLK_PERIOD * 4;
        
        -- End simulation
        sim_done <= true;
        wait for 100 ns;
        
        report "Simulation completed successfully";
        wait;
    end process;
    
    -- Monitor process to check output signals
    monitor_proc: process
    begin
        wait until rising_edge(clk_tb);
        
        if buffer_wr_tb = '1' then
            report "Buffer Write: Address = " & 
                   integer'image(to_integer(unsigned(buffer_addr_tb))) & 
                   ", Data = 0x" & to_hex_string(buffer_data_tb) & 
                   ", Timestamp = " & integer'image(to_integer(unsigned(buffer_timestamp_tb)));
        end if;
        
        if sim_done then
            wait;
        end if;
    end process;
    
end Behavioral;