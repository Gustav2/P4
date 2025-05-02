library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;
use std.env.all;

entity uart_transmitter_tb is
end uart_transmitter_tb;

architecture sim of uart_transmitter_tb is

    -- DUT Ports
    signal clk             : std_logic := '0';
    signal reset           : std_logic := '0';
    signal uart_txd        : std_logic;
    signal buffer_data     : std_logic_vector(47 downto 0) := (others => '0');
    signal buffer_wr       : std_logic := '0';
    signal buffer_rd_addr  : std_logic_vector(7 downto 0);
    signal tx_busy         : std_logic;
    signal tx_done         : std_logic;
    
    function get_clk_period(use_pll : boolean) return time is
    begin
        if use_pll then
            return 5 ns;        -- 200MHz with PLL
        else
            return 83.333 ns;   -- 12MHz base clock
        end if;
    end function;
    -- Clock constants
    constant CLK_PERIOD : time := get_clk_period(USE_PLL_CONSTANT);  -- ~12 MHz

begin

    -- Clock generation
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Instantiate the DUT
    uut: entity work.uart_transmitter
    generic map (
        USE_PLL_CONSTANT   => USE_PLL_CONSTANT,
        BAUD_RATE_CONSTANT => BAUD_RATE_CONSTANT
    )
    port map (
        clk             => clk,
        reset           => reset,
        uart_txd        => uart_txd,
        buffer_data     => buffer_data,
        buffer_wr       => buffer_wr,
        buffer_rd_addr  => buffer_rd_addr,
        tx_busy         => tx_busy,
        tx_done         => tx_done
    );

    -- Stimulus process
    stim_proc: process
    begin
        -- Hold reset high for a few clock cycles
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';

        wait for 5 * CLK_PERIOD;
        
        buffer_data <= x"48656c6c6f20";  -- "HELLO " in ASCII
        buffer_wr   <= '1';
        wait for CLK_PERIOD;
        buffer_wr   <= '0';
        
        -- Wait for transmission to complete using tx_done signal
        wait until tx_done = '1';
        wait for CLK_PERIOD;  -- Allow one extra clock cycle after tx_done
        
        buffer_data <= x"526f68646520";
        buffer_wr   <= '1';
        wait for CLK_PERIOD;
        buffer_wr   <= '0';
        
        -- Wait for transmission to complete using tx_done signal
        wait until tx_done = '1';
        wait for CLK_PERIOD;  -- Allow one extra clock cycle after tx_done
        
        buffer_data <= x"616e64205363";
        buffer_wr   <= '1';
        wait for CLK_PERIOD;
        buffer_wr   <= '0';
        
        -- Wait for transmission to complete using tx_done signal
        wait until tx_done = '1';
        wait for CLK_PERIOD;  -- Allow one extra clock cycle after tx_done
        
        buffer_data <= x"687761727a20";
        buffer_wr   <= '1';
        wait for CLK_PERIOD;
        buffer_wr   <= '0';
        
        -- Wait for transmission to complete using tx_done or tx_busy signals
        wait until tx_done = '1';
        wait for CLK_PERIOD;  -- Allow one extra clock cycle after tx_done
        
        std.env.stop;
    end process;
end sim;