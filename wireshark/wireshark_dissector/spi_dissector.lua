-- Create the protocol and subdissector
local proto_spi = Proto.new("SPI", "SPI Protocol")
local spi_post = Proto("0_SPI_Custom", "Grouped SPI Message")

-- User preferences
spi_post.prefs.bits_per_word = Pref.uint("Bits per word", 8, "Number of bits per words (usually 8)")
spi_post.prefs.packets_per_message = Pref.uint("Words per message", 3, "Number of words in one SPI message")
spi_post.prefs.sclk_adjust = Pref.uint("SCLK scaling factor", 131072, "Multiplier to compute SCLK frequency (Hz = raw * factor)")

-- Protocol fields
local f_miso = ProtoField.bool("spi.miso", "MISO", base.NONE, { [1] = "HIGH", [2] = "LOW" })
local f_mosi = ProtoField.bool("spi.mosi", "MOSI", base.NONE, { [1] = "HIGH", [2] = "LOW" })
local f_cs = ProtoField.bool("spi.cs", "CS", base.NONE, { [1] = "HIGH", [2] = "LOW" })
local f_sclk = ProtoField.string("spi.sclk_display", "SCLK")
local f_timestamp = ProtoField.uint32("spi.timestamp", "Timestamp", base.DEC)
local f_group_info = ProtoField.string("spi.info", "SPI Message Group")
local f_mosi_full_ascii = ProtoField.string("spi.mosi_full_ascii", "MOSI Full Message (ASCII)")
local f_mosi_full_hex   = ProtoField.string("spi.mosi_full_hex", "MOSI Full Message (Hex)")
local f_miso_full_ascii = ProtoField.string("spi.miso_full_ascii", "MISO Full Message (ASCII)")
local f_miso_full_hex   = ProtoField.string("spi.miso_full_hex", "MISO Full Message (Hex)")

-- Assigning the fields to the protocol object
proto_spi.fields = {
  f_miso,
  f_mosi,
  f_cs,
  f_sclk,
  f_timestamp,
  f_group_info,
  f_mosi_full_ascii,
  f_mosi_full_hex,
  f_miso_full_ascii,
  f_miso_full_hex 
}

function proto_spi.dissector(buffer, pinfo, tree)
  -- What displays in the "protocol" column
  pinfo.cols.protocol = "SPI Sniffer"

  -- Creating a main tree where the full buffer is included
  local spi_tree = tree:add("SPI Protocol", buffer())

  -- Seperating the bytes
  local first_byte  = buffer(0, 1):uint()
  local second_byte = buffer(1, 1):uint()
  local third_byte  = buffer(2, 1):uint()
  local fourth_byte = buffer(3, 1):uint()
  local fifth_byte  = buffer(4, 1):uint()
  local sixth_byte  = buffer(5, 1):uint()

  -- Extracting the bits
  local cs_bit = bit.band(first_byte, 0x20) ~= 0 -- bit 5
  local mosi_bit = bit.band(first_byte, 0x40) ~= 0 -- bit 6
  local miso_bit = bit.band(first_byte, 0x80) ~= 0 -- bit 7

  -- Timestamp values in last four bytes
  local timestamp = buffer(2, 4):uint() -- the actual timestamp in clock cycles
  local timestamp_bytes = string.format("%d %d %d %d", third_byte, 
                                        fourth_byte, fifth_byte, sixth_byte) -- the four timestamp bytes as string

  -- Extract bits 3-15 (sclk_freq)
  local first_sclk_freq = bit.band(first_byte, 0x1F) -- bit 0-4
  local second_sclk_freq = buffer(1, 1):uint() -- bit 8-15
  
  local sclk_freq = bit.lshift(first_sclk_freq, 8) + second_sclk_freq -- combine the two bytes
  local sclk_adjust = spi_post.prefs.sclk_adjust
  local mhz_sclk_freq = (sclk_freq * sclk_adjust) / 1000000 -- Convert to MHz
  local display_sclk_freq = mhz_sclk_freq >= 1 and string.format("%.1f MHz", mhz_sclk_freq) or string.format("%d kHz", mhz_sclk_freq * 1000)

  -- Adding subtrees for each field (this is the order they will be displayed in the subtree)
  spi_tree:add(f_mosi, buffer(0, 1), mosi_bit)
  spi_tree:add(f_miso, buffer(0, 1), miso_bit)
  spi_tree:add(f_cs, buffer(0, 1), cs_bit)
  spi_tree:add(f_sclk, buffer(0, 2), display_sclk_freq)
  spi_tree:add(f_timestamp, buffer(2, 4), timestamp):append_text(" (Bytes: ".. timestamp_bytes ..")")
end

-- Global data (reset at each capture load)
local packet_bits = {} -- indexed by packet number

-- Convert bit list to ASCII string (non-printables = '.')
local function bits_to_ascii(bits, bits_per_word)
    local result = ""
    local byte, count = 0, 0

    for _, bitval in ipairs(bits) do
        byte = bit.lshift(byte, 1)
        if bitval then byte = bit.bor(byte, 1) end
        count = count + 1

        if count == bits_per_word then
            local char = (byte >= 32 and byte <= 126) and string.char(byte) or "."
            result = result .. char
            byte = 0
            count = 0
        end
    end

    -- Handle partial word at end
    if count > 0 then
        byte = bit.lshift(byte, (bits_per_word - count))
        local char = (byte >= 32 and byte <= 126) and string.char(byte) or "."
        result = result .. char
    end

    return result
end

-- Convert bit list to Hex string
local function bits_to_hex(bits)
    local result = ""
    local byte, count = 0, 0

    for _, bitval in ipairs(bits) do
        byte = bit.lshift(byte, 1)
        if bitval then byte = bit.bor(byte, 1) end
        count = count + 1

        if count == 8 then
            result = result .. string.format("%02X", byte)
            byte = 0
            count = 0
        end
    end

    if count > 0 then
        byte = bit.lshift(byte, (8 - count))
        result = result .. string.format("%02X", byte)
    end

    return result
end

function spi_post.dissector(buffer, pinfo, tree)
    if buffer:len() < 1 then return end

    -- Read MOSI and MISO bits from byte
    local b = buffer(0,1):uint()
    local mosi = bit.band(b, 0x40) ~= 0  -- bit 6
    local miso = bit.band(b, 0x80) ~= 0  -- bit 7

    local pkt_num = pinfo.number
    local bits_per_word = spi_post.prefs.bits_per_word
    local group_size = spi_post.prefs.packets_per_message * bits_per_word

    local group_index = math.floor((pkt_num - 1) / group_size) + 1
    local group_pos   = ((pkt_num - 1) % group_size) + 1

    -- Store data
    packet_bits[pkt_num] = { group = group_index, pos = group_pos, mosi = mosi, miso = miso }

    -- Show group info on every packet
    local subtree = tree:add(spi_post, "SPI Message Group Info")
    subtree:add(f_group_info, string.format("Packet %d of Group #%d", group_pos, group_index))

    -- Collect all bits for the group
    local group_data = {}
    for i = 1, group_size do
        local pkt = ((group_index - 1) * group_size) + i
        local d = packet_bits[pkt]
        if not d then return end -- Don't show incomplete group
        table.insert(group_data, d)
    end

    -- Only add full message on last packet of group
    if group_pos == group_size then
        local mosi_bits, miso_bits = {}, {}
        for _, d in ipairs(group_data) do
            table.insert(mosi_bits, d.mosi)
            table.insert(miso_bits, d.miso)
        end

        -- Show both ASCII and Hex
        subtree:add(f_mosi_full_ascii, bits_to_ascii(mosi_bits, bits_per_word))
        subtree:add(f_miso_full_ascii, bits_to_ascii(miso_bits, bits_per_word))

        subtree:add(f_mosi_full_hex, bits_to_hex(mosi_bits))
        subtree:add(f_miso_full_hex, bits_to_hex(miso_bits))
    end
end

-- Register the post-dissector
register_postdissector(spi_post)

-- Register the protocol with Wireshark
spi_table = DissectorTable.get("wtap_encap") -- Use the wtap_encap table for custom DLTs
spi_table:add(147, proto_spi) -- Register your protocol for DLT 147 (USER0)