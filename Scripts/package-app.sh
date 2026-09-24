#!/bin/zsh

# Builds a release binary and wraps it in a minimal LSUIElement application.
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
dist_dir="${project_dir}/dist"
quota_bar_app_dir="${dist_dir}/QuotaBar.app"
legacy_app_dir="${dist_dir}/CodexQuotaMonitor.app"

cd "${project_dir}"
swift build -c release --product QuotaBar
bin_path="$(swift build -c release --show-bin-path)"

package_bundle() {
	local app_dir="$1"
	local contents_dir="${app_dir}/Contents"

	mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"
	cp "${bin_path}/QuotaBar" "${contents_dir}/MacOS/QuotaBar"
	cp "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"

	# Re-sign the completed bundle after Info.plist is present. SwiftPM's linker
	# signature covers only the executable and can be rejected by LaunchServices
	# with "code has no resources but signature indicates they must be present".
	codesign --force --deep --sign - "${app_dir}"
	echo "Created ${app_dir}"
}

package_bundle "${quota_bar_app_dir}"

# Remove the pre-rename duplicate only after the canonical bundle was built successfully.
if [[ -d "${legacy_app_dir}" ]]; then
	rm -rf -- "${legacy_app_dir}"
	echo "Removed legacy ${legacy_app_dir}"
fi
