#!/usr/bin/env python

import sys
import argparse
import glob
import os

import openrazer.client
import openrazer.client.constants as c


def ripple_single_type() -> callable:
    """
    Creates a simple callable which will convert int, int, int, float
    :return: Function
    :rtype: callable
    """
    count = 0

    def parse(arg_value):
        nonlocal count

        if count < 3:
            count += 1
            try:
                return int(arg_value)
            except ValueError:
                raise argparse.ArgumentTypeError("{0} is not an integer".format(arg_value))
        try:
            return float(arg_value)
        except ValueError:
            raise argparse.ArgumentTypeError("{0} is not a float".format(arg_value))
    return parse

def write_string(driver_path, device_file, payload):
    with open(os.path.join(driver_path, device_file), 'w') as open_file:
        open_file.write(payload)


def find_devices(vid, pids):
    for pid in pids:
        driver_paths = glob.glob(os.path.join('/sys/bus/hid/drivers/razerkbd', '*:{0:04X}:{1:04X}.*'.format(vid, pid)))

        for driver_path in driver_paths:
            device_type_path = os.path.join(driver_path, 'device_type')

            if os.path.exists(device_type_path):
                yield driver_path


parser = argparse.ArgumentParser()
action = parser.add_mutually_exclusive_group(required=True)
action.add_argument('--breath-random', action='store_true')
action.add_argument('--breath-single', nargs=3, metavar=('R', 'G', 'B'), type=int)
action.add_argument('--breath-dual', nargs=6, metavar=('R1', 'G1', 'B1', 'R2', 'G2', 'B2'), type=int)
action.add_argument('--reactive', nargs=4, metavar=('TIME', 'R', 'G', 'B'), type=int)
action.add_argument('--spectrum', action='store_true')
action.add_argument('--starlight-single', nargs=3, metavar=('R', 'G', 'B'), type=int)
action.add_argument('--static', nargs=3, metavar=('R', 'G', 'B'), type=int)
action.add_argument('--wave', metavar='DIRECTION', choices=('LEFT', 'RIGHT'), type=str)
action.add_argument('--ripple-single', nargs=4, metavar='R G B REFRESH_RATE', type=ripple_single_type())
action.add_argument('--ripple-random', metavar='REFRESH_RATE', type=float)
action.add_argument('--brightness', nargs=1, metavar='B', type=int)
action.add_argument('--test', action='store_true')

args = parser.parse_args()

device_manager = openrazer.client.DeviceManager()
keyboard = None

for device in device_manager.devices:
    if device.type == 'keyboard':
        keyboard = device
        break
else:
    if not args.test:
        print("Could not find suitable keyboard", file=sys.stderr)
    sys.exit(1)

if args.test:
    sys.exit(0)

elif args.breath_random:
    if keyboard.fx.has("breath_random"):
        keyboard.fx.breath_random()
    else:
        print("Keyboard doesn't support random breath mode", file=sys.stderr)
        sys.exit(1)

elif args.breath_single is not None:
    r, g, b = args.breath_single
    assert 0 <= r <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b <= 255, "Blue component must be between 0-255 inclusive"

    if keyboard.fx.has("breath_single"):
        keyboard.fx.breath_single(r, g, b)
    else:
        print("Keyboard doesn't support single breath mode", file=sys.stderr)
        sys.exit(1)

elif args.breath_dual is not None:
    r1, g1, b1, r2, g2, b2 = args.breath_dual
    assert 0 <= r1 <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g1 <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b1 <= 255, "Blue component must be between 0-255 inclusive"
    assert 0 <= r2 <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g2 <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b2 <= 255, "Blue component must be between 0-255 inclusive"

    if keyboard.fx.has("breath_dual"):
        keyboard.fx.breath_dual(r1, g1, b1, r2, g2, b2)
    else:
        print("Keyboard doesn't support dual breath mode", file=sys.stderr)
        sys.exit(1)

elif args.brightness is not None:
    assert 0 <= args.brightness[0] <= 255, "Brightness must be between 0-255 inclusive"
    b = args.brightness[0] * 255 / 100

    found_chroma = False
    for index, driver_path in enumerate(find_devices(0x1532, [0x021E, 0x022A]), start=1):
        found_chroma = True
        write_string(driver_path, 'matrix_brightness', str(b))
        break

    if not found_chroma:
        print("Keyboard not found", file=sys.stderr)
        sys.exit(1)

elif args.reactive is not None:
    t, r, g, b = args.reactive
    assert t in (c.REACTIVE_500MS, c.REACTIVE_1000MS, c.REACTIVE_1500MS, c.REACTIVE_2000MS)
    assert 0 <= r <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b <= 255, "Blue component must be between 0-255 inclusive"

    if keyboard.fx.has("reactive"):
        keyboard.fx.reactive(t, r, g, b)
    else:
        print("Keyboard doesn't support reactive mode", file=sys.stderr)
        sys.exit(1)

elif args.spectrum:
    if keyboard.fx.has("spectrum"):
        keyboard.fx.spectrum()
    else:
        print("Keyboard doesn't support spectrum mode", file=sys.stderr)
        sys.exit(1)

elif args.static is not None:
    r, g, b = args.static
    assert 0 <= r <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b <= 255, "Blue component must be between 0-255 inclusive"

    if keyboard.fx.has("static"):
        keyboard.fx.static(r, g, b)
    else:
        print("Keyboard doesn't support static mode", file=sys.stderr)
        sys.exit(1)

elif args.starlight_single is not None:
    r, g, b = args.starlight_single
    assert 0 <= r <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b <= 255, "Blue component must be between 0-255 inclusive"

    if keyboard.fx.has('starlight_single'):
      keyboard.fx.starlight_single(r, g, b, c.STARLIGHT_FAST)
    else:
        print("Keyboard doesn't support starlight-single mode", file=sys.stderr)
        sys.exit(1)

elif args.wave is not None:
    direction = args.wave
    if direction == 'LEFT':
        direction = c.WAVE_LEFT
    else:
        direction = c.WAVE_RIGHT

    if keyboard.fx.has("wave"):
        keyboard.fx.wave(direction)
    else:
        print("Keyboard doesn't support wave mode", file=sys.stderr)
        sys.exit(1)

elif args.ripple_single:
    r, g, b, refresh_rate = args.ripple_single
    assert 0 <= r <= 255, "Red component must be between 0-255 inclusive"
    assert 0 <= g <= 255, "Green component must be between 0-255 inclusive"
    assert 0 <= b <= 255, "Blue component must be between 0-255 inclusive"
    assert refresh_rate > 0, "Refresh rate cannot be negative"

    if keyboard.fx.has("ripple"):
        keyboard.fx.ripple(r, g, b, refresh_rate)
    else:
        print("Keyboard doesn't support static mode", file=sys.stderr)
        sys.exit(1)

elif args.ripple_random:
    refresh_rate = args.ripple_random
    assert refresh_rate > 0, "Refresh rate cannot be negative"

    if keyboard.fx.has("ripple"):
        keyboard.fx.ripple_random(refresh_rate)
    else:
        print("Keyboard doesn't support static mode", file=sys.stderr)
        sys.exit(1)

else:
    # Logically impossible to reach here
    print("Unknown option", file=sys.stderr)
    sys.exit(1)
