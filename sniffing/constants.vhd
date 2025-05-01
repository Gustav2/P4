library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package constants is
    -- Transmit constants
    constant BAUD_RATE_CONSTANT : integer := 12_000_000;
    
    -- Clock constants
    constant USE_PLL_CONSTANT   : boolean := false;

end package constants;