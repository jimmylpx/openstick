import sys
import os
import struct

def parse_gpt(dump_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    with open(dump_path, 'rb') as f:
        # Check MBR/GPT header at sector 1 (512)
        f.seek(512)
        header = f.read(512)
        if header[:8] != b'EFI PART':
            print(f"[!] Error: {dump_path} does not have valid EFI PART header at sector 1")
            return False

        part_entry_lba, num_parts, part_entry_size = struct.unpack('<QLL', header[72:72+16])
        f.seek(part_entry_lba * 512)
        entries_data = f.read(num_parts * part_entry_size)

        wanted = ['fsc', 'fsg', 'modem', 'modemst1', 'modemst2', 'persist', 'sec']
        extracted = []

        for i in range(num_parts):
            entry = entries_data[i*part_entry_size : (i+1)*part_entry_size]
            if len(entry) < 128:
                continue
            type_guid = entry[:16]
            if type_guid == b'\x00'*16:
                continue

            first_lba, last_lba = struct.unpack('<QQ', entry[32:48])
            raw_name = entry[56:128].decode('utf-16le', errors='ignore').rstrip('\x00')

            if raw_name.lower() in wanted or raw_name in wanted:
                name = raw_name.lower()
                offset = first_lba * 512
                size = (last_lba - first_lba + 1) * 512
                out_path = os.path.join(out_dir, f"{name}.bin")

                f.seek(offset)
                data = f.read(size)
                with open(out_path, 'wb') as out_f:
                    out_f.write(data)
                print(f"[✓] Extracted {name}.bin ({size / 1024 / 1024:.2f} MB, offset: {hex(offset)})")
                extracted.append(name)

        print(f"[OK] Total extracted partitions: {len(extracted)} -> {out_dir}")
        return True

if __name__ == '__main__':
    dump = sys.argv[1] if len(sys.argv) > 1 else 'HM.bin'
    out = sys.argv[2] if len(sys.argv) > 2 else 'stock_extracted'
    parse_gpt(dump, out)
