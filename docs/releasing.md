# Releasing

A release is a version tag (`v0.1.0`) on `main`. The release workflow
(`.github/workflows/release.yml`) builds the Arch package and the shell
plugin, attaches both to a GitHub release, and publishes the plugin to the
`main` branch of BVisagie/omarchy-hueometry-plugin, which the plugin
marketplace lists and `omarchy plugin add` clones.

## Cut a release

1. In one reviewed pull request: set the new version in `hueometry.pro`,
   `pkgbuild/PKGBUILD` and `plugin/manifest.json` (`bin/check` fails unless
   they agree), and date its CHANGELOG entry.
2. After it merges, on an Omarchy machine at that commit of `main`: run
   `bin/check` (CI cannot run the plugin's checks against a real shell).
3. Optionally run the release workflow by hand first (Actions, Release, Run
   workflow): a dry run builds both, keeps them as files on the run, and
   publishes the plugin to the plugin repository's `dry-run` branch only.
4. Tag that commit and push the tag:

   ```sh
   git tag -a v0.2.0 -m "Hueometry 0.2.0"
   git push origin v0.2.0
   ```

   The workflow refuses a tag that does not match the version or is not on
   the commit it builds. A build of the tag shows plain `v0.2.0` on the menu.

## Update the marketplace listing

The marketplace approves one exact commit of the plugin repository; a newer
commit shows as "Update unverified" until it is verified. After each release:

1. Note the plugin repository's new `main` commit (the full 40-character
   SHA): `git ls-remote https://github.com/BVisagie/omarchy-hueometry-plugin main`.
2. Open the marketplace's **Plugin verification** issue form
   (omacom/omarchy-plugin-marketplace), choose **Verify and publish a newer
   upstream commit**, and give the plugin ID `io.github.bvisagie.hueometry`,
   the repository URL and that SHA.

Cut no release while a submission or verification is pending: approval is
bound to the commit it checked. Never edit the plugin repository by hand;
fix the source and release again.
