# DE0-CV Ethernet

## Timing Advantage of DE0-CV
<img width="920" height="349" alt="image" src="https://github.com/user-attachments/assets/a7f3c595-153b-44a4-8272-8e72c003d1e9" />

data_valid pulses high at sample 205, once the incoming ITCH frame has passed its CRC-32 check. From there, itch_parser decodes the buffered payload and computes a BUY/SELL/HOLD decision — in this capture, BUY, reflected in signal[1:0] by sample 209. tx_start_pulse, which triggers the response frame, asserts the following cycle at sample 210. Total latency from a validated frame arriving to a trading decision being triggered: 5 samples × 20 ns (50 MHz) = 100 ns.


