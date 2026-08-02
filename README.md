# DE0-CV Ethernet

## About

This project implements a NASDAQ ITCH 5.0 market-data parser on a DE0-CV (Cyclone V) FPGA, receiving Ethernet frames directly through a LAN8720A PHY over RMII, no IP/UDP stack, using a custom ethertype (`0xABF9`) The FPGA deframes incoming frames, parses ITCH Add Order messages, tracks the best bid/offer, and outputs a BUY/SELL/HOLD trading signal as a response frame (`0xABFA`). 

## Setup
<img width="2886" height="2440" alt="image" src="https://github.com/user-attachments/assets/078e5815-cae2-4049-8d86-787ca8005788" />


## Wireshark
<img width="1332" height="52" alt="image" src="https://github.com/user-attachments/assets/e18b5b39-f54e-496c-813f-e32da80627e0" />
The packet being transmitted from PC to FPGA and then back from FPGA to PC.

## Timing Advantage of DE0-CV
<img width="920" height="349" alt="image" src="https://github.com/user-attachments/assets/a7f3c595-153b-44a4-8272-8e72c003d1e9" />

data_valid pulses high at sample 205, once the incoming ITCH frame has passed its CRC-32 check. From there, itch_parser decodes the buffered payload and computes a BUY/SELL/HOLD decision — in this capture, BUY, reflected in signal[1:0] by sample 209. tx_start_pulse, which triggers the response frame, asserts the following cycle at sample 210. Total latency from a validated frame arriving to a trading decision being triggered: 5 samples × 20 ns (50 MHz) = 100 ns.


