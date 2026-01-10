import zlib

compressed = bytes.fromhex('0b c9 c8 2c 56 00 a2 e4 fc dc 82 a2 d4 e2 e2 d4 14 85 f2 cc 92 0c 05 df 60 dd 28 cf 00 2e b0 74 62 4e 71 3e 1e 35 00')

print(f"Compressed size: {len(compressed)} bytes")

# Create a decompressor
dec = zlib.decompressobj(-15)  # -15 for raw deflate
decompressed = dec.decompress(compressed)
unused = dec.unused_data

print(f"Decompressed size: {len(decompressed)} bytes")
print(f"Decompressed: {decompressed}")
print(f"Unused data: {len(unused)} bytes: {unused.hex() if unused else 'none'}")
print(f"EOF reached: {dec.eof}")
