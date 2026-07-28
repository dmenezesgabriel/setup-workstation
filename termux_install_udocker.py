#!/usr/bin/env python3
import pexpect
import time
import sys
import re

HOST = "192.168.0.4"
PORT = "8022"
USER = "u0_a357"
PASSWORD = "159357"

def ssh_run(commands, timeout_cmd=30, timeout_total=120):
    child = pexpect.spawn(
        f'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {PORT} {USER}@{HOST}',
        timeout=timeout_total,
        encoding='utf-8',
        codec_errors='replace'
    )
    child.setwinsize(9999, 9999)

    child.expect('password:', timeout=15)
    child.sendline(PASSWORD)
    time.sleep(2)

    results = []
    for cmd in commands:
        marker = f'M4RK3R_{time.time()}'
        child.sendline(f'echo "{marker}"; {cmd}; echo "{marker}_END"')
        try:
            child.expect(f'{marker}_END', timeout=timeout_cmd)
            output = child.before
            # Strip echo of the command itself and markers
            lines = output.splitlines()
            # Remove the line with the echoed command
            filtered = []
            for line in lines:
                stripped = line.strip()
                if marker in stripped or 'echo "' in stripped:
                    continue
                # Remove ANSI escape sequences
                clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', stripped)
                clean = re.sub(r'\x1b\][0-9;]*[^\x07]*\x07', '', clean)
                clean = clean.strip()
                if clean:
                    filtered.append(clean)
            results.append((cmd, filtered))
        except Exception as e:
            results.append((cmd, [f'ERROR: {e}']))

    child.sendline('exit')
    child.expect(pexpect.EOF, timeout=5)
    return results

if __name__ == '__main__':
    results = ssh_run([
        'uname -m',
        'pkg update -y',
        'pkg install udocker -y',
        'udocker version',
        'udocker pull --platform=linux/arm64 alpine:latest',
        'udocker create --name=test alpine:latest',
        'udocker ps',
        'udocker run test /bin/echo "udocker_works_on_android"',
        'udocker rm test',
        'udocker rmi alpine:latest',
    ], timeout_cmd=60)

    for cmd, output in results:
        print(f"\n=== $ {cmd} ===")
        for line in output:
            print(f"  {line}")
