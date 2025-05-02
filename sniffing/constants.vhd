library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package constants is
    -- Transmit constants
    constant BAUD_RATE_CONSTANT : integer := 20_000_000;
    
    -- Clock constants
    constant USE_PLL_CONSTANT   : boolean := true;

end package constants;