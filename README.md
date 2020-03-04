# Freifunk Rhein Neckar - Gluon site

This is the site configuration of the [FFRN](https://www.freifunk-rhein-neckar.de/) for our on [Gluon](https://github.com/freifunk-gluon/gluon) based Firmware.


## Official Firmware of FFRN (recommended)
Our official Firmware images (build with this site configuration) can be found under [fw.ffrn.de](https://fw.ffrn.de). It is recommended to use those firmware releases!


## Build your own Firmware
If you want to build your own gluon images you could [start here](https://gluon.readthedocs.io/en/latest/user/getting_started.html#building-the-images). But keep in mind to no not disturb our network and update your router continuously.


## Changes we make to gluon
Our firmware images are generally based on the releases of [Gluon](https://github.com/freifunk-gluon/gluon). 

The only change we currently make is, that we use for the status page and the config mode, instead of magenta (`#dc0067`), a green (`#52995d`). This should only be done for our official releases to ensure a quick hint if a node uses our official firmware. If you build your own gluon please don't change the color (or you could use something different then green). But please keep the green for us.

To change the color you have to replace the value of `$ffmagenta` in `package/gluon-config-mode-theme/sass/gluon.scss` and inside the `header` section of `package/gluon-status-page/sass/status-page.scss` the value of the `background` color.
After you have done that you have to compile those scss files by running the following two sass commands:
```
sass --sourcemap=none -C -t compressed package/gluon-config-mode-theme/sass/gluon.scss package/gluon-config-mode-theme/files/lib/gluon/config-mode/www/static/gluon.css
sass --sourcemap=none -C -t compressed package/gluon-status-page/sass/status-page.scss package/gluon-status-page/files/lib/gluon/status-page/www/static/status-page.css
```