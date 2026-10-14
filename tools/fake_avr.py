#!/usr/bin/env python3
"""Fake Denon receiver for testing the app without touching real hardware.

    python3 tools/fake_avr.py [--mute-cycle | --power-cycle] [--port 2323]
    defaults write dev.antoine.SwiftDenon host "127.0.0.1:2323"   # then launch the app

Speaks just enough of the Denon telnet protocol: it pushes a status burst on connect and can
toggle main-zone power or mute every 2 seconds so UI transitions can be observed.
Restore your real address afterwards (Settings > Receiver, or `defaults write` again).
"""
import argparse, socket, threading, time

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=2323)
ap.add_argument("--power-cycle", action="store_true", help="toggle ZMON/ZMOFF every 2s")
ap.add_argument("--mute-cycle", action="store_true", help="toggle MUON/MUOFF every 2s")
args = ap.parse_args()

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", args.port))
srv.listen(5)

def handle(c):
    def send(*lines):
        c.sendall("".join(l + "\r" for l in lines).encode())

    def cycle(on_line, off_line):
        on = True
        while True:
            time.sleep(2)
            on = not on
            try:
                send(on_line if on else off_line)
            except Exception:
                return

    send("PWON", "ZMON", "Z2OFF", "MV385", "MVMAX 98", "SIMPLAY", "NSFRN Fake Amp",
         "SSFUNMPLAY Apple TV", "SSSODMPLAY USE", "SSSODDVD USE", "SSSOD END")
    if args.power_cycle:
        threading.Thread(target=cycle, args=("ZMON", "ZMOFF"), daemon=True).start()
    if args.mute_cycle:
        threading.Thread(target=cycle, args=("MUON", "MUOFF"), daemon=True).start()
    try:
        while c.recv(1024):
            pass
    except Exception:
        pass

print(f"fake AVR on 127.0.0.1:{args.port}")
while True:
    conn, _ = srv.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
