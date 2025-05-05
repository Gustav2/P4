-- Grouped SPI Postdissector

local spi_post = Proto("spi_grouped", "Grouped SPI Message")

-- User preferences
spi_post.prefs.bits_per_word = Pref.uint("Bits per word", 8, "Number of bits per words (usually 8)")
spi_post.prefs.packets_per_message = Pref.uint("Words per message", 3, "Number of words in one SPI message")

-- Define fields
local f_group_info = ProtoField.string("spi_grouped.info", "SPI Message Group")
local f_mosi_full_ascii = ProtoField.string("spi_grouped.mosi_full_ascii", "MOSI Full Message (ASCII)")
local f_mosi_full_hex   = ProtoField.string("spi_grouped.mosi_full_hex", "MOSI Full Message (Hex)")
local f_miso_full_ascii = ProtoField.string("spi_grouped.miso_full_ascii", "MISO Full Message (ASCII)")
local f_miso_full_hex   = ProtoField.string("spi_grouped.miso_full_hex", "MISO Full Message (Hex)")

spi_post.fields = { f_group_info, f_mosi_full_ascii, f_mosi_full_hex, f_miso_full_ascii, f_miso_full_hex }

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
        subtree:add(f_mosi_full_hex, bits_to_hex(mosi_bits))

        subtree:add(f_miso_full_ascii, bits_to_ascii(miso_bits, bits_per_word))
        subtree:add(f_miso_full_hex, bits_to_hex(miso_bits))
    end
end

-- Register the dissector
register_postdissector(spi_post)
