from struct import unpack
import struct
from scapy.all import Ether, Raw, sendp

'''

- send a payload of side, shares, price, and stock
- then send a packet using correct DST and SRC

'''
def send_payload(side, shares, price, stock):
    payload = struct.pack(">BBII",
        ord('A'),
        ord(side),
        shares,
        int(price * 10000)
    ) + stock.encode('ascii').ljust(8)

    frame = Ether(dst="02:00:00:00:00:01", src="", type=0xABF9) / Raw(load=payload)
    sendp(frame, iface="Realtek PCIe GbE Family Controller", verbose=False)


with open("07302019.NASDAQ_ITCH50", "rb") as f:
    while True:
        header = f.read(2)
        if len(header) < 2:
            break
        
        # Extract messages of message type A (orders)
        msg_len = unpack(">H", header)[0]
        msg = f.read(msg_len)
        if len(msg) < msg_len:
            break
        
        msg_type = chr(msg[0])

        # Guard to ensure message length being smaller won't disrupt script
        if msg_type != 'A' or len(msg) < 36:
            continue

        stock = msg[24:32].decode('ascii').strip()
        
        # Only look for Apple, APPL, stocks
        if msg_type == 'A' and stock == "AAPL":
            stock_locate = unpack(">H", msg[1:3])[0]
            timestamp = unpack(">Q", b'\x00\x00' + msg[5:11])[0]
            order_ref = unpack(">Q", msg[11:19])[0]
            side = chr(msg[19])
            shares = unpack(">I", msg[20:24])[0]
            stock = msg[24:32].decode('ascii').strip()
            price = unpack(">I", msg[32:36])[0] / 10000.0

            # Convert stock information into payload
            send_payload(side, shares, price, stock)
            break

            # Print for debugging

            '''
            print(type(shares))
            print(type(side))
            print(type(price))
            
            print(f"type:      Add Order")
            print(f"stock:     {stock}")
            print(f"side:      {'BUY' if side == 'B' else 'SELL'}")
            print(f"shares:    {shares}")
            print(f"price:     ${price:.4f}")
            print(f"order_ref: {order_ref}")
            print(f"timestamp: {timestamp} ns")
            print("\n")
            break
            '''

