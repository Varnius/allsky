#!/bin/bash

if [[ -z ${ALLSKY_HOME} ]]
then
	export ALLSKY_HOME="$(realpath "$(dirname "${BASH_ARGV0}")")"
fi
ME="$(basename "${BASH_ARGV0}")"

source "${ALLSKY_HOME}/variables.sh" 	|| exit 99
source "${ALLSKY_SCRIPTS}/functions.sh" || exit 99

if [[ ${EUID} -eq 0 ]]; then
	display_msg error "This script must NOT be run as root, do NOT use 'sudo'."
   exit 1
fi

# This script assumes the user already did the "git clone" into the "allsky" directory.
INSTALL_DIR="allsky"
cd ~/${INSTALL_DIR}  || exit 1

# Location of possible prior version of Allsky.
# If the user wants items copied from there to the new version,
# they should have manually renamed "allsky" to "allsky-OLD" prior to running this script.
PRIOR_ALLSKY_DIR="$(dirname "${PWD}")/${INSTALL_DIR}-OLD"

OLD_WEBUI_LOCATION="/var/www/html"		# location of old-style WebUI

TITLE="Allsky Installer"
ALLSKY_OWNER=$(id --group --name)
ALLSKY_GROUP=${ALLSKY_OWNER}
WEBSERVER_GROUP="www-data"
ALLSKY_VERSION="$( < "${ALLSKY_HOME}/version" )"
FINAL_SUDOERS_FILE="/etc/sudoers.d/allsky"
OLD_RASPAP_DIR="/etc/raspap"			# used to contain WebUI configuration files
FORCE_CREATING_SETTINGS_FILE="false"	# should a default settings file be created?
RESTORED_PRIOR_SETTINGS_FILE="false"
PRIOR_ALLSKY=""							# Set to "new" or "old" if they have a prior version
SUGGESTED_NEW_HOST_NAME='allsky'		# Suggested new host name
NEW_HOST_NAME=''						# User-specified host name
BRANCH="${GITHUB_MAIN_BRANCH}"			# default branch

# Repo files
REPO_SUDOERS_FILE="${ALLSKY_REPO}/sudoers.repo"
REPO_WEBUI_DEFINES_FILE="${ALLSKY_REPO}/allskyDefines.inc.repo"
REPO_LIGHTTPD_FILE="${ALLSKY_REPO}/lighttpd.conf.repo"
REPO_AVI_FILE="${ALLSKY_REPO}/avahi-daemon.conf.repo"
REPO_WEBCONFIG_FILE="${ALLSKY_REPO}/${ALLSKY_WEBSITE_CONFIGURATION_NAME}.repo"

# Directory for log files from installation.
# Needs to go somewhere that survives reboots but can be removed when done.
INSTALL_LOGS_DIR="${ALLSKY_CONFIG}/installation_logs"

# The POST_INSTALLATION_ACTIONS contains information the user needs to act upon after the reboot.
rm -f "${POST_INSTALLATION_ACTIONS}"		# shouldn't be there, but just in case

# display_msg() will send "log" entries to this file.
# DISPLAY_MSG_LOG is used in display_msg()
# shellcheck disable=SC2034
DISPLAY_MSG_LOG="${INSTALL_LOGS_DIR}/installation_log.txt"

# Some versions of Linux default to 750 so web server can't read it
chmod 755 "${ALLSKY_HOME}"


####################### functions

# Display a header surrounded by stars.
display_header() {
	HEADER="${1}"
	((LEN=${#HEADER} + 8))		# 8 for leading and trailing "*** "
	STARS=""
	while [[ ${LEN} -gt 0 ]]; do
		STARS="${STARS}*"
		((LEN--))
	done
	echo
	echo "${STARS}"
	echo -e "*** ${HEADER} ***"
	echo "${STARS}"
	echo
}


usage_and_exit()
{
	RET=${1}
	if [[ ${RET} -eq 0 ]]; then
		C="${YELLOW}"
	else
		C="${RED}"
	fi
	echo
	echo -e "${C}Usage: ${ME} [--help] [--debug] [--update] [--function function]${NC}"
	echo
	echo "'--help' displays this message and exits."
	echo
	echo "'--update' should only be used when instructed to by an Allsky Website page."
	echo
	echo "'--function' executs the specified function and quits."
	echo
	#shellcheck disable=SC2086
	exit ${RET}
}

calc_wt_size() {
	WT_WIDTH=$(tput cols)
	[[ ${WT_WIDTH} -gt 80 ]] && WT_WIDTH=80
}


# Stop Allsky.  If it's not running, nothing happens.
stop_allsky() {
	sudo systemctl stop allsky 2> /dev/null
}


# Get the branch of the new release; if not GITHUB_MAIN_BRANCH, save it.
get_branch() {
	local FILE="${ALLSKY_HOME}/.git/config"
	if [[ -f ${FILE} ]]; then
		B="$(sed -E --silent -e '/^\[branch "/s/(^\[branch ")(.*)("])/\2/p' "${FILE}")"
		if [[ -n ${B} && ${B} != "${GITHUB_MAIN_BRANCH}" ]]; then
			BRANCH="${B}"
			echo -n "${BRANCH}" > "${ALLSKY_HOME}/branch"
			display_msg info "Using '${BRANCH}' branch."
		fi
	else
		display_msg warning "${FILE} not found; assuming ${GITHUB_MAIN_BRANCH} branch"
	fi
}


# Prompt the user to select their camera type, if we can't determine it automatically.
# If they have a prior installation of Allsky that uses CAMERA_TYPE in config.sh,
# we can use its value and not prompt.
CAMERA_TYPE=""
select_camera_type() {
	if [[ ${PRIOR_ALLSKY} == "new" ]]; then
		# New style Allsky with CAMERA_TYPE in config.sh
		OLD_CONFIG="${PRIOR_ALLSKY_DIR}/config/config.sh"
		if [[ -f ${OLD_CONFIG} ]]; then
			# We can't "source" the config file because the new settings file doesn't exist,
			# so the "source" will fail.
			CAMERA_TYPE="$(grep "^CAMERA_TYPE=" "${OLD_CONFIG}" | sed -e "s/CAMERA_TYPE=//" -e 's/"//g')"
			[[ ${CAMERA_TYPE} != "" ]] && return
		fi
	fi
	# If they have the "old" style Allsky, don't bother trying to map the old $CAMERA
	# to the new $CAMERA_TYPE.

	# "2" is the number of menu items.
	MSG="\nSelect your camera type:\n"
	CAMERA_TYPE=$(whiptail --title "${TITLE}" --menu "${MSG}" 15 ${WT_WIDTH} 2 \
		"ZWO"  "   ZWO ASI" \
		"RPi"  "   Raspberry Pi HQ and compatible" \
		3>&1 1>&2 2>&3)
	if [[ $? -ne 0 ]]; then
		display_msg warning "Camera selection required.  Please re-run the installation and select a camera to continue."
		exit 2
	fi
	display_msg --log progress "Using ${CAMERA_TYPE} camera."
}


# Create the file that defines the WebUI variables.
create_webui_defines() {
	display_msg progress "Modifying locations for WebUI."
	FILE="${ALLSKY_WEBUI}/includes/allskyDefines.inc"
	sed		-e "s;XX_ALLSKY_HOME_XX;${ALLSKY_HOME};" \
			-e "s;XX_ALLSKY_CONFIG_XX;${ALLSKY_CONFIG};" \
			-e "s;XX_ALLSKY_SCRIPTS_XX;${ALLSKY_SCRIPTS};" \
			-e "s;XX_ALLSKY_TMP_XX;${ALLSKY_TMP};" \
			-e "s;XX_ALLSKY_IMAGES_XX;${ALLSKY_IMAGES};" \
			-e "s;XX_ALLSKY_MESSAGES_XX;${ALLSKY_MESSAGES};" \
			-e "s;XX_ALLSKY_WEBUI_XX;${ALLSKY_WEBUI};" \
			-e "s;XX_ALLSKY_WEBSITE_XX;${ALLSKY_WEBSITE};" \
			-e "s;XX_ALLSKY_WEBSITE_LOCAL_CONFIG_NAME_XX;${ALLSKY_WEBSITE_CONFIGURATION_NAME};" \
			-e "s;XX_ALLSKY_WEBSITE_REMOTE_CONFIG_NAME_XX;${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME};" \
			-e "s;XX_ALLSKY_WEBSITE_LOCAL_CONFIG_XX;${ALLSKY_WEBSITE_CONFIGURATION_FILE};" \
			-e "s;XX_ALLSKY_WEBSITE_REMOTE_CONFIG_XX;${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE};" \
			-e "s;XX_ALLSKY_OWNER_XX;${ALLSKY_OWNER};" \
			-e "s;XX_ALLSKY_GROUP_XX;${ALLSKY_GROUP};" \
			-e "s;XX_WEBSERVER_GROUP_XX;${WEBSERVER_GROUP};" \
			-e "s;XX_ALLSKY_REPO_XX;${ALLSKY_REPO};" \
			-e "s;XX_ALLSKY_VERSION_XX;${ALLSKY_VERSION};" \
			-e "s;XX_RASPI_CONFIG_XX;${ALLSKY_CONFIG};" \
		"${REPO_WEBUI_DEFINES_FILE}"  >  "${FILE}"
		chmod 644 "${FILE}"
}


# Recreate the options file.
# This can be used after installation if the options file get hosed.
recreate_options_file() {
	CAMERA_TYPE="$(grep "^CAMERA_TYPE=" "${ALLSKY_CONFIG}/config.sh" | sed -e "s/CAMERA_TYPE=//" -e 's/"//g')"
	save_camera_capabilities "true"
	set_webserver_permissions
}

# Save the camera capabilities and use them to set the WebUI min, max, and defaults.
# This will error out and exit if no camera installed,
# otherwise it will determine what capabilities the connected camera has,
# then create an "options" file specific to that camera.
# It will also create a default "settings" file.
save_camera_capabilities() {
	if [[ -z ${CAMERA_TYPE} ]]; then
		display_msg error "INTERNAL ERROR: CAMERA_TYPE not set in save_camera_capabilities()."
		return 1
	fi

	OPTIONSFILEONLY="${1}"

	# Create the camera type/model-specific options file and optionally a default settings file.
	# --cameraTypeOnly tells makeChanges.sh to only change the camera info, then exit.
	# It displays any error messages.
	if [[ ${FORCE_CREATING_SETTINGS_FILE} == "true" ]]; then
		FORCE="--force"
		MSG=" and default settings"
	else
		FORCE=""
		MSG=""
	fi

	if [[ ${OPTIONSFILEONLY} == "true" ]]; then
		OPTIONSONLY="--optionsOnly"
	else
		OPTIONSONLY=""
		display_msg progress "Setting up WebUI options${MSG} for ${CAMERA_TYPE} cameras."
	fi
	#shellcheck disable=SC2086
	"${ALLSKY_SCRIPTS}/makeChanges.sh" ${FORCE} ${OPTIONSONLY} --cameraTypeOnly ${DEBUG_ARG} \
		"cameraType" "Camera Type" "${CAMERA_TYPE}"
	RET=$?
	if [[ ${RET} -ne 0 ]]; then
		#shellcheck disable=SC2086
		if [[ ${RET} -eq ${EXIT_NO_CAMERA} ]]; then
			MSG="No camera was found; one must be connected and working for the installation to succeed.\n"
			MSG="$MSG}After connecting your camera, run '${ME} --update'."
			whiptail --title "${TITLE}" --msgbox "${MSG}" 12 ${WT_WIDTH} 3>&1 1>&2 2>&3
			display_msg --log error "No camera detected - installation aborted."
		elif [[ ${OPTIONSFILEONLY} == "false" ]]; then
			display_msg --log error "Unable to save camera capabilities."
		fi
		return 1
	fi

	return 0
}



# Update the sudoers file so the web server can execute certain commands with sudo.
do_sudoers()
{
	display_msg progress "Creating/updating sudoers file."
	sed -e "s;XX_ALLSKY_SCRIPTS_XX;${ALLSKY_SCRIPTS};" "${REPO_SUDOERS_FILE}"  >  /tmp/x
	sudo install -m 0644 /tmp/x "${FINAL_SUDOERS_FILE}" && rm -f /tmp/x
}

# Ask the user if they want to reboot
ask_reboot() {
	AT="     http://${NEW_HOST_NAME}.local\n"
	AT="${AT}or\n"
	AT="${AT}     http://$(hostname -I | sed -e 's/ .*$//')"
	MSG="*** The Allsky Software is now installed. ***"
	MSG="${MSG}\n\nYou must reboot the Raspberry Pi to finish the installation."
	MSG="${MSG}\n\nAfter reboot you can connect to the WebUI at:\n"
	MSG="${MSG}${AT}"
	MSG="${MSG}\n\nReboot now?"
	if whiptail --title "${TITLE}" --yesno "${MSG}" 18 ${WT_WIDTH} 3>&1 1>&2 2>&3; then
		sudo reboot now
	else
		display_msg notice "You need to reboot the Pi before Allsky will work."
		MSG="If you have not already rebooted your Pi, please do so now.\n"
		MSG="${MSG}You can connect to the WebUI at:\n"
		MSG="${MSG}${AT}"
		echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
	fi
}


# Check for size of RAM+swap during installation (Issue # 969).
# recheck_swap is used to check swap after the installation,
# and is referenced in the Allsky Documentation.
recheck_swap() {
	check_swap "prompt"
}
check_swap() {
	if [[ ${1} == "prompt" ]]; then
		PROMPT="true"
	else
		PROMPT="false"
	fi

	# Note: This doesn't produce exact results.  On a 4 GB Pi, it returns 3.74805.
	RAM_SIZE=$(free --mebi | awk '{if ($1 == "Mem:") {print $2; exit 0} }')		# in MB
# TODO: are these the best numbers ??
	if [[ ${RAM_SIZE} -le 1024 ]]; then
		SUGGESTED_SWAP_SIZE=4096
	elif [[ ${RAM_SIZE} -le 2048 ]]; then
		SUGGESTED_SWAP_SIZE=2048
	elif [[ ${RAM_SIZE} -le 4046 ]]; then
		SUGGESTED_SWAP_SIZE=1025
	else
		SUGGESTED_SWAP_SIZE=0
	fi

	# Not sure why, but displayed swap is often 1 MB less than what's in /etc/dphys-swapfile
	CURRENT_SWAP=$(free --mebi | awk '{if ($1 == "Swap:") {print $2 + 1; exit 0} }')		# in MB
	CURRENT_SWAP=${CURRENT_SWAP:-0}
	if [[ ${CURRENT_SWAP} -lt ${SUGGESTED_SWAP_SIZE} || ${PROMPT} == "true" ]]; then
		[[ ${FUNCTION} == "" ]] && sleep 2		# time to read prior messages
		if [[ ${CURRENT_SWAP} -eq 0 ]]; then
			AMT="no"
			M="added"
		else
			AMT="${CURRENT_SWAP} MB of"
			M="increased"
		fi
		MSG="\nYour Pi currently has ${AMT} swap space."
		MSG="${MSG}\nBased on your memory size of ${RAM_SIZE} MB,"
		if [[ ${CURRENT_SWAP} -ge ${SUGGESTED_SWAP_SIZE} ]]; then
			SUGGESTED_SWAP_SIZE=${CURRENT_SWAP}
			MSG="${MSG} there is no need to change anything, but you can if you would like."
		else
			MSG="${MSG} we suggest ${SUGGESTED_SWAP_SIZE} MB of swap"
			MSG="${MSG} to decrease the chance of timelapse and other failures."
			MSG="${MSG}\n\nDo you want swap space ${M}?"
			MSG="${MSG}\n\nYou may change the amount of swap by changing the number below."
		fi

		SWAP_SIZE=$(whiptail --title "${TITLE}" --inputbox "${MSG}" 18 ${WT_WIDTH} \
			"${SUGGESTED_SWAP_SIZE}" 3>&1 1>&2 2>&3)
		if [[ ${SWAP_SIZE} == "" || ${SWAP_SIZE} == "0" ]]; then
			if [[ ${CURRENT_SWAP} -eq 0 && ${SUGGESTED_SWAP_SIZE} -gt 0 ]]; then
				display_msg --log warning "With no swap space you run the risk of programs failing."
			else
				display_msg --log info "Swap will remain at ${CURRENT_SWAP}."
			fi
		else
			sudo dphys-swapfile swapoff					# Stops the swap file
			sudo sed -i "/CONF_SWAPSIZE/ c CONF_SWAPSIZE=${SWAP_SIZE}" /etc/dphys-swapfile
			sudo dphys-swapfile setup  > /dev/null		# Sets up new swap file
			sudo dphys-swapfile swapon					# Turns on new swap file
			display_msg --log progress "Swap space set to ${SWAP_SIZE} MB."
		fi
	else
		display_msg --log progress "Size of current swap (${CURRENT_SWAP} MB) is sufficient; no change needed."
	fi
}


# Check if ${ALLSKY_TMP} exists, and if it does,
# save any *.jpg files (which we probably created), then remove everything else,
# then mount it.
check_and_mount_tmp() {
	TMP_DIR="/tmp/IMAGES"

	if [[ -d "${ALLSKY_TMP}" ]]; then
		IMAGES="$(find "${ALLSKY_TMP}" -name '*.jpg')"
		if [[ -n ${IMAGES} ]]; then
			mkdir "${TMP_DIR}"
			# Need to allow for files with spaces in their names.
			# TODO: there has to be a better way.
			echo "${IMAGES}" | \
				while read -r image
				do
					mv "${image}" "${TMP_DIR}"
				done
		fi
		rm -f "${ALLSKY_TMP}"/*
	else
		mkdir "${ALLSKY_TMP}"
	fi

	# Now mount and restore any images that were there before
	sudo mount -a
	if [[ -d ${TMP_DIR} ]]; then
		mv "${TMP_DIR}"/* "${ALLSKY_TMP}"
		rmdir "${TMP_DIR}"
	fi
}

# Check if prior ${ALLSKY_TMP} was a memory filesystem.
# If not, offer to make it one.
check_tmp() {
	INITIAL_FSTAB_STRING="tmpfs ${ALLSKY_TMP} tmpfs"

	# Check if currently a memory filesystem.
	if grep --quiet "^${INITIAL_FSTAB_STRING}" /etc/fstab; then
		display_msg --log progress "${ALLSKY_TMP} is currently in memory; no change needed."

		# If there's a prior Allsky version and it's tmp directory is mounted,
		# try to unmount it, but that often gives an error that it's busy,
		# which isn't really a problem since it'll be unmounted at the reboot.
		# /etc/fstab has ${ALLSKY_TMP} but the mount point is currently in the PRIOR Allsky.
		D="${PRIOR_ALLSKY_DIR}/tmp"
		if [[ -d "${D}" ]] && mount | grep --silent "${D}" ; then
			# The Samba daemon is one known cause of "target busy".
			sudo umount -f "${D}" 2> /dev/null ||
				(
					sudo systemctl restart smbd 2> /dev/null
					sudo umount -f "${D}" 2> /dev/null
				)
		fi

		# If the new Allsky's ${ALLSKY_TMP} is already mounted, don't do anything.
		# This would be the case during an upgrade.
		if mount | grep --silent "${ALLSKY_TMP}" ; then
			return 0
		fi

		check_and_mount_tmp		# works on new ${ALLSKY_TMP}
		return 0
	fi

	SIZE=75		# MB - should be enough
	MSG="Making ${ALLSKY_TMP} reside in memory can drastically decrease the amount of writes to the SD card, increasing its life."
	MSG="${MSG}\n\nDo you want to make it reside in memory?"
	MSG="${MSG}\n\nNote: anything in it will be deleted whenever the Pi is rebooted, but that's not an issue since the directory only contains temporary files."
	if whiptail --title "${TITLE}" --yesno "${MSG}" 15 ${WT_WIDTH}  3>&1 1>&2 2>&3; then
		echo "${INITIAL_FSTAB_STRING} size=${SIZE}M,noatime,lazytime,nodev,nosuid,mode=775,uid=${ALLSKY_OWNER},gid=${WEBSERVER_GROUP}" | sudo tee -a /etc/fstab > /dev/null
		check_and_mount_tmp
		display_msg --log progress "${ALLSKY_TMP} is now in memory."
	else
		display_msg --log info "${ALLSKY_TMP} will remain on disk."
		mkdir -p "${ALLSKY_TMP}"
	fi
}

check_installation_success() {
	local RET=${1}
	local MESSAGE="${2}"
	local LOG="${3}"
	local D="${4}"

	if [[ ${RET} -ne 0 ]]; then
		display_msg error "${MESSAGE}"
		MSG="The full log file is in ${LOG}"
		MSG="${MSG}\nThe end of the file is:"
		display_msg info "${MSG}"
		tail -5 "${LOG}"

		return 1
	fi
	[[ ${D} == "true" ]] && cat "${LOG}"

	return 0
}


# Install the web server.
install_webserver() {
	display_msg progress "Installing the web server."
	sudo systemctl stop hostapd 2> /dev/null
	sudo systemctl stop lighttpd 2> /dev/null
	TMP="${INSTALL_LOGS_DIR}/lighttpd.install.log"
	(sudo apt-get update && sudo apt-get install -y lighttpd php-cgi php-gd hostapd dnsmasq avahi-daemon) > "${TMP}" 2>&1
	check_installation_success $? "lighttpd installation failed" "${TMP}" "${DEBUG}" || exit_with_image 1

	FINAL_LIGHTTPD_FILE="/etc/lighttpd/lighttpd.conf"
	sed \
		-e "s;XX_ALLSKY_WEBUI_XX;${ALLSKY_WEBUI};g" \
		-e "s;XX_ALLSKY_HOME_XX;${ALLSKY_HOME};g" \
		-e "s;XX_ALLSKY_IMAGES_XX;${ALLSKY_IMAGES};g" \
		-e "s;XX_ALLSKY_WEBSITE_XX;${ALLSKY_WEBSITE};g" \
		-e "s;XX_ALLSKY_DOCUMENTATION_XX;${ALLSKY_DOCUMENTATION};g" \
			"${REPO_LIGHTTPD_FILE}"  >  /tmp/x
	sudo install -m 0644 /tmp/x "${FINAL_LIGHTTPD_FILE}" && rm -f /tmp/x

	sudo lighty-enable-mod fastcgi-php > /dev/null 2>&1
	sudo rm -fr /var/log/lighttpd/*		# Start off with a clean log file.
	sudo systemctl start lighttpd
	
	chmod 755 "${ALLSKY_WEBUI}/includes/createAllskyOptions.php"	# executable .php file
}

# Prompt for a new hostname if needed,
# and update all the files that contain the hostname.
prompt_for_hostname() {
	# If the Pi is already called ${SUGGESTED_NEW_HOST_NAME},
	# then the user already updated the name, so don't prompt again.

	CURRENT_HOSTNAME=$(tr -d " \t\n\r" < /etc/hostname)
	[[ ${CURRENT_HOSTNAME} == "${SUGGESTED_NEW_HOST_NAME}" ]] && return

	MSG="Please enter a hostname for your Pi."
	MSG="${MSG}\n\nIf you have more than one Pi on your network they must all have unique names."
	NEW_HOST_NAME=$(whiptail --title "${TITLE}" --inputbox "${MSG}" 10 ${WT_WIDTH} \
		"${SUGGESTED_NEW_HOST_NAME}" 3>&1 1>&2 2>&3)
	if [[ $? -ne 0 ]]; then
		display_msg warning "You must specify a host name.  Please re-run the installation and select one continue."
		exit 2
	fi

	if [[ ${CURRENT_HOSTNAME} != "${NEW_HOST_NAME}" ]]; then
		echo "${NEW_HOST_NAME}" | sudo tee /etc/hostname > /dev/null
		sudo sed -i "s/127.0.1.1.*${CURRENT_HOSTNAME}/127.0.1.1\t${NEW_HOST_NAME}/" /etc/hosts
	fi

	# Set up the avahi daemon if needed.
	FINAL_AVI_FILE="/etc/avahi/avahi-daemon.conf"
	[[ -f ${FINAL_AVI_FILE} ]] && grep -i --quiet "host-name=${NEW_HOST_NAME}" "${FINAL_AVI_FILE}"
	if [[ $? -ne 0 ]]; then
		# New NEW_HOST_NAME is not found in the file, or the file doesn't exist,
		# so need to configure it.
		display_msg progress "Configuring avahi-daemon."

		sed "s/XX_HOST_NAME_XX/${NEW_HOST_NAME}/g" "${REPO_AVI_FILE}" > /tmp/x
		sudo install -m 0644 /tmp/x "${FINAL_AVI_FILE}" && rm -f /tmp/x
	fi
}



# Set permissions on various web-related items.
set_permissions() {
	display_msg progress "Setting permissions on web-related files."

	# Make sure the currently running user has can write to the webserver root
	# and can run sudo on anything.
	G="$(groups "${ALLSKY_OWNER}")"
	if ! echo "${G}" | grep --silent " sudo"; then
		display_msg progress "Adding ${ALLSKY_OWNER} to sudo group."

		### TODO:  Hmmm.  We need to run "sudo" to add to the group,
		### but we don't have "sudo" permissions yet...
		### sudo addgroup "${ALLSKY_OWNER}" "sudo"
	fi

	if ! echo "${G}" | grep --silent " ${WEBSERVER_GROUP}"; then
		sudo addgroup "${ALLSKY_OWNER}" "${WEBSERVER_GROUP}"
	fi

	# Remove any old entries; we now use /etc/sudoers.d/allsky instead of /etc/sudoers.
	sudo sed -i -e "/allsky/d" -e "/${WEBSERVER_GROUP}/d" /etc/sudoers
	do_sudoers

	# The web server needs to be able to create and update many of the files in ${ALLSKY_CONFIG}.
	# Not all, but go ahead and chgrp all of them so we don't miss any new ones.
	find "${ALLSKY_CONFIG}/" -type f -exec chmod 664 {} \;
	find "${ALLSKY_CONFIG}/" -type d -exec chmod 775 {} \;
	sudo chgrp -R "${WEBSERVER_GROUP}" "${ALLSKY_CONFIG}"

	# The files should already be the correct permissions/owners, but just in case, set them.
	# We don't know what permissions may have been on the old website, so use "sudo".
	sudo find "${ALLSKY_WEBUI}/" -type f -exec chmod 644 {} \;
	sudo find "${ALLSKY_WEBUI}/" -type d -exec chmod 755 {} \;

	chmod 775 "${ALLSKY_TMP}"
	sudo chgrp "${WEBSERVER_GROUP}" "${ALLSKY_TMP}"

	# This is actually an Allsky Website file, but in case we restored the old website,
	# set its permissions.
	chgrp -f "${WEBSERVER_GROUP}" "${ALLSKY_WEBSITE_CONFIGURATION_FILE}"
	chmod -R 775 "${ALLSKY_WEBUI}/overlay"
	sudo chgrp -R "${WEBSERVER_GROUP}" "${ALLSKY_WEBUI}/overlay"

	chmod 755 "${ALLSKY_WEBUI}/includes/createAllskyOptions.php"	# executable .php file
}


# Check if there's a WebUI in the old-style location,
# or if the directory exists but there doesn't appear to be a WebUI in it.
# The installation (sometimes?) creates the directory.

OLD_WEBUI_LOCATION_EXISTS_AT_START="false"
does_old_WebUI_locaion_exist() {
	[[ -d ${OLD_WEBUI_LOCATION} ]] && OLD_WEBUI_LOCATION_EXISTS_AT_START="true"
}

check_old_WebUI_location() {
	[[ ! -d ${OLD_WEBUI_LOCATION} ]] && return

	if [[ ${OLD_WEBUI_LOCATION_EXISTS_AT_START} == "false" ]]; then
		# Installation created the directory so get rid of it.
		sudo rm -fr "${OLD_WEBUI_LOCATION}"
		return
	fi

	if [[ ! -d ${OLD_WEBUI_LOCATION}/includes ]]; then
		MSG="The old WebUI location '${OLD_WEBUI_LOCATION}' exists but it doesn't contain a valid WebUI."
		MSG="${MSG}\nPlease check it out after installation."
		whiptail --title "${TITLE}" --msgbox "${MSG}" 15 ${WT_WIDTH}   3>&1 1>&2 2>&3
		display_msg notice "${MSG}"
		echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
		return
	fi

	MSG="An old version of the WebUI was found in ${OLD_WEBUI_LOCATION}; it is no longer being used so you may remove it after intallation."
	MSG="${MSG}\n\nWARNING: if you have any other web sites in that directory, they will no longer be accessible via the web server."
	whiptail --title "${TITLE}" --msgbox "${MSG}" 15 ${WT_WIDTH}   3>&1 1>&2 2>&3
	display_msg notice "${MSG}"
	echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
}

handle_prior_website() {
	OLD_WEBSITE="${OLD_WEBUI_LOCATION}/allsky"
	if [[ -d ${OLD_WEBSITE} ]]; then
		ALLSKY_WEBSITE_OLD="${OLD_WEBSITE}"						# old-style Website
	elif [[ -d ${PRIOR_ALLSKY_DIR}/html/allsky ]]; then
		ALLSKY_WEBSITE_OLD="${PRIOR_ALLSKY_DIR}/html/allsky"	# new-style Website
	else
		return													# no prior Website
	fi

	# Move any prior ALLSKY_WEBSITE to the new location.
	# This HAS to be done since the lighttpd server only looks in the new location.
	# Note: This MUST come before the old WebUI check below so we don't remove the prior website
	# when we remove the prior WebUI.

	OK="true"
	if [[ -d ${ALLSKY_WEBSITE} ]]; then
		# Hmmm.  There's an old webite AND a new one.
		# Allsky doesn't ship with the website directory, so not sure how one got there...
		# Try to remove the new one - if it's not empty the remove will fail.
		rmdir "${ALLSKY_WEBSITE}"
		if [[ $? -ne 0 ]]; then
			display_msg error "New website in '${ALLSKY_WEBSITE}' is not empty."
			display_msg info "  Move the contents manually from '${ALLSKY_WEBSITE_OLD}',"
			display_msg info "  and then remove the old location.\n"
			OK="false"

			# Move failed, but still check if prior website is outdated.
			PRIOR_SITE="${ALLSKY_WEBSITE_OLD}"
		fi
	fi
	if [[ ${OK} = "true" ]]; then
		display_msg progress "Moving prior Allsky Website from ${ALLSKY_WEBSITE_OLD} to new location."
		sudo mv "${ALLSKY_WEBSITE_OLD}" "${ALLSKY_WEBSITE}"
		PRIOR_SITE="${ALLSKY_WEBSITE}"
	fi

	# Check if the prior website is outdated.
	VERSION_FILE="${PRIOR_SITE}/version"
	if [[ -f ${VERSION_FILE} ]]; then
		OLD_VERSION=$( < "${VERSION_FILE}" )
	else
		OLD_VERSION="** Unknown, but old **"
	fi
	NEW_VERSION="$(curl --show-error --silent "${GITHUB_RAW_ROOT}/allsky-website/master/version")"
	RET=$?
	if [[ ${RET} -eq 0 && ${OLD_VERSION} < "${NEW_VERSION}" ]]; then
		MSG="There is a newer Allsky Website available; please upgrade to it.\n"
		MSG="${MSG}Your    version: ${OLD_VERSION}\n"
		MSG="${MSG}Current version: ${NEW_VERSION}\n"
		MSG="${MSG}\nYou can upgrade the Allky Website by executing:\n"
		MSG="${MSG}     cd ~/allsky; website/install.sh"
		display_msg notice "${MSG}"
		echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
	fi
}


# If the locale isn't already set, set it if possible
set_locale() {
	LOCALE="$(settings .locale)"
	[[ -n ${LOCALE} ]] && return		# already set up

	display_msg progress "Setting locale."
	LOCALE="$(locale | grep LC_NUMERIC | sed -e 's;LC_NUMERIC=";;' -e 's;";;')"
	if [[ -z ${LOCALE} ]]; then
		MSG="Unable to determine your locale.\nRun the 'locale' command and then update the WebUI."
		display_msg warning "${MSG}"
		echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
	else
		jq ".locale = \"${LOCALE}\"" "${SETTINGS_FILE}" > /tmp/x && mv /tmp/x "${SETTINGS_FILE}"
	fi
}


# If there's a prior version of the software,
# ask the user if they want to move stuff from there to the new directory.
# Look for a directory inside the old one to make sure it's really an old allsky.
check_if_prior_Allsky() {
	if [[ -d ${PRIOR_ALLSKY_DIR}/src ]]; then
		MSG="You appear to have a prior version of Allsky in ${PRIOR_ALLSKY_DIR}."
		MSG="${MSG}\n\nDo you want to restore the prior images, darks, and certain settings?"
		if whiptail --title "${TITLE}" --yesno "${MSG}" 15 ${WT_WIDTH}  3>&1 1>&2 2>&3; then
			if [[ -f  ${PRIOR_ALLSKY_DIR}/version ]]; then
				PRIOR_ALLSKY="new"		# New style Allsky with CAMERA_TYPE set in config.sh
			else
				PRIOR_ALLSKY="old"		# Old style with CAMERA set in config.sh
			fi
		else
			MSG="If you want your old images, darks, settings, etc."
			MSG="${MSG} from the prior verion of Allsky, you'll need to manually move them to the new version."
			whiptail --title "${TITLE}" --msgbox "${MSG}" 12 ${WT_WIDTH} 3>&1 1>&2 2>&3
			display_msg --log info "Will NOT restore from prior version of Allsky."
		fi
	else
		MSG="No prior version of Allsky found."
		MSG="${MSG}\n\nIf you DO have a prior version and you want images, darks, and certain settings moved from the prior version to the new one, rename the prior version to ${PRIOR_ALLSKY_DIR} before running this installation."
		MSG="${MSG}\n\nDo you want to continue?"
		if ! whiptail --title "${TITLE}" --yesno "${MSG}" 15 ${WT_WIDTH} 3>&1 1>&2 2>&3; then
			display_msg info "Rename the directory with your prior version of Allsky to\n'${PRIOR_ALLSKY_DIR}', then run the installation again.\n"
			exit 0
		fi

		# No prior Allsky so force creating a settings file.
		FORCE_CREATING_SETTINGS_FILE="true"
	fi
}


install_dependencies_etc() {
	# These commands produce a TON of output that's not needed unless there's a problem.
	# They also take a little while, so hide the output and let the user know.

	display_msg progress "Installing dependencies."
	TMP="${INSTALL_LOGS_DIR}/make_deps.log"
	#shellcheck disable=SC2024
	sudo make deps > "${TMP}" 2>&1
	check_installation_success $? "Dependency installation failed" "${TMP}" "${DEBUG}" || exit_with_image 1

	display_msg progress "Preparing Allsky commands."
	TMP="${INSTALL_LOGS_DIR}/make_all.log"
	#shellcheck disable=SC2024
	make all > "${TMP}" 2>&1
	check_installation_success $? "Compile failed" "${TMP}" "${DEBUG}" || exit_with_image 1

	TMP="${INSTALL_LOGS_DIR}/make_install.log"
	#shellcheck disable=SC2024
	sudo make install > "${TMP}" 2>&1
	check_installation_success $? "make install failed" "${TMP}" "${DEBUG}" || exit_with_image 1

	return 0
}

# Update config.sh
update_config_sh() {
	sed -i \
		-e "s;XX_ALLSKY_VERSION_XX;${ALLSKY_VERSION};g" \
		-e "s/^CAMERA_TYPE=.*$/CAMERA_TYPE=\"${CAMERA_TYPE}\"/" \
		"${ALLSKY_CONFIG}/config.sh"
}

# Create the log file and make it readable/writable by the user; this aids in debugging.
create_allsky_log() {
	display_msg progress "Set permissions on Allsky log (${ALLSKY_LOG})."
	sudo truncate -s 0 "${ALLSKY_LOG}"
	sudo chmod 664 "${ALLSKY_LOG}"
	sudo chgrp "${ALLSKY_GROUP}" "${ALLSKY_LOG}"
}


# If the user wanted to restore files from a prior version of Allsky, do that.
restore_prior_files() {
	if [[ -d ${OLD_RASPAP_DIR} ]]; then
		MSG="\nThe '${OLD_RASPAP_DIR}' directory is no longer used.\n"
		MSG="${MSG}When installation is done you may remove it by executing:\n"
		MSG="${MSG}    sudo rm -fr ${OLD_RASPAP_DIR}\n"
		display_msg info "${MSG}"
		echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
	fi

	if [[ -z ${PRIOR_ALLSKY} ]]; then
		return			# Nothing left to do in this function, so return
	fi

	if [[ -f ${PRIOR_ALLSKY_DIR}/scripts/endOfNight_additionalSteps.sh ]]; then
		display_msg progress "Restoring endOfNight_additionalSteps.sh."
		mv "${PRIOR_ALLSKY_DIR}/scripts/endOfNight_additionalSteps.sh" "${ALLSKY_SCRIPTS}"
	fi

	if [[ -f ${PRIOR_ALLSKY_DIR}/scripts/endOfDay_additionalSteps.sh ]]; then
		display_msg progress "Restoring endOfDay_additionalSteps.sh."
		mv "${PRIOR_ALLSKY_DIR}/scripts/endOfDay_additionalSteps.sh" "${ALLSKY_SCRIPTS}"
	fi

	if [[ -d ${PRIOR_ALLSKY_DIR}/images ]]; then
		display_msg progress "Restoring images."
		mv "${PRIOR_ALLSKY_DIR}/images" "${ALLSKY_HOME}"
	fi

	if [[ -d ${PRIOR_ALLSKY_DIR}/darks ]]; then
		display_msg progress "Restoring darks."
		mv "${PRIOR_ALLSKY_DIR}/darks" "${ALLSKY_HOME}"
	fi

	PRIOR_CONFIG_DIR="${PRIOR_ALLSKY_DIR}/config"

	# If the user has an older release, these files may be in /etc/raspap.
	# Check for both.
	if [[ ${PRIOR_ALLSKY} == "new" ]]; then
		D="${PRIOR_CONFIG_DIR}"
	else
		D="${OLD_RASPAP_DIR}"
	fi
	if [[ -f ${D}/raspap.auth ]]; then
		display_msg progress "Restoring WebUI security settings."
		mv "${D}/raspap.auth" "${ALLSKY_CONFIG}"
	fi

	# Restore any REMOTE Allsky Website configuration file.
	if [[ -f ${PRIOR_CONFIG_DIR}/${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME} ]]; then
		display_msg progress "Restoring remote Allsky Website ${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME}."
		mv "${PRIOR_CONFIG_DIR}/${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME}" "${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE}"

		# Check if this is an older Allsky Website configuration file type.
		OLD="false"
		PRIOR_CONFIG_VERSION="$(jq .ConfigVersion "${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE}")"
		if [[ ${PRIOR_CONFIG_VERSION} == "null" ]]; then
			OLD="true"		# Hmmm, it should have the version
		else
			NEW_CONFIG_VERSION="$(jq .ConfigVersion "${REPO_WEBCONFIG_FILE}")"
			if [[ ${PRIOR_CONFIG_VERSION} < "${NEW_CONFIG_VERSION}" ]]; then
				OLD="true"
			fi
		fi
		if [[ ${OLD} == "true" ]]; then
			MSG="Your ${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE} is an older version.\n"
			MSG="${MSG}Your    version: ${PRIOR_CONFIG_VERSION}\n"
			MSG="${MSG}Current version: ${NEW_CONFIG_VERSION}\n"
			MSG="${MSG}\nPlease compare it to the new one in ${REPO_WEBCONFIG_FILE}"
			MSG="${MSG} to see what fields have been added, changed, or removed.\n"
			display_msg warning "${MSG}"
			echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
		fi
	fi
	# We don't check for old LOCAL Allsky Website configuration files.
	# That's done when they install the Allsky Website.

	if [[ -f ${PRIOR_CONFIG_DIR}/uservariables.sh ]]; then
		display_msg progress "Restoring uservariables.sh."
		mv "${PRIOR_CONFIG_DIR}/uservariables.sh" "${ALLSKY_CONFIG}"
	fi

	SETTINGS_MSG=""
	if [[ ${PRIOR_ALLSKY} == "new" ]]; then
		if [[ -f ${PRIOR_CONFIG_DIR}/settings.json ]]; then
			display_msg progress "Restoring WebUI settings."
			# This file is probably a link to a camera type/model-specific file,
			# so copy it instead of moving it to not break the link.
			cp "${PRIOR_CONFIG_DIR}/settings.json" "${ALLSKY_CONFIG}"
			RESTORED_PRIOR_SETTINGS_FILE="true"
			# TODO: check if this is an older versions of the file,
			# and if so, reset "lastChanged" to null.
			# BUT, how do we determine if it's an old file,
			# given that it's initially created at installation time?
		fi
		# else, what the heck?  Their prior version is "new" but they don't have a settings file?
	else
		# settings file is old style in ${OLD_RASPAP_DIR}.
		if [[ ${CAMERA_TYPE} == "ZWO" ]]; then
			CT="ZWO"
		else
			CT="RPiHQ"		# RPi cameras used to be called "RPiHQ".
		fi
		SETTINGS="${OLD_RASPAP_DIR}/settings_${CT}.json"
		if [[ -f ${SETTINGS} ]]; then
			SETTINGS_MSG="\n\nYou also need to transfer your old settings to the WebUI.\nUse ${SETTINGS} as a guide.\n"

			# Restore the latitude and longitude so Allsky can start after reboot.
			LAT="$(settings .latitude "${SETTINGS}")"
			LONG="$(settings .longitude "${SETTINGS}")"
			ANGLE="$(settings .angle "${SETTINGS}")"
			jq ".latitude=\"${LAT}\" | .longitude=\"${LONG}\" | .angle=\"${ANGLE}\"" "${SETTINGS_FILE}" > /tmp/x && mv /tmp/x "${SETTINGS_FILE}"
			display_msg --log progress "Prior latitude and longitude saved."
			# It would be nice to transfer other settings, but a lot of setting names changed
			# and it's not worth trying to look for all names.
		fi

		# If we ever automate migrating settings, this next statement should be deleted.
		FORCE_CREATING_SETTINGS_FILE="true"
	fi
	# Do NOT restore options.json - it will be recreated.

	# This may miss really-old variables that no longer exist.

	FOUND="true"
	if [[ -f ${PRIOR_CONFIG_DIR}/ftp-settings.sh ]]; then
		PRIOR_FTP="${PRIOR_CONFIG_DIR}/ftp-settings.sh"
	elif [[ -f ${PRIOR_ALLSKY_DIR}/scripts/ftp-settings.sh ]]; then
		PRIOR_FTP="${PRIOR_ALLSKY_DIR}/scripts/ftp-settings.sh"
	else
		PRIOR_FTP="ftp-settings.sh (in unknown location)"
		FOUND="false"
	fi

	## TODO: Try to automate this.
	# Unfortunately, it's not easy since the prior configuration files could be from
	# any Allsky version, and the variables and their names changed and we don't have a
	# mapping of old-to-new names.

	# display_msg progress "Restoring settings from config.sh and ftp-settings.sh."
	# ( source ${PRIOR_FTP}
	#	for each variable:
	#		/^variable=/ c;variable="$oldvalue";
	#	Deal with old names from version 0.8
	# ) > /tmp/x
	# sed -i --file=/tmp/x "${ALLSKY_CONFIG}/ftp-settings.sh"
	# rm -f /tmp/x
	
	# similar for config.sh, but
	#	- don't transfer CAMERA
	#	- handle renames
	#	- handle variable that were moved to WebUI
	#		> DAYTIME_CAPTURE
	#
	# display_msg info "\nIMPORTANT: check config/config.sh and config/ftp-settings.sh for correctness.\n"

	if [[ ${PRIOR_ALLSKY} == "new" && ${FOUND} == "true" ]]; then
		MSG="Your config.sh and ftp-settings.sh files should be very similar to the"
		MSG="${MSG}\nnew ones, other than your changes."
		MSG="${MSG}\nThere may be an easy way to update the new configuration files."
		MSG="${MSG}\nAfter installation, see ${POST_INSTALLATION_ACTIONS} for details."

		MSG2="You can compare the old and new configuration files with the following commands,"
		MSG2="${MSG2}\nand if the only differences are your changes, you can simply copy the old files to the new location:"
		MSG2="${MSG2}\n\ndiff ${PRIOR_FTP} ${ALLSKY_CONFIG}"
		MSG2="${MSG2}\n\nand"
		MSG2="${MSG2}\n\ndiff ${PRIOR_CONFIG_DIR}/config.sh ${ALLSKY_CONFIG}"
	else
		MSG="You need to manually move the contents of"
		MSG="${MSG}\n     ${PRIOR_CONFIG_DIR}/config.sh"
		MSG="${MSG}\nand"
		MSG="${MSG}\n     ${PRIOR_FTP}"
		MSG="${MSG}\n\nto the new files in ${ALLSKY_CONFIG}."
		MSG="${MSG}\n\nNOTE: some settings are no longer in config.sh and some changed names."
		MSG="${MSG}\nDo NOT add the old/deleted settings back in."
		MSG2=""
	fi
	MSG="${MSG}${SETTINGS_MSG}"
	whiptail --title "${TITLE}" --msgbox "${MSG}" 18 ${WT_WIDTH} 3>&1 1>&2 2>&3
	display_msg info "\n${MSG}\n"
	echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
	[[ ${MSG2} != "" ]] && echo -e "\n${MSG2}" >> "${POST_INSTALLATION_ACTIONS}"
}


# Update Allsky and exit.  It basically resets things.
# This can be needed if the user hosed something up, or there was a problem somewhere.
do_update() {
	source "${ALLSKY_CONFIG}/config.sh"		# Get current CAMERA_TYPE
	if [[ -z ${CAMERA_TYPE} ]]; then
		display_msg error "CAMERA_TYPE not set in config.sh."
		exit 1
	fi

	create_webui_defines

	save_camera_capabilities "false" || exit 1
	set_webserver_permissions

	# Update the sudoers file if it's missing some entries.
	# Look for the last entry added (should be the last entry in the file).
	# Don't simply copy the repo file to the final location in case the repo file isn't up to date.
	grep --silent "/date" "${FINAL_SUDOERS_FILE}"
	# shellcheck disable=SC2181
	if [[ $? -ne 0 ]]; then
		display_msg progress "Updating sudoers list."
		grep --silent "/date" "${REPO_SUDOERS_FILE}"
		# shellcheck disable=SC2181
		if [[ $? -ne 0 ]]; then
				display_msg error "Please get the newest '$(basename "${REPO_SUDOERS_FILE}")' file from Git and try again."
			exit 2
		fi
		do_sudoers
	fi

	exit 0
}

# Install the overlay and modules system
install_overlay()
{

		cp "${ALLSKY_CONFIG}/overlay-${CAMERA_TYPE}.json" "${ALLSKY_CONFIG}/overlay.json"

		display_msg progress "Installing PHP Modules."
		TMP="${INSTALL_LOGS_DIR}/PHP_modules.log"
		(
			sudo apt-get install -y php-zip && \
			sudo apt-get install -y php-sqlite3 && \
			sudo apt install -y python3-pip
		) > "${TMP}" 2>&1
		check_installation_success $? "PHP module installation failed" "${TMP}" "${DEBUG}" || exit_with_image 1

		display_msg progress "Installing other PHP dependencies."
		TMP="${INSTALL_LOGS_DIR}/libatlas.log"
		# shellcheck disable=SC2069,SC2024
		sudo apt-get -y install libatlas-base-dev 2>&1 > "${TMP}"
# TODO: or > then 2>&1 ???
		check_installation_success $? "PHP dependencies failed" "${TMP}" "${DEBUG}" || exit_with_image 1

		# Doing all the python dependencies at once can run /tmp out of space, so do one at a time.
		# This also allows us to display progress messages.
		if [[ ${OS} == "buster" ]]; then
			M=" for Buster"
			R="-buster"
		else
			M=""
			R=""
		fi
		MSG2="  This may take a LONG time if the packages are not already installed."
		display_msg progress "Installing Python dependencies${M}."  "${MSG2}"
		TMP="${INSTALL_LOGS_DIR}/Python_dependencies"
		PIP3_BUILD="${ALLSKY_HOME}/pip3.build"
		mkdir -p "${PIP3_BUILD}"
		COUNT=0
		local NUM=$(wc -l < "${ALLSKY_REPO}/requirements${R}.txt")
		while read -r package
		do
			COUNT=$((COUNT+1))
			echo "${package}" > /tmp/package
			L="${TMP}.${COUNT}.log"
			display_msg progress "   === Package # ${COUNT} of ${NUM}: [${package}]"
			pip3 install --no-warn-script-location --build "${PIP3_BUILD}" -r /tmp/package > "${L}" 2>&1
			# These files are too big to display so pass in "false" instead of ${DEBUG}.
			if ! check_installation_success $? "Python dependency [${package}] failed" "${L}" false ; then
				rm -fr "${PIP3_BUILD}"
				exit_with_image 1
			fi
		done < "${ALLSKY_REPO}/requirements${R}.txt"
		rm -fr "${PIP3_BUILD}"

		display_msg progress "Installing Trutype fonts."
		TMP="${INSTALL_LOGS_DIR}/msttcorefonts.log"
		# shellcheck disable=SC2069,SC2024
		sudo apt-get -y install msttcorefonts 2>&1 > "${TMP}"
# TODO: or > then 2>&1 ???
		check_installation_success $? "Trutype fonts failed" "${TMP}" "${DEBUG}" || exit_with_image 1

		display_msg progress "Setting up modules."
		sudo mkdir -p /etc/allsky/modules
		sudo chown -R "${ALLSKY_OWNER}:${WEBSERVER_GROUP}" /etc/allsky
		sudo chmod -R 774 /etc/allsky
}

check_if_buster() {
	if [[ ${OS} == "buster" ]]; then
		MSG="This release runs best on the newer Bullseye operating system"
		MSG="${MSG} that was released in November, 2021."
		MSG="${MSG}\nYou are running the older Buster operating system and we"
		MSG="${MSG} recommend doing a fresh install of Bullseye on a clean SD card."
		MSG="${MSG}\n\nDo you want to continue anyhow?"
		if ! whiptail --title "${TITLE}" --yesno "${MSG}" 18 ${WT_WIDTH} 3>&1 1>&2 2>&3; then
			exit 0
		fi
	fi
}

# Display an image the user will see when they go to the WebUI.
display_image() {
	local IMAGE_NAME="${1}"

	I="${ALLSKY_TMP}/image.jpg"

	if [[ -z ${IMAGE_NAME} ]]; then		# No IMAGE_NAME means remove the image
		rm -f "${I}"
		return
	fi

	if [[ ${IMAGE_NAME} == "ConfigurationNeeded" && -f ${POST_INSTALLATION_ACTIONS} ]]; then
		# Add a message the user will see in the WebUI.
		cat "${POST_INSTALLATION_ACTIONS}" >> "${ALLSKY_LOG}"
		WEBUI_MESSAGE="Actions needed.  See ${ALLSKY_LOG}."
		"${ALLSKY_SCRIPTS}/addMessage.sh" "Warning" "${WEBUI_MESSAGE}"
	fi

	# ${ALLSKY_TMP} may not exist yet, i.e., at the beginning of installation.
	mkdir -p "${ALLSKY_TMP}"
	cp "${ALLSKY_NOTIFICATION_IMAGES}/${IMAGE_NAME}.jpg" "${I}" 2> /dev/null
}

# Installation failed.
# Replace the "installing" messaged with a "failed" one.
exit_with_image() {
	display_image "InstallationFailed"
	#shellcheck disable=SC2086
	exit ${1}
}

####################### main part of program

##### Log files write to ${ALLSKY_CONFIG}, which doesn't exist yet, so create it.
mkdir -p "${ALLSKY_CONFIG}"
rm -fr "${INSTALL_LOGS_DIR}"			# shouldn't be there, but just in case
mkdir "${INSTALL_LOGS_DIR}"

OS="$(grep CODENAME /etc/os-release | cut -d= -f2)"	# usually buster or bullseye

##### Check arguments
OK="true"
HELP="false"
DEBUG="false"
DEBUG_ARG=""
UPDATE="false"
FUNCTION=""
while [ $# -gt 0 ]; do
	ARG="${1}"
	case "${ARG}" in
		--help)
			HELP="true"
			;;
		--debug)
			DEBUG="true"
			DEBUG_ARG="${ARG}"		# we can pass this to other scripts
			;;
		--update)
			UPDATE="true"
			;;
		--function)
			FUNCTION="${2}"
			shift
			;;
		*)
			display_msg error "Unknown argument: '${ARG}'."
			OK="false"
			;;
	esac
	shift
done
[[ ${HELP} == "true" ]] && usage_and_exit 0
[[ ${OK} == "false" ]] && usage_and_exit 1

##### Display the welcome header
if [[ ${FUNCTION} == "" ]]; then
	if [[ ${UPDATE} == "true" ]]; then
		H="Updating Allsky"
	else
		H="Welcome to the ${TITLE}"
	fi
	display_header "${H}"
fi

##### Calculate whiptail sizes
calc_wt_size

##### Stop Allsky
stop_allsky

##### Get branch
get_branch

##### Handle updates
[[ ${UPDATE} == "true" ]] && do_update		# does not return

##### See if there's an old WebUI
does_old_WebUI_locaion_exist

##### Execute any specified function, then exit.
if [[ ${FUNCTION} != "" ]]; then
	if ! type "${FUNCTION}" > /dev/null; then
		display_msg error "Unknown function: '${FUNCTION}'."
		exit 1
	fi

	${FUNCTION}
	exit $?
fi


##### Display an image in the WebUI
display_image "InstallationInProgress"

# Do as much of the prompting up front, then do the long-running work, then prompt at the end.

##### Determine if there's a prior version
check_if_prior_Allsky

##### Determine the camera type
select_camera_type

##### Get the new host name
prompt_for_hostname

##### Check for sufficient swap space
check_swap

##### Optionally make ${ALLSKY_TMP} a memory filesystem
check_tmp


MSG="\nThe following steps can take about AN HOUR depending on the speed of your Pi"
MSG="${MSG}\nand how many of the necessary dependencies are already installed."
MSG="${MSG}\nYou will see progress messages throughout the process."
MSG="${MSG}\nAt the end you will be prompted again for additional steps.\n"
whiptail --title "${TITLE}" --msgbox "${MSG}" 12 ${WT_WIDTH} 3>&1 1>&2 2>&3
display_msg info "${MSG}"


##### Install web server
# This must come BEFORE save_camera_capabilities, since it installs php.
install_webserver

##### Install dependencies, then compile and install Allsky software
install_dependencies_etc || exit_with_image 1

##### Update config.sh
# This must come BEFORE save_camera_capabilities, since it uses the camera type.
update_config_sh

##### Create the file that defines the WebUI variables.
create_webui_defines

##### Create the camera type-model-specific "options" file
# This should come after the steps above that create ${ALLSKY_CONFIG}.
save_camera_capabilities "false" || exit_with_image 1			# prompts on error only

# Code later needs "settings()" function.
source "${ALLSKY_CONFIG}/config.sh" || exit_with_image 1

##### Create ${ALLSKY_LOG}
create_allsky_log

##### Set locale
set_locale

##### install the overlay and modules system
install_overlay

##### Check for, and handle any prior Allsky Website
handle_prior_website

##### Restore prior files if needed
restore_prior_files									# prompts if prior Allsky exists

##### Set permissions.  Want this at the end so we make sure we get all files.
set_permissions

##### Check if there's an old WebUI and let the user know it's no longer used.
check_old_WebUI_location							# prompt if prior old-style WebUI


######## All done


if [[ ${RESTORED_PRIOR_SETTINGS_FILE} == "true" ]]; then
	# If we restored a prior settings file, no configuration is needed
	# so remove any existing file.
	display_image ""
else
	MSG="NOTE: Default settings were created for your camera."
	MSG="${MSG}\n\nHowever some entries may not have been set, like latitude, so you MUST"
	MSG="${MSG}\ngo to the 'Allsky Settings' page in the WebUI after rebooting to make updates."
	whiptail --title "${TITLE}" --msgbox "${MSG}" 12 ${WT_WIDTH} 3>&1 1>&2 2>&3
	echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"

	display_image "ConfigurationNeeded"
fi

if [[ -n ${PRIOR_ALLSKY} ]]; then
	MSG="When you are sure everything is working with this new release,"
	MSG="${MSG} remove your old version in ${PRIOR_ALLSKY_DIR} to save disk space."
	whiptail --title "${TITLE}" --msgbox "${MSG}" 12 ${WT_WIDTH} 3>&1 1>&2 2>&3
	echo -e "\n\n==========\n${MSG}" >> "${POST_INSTALLATION_ACTIONS}"
fi

ask_reboot			# prompts

exit 0
