import struct
import os
import sys

def extract_gpt(bin_file, out_dir):
    required = ['fsc', 'fsg', 'modem', 'modemst1', 'modemst2', 'persist', 'sec']
    if not os.path.exists(bin_file):
        print(f"[!] File {bin_file} tidak ditemukan.")
        sys.exit(1)

    os.makedirs(out_dir, exist_ok=True)
    print(f"[*] Membaca GPT partition table dari {bin_file}...")

    with open(bin_file, 'rb') as f:
        f.seek(512)
        hdr = f.read(92)
        if len(hdr) < 92 or hdr[:8] != b'EFI PART':
            print("[!] Header GPT tidak ditemukan di LBA 1.")
            sys.exit(1)

        part_lba, num_entries, entry_size = struct.unpack('<QII', hdr[72:88])
        f.seek(part_lba * 512)

        extracted_count = 0
        for i in range(num_entries):
            entry = f.read(entry_size)
            if len(entry) < 128 or entry[:16] == b'\x00' * 16:
                continue
            start_lba, end_lba = struct.unpack('<QQ', entry[32:48])
            name = entry[56:128].decode('utf-16le', errors='ignore').rstrip('\x00').lower()

            for req in required:
                if name == req:
                    size_bytes = (end_lba - start_lba + 1) * 512
                    out_path = os.path.join(out_dir, f"{req}.bin")

                    cur_pos = f.tell()
                    f.seek(start_lba * 512)
                    data = f.read(size_bytes)
                    f.seek(cur_pos)

                    with open(out_path, 'wb') as out_f:
                        out_f.write(data)
                    print(f"    [OK] Partisi {req} ({len(data)} bytes) berhasil diekstrak -> {out_path}")
                    extracted_count += 1
                    break

    print(f"[*] Selesai mengekstrak {extracted_count} partisi asli.")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: extract_gpt.py <backup.bin> <output_dir>")
        sys.exit(1)
    extract_gpt(sys.argv[1], sys.argv[2])
