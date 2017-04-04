#!/bin/bash
#
# Flash compilation script for the Nexus 6P
#
# Copyright (C) 2016-2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# PURPOSE: Build Flash Kernel and package it into a flashable zip
# USAGE: $ bash kernel.sh -h


############
#          #
#  COLORS  #
#          #
############

BLINK_RED="\033[05;31m"
BOLD="\033[1m"
RED="\033[01;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh

# MAC CHECK; THIS SCRIPT SHOULD ONLY BE RUN ON LINUX
if [[ $( uname -a | grep -i "darwin" ) ]]; then
    reportError "Wrong window! ;)" && exit
fi

# PRINT A HELP MENU IF REQUESTED
function help_menu() {
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RESTORE} Builds and packages Flash Kernel\n"
    echo -e "${BOLD}USAGE:${RESTORE} bash ${0} <options>\n"
    echo -e "${BOLD}EXAMPLE:${RESTORE} bash ${0} public tc 4.9 defconfig angler_defconfig\n"
    echo -e "${BOLD}Options:${RESTORE}"
    echo -e "   public:     builds and pushes to the public folder"
    echo -e "   tc 4.9:     builds with the stock AOSP 4.9 toolchain"
    echo -e "   defconfig:  builds with the specified defconfig\n"
    echo -e "No options will build a normal kernel and push to private folder\n"
    exit
}


################
#              #
#  PARAMETERS  #
#              #
################

# UNSET PREVIOUSLY USED VARIABLES IN CASE SCRIPT WAS SOURCED
unset LOCALVERSION
unset MODE
unset TOOLCHAIN_NAME
unset DEFCONFIG
SUCCESS=false

# DEFINE NECESSARY VARIABLES
DEVICE=angler
KERNEL_BRANCH=n7.1.2-flash

# GATHER PARAMETERS
while [[ $# -ge 1 ]]; do
    case "${1}" in
        "private"|"public"|"test")
            MODE=${1} ;;
        "tc")
            shift
            if [[ $# -ge 1 ]]; then
                case "${1}" in
                    "4.9")
                        TOOLCHAIN_NAME=AOSP-4.9 ;;
                    *)
                        reportError "Invalid TC type!" && exit ;;
                esac
            else
                reportError "Please specify a TC type!" && exit
            fi ;;
        "defconfig")
            shift
            if [[ $# -ge 1 ]]; then
                DEFCONFIG=${1}
            else
                reportError "Please specify a defconfig!" && exit
            fi ;;
        "-h"|"--help")
            help_menu ;;
        *)
            reportError "Invalid parameter" && exit ;;
    esac

    shift
done

if [[ -z ${DEVICE} || -z ${KERNEL_BRANCH} ]]; then
    reportError "You did not specify a necessary parameter!" && exit
fi

if [[ -z ${MODE} ]]; then
    MODE=private
fi


###############
#             #
#  VARIABLES  #
#             #
###############

# ANDROID_HEAD: head folder of all Android folders
# KERNEL_HEAD: head folder to all kernel folders
# ZIP_MOVE_HEAD: head folder to all the folders that hold completed zips
# TOOLCHAIN_HEAD: head folder for toolchains (also holds the source)
# ANYKERNEL_FOLDER: folder that holds AnyKernel source
# SOURCE_FOLDER: folder that holds kernel source
# ARCHITECTURE: architecture of the device we are compiling for
# KERNEL_IMAGE: name of the completed kernel image
# TOOLCHAIN_PREFIX: end of the toolchain name
# TOOLCHAIN_NAME: name of the toolchain we want to compile and use
# TOOLCHAIN_FOLDER: final location of the toolchain after compilation
# ZIP_MOVE: final location of the completed zip files
# ANYKERNEL_BRANCH: branch that we are using for our AnyKernel source
# THREADS: -j flag for make with the number of threads available
# DEFCONFIG: name of the defconfig we are using
# KERNEL: location of the kernel image after compilation


ANDROID_HEAD=${HOME}
KERNEL_HEAD=${ANDROID_HEAD}/Kernels
ZIP_MOVE_HEAD=${HOME}/Web/Downloads
TOOLCHAIN_HEAD=${HOME}/Toolchains/Prebuilts
ANYKERNEL_FOLDER=${KERNEL_HEAD}/anykernel
if [[ -z ${DEFCONFIG} ]]; then
    DEFCONFIG=flash_defconfig
fi
SOURCE_FOLDER=${KERNEL_HEAD}/${DEVICE}
ARCHITECTURE=arm64
KERNEL_IMAGE=Image.gz-dtb
TOOLCHAIN_PREFIX=aarch64-linux-android-
if [[ -z ${TOOLCHAIN_NAME} ]]; then
    TOOLCHAIN_NAME=${TOOLCHAIN_PREFIX}6.x
fi
TOOLCHAIN_FOLDER=${TOOLCHAIN_HEAD}/${TOOLCHAIN_NAME}
case ${MODE} in
    "private")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/.superhidden/Kernels
        ANYKERNEL_BRANCH=${DEVICE}-flash-personal-7.1.2 ;;
    "public")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels
        ANYKERNEL_BRANCH=${DEVICE}-flash-public-7.1.2 ;;
    "test")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/.tmp
        ANYKERNEL_BRANCH=${DEVICE}-flash-public-7.1.2 ;;
esac
THREADS=-j$( nproc --all )
KERNEL=${SOURCE_FOLDER}/arch/${ARCHITECTURE}/boot/${KERNEL_IMAGE}


################
#              #
# SCRIPT START #
#              #
################

# SET THE START OF THE SCRIPT
START=$( TZ=MST date +"%s" )


# SILENTLY SHIFT KERNEL BRANCHES
clear && cd "${SOURCE_FOLDER}"

# ONLY CHECKOUT IF WE ARE NOT CURRENTLY BISECTING OR REBASING
if [[ ! $(git status | grep "bisect\|rebase") ]]; then
    git checkout ${KERNEL_BRANCH} > /dev/null 2>&1
fi

# SET KERNEL VERSION FROM MAKEFILE
KERNEL_VERSION=$( grep -r "EXTRAVERSION = -" ${SOURCE_FOLDER}/Makefile | sed 's/^.*f/f/' )

# CONDITIONALLY DEFINE ZIP NAME
if [[ -n ${KERNEL_VERSION} ]]; then
    export LOCALVERSION=-$( TZ=MST date +%Y%m%d )
    ZIP_NAME=${KERNEL_VERSION}${LOCALVERSION}-$( TZ=MST date +%H%M )
else
    ZIP_NAME=flash-angler-$( TZ=MST date +%Y%m%d-%H%M )
fi


###################
# SHOW ASCII TEXT #
###################

echo -e ${RED}; newLine
echo -e "================================================================================================"; newLine; newLine
echo -e "  ___________________________________  __   ______ _______________________   ________________   "
echo -e "  ___  ____/__  /___    |_  ___/__  / / /   ___  //_/__  ____/__  __ \__  | / /__  ____/__  /   "
echo -e "  __  /_   __  / __  /| |____ \__  /_/ /    __  ,<  __  __/  __  /_/ /_   |/ /__  __/  __  /    "
echo -e "  _  __/   _  /___  ___ |___/ /_  __  /     _  /| | _  /___  _  _, _/_  /|  / _  /___  _  /___  "
echo -e "  /_/      /_____/_/  |_/____/ /_/ /_/      /_/ |_| /_____/  /_/ |_| /_/ |_/  /_____/  /_____/  "; newLine; newLine; newLine
echo -e "================================================================================================"; newLine; newLine


#########################
#  SHOW KERNEL VERSION  #
#########################

echoText "KERNEL VERSION"; newLine

echo -e ${RED}${ZIP_NAME}${RESTORE}; newLine


####################
# CLEANING FOLDERS #
####################

echoText "CLEANING UP"

# Cleaning of AnyKernel directory
cd "${ANYKERNEL_FOLDER}"
git checkout ${ANYKERNEL_BRANCH}
rm -rf ${KERNEL_IMAGE}


#################
# MAKING KERNEL #
#################

echoText "MAKING KERNEL"

cd "${SOURCE_FOLDER}"

# TAG THE HEAD COMMIT WITH THE VERSION FIRST IF IT'S A PUBLIC BUILD
if [[ ${MODE} = "public" ]]; then
    git tag -a "${ZIP_NAME}" -m "${ZIP_NAME}"
    git push origin "${ZIP_NAME}"
fi

# PROPERLY POINT COMPILER TO TOOLCHAIN AND ARCHITECTURE
export CROSS_COMPILE=${TOOLCHAIN_FOLDER}/bin/${TOOLCHAIN_PREFIX}
export ARCH=${ARCHITECTURE}
export SUBARCH=${ARCHITECTURE}

# CLEAN PREVIOUSLY COMPILED FILES AND DEFCONFIG
make clean && make mrproper

# POINT TO PROPER DEFCONFIG
make ${DEFCONFIG}

# MAKE THE KERNEL
time make ${THREADS} | tee -a ${LOGDIR}/Compilation/Kernels/${ZIP_NAME}.log


######################
# IF KERNEL COMPILED #
######################

if [[ $( ls ${KERNEL} 2>/dev/null | wc -l ) != 0 ]]; then
    # SET BUILD SUCCESS STRING AND SUCCESS VARIABLE
    BUILD_RESULT_STRING="BUILD SUCCESSFUL" && SUCCESS=true


    #####################
    # COPY KERNEL IMAGE #
    #####################

    newLine; echoText "MOVING $( echo ${KERNEL_IMAGE} | awk '{print toupper($0)}' ) ($( du -h "${KERNEL}" | awk '{print $1}' ))"
    cp "${KERNEL}" "${ANYKERNEL_FOLDER}"

    # MAKE ZIP_FORMAT VARIABLE
    ZIP_FORMAT=f*.zip

    # IF ZIPMOVE DOESN'T EXIST, MAKE IT; OTHERWISE, CLEAN IT
    if [[ ! -d "${ZIP_MOVE}" ]]; then
        mkdir -p "${ZIP_MOVE}"
    elif [[ ${MODE} != "public" ]]; then
        rm -rf "${ZIP_MOVE}"/*
    fi

    # MOVE TO ANYKERNEL FOLDER
    cd "${ANYKERNEL_FOLDER}"


    #################
    # MAKE ZIP FILE #
    #################

    echoText "MAKING FLASHABLE ZIP"
    zip -r9 ${ZIP_NAME}.zip * -x README.md ${ZIP_NAME}.zip > /dev/null 2>&1


    #################
    # MOVE ZIP FILE #
    #################

    mv ${ZIP_NAME}.zip "${ZIP_MOVE}"

    # IF IT IS A TEST BUILD, UPLOAD IT
    if [[ ${MODE} = "test" ]]; then
        URL=$( curl -s --upload-file "${ZIP_MOVE}/${ZIP_NAME}.zip" "https://transfer.sh/${ZIP_NAME}.zip" )
    fi


    ###################
    # GENERATE MD5SUM #
    ###################

    md5sum "${ZIP_MOVE}"/${ZIP_NAME}.zip > "${ZIP_MOVE}"/${ZIP_NAME}.zip.md5sum


    # CLEAN ZIMAGE-DTB FROM ANYKERNEL FOLDER AFTER ZIPPING AND MOVING
    rm -rf "${ANYKERNEL_FOLDER}"/Image.gz-dtb


###################
# IF BUILD FAILED #
###################

else
    BUILD_RESULT_STRING="BUILD FAILED"
    SUCCESS=false
fi


##############
# SCRIPT END #
##############

echoText "${BUILD_RESULT_STRING}!"

END=$( TZ=MST date +"%s" )


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION, AND SIZE
if [[ ${SUCCESS} = true ]]; then
    case ${MODE} in
        "private"|"public")
            echo -e ${RED}"FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip"
            echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_NAME}.zip | awk '{print $1}' )"${RESTORE} ;;
        "test")
            echo -e ${RED}"FILE LOCATION: ${URL}"${RESTORE} ;;
    esac
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e "DURATION: $( format_time ${END} ${START} )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +"%m/%d/%Y %H:%M:%S" ): ${BASH_SOURCE} ${1}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( format_time ${END} ${START} )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
    # FILE LOCATION: PATH
    case ${MODE} in
        "private"|"public")
            echo -e "FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip" >> ${LOG} ;;
        "test")
            echo -e "FILE LOCATION: ${URL}" >> ${LOG} ;;
    esac
fi


##############
# SCRIPT END #
##############

# KILL TMP FOLDER
if [[ ${MODE} = "test" ]]; then
    rm -rf ${ZIP_MOVE}
fi

echo -e "\a"
unset LOCALVERSION
