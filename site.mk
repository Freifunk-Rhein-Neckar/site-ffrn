##	Freifunk Rhein-Neckar Gluon site.mk makefile


##	DEFAULT_GLUON_RELEASE
#		version string to use for images
#		gluon relies on
#			opkg compare-versions "$1" '>>' "$2"
#		to decide if a version is newer or not.

FFRN_SITE_VERSION := 2.4

DEFAULT_GLUON_RELEASE := $(FFRN_SITE_VERSION).x-$(shell date '+%Y%m%d')
DEFAULT_GLUON_PRIORITY := 0

# multidomain support
GLUON_MULTIDOMAIN := 0

# Languages to include
GLUON_LANGS ?= de en

# Set region for region specific firmwares
GLUON_REGION ?= eu

# Allow overriding the release number from the command line
GLUON_RELEASE ?= $(DEFAULT_GLUON_RELEASE)
GLUON_PRIORITY ?= ${DEFAULT_GLUON_PRIORITY}

# Don't build factory firmware for deprecated devices
GLUON_DEPRECATED ?= upgrade
