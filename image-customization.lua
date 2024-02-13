-- Generic features and packages for all devices
features({
	'autoupdater',
	'config-mode-geo-location-osm',
	'ebtables-filter-multicast',
	'ebtables-filter-ra-dhcp',
	'ebtables-limit-arp',
	'ebtables-source-filter',
	'mesh-batman-adv-15',
	'mesh-vpn-fastd-l2tp',
	'radvd',
	'radv-filterd',
	'respondd',
	'status-page',
	'web-advanced',
	'web-logging',
	'web-private-wifi',
	'web-wizard',
})

packages({
	'iwinfo',
	'respondd-module-airtime',
})

-- Packages and features for devices which are not flagged as tiny
if not device_class('tiny') then
	packages({
		'ffda-gluon-usteer'
	})

	features({
		'mesh-vpn-sqm',
		'tls',
		'web-cellular',
		'wireless-encryption-wpa3'
	})
end

-- Custom package lists
local pkgs_usb_hid = {
	'kmod-usb-hid',
	'kmod-hid-generic'
}

local pkgs_usb_serial = {
	'kmod-usb-serial',
	'kmod-usb-serial-ch341',
	'kmod-usb-serial-cp210x',
	'kmod-usb-serial-ftdi',
	'kmod-usb-serial-pl2303'
}

local pkgs_usb_storage = {
	'block-mount',
	'blkid',
	'kmod-fs-ext4',
	'kmod-fs-ntfs',
	'kmod-fs-vfat',
	'kmod-usb-storage',
	'kmod-usb-storage-extras',  -- Card Readers
	'kmod-usb-storage-uas',     -- USB Attached SCSI (UAS/UASP)
	'kmod-nls-base',
	'kmod-nls-cp1250',          -- NLS Codepage 1250 (Eastern Europe)
	'kmod-nls-cp437',           -- NLS Codepage 437 (United States, Canada)
	'kmod-nls-cp850',           -- NLS Codepage 850 (Europe)
	'kmod-nls-cp852',           -- NLS Codepage 852 (Europe)
	'kmod-nls-iso8859-1',       -- NLS ISO 8859-1 (Latin 1)
	'kmod-nls-iso8859-13',      -- NLS ISO 8859-13 (Latin 7; Baltic)
	'kmod-nls-iso8859-15',      -- NLS ISO 8859-15 (Latin 9)
	'kmod-nls-iso8859-2',       -- NLS ISO 8859-2 (Latin 2)
	'kmod-nls-utf8'             -- NLS UTF-8
}

local pkgs_usb_net = {
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
}

local pkgs_pci = {
	'pciutils'
}

local pkgs_pci_net = {
	'kmod-bnx2'
}

if target('ath79') then
	if device({
		'buffalo-wzr-hp-ag300h',
		'devolo-wifi-pro-1750e',
		'buffalo-wzr-600dhp',
		'buffalo-wzr-hp-g300nh-rtl8366s',
		'd-link-dir825b1',
		'gl.inet-gl-ar150',
		'gl.inet-6416',
		'gl.inet-gl-ar150',
		'gl.inet-gl-ar300m-nor',
		'gl.inet-gl-ar300m-lite',
		'gl.inet-gl-ar750',
		'gl.inet-gl-ar750s-nor',
		'gl.inet-gl-xe300',
		'librerouter-v1',
		'netgear-wndr3700',
		'netgear-wndr3700-v2',
		'netgear-wndr3700-v4',
		'netgear-wndr3800',
		'netgear-wndr3800ch',
		'netgear-wndr4300',
		'tp-link-archer-a7-v5',
		'tp-link-archer-c5-v1',
		'tp-link-archer-c7-v2',
		'tp-link-archer-c7-v4',
		'tp-link-archer-c7-v5',
		'tp-link-archer-c59-v1',
		'tp-link-tl-wdr3500-v1',
		'tp-link-tl-wdr3600-v1',
		'tp-link-tl-wdr4300-v1',
		'tp-link-tl-wr842n-v3',
		'tp-link-tl-wr902ac-v1',
		'tp-link-tl-wr1043nd-v2',
		'tp-link-tl-wr1043nd-v3',
		'tp-link-tl-wr1043nd-v4',
	}) then
		packages(pkgs_usb_serial)
	end
end

if target('ipq40xx') then
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

if target('ipq806x') then
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

if target('mediatek') then
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

if target('mpc85xx') then
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

if target('ramips', 'mt7621') then
	packages(pkgs_usb_serial)
end

if target('rockchip') then
	-- No PCI / video
	packages(pkgs_usb_net)
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

if target('sunxi') then
	-- No PCI / video
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

-- Include all custom packages for RaspberryPi
if target('bcm27xx') then
	packages(pkgs_usb_hid)
	packages(pkgs_usb_net)
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

-- Include all custom packages for x86
if target('x86') then
	packages(pkgs_pci)
	packages(pkgs_pci_net)
	packages(pkgs_usb_hid)
	packages(pkgs_usb_net)
	packages(pkgs_usb_serial)
	packages(pkgs_usb_storage)
end

-- Network-activated setup-mode for NWA55AXE
if device({'zyxel-nwa55axe'}) then
	packages({'ffda-network-setup-mode'})
end
