#!/bin/bash
XDG_DOCUMENTS_DIR="${XDG_DOCUMENTS_DIR:-$(xdg-user-dir DOCUMENTS)}"
if [[ -z "${XDG_DOCUMENTS_DIR}" ]]; then
	echo 'Error: Failed to get XDG_DOCUMENTS_DIR, refuse to continue'
	exit 1
fi
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
WECHAT_DATA_DIR="${XDG_DOCUMENTS_DIR}/WeChat_Data"
WECHAT_FILES_DIR="${WECHAT_DATA_DIR}/xwechat_files"
WECHAT_HOME_DIR="${WECHAT_DATA_DIR}/home"

env_add() {
	BWRAP_ENV_APPEND+=(--setenv "$1" "$2")
}
BWRAP_ENV_APPEND=()
# wechat-universal only support xcb
env_add QT_QPA_PLATFORM xcb
env_add PATH "/sandbox:${PATH}"
[[ -z "${QT_IM_MODULE}" ]] && env_add QT_IM_MODULE fcitx
[[ -z "${GTK_USE_PORTAL}" ]] && env_add GTK_USE_PORTAL 1
# KDE won't use QT_AUTO_SCREEN_SCALE_FACTOR, but use QT_SCALE_FACTOR
if [[ "${XDG_CURRENT_DESKTOP}" == KDE ]]; then
	[[ -z "${QT_SCALE_FACTOR}" ]] && 
		env_add QT_SCALE_FACTOR $(
			kreadconfig6 --group KScreen --key ScaleFactor --default 1.0 ||
			kreadconfig5 --group KScreen --key ScaleFactor --default 1.0 ||
			echo 1.0)
else
	[[ -z "${QT_AUTO_SCREEN_SCALE_FACTOR}" ]] && env_add QT_AUTO_SCREEN_SCALE_FACTOR 1
fi

mkdir -p "${WECHAT_FILES_DIR}" "${WECHAT_HOME_DIR}"
ln -snf "${WECHAT_FILES_DIR}" "${WECHAT_HOME_DIR}/xwechat_files"

# resolv.con
REAL_RESOLV=$(readlink -f /etc/resolv.conf)
if [[ "${REAL_RESOLV}" != /etc/resolv.conf ]]; then
	BWRAP_RESOLV=(--ro-bind "${REAL_RESOLV}"{,})
else
	BWRAP_RESOLV=()
fi

# 7Ji: adapted from Kimiblock's aur/wechat-uos-bwrap, thanks :)
BWRAP_ARGS=(
	# Drop privileges
	--unshare-all
	--share-net
	--cap-drop ALL
	--die-with-parent
	# /usr
	--ro-bind /usr{,}
	--symlink usr/lib /lib
	--symlink usr/lib /lib64
	--symlink usr/bin /bin
	--symlink usr/bin /sbin
	--bind /usr/bin/{true,lsblk}
	# /sandbox
	--ro-bind /{usr/lib/flatpak-xdg-utils,sandbox}/xdg-open
	--ro-bind /{usr/share/wechat-universal/usr/bin,sandbox}/dde-file-manager
	# /dev
	--dev /dev
	--dev-bind /dev/dri{,}
	# /proc
	--proc /proc
	# /etc
	--ro-bind /etc{,}
	# /run
	--ro-bind-try "${XAUTHORITY}"{,}
	--ro-bind "${XDG_RUNTIME_DIR}/bus"{,}
	--ro-bind "${XDG_RUNTIME_DIR}/pulse"{,}
	# /opt, Wechat-beta itself
	--ro-bind /opt/wechat-universal{,}
	# license fixups in various places
	--ro-bind {/usr/share/wechat-universal,}/usr/lib/license
	--ro-bind {/usr/share/wechat-universal,}/var/
	--ro-bind {/usr/share/wechat-universal,}/etc/os-release
	--ro-bind {/usr/share/wechat-universal,}/etc/lsb-release
	# /home
	--bind "${WECHAT_HOME_DIR}" "${HOME}"
	--bind "${WECHAT_FILES_DIR}"{,}
	--ro-bind-try "${HOME}/.fontconfig"{,}
	--ro-bind-try "${HOME}/.fonts"{,}
	--ro-bind-try "${HOME}/.config/fontconfig"{,}
	--ro-bind-try "${HOME}/.local/share/fonts"{,}
)

exec bwrap "${BWRAP_ARGS[@]}" "${BWRAP_RESOLV[@]}" "${BWRAP_ENV_APPEND[@]}" /opt/wechat-universal/wechat "$@"