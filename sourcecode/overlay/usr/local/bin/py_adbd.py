#!/usr/bin/env python3
"""
py_adbd.py - Zero-Auth Standalone ADB Daemon for OpenStick (Snapdragon 410 / MSM8916)
Binds strictly to 192.168.100.1:5555 (Isolated USB RNDIS cable interface)
Direct interactive root shell with PTY ANSI terminal support.
"""

import sys
import os
import pty
import socket
import select
import struct
import threading

A_SYNC = 0x434e5953
A_CNXN = 0x4e584e43
A_OPEN = 0x4e45504f
A_OKAY = 0x59414b4f
A_CLSE = 0x45534c43
A_WRTE = 0x45545257
A_AUTH = 0x48545541

A_VERSION = 0x01000000
MAX_PAYLOAD = 4096

def pack_msg(cmd, arg0, arg1, data=b''):
    data_len = len(data)
    crc = sum(data) & 0xffffffff if data else 0
    magic = cmd ^ 0xffffffff
    hdr = struct.pack('<6I', cmd, arg0, arg1, data_len, crc, magic)
    return hdr + data

def read_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)

def handle_client(sock, addr):
    local_id_counter = 1
    streams = {} # local_id -> (master_fd, pid, remote_id)
    streams_lock = threading.Lock()

    try:
        while True:
            hdr_bytes = read_exact(sock, 24)
            if not hdr_bytes:
                break
            cmd, arg0, arg1, data_len, data_crc, magic = struct.unpack('<6I', hdr_bytes)
            if (cmd ^ 0xffffffff) != magic:
                break

            data = read_exact(sock, data_len) if data_len > 0 else b''

            if cmd == A_CNXN:
                # Banner: device::ro.product.name=msm8916;ro.product.model=OpenStick;ro.product.device=openstick;
                banner = b'device::ro.product.name=msm8916;ro.product.model=OpenStick;ro.product.device=openstick;features=shell_v2,cmd,stat_v2,ls_v2,fixed_push_mkdir,apex,abb,fixed_push_symlink_timestamp,abb_exec,remount_shell,track_app,sendrecv_v2,sendrecv_v2_brotli,sendrecv_v2_lz4,sendrecv_v2_zstd,sendrecv_v2_dry_run_send,openscreen_mdns;'
                resp = pack_msg(A_CNXN, A_VERSION, MAX_PAYLOAD, banner)
                sock.sendall(resp)

            elif cmd == A_OPEN:
                remote_id = arg0
                service = data.decode('utf-8', errors='ignore').rstrip('\x00')
                local_id = local_id_counter
                local_id_counter += 1

                # Spawn interactive PTY root shell
                master_fd, slave_fd = pty.openpty()
                pid = os.fork()
                if pid == 0:
                    os.close(master_fd)
                    os.setsid()
                    os.dup2(slave_fd, 0)
                    os.dup2(slave_fd, 1)
                    os.dup2(slave_fd, 2)
                    if slave_fd > 2:
                        os.close(slave_fd)
                    
                    os.environ['TERM'] = 'xterm-256color'
                    os.environ['HOME'] = '/root'
                    os.environ['USER'] = 'root'
                    os.environ['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
                    
                    if service.startswith('shell:'):
                        cmd_to_run = service[6:].strip()
                        if cmd_to_run:
                            os.execlp('/bin/bash', 'bash', '-c', cmd_to_run)
                        else:
                            os.execlp('/bin/bash', 'bash', '-l')
                    else:
                        os.execlp('/bin/bash', 'bash', '-l')
                    sys.exit(0)
                else:
                    os.close(slave_fd)
                    with streams_lock:
                        streams[local_id] = (master_fd, pid, remote_id)
                    sock.sendall(pack_msg(A_OKAY, local_id, remote_id))

                    def pty_reader(lid, mfd, rid):
                        try:
                            while True:
                                r, _, _ = select.select([mfd], [], [], 0.5)
                                if r:
                                    out = os.read(mfd, 1024)
                                    if not out:
                                        break
                                    sock.sendall(pack_msg(A_WRTE, lid, rid, out))
                        except Exception:
                            pass
                        finally:
                            try:
                                sock.sendall(pack_msg(A_CLSE, lid, rid))
                            except Exception:
                                pass
                            with streams_lock:
                                if lid in streams:
                                    del streams[lid]
                            try:
                                os.close(mfd)
                            except Exception:
                                pass

                    t = threading.Thread(target=pty_reader, args=(local_id, master_fd, remote_id), daemon=True)
                    t.start()

            elif cmd == A_WRTE:
                local_id = arg1
                with streams_lock:
                    st = streams.get(local_id)
                if st:
                    master_fd, pid, remote_id = st
                    try:
                        os.write(master_fd, data)
                        sock.sendall(pack_msg(A_OKAY, local_id, remote_id))
                    except Exception:
                        pass

            elif cmd == A_CLSE:
                local_id = arg1
                with streams_lock:
                    st = streams.pop(local_id, None)
                if st:
                    master_fd, pid, remote_id = st
                    try:
                        os.close(master_fd)
                        os.kill(pid, 9)
                    except Exception:
                        pass

    except Exception:
        pass
    finally:
        with streams_lock:
            for lid, (mfd, pid, rid) in list(streams.items()):
                try:
                    os.close(mfd)
                    os.kill(pid, 9)
                except Exception:
                    pass
            streams.clear()
        sock.close()

def main():
    bind_ip = sys.argv[1] if len(sys.argv) > 1 else '192.168.100.1'
    bind_port = int(sys.argv[2]) if len(sys.argv) > 2 else 5555

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((bind_ip, bind_port))
    srv.listen(5)

    while True:
        try:
            client, addr = srv.accept()
            t = threading.Thread(target=handle_client, args=(client, addr), daemon=True)
            t.start()
        except KeyboardInterrupt:
            break
        except Exception:
            pass

if __name__ == '__main__':
    main()
