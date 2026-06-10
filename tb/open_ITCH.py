with open("07302019.NASDAQ_ITCH50", "rb") as f:
    data = f.read(1000)  # read first 100 bytes

print(data)