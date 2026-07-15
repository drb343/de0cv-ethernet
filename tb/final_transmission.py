import struct, time, sys, threading
from scapy.all import Ether, Raw, sendp, sniff

IFACE = "Realtek PCIe GbE Family Controller"
DST, SRC, ETYPE_IN = "02:00:00:00:00:01", "02:00:00:00:00:02", 0xABF9
ETYPE_OUT = 0xABFA

SCENARIOS = {
    "buy":  [("B", 170.00)],
    "sell": [("B", 180.00)],
    "hold": [("B", 180.00), ("S", 190.00)],
}

SIGNAL_NAMES = {0: "HOLD", 1: "BUY", 2: "SELL"}
received = []

def handle_pkt(pkt):
    if pkt.haslayer(Ether) and pkt[Ether].type == ETYPE_OUT and pkt.haslayer(Raw):
        payload = bytes(pkt[Raw].load)
        sig_byte = payload[0]
        received.append(sig_byte)
        print(f"  <<< received signal frame: byte=0x{sig_byte:02X} "
              f"({SIGNAL_NAMES.get(sig_byte, 'unknown')})")

def send(side, price):
    payload = struct.pack(">BBII", ord('A'), ord(side), 100,
                          int(round(price * 10000))) + b"AAPL    "
    sendp(Ether(dst=DST, src=SRC, type=ETYPE_IN) / Raw(payload),
          iface=IFACE, verbose=False)
    print(f"  sent side={side} price=${price:.2f}")

if len(sys.argv) != 2 or sys.argv[1] not in SCENARIOS:
    print("usage: python test_signal.py [buy|sell|hold]")
    sys.exit(1)

name = sys.argv[1]
print(f"\n=== {name.upper()} ===")
print(">>> PRESS RESET ON THE BOARD BEFORE CONTINUING <<<")
input("    press Enter once reset is done...")

# Start the sniffer first so we don't miss a fast reply.
sniffer = threading.Thread(
    target=lambda: sniff(iface=IFACE, filter=f"ether proto 0x{ETYPE_OUT:04x}",
                          prn=handle_pkt, timeout=5, store=False),
    daemon=True,
)
sniffer.start()
time.sleep(0.3)  # give Npcap a moment to actually bind before sending

for side, price in SCENARIOS[name]:
    send(side, price)
    time.sleep(0.5)

print("  waiting for FPGA response (5s)...")
sniffer.join()

if not received:
    print("\n  !!! no response frame captured — check ready_signal, tx_start_pulse on SignalTap !!!")
else:
    print(f"\n  {len(received)} response frame(s): {[SIGNAL_NAMES.get(b,'?') for b in received]}")