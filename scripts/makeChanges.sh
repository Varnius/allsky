#!/bin/bash

ME="$(basename "${BASH_ARGV0}")"

# Allow this script to be executed manually, which requires several variables to be set.
if [[ -z ${ALLSKY_HOME} ]]; then
	ALLSKY_HOME="$(realpath "$(dirname "${BASH_ARGV0}")/..")"
	export ALLSKY_HOME
fi
# shellcheck disable=SC1090
source "${ALLSKY_HOME}/variables.sh"

# This script may be called during installation BEFORE there is a settings file.
# config.sh looks for the file and produces an error if it doesn't exist,
# so only include these two files if there IS a settings file.
if [[ -f ${SETTINGS_FILE} ]]; then
	# shellcheck disable=SC1090
	source "${ALLSKY_CONFIG}/config.sh"
	# shellcheck disable=SC1090
	source "${ALLSKY_CONFIG}/ftp-settings.sh"
fi
# shellcheck disable=SC1090
source "${ALLSKY_SCRIPTS}/functions.sh" || exit 99

function usage_and_exit()
{
	echo -e "${wERROR}"
	echo "Usage: ${ME} [--debug] [--optionsOnly] [--cameraTypeOnly] [--restarting] key label new_value [...]"
	echo -e "${wNC}"
	echo "There must be a multiple of 3 key/label/old_value/new_value arguments"
	echo "unless the --optionsOnly argument is given."
	exit ${1}
}

# Check arguments
OK=true
DEBUG=false
DEBUG_ARG=""
HELP=false
OPTIONS_FILE_ONLY=false
RESTARTING=false			# Will the caller restart Allsky?
CAMERA_TYPE_ONLY=false		# Only update the cameraType ?
FORCE=""					# Passed to createAllskyOptions.php

while [[ $# -gt 0 ]]; do
	ARG="${1}"
	case "${ARG}" in
		--debug)
			DEBUG=true
			DEBUG_ARG="${ARG}"		# So we can pass to other scripts
			;;
		--help)
			HELP=true
			;;
		--optionsOnly)
			OPTIONS_FILE_ONLY=true
			SETTINGS_FILE=""
			;;
		--cameraTypeOnly)
			CAMERA_TYPE_ONLY=true
			;;
		--force)
			FORCE="${ARG}"
			;;
		--restarting)
			RESTARTING=true
			;;
		-*)
			echo -e "${wERROR}ERROR: Unknown argument: '${ARG}'${wNC}"
			OK="false"
			;;
		*)
			break
			;;
	esac
	shift
done

[[ ${HELP} == "true" ]] && usage_and_exit 0
[[ ${OK} == "false" ]] && usage_and_exit 1
if [[ ${OPTIONS_FILE_ONLY} == "false" ]]; then
	[[ $# -eq 0 ]] && usage_and_exit 1
	[[ $(($# % 3)) -ne 0 ]] && usage_and_exit 2
fi


# This output may go to a web page, so use "w" colors.
# shell check doesn't realize there were set in variables.sh
wOK="${wOK}"
wWARNING="${wWARNING}"
wERROR="${wERROR}"
wDEBUG="${wDEBUG}"
wBOLD="${wBOLD}"
wNBOLD="${wNBOLD}"
wNC="${wNC}"

# Does the change need Allsky to be restarted in order to take affect?
NEEDS_RESTART=false

RUN_POSTTOMAP=false
POSTTOMAP_ACTION=""
WEBSITE_CONFIG=()
WEB_CONFIG_FILE=""
HAS_WEBSITE_RET=""
SHOW_POSTDATA_MESSAGE=true
TWILIGHT_DATA_CHANGED=false

# Several of the fields are in the Allsky Website configuration file,
# so check if the IS a file before trying to update it.
# Return 0 on found and 1 on not found.
function check_website()
{
	[[ ${HAS_WEBSITE_RET} != "" ]] && return ${HAS_WEBSITE_RET}		# already checked

	WEB_CONFIG_FILE="${ALLSKY_WEBSITE_CONFIGURATION_FILE}"
	[[ -f ${WEB_CONFIG_FILE} ]] && HAS_WEBSITE_RET=0 && return ${HAS_WEBSITE_RET}

	WEB_CONFIG_FILE="${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE}"
	if [[ -f ${WEB_CONFIG_FILE} ]]; then
		HAS_WEBSITE_RET=0
	else
		echo -e "${wWARNING}WARNING: No local or remote Allsky Website found.${wNC}"
		WEB_CONFIG_FILE=""
		HAS_WEBSITE_RET=1
	fi
	return ${HAS_WEBSITE_RET}
}

while [[ $# -gt 0 ]]; do
	KEY="${1}"
	LABEL="${2}"
	NEW_VALUE="${3}"
	if [[ ${DEBUG} == "true" ]]; then
		MSG="New ${KEY} = [${NEW_VALUE}]"
		if [[ ${ON_TTY} -eq 1 ]]; then
			echo -e "${wDEBUG}${ME}: ${MSG}${wNC}"
		else	# called from WebUI.
			echo -e "${wDEBUG}${ME}: ${MSG}${wNC}"
			echo -e "<script>console.log('${MSG}');</script>"
		fi
	fi

	# Unfortunately, the Allsky configuration file was already updated,
	# so if we find a bad entry, e.g., a file doesn't exist, all we can do is warn the user.
	case "${KEY}" in

		cameraType)
			if [[ ${OPTIONS_FILE_ONLY} == "false" ]]; then

				# If we can't set the new camera type, it's a major problem so exit right away.
				# NOTE: when we're changing cameraType we're not changing anything else.

				CC_FILE_OLD="${CC_FILE}-OLD"

				if [[ -f ${CC_FILE} ]]; then
					# Save the current file just in case creating a new one fails.
					# It's a link so copy it to a temp name, then remove the old name.
					cp "${CC_FILE}" "${CC_FILE_OLD}"
					rm -f "${CC_FILE}"
				fi

				# Create the camera capabilities file for the new camera type.
				# Use Debug Level 3 to give the user more info on error.

				# The software for RPi cameras needs to know what command is being used to
				# capture the images.
				if [[ ${NEW_VALUE} == "RPi" ]]; then
					if ! C="$(determineCommandToUse "false" "" )" ; then
						echo -e "${wERROR}${ME}: ERROR: unable to determine command to use, RET=${RET}, C=${C}.${wNC}."
						exit ${RET}
					fi
					C="-cmd ${C}"
				else
					C=""
				fi
				[[ ${DEBUG} == "true" ]] && echo -e "${wDEBUG}Calling capture_${NEW_VALUE} ${C} -cc_file '${CC_FILE}'${wNC}"
				"${ALLSKY_BIN}/capture_${NEW_VALUE}" ${C} -debuglevel 3 -cc_file "${CC_FILE}"
				RET=$?
				if [[ ${RET} -ne 0 || ! -f ${CC_FILE} ]]; then
					echo -e "${wERROR}ERROR: Unable to create cc file '${CC_FILE}'.${wNC}"

					# Restore prior cc file if there was one.
					[[ -f ${CC_FILE_OLD} ]] && mv "${CC_FILE_OLD}" "${CC_FILE}"
					exit ${RET}		# the actual exit code is important
				fi

				# Create a link to a file that contains the camera type and model in the name.
				CAMERA_TYPE="${NEW_VALUE}"		# already know it
				CAMERA_MODEL="$(jq .cameraModel "${CC_FILE}" | sed 's/"//g')"
				if [[ -z ${CAMERA_MODEL} ]]; then
					echo -e "${wERROR}ERROR: 'cameraModel' not found in ${CC_FILE}.${wNC}"
					[[ -f ${CC_FILE_OLD} ]] && mv "${CC_FILE_OLD}" "${CC_FILE}"
					exit 1
				fi

				# ${CC_FILE} is a generic name defined in config.sh.
				# ${SPECIFIC_NAME} is specific to the camera type/model.
				# It isn't really needed except debugging.
				SPECIFIC_NAME="${ALLSKY_CONFIG}/${CC_FILE_NAME}_${CAMERA_TYPE}_${CAMERA_MODEL}.${CC_FILE_EXT}"

				# Any old and new camera capabilities file should be the same unless Allsky
				# adds or changes capabilities, so delete the old one just in case.
				ln --force "${CC_FILE}" "${SPECIFIC_NAME}"

				if ! sed -i -e "s/^CAMERA_TYPE=.*$/CAMERA_TYPE=\"${NEW_VALUE}\"/" "${ALLSKY_CONFIG}/config.sh"; then
					echo -e "${wERROR}ERROR updating ${wBOLD}${LABEL}${wNBOLD}.${wNC}"
					[[ -f ${CC_FILE_OLD} ]] && mv "${CC_FILE_OLD}" "${CC_FILE}"
					exit 1
				fi

				# The old file is no longer needed.
				rm -f "${CC_FILE_OLD}"
			fi

			# createAllskyOptions.php will use the cc file and the options template file
			# to create an OPTIONS_FILE for this camera type/model.
			# These variables don't include a directory since the directory is specified with "--dir" below.

			if [[ ${DEBUG} == "true" ]]; then
				echo -e "${wDEBUG}Calling:" \
					"${ALLSKY_WEBUI}/includes/createAllskyOptions.php" \
					${FORCE} ${DEBUG_ARG} \
					--cc_file "${CC_FILE}" \
					--options_file "${OPTIONS_FILE}" \
					--settings_file "${SETTINGS_FILE}${wNC}"
			fi
			R="$("${ALLSKY_WEBUI}/includes/createAllskyOptions.php" \
				${FORCE} ${DEBUG_ARG} \
				--cc_file "${CC_FILE}" \
				--options_file "${OPTIONS_FILE}" \
				--settings_file "${SETTINGS_FILE}" \
				2>&1)"

			# .php files don't return error codes so we check if it worked by
			# looking for a string in its output.

			if [[ -n ${R} ]]; then
				if ! echo "${R}" | grep --quiet "XX_WORKED_XX"; then
					echo -n -e "${wERROR}ERROR: Unable to create '${OPTIONS_FILE}'"
					if [[ ${OPTIONS_FILE_ONLY} == "true" ]]; then
						echo -e "file.${wNC}"
					else
						echo -e " and '${SETTINGS_FILE}' files.${wNC}"
					fi
					echo "${R}"
					exit 1
				fi
			else
				# If there's no output, there won't be any special string
				# so assume the file(s) didn't get created.
				# We don't simply fall through to the code after the "else" so we can
				# output a more specific error message for debugging purposes.
				echo -n -e "${wERROR}ERROR: Unable to create '${OPTIONS_FILE}'"
				if [[ ${OPTIONS_FILE_ONLY} == "false" ]]; then
					echo " and '${SETTINGS_FILE}' files"
				fi
				echo -e " - nothing returned.${wNC}"
				exit 1
			fi

			OK=true
			if [[ ! -f ${OPTIONS_FILE} ]]; then
				echo -e "${wERROR}${ME}: ERROR Options file ${OPTIONS_FILE} not created.${wNC}"
				OK=false
			fi
			if [[ ! -f ${SETTINGS_FILE} && ${OPTIONS_FILE_ONLY} == "false" ]]; then
				echo -e "${wERROR}${ME}: ERROR Settings file ${SETTINGS_FILE} not created.${wNC}"
				OK=false
			fi
			[[ ${OK} == "false" ]] && exit 2

			# It's an error if XX_WORKED_XX is NOT in the output.
			echo -e "${R}" | grep --silent "XX_WORKED_XX" || exit 2

			# Don't do anything else if ${CAMERA_TYPE_ONLY} is set.
			[[ ${CAMERA_TYPE_ONLY} == "true" ]] && exit 0

			SHOW_POSTDATA_MESSAGE=false	# user doesn't need to see this output
			NEEDS_RESTART=true
			;;

		filename)
			check_website && WEBSITE_CONFIG+=("config.imageName" "${LABEL}" "${NEW_VALUE}")
			NEEDS_RESTART=true
			;;

		extratext)
			# It's possible the user will create/populate the file while Allsky is running,
			# so it's not an error if the file doesn't exist or is empty.
			if [[ -n ${NEW_VALUE} ]]; then
				if [[ ! -f ${NEW_VALUE} ]]; then
					echo -e "${wWARNING}WARNING: '${NEW_VALUE}' does not exist; please change it.${wNC}"
				elif [[ ! -s ${NEW_VALUE} ]]; then
					echo -e "${wWARNING}WARNING: '${NEW_VALUE}' is empty; please change it.${wNC}"
				fi
			fi
			NEEDS_RESTART=true
			;;

		latitude | longitude)
			# Allow either +/- decimal numbers, OR numbers with N, S, E, W, but not both.
			if NEW_VALUE="$(convertLatLong "${NEW_VALUE}" "${KEY}")" ; then
				check_website && WEBSITE_CONFIG+=(config."${KEY}" "${LABEL}" "${NEW_VALUE}")
			else
				echo -e "${wWARNING}WARNING: ${NEW_VALUE}.${wNC}"
			fi
			NEEDS_RESTART=true
			TWILIGHT_DATA_CHANGED=true
			;;

		angle)
			NEEDS_RESTART=true
			TWILIGHT_DATA_CHANGED=true
			;;

		takeDaytimeImages)
			NEEDS_RESTART=true
			TWILIGHT_DATA_CHANGED=true
			;;

		config)
			if [[ ${NEW_VALUE} == "" ]]; then
				NEW_VALUE="[none]"
			elif [[ ${NEW_VALUE} != "[none]" ]]; then
				if [[ ! -f ${NEW_VALUE} ]]; then
					echo -e "${wWARNING}WARNING: Configuration File '${NEW_VALUE}' does not exist; please change it.${wNC}"
				elif [[ ! -s ${NEW_VALUE} ]]; then
					echo -e "${wWARNING}WARNING: Configuration File '${NEW_VALUE}' is empty; please change it.${wNC}"
				fi
			fi
			;;

		dayTuningFile | nightTuningFile)
			if [[ -n ${NEW_VALUE} && ! -f ${NEW_VALUE} ]]; then
				echo -e "${wWARNING}WARNING: Tuning File '${NEW_VALUE}' does not exist; please change it.${wNC}"
			fi
			NEEDS_RESTART=true
			;;

		displaySettings)
			if [[ ${NEW_VALUE} -eq 0 ]]; then
				NEW_VALUE=false
			else
				NEW_VALUE=true
			fi
			if check_website; then
				PARENT="homePage.popoutIcons"
				INDEX=$(getJSONarrayIndex "${WEB_CONFIG_FILE}" "${PARENT}" "Allsky Settings")
				if [[ ${INDEX} -ge 0 ]]; then
					WEBSITE_CONFIG+=("${PARENT}[${INDEX}].display" "${LABEL}" "${NEW_VALUE}")
				else
					echo -e "${wWARNING}WARNING: Unable to update ${wBOLD}${LABEL}${wNBOLD} in ${WEB_CONFIG_FILE}; ignoring.${wNC}"
				fi
			else
				echo -e "${wWARNING}<br>Change to ${wBOLD}${LABEL}${wNBOLD} not relevant.${wNC}"
			fi
			;;

		showonmap)
			[[ ${NEW_VALUE} -eq 0 ]] && POSTTOMAP_ACTION="--delete"
			RUN_POSTTOMAP=true
			;;

		location | owner | camera | lens | computer)
			RUN_POSTTOMAP=true
			check_website && WEBSITE_CONFIG+=(config."${KEY}" "${LABEL}" "${NEW_VALUE}")
			;;

		websiteurl | imageurl)
			RUN_POSTTOMAP=true
			;;


		*)
			echo -e "${wWARNING}WARNING: Unknown label '${LABEL}', key='${KEY}'; ignoring.${wNC}"
			;;

		esac
		shift 3
done

if check_website ; then
	# Anytime a setting in settings.json changed we want to
	# send an updated file to any Allsky Website(s).
	[[ ${DEBUG} == "true" ]] && echo -e "${wDEBUG}Executing postData.sh${NC}"
	if [[ ${TWILIGHT_DATA_CHANGED} == "true" ]]; then
		x=""
	else
		x="--settingsOnly"
	fi

	if RESULT="$("${ALLSKY_SCRIPTS}/postData.sh" ${x} >&2)" ; then
		if [[ ${SHOW_POSTDATA_MESSAGE} == "true" ]]; then
			if [[ ${TWILIGHT_DATA_CHANGED} == "true" ]]; then
				echo -en "${wOK}"
				echo -e "Updated twilight data sent to your Allsky Website."
				echo -e "${wBOLD}If you have the Allsky Website open in a browser, please refresh the window.${wNBOLD}"
				echo -en "${wNC}"
			fi
			# Users don't need to know that the settings file was sent.
		fi
	else
		echo -e "${wERROR}ERROR posting updated twilight data: ${RESULT}.${wNC}"
	fi
fi

if [[ ${#WEBSITE_CONFIG[@]} -gt 0 ]]; then
	[[ ${DEBUG} == "true" ]] && echo -e "${wDEBUG}Executing updateWebsiteConfig.sh${NC}"
	"${ALLSKY_SCRIPTS}/updateWebsiteConfig.sh" ${DEBUG_ARG} "${WEBSITE_CONFIG[@]}"
fi

if [[ ${RUN_POSTTOMAP} == "true" ]]; then
	[[ ${DEBUG} == "true" ]] && echo -e "${wDEBUG}Executing postToMap.sh${NC}"
	"${ALLSKY_SCRIPTS}/postToMap.sh" --whisper --force ${DEBUG_ARG} ${POSTTOMAP_ACTION}
fi

if [[ ${RESTARTING} == "false" && ${NEEDS_RESTART} == "true" ]]; then
	echo -en "${wOK}${wBOLD}"
	echo "*** You must restart Allsky for your change to take affect. ***"
	echo -en "${wNBOLD}${wNC}"
fi


exit 0

