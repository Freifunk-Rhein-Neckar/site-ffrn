#!/usr/bin/env python3
import os
from collections import defaultdict

from jinja2 import Template

# This script is from the ffda Site
# yout can find the original at their repo:
# https://git.darmstadt.ccc.de/ffda/firmware/site/-/blob/master/contrib/genpkglist.py


# path to your gluon checkout, will be used to find targets and devices
GLUON_DIR = '/home/tom/git/Freifunk-Rhein-Neckar/firmware/gluon/'


class PackageList:
    def __init__(self, name: str, pkgs: list):
        self.name = name
        self.pkgs = pkgs

    def __repr__(self):
        return self.name

    def __lt__(self, other):
        return self.name < other.name

    def render(self):
        return Template("""
INCLUDE_{{ name }} := \\
{%- for pkg in pkgs %}
    {{ pkg }}{% if not loop.last %} \\{% endif %}
{%- endfor %}

EXCLUDE_{{ name }} := \\
{%- for pkg in pkgs %}
    -{{ pkg }}{% if not loop.last %} \\{% endif %}
{%- endfor %}""").render(
            name=self.name,
            pkgs=self.pkgs
        )


class Target:
    def __init__(self, name):
        self.name = name
        self.devices = set()
        self.pkglists = set()
        self.excludes = defaultdict(set)

    def add_device(self, device: str):
        self.devices.add(device)

    def add_pkglist(self, pkglist: PackageList):
        self.pkglists.add(pkglist)
        return self

    def exclude(self, devices: list[str], pkglists: list[PackageList]=None):
        for device in devices:
            assert(device in self.devices), "Device %s not in target %s" % (device, self.name)
            if not pkglists:
                self.excludes[device] = self.pkglists
            else:
                self.excludes[device] = self.excludes[device].union(pkglists)

        return self

    def render(self):
        if not self.pkglists:
            return """
# no pkglists for target %s
""" % self.name
        return Template("""
ifeq ($(GLUON_TARGET),{{ target }})
    GLUON_SITE_PACKAGES += {% for pkglist in pkglists %}$(INCLUDE_{{ pkglist.name }}){% if not loop.last %} {% endif %}{% endfor %}
{% for device, exclude in excludes.items() %}
    GLUON_{{ device }}_SITE_PACKAGES += {% for pkglist in exclude|sort %}$(EXCLUDE_{{ pkglist.name }}){% if not loop.last %} {% endif %}{% endfor %}
{%- endfor %}
endif""").render(
            target=self.name,
            pkglists=sorted(self.pkglists),
            excludes=self.excludes
        )


targets = {}
targetdir = os.path.join(GLUON_DIR, 'targets')
for targetfile in os.listdir(targetdir):
    if targetfile in ['generic', 'targets.mk'] or targetfile.endswith('.inc'):
        continue

    target = Target(targetfile)
    with open(os.path.join(targetdir, targetfile)) as handle:
        for line in handle.readlines():
            if line.startswith('device'):
                target.add_device(line.split('\'')[1])

    targets[targetfile] = target


#
# package definitions
#

pkglists = []

PKGS_USB = PackageList('USB', ['usbutils'])
pkglists.append(PKGS_USB)

PKGS_USB_HID = PackageList('USB_HID', [
    'kmod-usb-hid',
    'kmod-hid-generic'
])
pkglists.append(PKGS_USB_HID)

PKGS_USB_SERIAL = PackageList('USB_SERIAL', [
    'kmod-usb-serial',
    'kmod-usb-serial-ftdi',
    'kmod-usb-serial-pl2303'
])
pkglists.append(PKGS_USB_SERIAL)

PKGS_USB_STORAGE = PackageList('USB_STORAGE', [
    'block-mount',
    'blkid',
    'kmod-fs-ext4',
    'kmod-fs-ntfs',
    'kmod-fs-vfat',
    'kmod-usb-storage',
    'kmod-usb-storage-extras',  # Card Readers
    'kmod-usb-storage-uas',     # USB Attached SCSI (UAS/UASP)
    'kmod-nls-base',
    'kmod-nls-cp1250',          # NLS Codepage 1250 (Eastern Europe)
    'kmod-nls-cp437',           # NLS Codepage 437 (United States, Canada)
    'kmod-nls-cp850',           # NLS Codepage 850 (Europe)
    'kmod-nls-cp852',           # NLS Codepage 852 (Europe)
    'kmod-nls-iso8859-1',       # NLS ISO 8859-1 (Latin 1)
    'kmod-nls-iso8859-13',      # NLS ISO 8859-13 (Latin 7; Baltic)
    'kmod-nls-iso8859-15',      # NLS ISO 8859-15 (Latin 9)
    'kmod-nls-iso8859-2',       # NLS ISO 8859-2 (Latin 2)
    'kmod-nls-utf8'             # NLS UTF-8
])
pkglists.append(PKGS_USB_STORAGE)

PKGS_USB_NET = PackageList('USB_NET', [
    'kmod-mii',
    'kmod-usb-net',
    'kmod-usb-net-asix',
    'kmod-usb-net-asix-ax88179',
    'kmod-usb-net-cdc-eem',
    'kmod-usb-net-cdc-ether',
    'kmod-usb-net-cdc-subset',
    'kmod-usb-net-dm9601-ether',
    'kmod-usb-net-hso',
    'kmod-usb-net-ipheth',
    'kmod-usb-net-mcs7830',
    'kmod-usb-net-pegasus',
    'kmod-usb-net-rndis',
    'kmod-usb-net-rtl8152',
    'kmod-usb-net-smsc95xx',
    'ffda-usb-wan-hotplug',
])
pkglists.append(PKGS_USB_NET)

PKGS_PCI = PackageList('PCI', ['pciutils'])
pkglists.append(PKGS_PCI)

PKGS_PCI_NET = PackageList('PCI_NET', [
    'kmod-bnx2'  # Broadcom NetExtreme BCM5706/5708/5709/5716
])
pkglists.append(PKGS_PCI_NET)

PKGS_TLS = PackageList('TLS', [
    'ca-bundle',
    'libustream-openssl'
])
pkglists.append(PKGS_TLS)

#
# package assignment
#

targets.get('ath79-generic'). \
    add_pkglist(PKGS_USB). \
    add_pkglist(PKGS_USB_NET). \
    add_pkglist(PKGS_USB_SERIAL). \
    add_pkglist(PKGS_USB_STORAGE). \
    add_pkglist(PKGS_TLS). \
    exclude([  # devices without usb ports
        'avm-fritz-wlan-repeater-450e',
        'd-link-dap-1330-a1',
        'd-link-dap-1365-a1',
        'd-link-dap-2660-a1',
        'devolo-wifi-pro-1200e',
        'devolo-wifi-pro-1200i',
        'devolo-wifi-pro-1750c',
        'devolo-wifi-pro-1750e',
        'devolo-wifi-pro-1750i',
        'devolo-wifi-pro-1750x',
        'enterasys-ws-ap3705',
        'joy-it-jt-or750i',
        'ocedo-raccoon',
        'openmesh-a40',
        'openmesh-a60',
        'openmesh-mr1750-v1',
        'openmesh-mr1750-v2',
        'openmesh-mr600-v1',
        'openmesh-mr600-v2',
        'openmesh-mr900-v1',
        'openmesh-mr900-v2',
        'openmesh-om2p-hs-v1',
        'openmesh-om2p-hs-v2',
        'openmesh-om2p-hs-v3',
        'openmesh-om2p-hs-v4',
        'openmesh-om2p-lc',
        'openmesh-om2p-v1',
        'openmesh-om2p-v2',
        'openmesh-om2p-v4',
        'openmesh-om5p',
        'openmesh-om5p-ac-v1',
        'openmesh-om5p-ac-v2',
        'openmesh-om5p-an',
        'plasma-cloud-pa300',
        'plasma-cloud-pa300e',
        'siemens-ws-ap3610',
        'tp-link-archer-c2-v3',
        'tp-link-archer-c6-v2',
        'tp-link-archer-c25-v1',
        'tp-link-cpe210-v1',
        'tp-link-cpe210-v2',
        'tp-link-cpe220-v3',
        'tp-link-cpe510-v1',
        'tp-link-cpe510-v2',
        'tp-link-cpe510-v3',
        'tp-link-eap225-outdoor-v1',
        'tp-link-tl-wr810n-v1',
        'tp-link-wbs210-v1',
        'tp-link-wbs210-v2',
        'ubiquiti-nanostation-m-xw',
        'ubiquiti-unifi-ac-lite',
        'ubiquiti-unifi-ac-lr',
        'ubiquiti-unifi-ac-mesh',
        'ubiquiti-unifi-ap',
        'ubiquiti-unifi-ap-pro'
    ], pkglists=[PKGS_USB, PKGS_USB_NET, PKGS_USB_SERIAL, PKGS_USB_STORAGE])

targets.get('lantiq-xrx200'). \
    add_pkglist(PKGS_USB). \
    add_pkglist(PKGS_USB_NET). \
    add_pkglist(PKGS_USB_SERIAL). \
    add_pkglist(PKGS_USB_STORAGE). \
    add_pkglist(PKGS_TLS). \
    exclude([  # devices without usb ports
        'tp-link-td-w8970',
    ], pkglists=[PKGS_USB, PKGS_USB_NET, PKGS_USB_SERIAL, PKGS_USB_STORAGE])

for target in ['ipq40xx-generic', 'ipq806x-generic', 'lantiq-xway', 'mpc85xx-p1010', 'mpc85xx-p1020', 'mvebu-cortexa9', 'ramips-mt7620', 'rockchip-armv8', 'sunxi-cortexa7']:
    targets.get(target). \
        add_pkglist(PKGS_USB). \
        add_pkglist(PKGS_USB_NET). \
        add_pkglist(PKGS_USB_SERIAL). \
        add_pkglist(PKGS_USB_STORAGE). \
        add_pkglist(PKGS_TLS)

targets.get('mpc85xx-p1020').add_pkglist(PKGS_TLS)

for target in ['bcm27xx-bcm2708', 'bcm27xx-bcm2709', 'bcm27xx-bcm2710']:
    targets.get(target). \
        add_pkglist(PKGS_USB). \
        add_pkglist(PKGS_USB_NET). \
        add_pkglist(PKGS_USB_SERIAL). \
        add_pkglist(PKGS_USB_STORAGE). \
        add_pkglist(PKGS_USB_HID). \
        add_pkglist(PKGS_TLS)

targets.get('mediatek-mt7622'). \
    add_pkglist(PKGS_USB). \
    add_pkglist(PKGS_USB_NET). \
    add_pkglist(PKGS_USB_SERIAL). \
    add_pkglist(PKGS_USB_STORAGE). \
    add_pkglist(PKGS_TLS). \
    exclude([  # devices without usb ports
        'ubiquiti-unifi-6-lr'], pkglists=[PKGS_USB, PKGS_USB_NET, PKGS_USB_SERIAL, PKGS_USB_STORAGE])

targets.get('ramips-mt7621'). \
    add_pkglist(PKGS_USB). \
    add_pkglist(PKGS_USB_NET). \
    add_pkglist(PKGS_USB_SERIAL). \
    add_pkglist(PKGS_USB_STORAGE). \
    add_pkglist(PKGS_TLS). \
    exclude([  # devices without usb ports
        'netgear-ex6150',
        'ubiquiti-edgerouter-x',
        'ubiquiti-edgerouter-x-sfp'], pkglists=[PKGS_USB, PKGS_USB_NET, PKGS_USB_SERIAL, PKGS_USB_STORAGE])

targets.get('ramips-mt76x8'). \
    add_pkglist(PKGS_USB). \
    add_pkglist(PKGS_USB_NET). \
    add_pkglist(PKGS_USB_SERIAL). \
    add_pkglist(PKGS_USB_STORAGE). \
    add_pkglist(PKGS_TLS). \
    exclude([   # devices without usb ports
        'cudy-wr1000',
        'gl.inet-vixmini',
        'tp-link-archer-c50-v3',
        'tp-link-archer-c50-v4',
        'tp-link-tl-wa801nd-v5',
        'tp-link-tl-wr841n-v13'], pkglists=[PKGS_USB, PKGS_USB_NET, PKGS_USB_SERIAL, PKGS_USB_STORAGE])

for target in ['x86-64', 'x86-generic', 'x86-geode']:
    targets.get(target). \
        add_pkglist(PKGS_USB). \
        add_pkglist(PKGS_USB_NET). \
        add_pkglist(PKGS_USB_SERIAL). \
        add_pkglist(PKGS_USB_STORAGE). \
        add_pkglist(PKGS_PCI). \
        add_pkglist(PKGS_PCI_NET). \
        add_pkglist(PKGS_TLS)


if __name__ == '__main__':
    for pkglist in pkglists:
        print(pkglist.render())

    for target in sorted(targets.values(), key=lambda x: x.name):
        print(target.render())
