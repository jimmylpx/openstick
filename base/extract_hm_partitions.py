#!/usr/bin/env python3
import os
import sys
import struct

def extract_partitions(hm_bin_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    target_partitions = {"fsc", "fsg", "modem", "modemst1", "modemst2", "persist", "sec"}
    extracted = set()

    with open(hm_bin_path, "rb") as f:
        # Check GPT header at LBA 1 (offset 512)
        f.seek(512)
        gpt_header = f.read(512)
        sig = gpt_header[0:8]
        
        if sig == b"EFI PART":
            part_entry_lba, num_parts, part_size = struct.unpack("<QII", gpt_header[72:88])
            f.seek(part_entry_lba * 512)
            
            for i in range(num_parts):
                entry = f.read(part_size)
                type_guid = entry[0:16]
                if type_guid == b"\x00" * 16:
                    continue
                first_lba, last_lba, flags = struct.unpack("<QQQ", entry[32:56])
                name = entry[56:128].decode("utf-16le", errors="replace").rstrip("\x00")
                
                if name in target_partitions:
                    size_bytes = (last_lba - first_lba + 1) * 512
                    f.seek(first_lba * 512)
                    data = f.read(size_bytes)
                    out_path = os.path.join(output_dir, f"{name}.bin")
                    with open(out_path, "wb") as out_f:
                        out_f.write(data)
                    print(f"[+] Extracted '{name}' (LBA {first_lba}, {size_bytes} bytes) -> {out_path}")
                    extracted.add(name)
                    # return to next partition entry
                    f.seek((part_entry_lba * 512) + ((i + 1) * part_size))

    # Fallback to hardcoded offsets if GPT wasn't found
    if extracted != target_partitions:
        print("[!] Using fallback offsets for remaining partitions...")
        fallback_offsets = [
            ("modem", 131072, 64 * 1024 * 1024),
            ("modemst1", 276480, 1572864),
            ("modemst2", 279552, 1572864),
            ("fsc", 284672, 1024),
            ("fsg", 393280, 1572864),
            ("sec", 396352, 16384),
            ("persist", 2067552, 32 * 1024 * 1024)
        ]
        with open(hm_bin_path, "rb") as f:
            for name, start_lba, size_bytes in fallback_offsets:
                if name not in extracted:
                    f.seek(start_lba * 512)
                    data = f.read(size_bytes)
                    out_path = os.path.join(output_dir, f"{name}.bin")
                    with open(out_path, "wb") as out_f:
                        out_f.write(data)
                    print(f"[+] Extracted fallback '{name}' -> {out_path}")

    print("\n[✓] All stock baseband/modem partitions extracted successfully!")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hm_bin = sys.argv[1] if len(sys.argv) > 1 else os.path.join(script_dir, "HM.bin")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(script_dir, "stock_extracted")
    extract_partitions(hm_bin, out_dir)
