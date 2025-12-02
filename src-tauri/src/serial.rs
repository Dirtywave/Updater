use std::{io, time::Duration};

use serialport::{SerialPortInfo, UsbPortInfo};
use slip::{process_command, SlipDecoder};

// Bricked/reset Teensy (MicroMod) shows up as:

// {
// 	"action": "add",
// 	"tag": "14908930-Teensy",
// 	"serial": "14908930",
// 	"description": "Teensyduino RawHID",
// 	"model": "Teensy MicroMod",
// 	"location": "usb-1-1",
// 	"capabilities": ["unique", "run", "rtc", "reboot", "serial"],
// 	"interfaces": [
// 		[
// 			"RawHID",
// 			"IOService:/AppleARMPE/arm-io@10F00000/AppleT810xIO/usb-drd1@2280000/AppleT8103USBXHCI@01000000/usb-drd1-port-hs@01100000/Teensyduino RawHID@01100000/IOUSBHostInterface@0/AppleUserUSBHostHIDDevice"
// 		],
// 		[
// 			"Seremu",
// 			"IOService:/AppleARMPE/arm-io@10F00000/AppleT810xIO/usb-drd1@2280000/AppleT8103USBXHCI@01000000/usb-drd1-port-hs@01100000/Teensyduino RawHID@01100000/IOUSBHostInterface@1/AppleUserUSBHostHIDDevice"
// 		]
// 	]
// }

// M8 SLIP Serial Receive command list
// 'S' - Theme Color command: 4 bytes. First byte is index (0 to 12), following 3 bytes is R, G, and B
// 'C' - Joypad/Controller command: 1 byte. Represents all 8 keys in hardware pin order: LEFT|UP|DOWN|SELECT|START|RIGHT|OPT|EDIT
// 'K' - Keyjazz note command: 1 or 2 bytes. First byte is note, second is velocity, if note is zero stops note and does not expect a second byte.
// 'D' - Disable command. Send this command when disconnecting from M8. No extra bytes following
// 'E' - Enable display command: No extra bytes following
// 'R' - Reset display command: No extra bytes following

// M8 SLIP Serial Send command list
// 251 - Joypad key pressed state (hardware M8 only) - sends the keypress state as a single byte in hardware pin order: LEFT|UP|DOWN|SELECT|START|RIGHT|OPT|EDIT
// 252 - Draw oscilloscope waveform command: zero bytes if off - uint8 r, uint8 g, uint8 b, followed by 320 byte value array containing the waveform
// 253 - Draw character command: 12 bytes. char c, int16 x position, int16 y position, uint8 r, uint8 g, uint8 b, uint8 r_background, uint8 g_background, uint8 b_background
// 254 - Draw rectangle command: 12 bytes. int16 x position, int16 y position, int16 width, int16 height, uint8 r, uint8 g, uint8 b

pub mod device;
pub mod provider;
pub mod slip;
pub mod tycmd;

pub const MANUFACTURER_NAME: &str = "DirtyWave";
pub const PRODUCT_NAME: &str = "M8";

pub const DIRTYWAVE_VENDOR_ID: u16 = 5824;
pub const MODEL_2_PRODUCT_ID: u16 = 1162;

pub fn get_usb_port_info(port: &SerialPortInfo) -> Option<UsbPortInfo> {
    if port.port_name.contains("cu") {
        if let serialport::SerialPortType::UsbPort(ref usb_port) = port.port_type {
            return Some(usb_port.clone());
        }
    }

    None
}

pub fn is_usb_serial_port(port: &SerialPortInfo) -> bool {
    Option::is_some(&get_usb_port_info(port))
}

pub fn is_m8_serial_port(port: &SerialPortInfo) -> bool {
    if is_usb_serial_port(port) {
        if let Some(usb_port_info) = get_usb_port_info(port) {
            if usb_port_info.vid == DIRTYWAVE_VENDOR_ID && usb_port_info.pid == MODEL_2_PRODUCT_ID {
                return true;
            }
        }
    }

    false
}

pub fn filter_to_m8_serial_ports(ports: Vec<SerialPortInfo>) -> Vec<SerialPortInfo> {
    ports.into_iter().filter(is_m8_serial_port).collect()
}

pub fn enumerate_m8_serial_ports() -> Vec<SerialPortInfo> {
    let ports = serialport::available_ports().expect("No ports found!");

    filter_to_m8_serial_ports(ports)
}

pub fn get_m8_details(path: &str) {
    let mut port = serialport::new(path, 115_200)
        .data_bits(serialport::DataBits::Eight)
        .parity(serialport::Parity::None)
        .stop_bits(serialport::StopBits::One)
        .flow_control(serialport::FlowControl::None)
        .timeout(Duration::from_millis(10))
        .open()
        .expect("Failed to open port");

    let mut decoder = SlipDecoder::new();
    let mut read_buf = [0u8; 256];

    let output = "E".as_bytes();

    port.write_all(output).expect("Write failed!");

    // Main loop: read bytes from the port, feed them into the SLIP decoder,
    // and process complete packets.
    'loop_outer: loop {
        match port.read(&mut read_buf) {
            Ok(n) if n > 0 => {
                for &byte in &read_buf[..n] {
                    match decoder.process_byte(byte) {
                        Ok(Some(packet)) => {
                            log::info!("Received packet: {:02X?}", packet);
                            process_command(&packet);

                            break 'loop_outer;
                        }
                        Ok(None) => { /* still building a packet */ }
                        Err(e) => {
                            log::info!("SLIP decoding error: {}", e);
                            // Clear the current buffer and reset escape state.
                            decoder.buffer.clear();
                            decoder.escaped = false;

                            break 'loop_outer;
                        }
                    }
                }
            }
            Ok(_) => { /* no data read; continue looping */ }
            Err(ref e) if e.kind() == io::ErrorKind::TimedOut => { /* continue on timeout */ }
            Err(e) => {
                log::info!("Error reading from serial port: {}", e);
            }
        }
    }
}
