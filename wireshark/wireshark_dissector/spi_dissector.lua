-- Create the protocol
local proto_spi = Proto.new("SPI", "SPI Protocol")

-- Function for wireshark to call
function proto_spi.dissector(buffer, pinfo, tree)
end

-- Protocol fields
local field_miso = ProtoField.bool("spi.miso", "MISO", base.NONE)
local field_mosi = ProtoField.bool("spi.mosi", "MOSI", base.NONE)
local field_cs = ProtoField.bool("spi.cs", "CS", base.NONE)
local field_sclk = ProtoField.uint16("spi.sclk", "SCLK", base.DEC)
local field_timestamp = ProtoField.uint32("spi.timestamp", "Timestamp", base.DEC)

-- The thing that is called to display the fields (i think?)
proto_spi.fields = {
  field_miso,
  field_mosi,
  field_cs,
  field_sclk,
  field_timestamp
}

function proto_spi.dissector(buffer, pinfo, tree)
  -- What displays in the "protocol" column
  pinfo.cols.protocol = "SPI Sniffer"

  -- A subtree where the payload is the "buffer" input
  local payload_tree = tree:add("SPI Protocol", buffer())

  -- Making the fields
  local first_byte = buffer(0, 1):uint()
  local second_byte = buffer(1, 1):uint()
  local third_byte = buffer(2, 1):uint()
  local fourth_byte = buffer(3, 1):uint()
  local fifth_byte = buffer(4, 1):uint()
  local sixth_byte = buffer(5, 1):uint()

  -- Timestamp values in last four bytes
  local timestamp = buffer(2, 4):uint() -- the actual timestamp in clock cycles
  local timestamp_bytes = string.format("%d %d %d %d", third_byte, 
                                        fourth_byte, fifth_byte, sixth_byte) -- the four timestamp bytes as string

  -- Extract bits 3-15 (sclk_freq)
  local sclk_freq = bit.rshift(bit.band(first_byte, 0xF8), 3) -- Extract bits 3-7 and shift them to the least significant position
  sclk_freq = bit.bor(sclk_freq, bit.lshift(second_byte, 5)) -- Combine with bits 8-15

  -- Adding all the tree items (displays in the order they are added but columns must be manually configured)
  payload_tree:add(field_cs, buffer(0, 1), bit.band(first_byte, 0x20) ~= 0) -- bit 5
  payload_tree:add(field_miso, buffer(0, 1), bit.band(first_byte, 0x80) ~= 0) -- bit 7
  payload_tree:add(field_mosi, buffer(0, 1), bit.band(first_byte, 0x40) ~= 0) -- bit 6
  payload_tree:add(field_sclk, buffer(0, 2), sclk_freq)
  payload_tree:add(field_timestamp, buffer(2, 4), timestamp):append_text(" (Bytes: ".. timestamp_bytes ..")")

end

-- Register the protocol with Wireshark
spi_table = DissectorTable.get("wtap_encap") -- Use the wtap_encap table for custom DLTs
spi_table:add(147, proto_spi) -- Register your protocol for DLT 147 (USER0)