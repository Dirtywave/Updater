const END: u8 = 0xC0;
const ESC: u8 = 0xDB;
const ESC_END: u8 = 0xDC;
const ESC_ESC: u8 = 0xDD;

/// SLIP decode errors.
#[derive(Debug)]
pub enum SlipError {
    UnrecognizedEscapeByte(u8),
}

impl std::fmt::Display for SlipError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            SlipError::UnrecognizedEscapeByte(b) => {
                write!(f, "Unrecognized escape byte: 0x{:X}", b)
            }
        }
    }
}

impl std::error::Error for SlipError {}

/// A simple SLIP decoder that consumes incoming bytes and yields complete commands.
pub struct SlipDecoder {
    pub buffer: Vec<u8>,
    pub escaped: bool,
}
impl Default for SlipDecoder {
    fn default() -> Self {
        Self::new()
    }
}

impl SlipDecoder {
    pub fn new() -> Self {
        Self {
            buffer: Vec::new(),
            escaped: false,
        }
    }

    /// Process a single byte from the stream.
    ///
    /// Returns `Some(packet)` when an END byte (0xC0) terminates a non-empty command.
    pub fn process_byte(&mut self, byte: u8) -> Result<Option<Vec<u8>>, SlipError> {
        if self.escaped {
            // Process the byte following an escape.
            self.escaped = false;
            match byte {
                ESC_END => self.buffer.push(END),
                ESC_ESC => self.buffer.push(ESC),
                other => return Err(SlipError::UnrecognizedEscapeByte(other)),
            }
        } else {
            match byte {
                ESC => self.escaped = true,
                END => {
                    if !self.buffer.is_empty() {
                        let packet = self.buffer.clone();
                        self.buffer.clear();
                        return Ok(Some(packet));
                    }
                    // Ignore extra END bytes (which can be used as keep-alives).
                }
                other => self.buffer.push(other),
            }
        }
        Ok(None)
    }
}

/// Process and dispatch a received command packet.
///
/// For demonstration, we match on the first byte so that:
/// - 0xFB represents a key command (3-byte packet),
/// - 0xFF represents a system info command (6-byte packet).
pub fn process_command(packet: &[u8]) {
    if packet.is_empty() {
        return;
    }

    match packet[0] {
        0xFB => {
            log::info!("FB Key command packet: {:02X?}", packet);
            if packet.len() >= 3 {
                log::info!("  Keys state: 0x{:02X}", packet[1]);
            }
        }
        0xFF => {
            log::info!("System Info command packet: {:02X?}", packet);
            if packet.len() >= 6 {
                log::info!("  Device Type: {}", packet[1]);

                log::info!(
                    "  Firmware Version: {}.{}.{}",
                    packet[2],
                    packet[3],
                    packet[4]
                );

                log::info!("  Font Mode: {}", packet[5]);
            }
        }
        other => {
            log::info!("Unknown command type (0x{:X}): {:02X?}", other, packet);
        }
    }
}
