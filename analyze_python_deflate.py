import zlib
import io

compressed = bytes.fromhex('0b c9 c8 2c 56 00 a2 e4 fc dc 82 a2 d4 e2 e2 d4 14 85 f2 cc 92 0c 05 df 60 dd 28 cf 00 2e b0 74 62 4e 71 3e 1e 35 00')

print(f"Compressed size: {len(compressed)} bytes = {len(compressed) * 8} bits")

# Create a decompressor with detailed tracking
class TrackingBytesIO(io.BytesIO):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.bytes_read = 0

    def read(self, size=-1):
        data = super().read(size)
        self.bytes_read += len(data)
        return data

tracked_input = TrackingBytesIO(compressed)
dec = zlib.decompressobj(-15)  # -15 for raw deflate

output = b''
chunk_size = 1  # Read 1 byte at a time to track consumption
while True:
    chunk = tracked_input.read(chunk_size)
    if not chunk:
        break
    try:
        decompressed = dec.decompress(chunk)
        output += decompressed
        print(f"After reading {tracked_input.bytes_read} bytes ({tracked_input.bytes_read * 8} bits): decompressed {len(output)} bytes")
    except Exception as e:
        print(f"Error after {tracked_input.bytes_read} bytes: {e}")
        break

# Final decompress
if hasattr(dec, 'flush'):
    final = dec.flush()
    output += final
    if final:
        print(f"Flush produced {len(final)} more bytes")

unused = dec.unused_data
print(f"\nFinal results:")
print(f"  Total input consumed: {tracked_input.bytes_read} bytes ({tracked_input.bytes_read * 8} bits)")
print(f"  Total output: {len(output)} bytes")
print(f"  Unused data: {len(unused)} bytes: {unused.hex() if unused else 'none'}")
print(f"  EOF reached: {dec.eof}")
print(f"  Decompressed: {output!r}")
