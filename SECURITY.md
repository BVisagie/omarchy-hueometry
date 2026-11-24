# Security

Please report a security problem privately, through GitHub's private
vulnerability reporting: on this repository, open the **Security** tab and
choose **Report a vulnerability**. Do not open a public issue for it.

This covers the game in this repository: the standalone app (the Arch
package) and the Omarchy shell plugin built from it
(BVisagie/omarchy-hueometry-plugin). Hueometry makes no network
connections and runs no other programs (except, on an older shell without
the plugin API, `omarchy-shell` to open its own overlay from the bar); it
reads and writes only its own
save files under `$XDG_DATA_HOME/hueometry` and `$XDG_CONFIG_HOME/hueometry`.
The plugin runs inside the Omarchy shell's process, like every shell plugin.

Fixes are released as a new version; see docs/releasing.md.
