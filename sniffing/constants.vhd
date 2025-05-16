
-- ============================================================================
--  CONSTANTS
--
--  Description:
--      Global design constants used across the SPI sniffer system.
--
--  Constants:
--      - BAUD_RATE_CONSTANT    : Baud rate for UART transmission
--      - USE_PLL_CONSTANT      : Enable/disable PLL for high-speed clocking
--      - BUFFER_WIDTH_CONSTANT : Data width of the circular buffer
--      - BUFFER_DEPTH_CONSTANT : Depth of the circular buffer (2^BUFFER_DEPTH_CONSTANT)
--
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package constants is
    constant BAUD_RATE_CONSTANT    : integer := 12_000_000;
    constant USE_PLL_CONSTANT      : boolean := true;
    constant BUFFER_WIDTH_CONSTANT : integer := 48;
    constant BUFFER_DEPTH_CONSTANT : integer := 13;
end package constants;
