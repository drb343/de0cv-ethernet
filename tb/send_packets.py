from scapy.all import Ether, sendp, Raw

pkt = Ether(
    src="",
    dst="02:00:00:00:00:01",
    type=0xABF9
) / Raw(load=b"buy\x00" * 16)  # 64 bytes payload

sendp(pkt, iface="Realtek PCIe GbE Family Controller", verbose=False)