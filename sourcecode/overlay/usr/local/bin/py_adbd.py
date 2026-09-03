#!/usr/bin/env python3
"""
py_adbd.py - Zero-Auth Standalone ADB Daemon for OpenStick (Snapdragon 410 / MSM8916)
Binds strictly to 192.168.100.1:5555 (Isolated USB RNDIS cable interface)
Runs as user 'user' with full controlling PTY session & job control.
"""

import socket
import struct
import subprocess
import os
import pty
import select
import threading
import sys
import fcntl
import termios

A_SYNC = 0x434e5953
A_CNXN = 0x4e584e43
A_AUTH = 0x48545541
A_OPEN = 0x4e45504f
A_OKAY = 0x59414b4f
A_CLSE = 0x45534c43
A_WRTE = 0x45545257

A_VERSION = 0x01000000
MAX_PAYLOAD = 262144

def make_msg(cmd, arg0, arg1, data=b""):
    data_len = len(data)
    data_crc = sum(data) & 0xFFFFFFFF
    magic = cmd ^ 0xFFFFFFFF
    header = struct.pack("<6I", cmd, arg0, arg1, data_len, data_crc, magic)
    return header + data

def read_msg(sock):
    header = b""
    while len(header) < 24:
        chunk = sock.recv(24 - len(header))
        if not chunk:
            return None, None, None, None
        header += chunk
    cmd, arg0, arg1, data_len, data_crc, magic = struct.unpack("<6I", header)
    if (cmd ^ 0xFFFFFFFF) != magic:
        return None, None, None, None
    data = b""
    while len(data) < data_len:
        chunk = sock.recv(data_len - len(data))
        if not chunk:
            break
        data += chunk
    return cmd, arg0, arg1, data

def handle_client(sock):
    try:
        cmd, arg0, arg1, data = read_msg(sock)
        if cmd != A_CNXN:
            sock.close()
            return

        banner = b"device::ro.product.name=openstick;ro.product.model=OpenStick;ro.product.device=msm8916;features=cmd,stat_v2,ls_v2,fixed_push_mkdir,apex,abb,fixed_push_symlink_timestamp,abb_exec,remount_shell,track_app,sendrecv_v2,sendrecv_v2_brotli,sendrecv_v2_lz4,sendrecv_v2_zstd,sendrecv_v2_dry_run_send,openscreen_mdns;"
        sock.sendall(make_msg(A_CNXN, A_VERSION, MAX_PAYLOAD, banner))

        local_id = 1
        remote_id = None
        master_fd = None
        proc = None

        while True:
            cmd, arg0, arg1, data = read_msg(sock)
            if cmd is None:
                break

            if cmd == A_OPEN:
                remote_id = arg0
                dest = data.strip(b"\x00\r\n\t ").decode("utf-8", errors="ignore")
                sock.sendall(make_msg(A_OKAY, local_id, remote_id))

                master_fd, slave_fd = pty.openpty()

                def setup_controlling_tty(s_fd):
                    def _fn():
                        os.setsid()
                        try:
                            fcntl.ioctl(s_fd, termios.TIOCSCTTY, 0)
                        except Exception:
                            pass
                        try:
                            os.tcsetpgrp(s_fd, os.getpgrp())
                        except Exception:
                            pass
                    return _fn

                shell_cmd = dest[6:].strip() if dest.startswith("shell:") else ""
                if shell_cmd:
                    args = ["/bin/bash", "-c", shell_cmd]
                else:
                    args = ["/bin/bash", "-l"]

                cur_home = "/home/user" if os.path.isdir("/home/user") else "/root"
                child_env = dict(os.environ)
                child_env["TERM"] = "xterm-256color"
                child_env["HOME"] = cur_home
                child_env["USER"] = "user" if cur_home == "/home/user" else "root"
                child_env["LOGNAME"] = child_env["USER"]
                child_env["SHELL"] = "/bin/bash"

                proc = subprocess.Popen(
                    args,
                    stdin=slave_fd,
                    stdout=slave_fd,
                    stderr=slave_fd,
                    close_fds=True,
                    cwd=cur_home,
                    preexec_fn=setup_controlling_tty(slave_fd),
                    env=child_env
                )
                os.close(slave_fd)

                def pty_to_adb():
                    try:
                        while True:
                            r, _, _ = select.select([master_fd], [], [], 0.5)
                            if r:
                                chunk = os.read(master_fd, 4096)
                                if not chunk:
                                    break
                                sock.sendall(make_msg(A_WRTE, local_id, remote_id, chunk))
                            if proc.poll() is not None:
                                break
                    except Exception:
                        pass
                    finally:
                        try:
                            sock.sendall(make_msg(A_CLSE, local_id, remote_id))
                        except Exception:
                            pass

                t = threading.Thread(target=pty_to_adb, daemon=True)
                t.start()

            elif cmd == A_WRTE:
                if master_fd is not None:
                    try:
                        os.write(master_fd, data)
                        sock.sendall(make_msg(A_OKAY, local_id, remote_id))
                    except Exception:
                        pass

            elif cmd == A_OKAY:
                pass

            elif cmd == A_CLSE:
                if proc:
                    proc.terminate()
                if master_fd:
                    os.close(master_fd)
                break
    except Exception:
        pass
    finally:
        sock.close()

def main():
    bind_ip = sys.argv[1] if len(sys.argv) > 1 else "192.168.100.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5555

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((bind_ip, port))
    server.listen(5)
    print(f"[*] ADB Isolated Server listening on {bind_ip}:{port} (USER SHELL)")

    while True:
        client, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(client,), daemon=True)
        t.start()

if __name__ == "__main__":
    main()
