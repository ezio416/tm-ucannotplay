# c 2025-08-12
# m 2026-02-03

# This Python script will automatically kill the Ubisoft Connect process after a game closes
# Ubisoft Connect has an issue where if it is left running while the PC is put to sleep, it will sign the user out
# It is intended for use with the UCannotPlay plugin in Openplanet - https://openplanet.dev/plugin/UCannotPlay

# Run this script in Task Scheduler:
#   -

import os
import socket
import struct


def main() -> None:
    HOST = '127.0.0.1'
    PORT = 4162

    exe:         str  = ''
    running:     bool = False
    was_running: bool = True
    year:        int  = 0

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind((HOST, PORT))
    sock.listen()
    sock.settimeout(0.5)

    print(f'listening on {HOST}:{PORT}')

    try:
        while True:
            try:
                conn, addr = sock.accept()
                print(f'connected by {addr}')

                if (data := conn.recv(2)):
                    try:
                        year, = struct.unpack('<H', data)
                        print(f'got year: {year}')
                        if year == 2016:
                            exe = 'TrackmaniaTurbo.exe'
                        elif year == 2020:
                            exe = 'Trackmania.exe'
                        else:
                            print(f'invalid year: {year}')
                            exe = ''
                            year = 0

                    except struct.error as e:
                        print(e)
                        year = 0
                        pass

                else:
                    print("no data!")

            except socket.timeout:
                pass

            except Exception as e:
                print(e)
                year = 0

            if not year:
                running = False
                was_running = True
                continue

            print(f'year: {year}, exe: {exe}')

            running = not os.popen(f'tasklist /FI "imagename eq {exe}"').read().startswith('INFO')
            print(f'running: {running}')

            if was_running != running:
                was_running = running

                if not running:
                    print('killing upc process')
                    os.popen('taskkill /F /im "upc.exe"')
                    year = 0

    except KeyboardInterrupt:
        print('KeyboardInterrupt')
        sock.close()


if __name__ == '__main__':
    main()
