"""Capture an explicitly selected Android device; no install or data reset."""
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', help='Output capture name (letters, digits, _ or -)')
    parser.add_argument('--adb', help='Full path to adb executable')
    parser.add_argument('--sdk', help='Android SDK root; otherwise ANDROID_SDK_ROOT/ANDROID_HOME')
    parser.add_argument('--serial', help='Device serial; optional only with exactly one device')
    parser.add_argument('--output', type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[1] / 'build' / 'sync-device')
    args = parser.parse_args(argv)
    if not re.fullmatch(r'[\w-]+', args.name):
        parser.error('name may contain only letters, digits, _ and -')
    return args


def resolve_adb(args):
    if args.adb:
        return args.adb
    sdk = args.sdk or os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
    if sdk:
        return str(pathlib.Path(sdk) / 'platform-tools' / ('adb.exe' if os.name == 'nt' else 'adb'))
    executable = shutil.which('adb')
    if executable:
        return executable
    raise RuntimeError('Set --adb, --sdk or ANDROID_SDK_ROOT to select the Android SDK.')


def main(argv=None):
    args = parse_args(argv)
    executable = resolve_adb(args)
    serial = args.serial
    if not serial:
        rows = subprocess.check_output([executable, 'devices'], timeout=30).decode().splitlines()[1:]
        devices = [row.split()[0] for row in rows if len(row.split()) == 2 and row.split()[1] == 'device']
        if len(devices) != 1:
            raise RuntimeError('Use --serial: exactly one ready device is required for automatic selection.')
        serial = devices[0]
    adb = [executable, '-s', serial]
    args.output.mkdir(parents=True, exist_ok=True)
    remote = f'/sdcard/lanjiao-capture-{uuid.uuid4().hex}.xml'
    try:
        dump = subprocess.run(adb + ['shell', 'uiautomator', 'dump', remote],
                              check=False, capture_output=True, timeout=30)
        png = subprocess.check_output(adb + ['exec-out', 'screencap', '-p'], timeout=30)
        (args.output / (args.name + '.png')).write_bytes(png)
        xml = subprocess.run(adb + ['exec-out', 'cat', remote], check=False,
                             capture_output=True, timeout=30).stdout
        if dump.returncode != 0 or not xml.startswith(b'<?xml'):
            print('UI hierarchy unavailable (animated page); screenshot saved.')
            return
        (args.output / (args.name + '.xml')).write_bytes(xml)
        for node in ET.fromstring(xml).iter('node'):
            label = node.get('text') or node.get('content-desc')
            if label:
                print(label.replace('\n', ' / '), node.get('bounds'))
    finally:
        subprocess.run(adb + ['shell', 'rm', '-f', remote], check=False,
                       capture_output=True, timeout=30)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
