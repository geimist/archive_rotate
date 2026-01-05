#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2317,2329,2125
version="v1.2.0"
#################################################################################
#   2025-12-26                                                                  #
#   © 2026 by geimist                                                           #
#################################################################################

# ./archive_rotate.sh -s=*.odb -h=*x72 -d=1x60 -m=1x* -p="/volume1/TEMP/SICHERUNGSKOPIEN/" -v --dry-run

make_dummy () {
    # create dummy files for test
    # to aktivate this function remove or disable the next line
return
    # adjust the following 3 parameters:
    DummyDir="/<FULL_PATH>"
    MaxHours=24
    IntervallHours=1
    
    printf "\n---------------------------------------------------------------------------\n"
    [ ! -d "${DummyDir}" ] && echo "{DummyDir} is not a valid directory - create it" && mkdir -p "${DummyDir}"

    IFS=' ' read -ra houre_array <<< "$(seq -s ' ' 1 "${IntervallHours}" "${MaxHours}")"
    for houre in "${houre_array[@]}"; do
        touch -t "$(date -d "-${houre}" hours +%Y%m%d%H%M)" "${DummyDir}/$(date -d "-${houre}" hours +%Y-%m-%d_%H-%M).dummy"
    done
    printf "\n---------------------------------------------------------------------------\n"
    exit
}
make_dummy

#################################################################################
#   MAIN SCRIPT                                                                 #
#################################################################################

# Usage info
show_help () {
cat << EOF
This script rotates archived files by user specified pattern.
v1.2.0 © 2026 by geimist

Usage: ./${0##*/} [-c -r -v --dry-run] -p=Path [-s=searchpattern] [-h=…|-d=…|-w=…|-m=…|-y=…]

Example:
./${0##*/} -crv -p="/volume1/home/MySQL_Backup/" --searchpattern="WordPress_*" --filesperhour="*x48" -d=24x7 -m="1x*"

- The specification for the number of files and time periods is separated 
  by an "x" [DIGITxDIGIT eg. -h=7x6 for 7 files per hour for 6 hours].
- The time periods are added together. This means that the next larger 
  period starts at the end of the previous smaller period.
- Older files outside the defined period are deleted if parameters 
  -c / --cleanig are set, otherwise the files are ignored.
- Periods and counts can also be defined as wildcards [*].
- Intervals are dynamic. For example, if 12 files are to be kept per year, 
  and all files of this period are from one day, 12 files will also be kept, 
  although they have a disproportionately small time interval.

    -p= --path=             Path to parent directory

Arguments for the count of kept files and count of the respective period:
    -h= --filesperhour=     how many files per how many hours [eg. 60x24 means: 24 hours with 60 files each]
    -d= --filesperday=      how many files per how many days
    -w= --filesperweek=     how many files per how many weeks
    -m= --filespermonth=    how many files per how many month
    -y= --filesperyear=     how many files per how many years

optional arguments:
        --dry-run           perform a trial run with no changes made
    -c  --cleaning          delete files out of range
        --quiet             silent mode
    -r  --recursive         also searches in subdirectories
    -s= --searchpattern=    only files who match pattern are proceeded 
    -v  --verbose           explain what is being done

    -h  --help              display this help and exit

EOF
exit 1
}

verbose=0
TotalHours=0
SEARCHPATTERN=*
purge=0
DryRun=0
abort=0
TotalCountDel=0
recursive="-maxdepth 1"
quiet=0
DeletedBytes=0
TotalFileSize=0

# read arguments
if [ -z "$*" ]; then
    echo -e
    echo "Too few arguments!"
    show_help
fi

for i in "$@" ; do
    case $i in
        -p=*|--path=*)
        WORKDIR="${i#*=}"
        [ ! -d "$WORKDIR" ] && echo "ERROR - not a valid path! ($WORKDIR)" && exit 1
        ;;
        -s=*|--searchpattern=*)
        SEARCHPATTERN="${i#*=}"
        shift # past argument=value
        ;;
        -h=*|--filesperhour=*)
        X_FILE_PER_X_HOURE="${i#*=}"
        if ! grep -qE '([0-9]{1,}|\*)x([0-9]|\*){1,}' <<< "${X_FILE_PER_X_HOURE}" ; then
            echo "ERROR - false syntax [-h=${X_FILE_PER_X_HOURE} / --filesperhour=${X_FILE_PER_X_HOURE}]"
            exit 1
        fi
        shift
        ;;
        -d=*|--filesperday=*)
        X_FILE_PER_X_DAY="${i#*=}"
        if ! grep -qE '([0-9]{1,}|\*)x([0-9]|\*){1,}' <<< "${X_FILE_PER_X_DAY}" ; then
            echo "ERROR - false syntax [-h=${X_FILE_PER_X_DAY} / --filesperhour=${X_FILE_PER_X_DAY}]"
            exit 1
        fi
        shift
        ;;
        -w=*|--filesperweek=*)
        X_FILE_PER_X_WEEK="${i#*=}"
        if ! grep -qE '([0-9]{1,}|\*)x([0-9]|\*){1,}' <<< "${X_FILE_PER_X_WEEK}" ; then
            echo "ERROR - false syntax [-h=${X_FILE_PER_X_WEEK} / --filesperhour=${X_FILE_PER_X_WEEK}]"
            exit 1
        fi
        shift
        ;;
        -m=*|--filespermonth=*)
        X_FILE_PER_X_MONTH="${i#*=}"
        if ! grep -qE '([0-9]{1,}|\*)x([0-9]|\*){1,}' <<< "${X_FILE_PER_X_MONTH}" ; then
            echo "ERROR - false syntax [-h=${X_FILE_PER_X_MONTH} / --filesperhour=${X_FILE_PER_X_MONTH}]"
            exit 1
        fi
        shift
        ;;
        -y=*|--filesperyear=*)
        X_FILE_PER_X_YEAR="${i#*=}"
        if ! grep -qE '([0-9]{1,}|\*)x([0-9]|\*){1,}' <<< "${X_FILE_PER_X_YEAR}" ; then
            echo "ERROR - false syntax [-h=${X_FILE_PER_X_YEAR} / --filesperhour=${X_FILE_PER_X_YEAR}]"
            exit 1
        fi
        shift
        ;;
        --dry-run)
        DryRun=1
        shift
        ;;
        -v|--verbose)
        verbose=1
        shift
        ;;
        -r|--recursive)
        recursive=
        shift
        ;;
        -c|--cleaning)
        purge=1
        shift
        ;;
        -q|--quiet)
        quiet=1
        shift
        ;;
        -rv|-vr)
        recursive=
        verbose=1
        shift
        ;;
        -cr|-rc)
        recursive=
        purge=1
        shift
        ;;
        -cv|-vc)
        verbose=1
        purge=1
        shift
        ;;
        -crv|-cvr|-vcr|-vrc|-rcv|-rvc)
        verbose=1
        purge=1
        recursive=
        shift
        ;;
        -h|--help)
        show_help
        ;;
        *)
        echo "ERROR - unknown argument ($1)!"
        show_help
        ;;
    esac
done

# DEBUG
#DryRun=1



# Calculate TotalHours
TotalHours=0
[ -n "${X_FILE_PER_X_HOURE}" ] && periods_val=$(echo "${X_FILE_PER_X_HOURE}" | awk -Fx '{print $2}') && if [[ "$periods_val" =~ ^[0-9]+$ ]]; then TotalHours=$(( TotalHours + periods_val * 1 )); else TotalHours=999999999; fi
[ -n "${X_FILE_PER_X_DAY}" ] && periods_val=$(echo "${X_FILE_PER_X_DAY}" | awk -Fx '{print $2}') && if [[ "$periods_val" =~ ^[0-9]+$ ]]; then TotalHours=$(( TotalHours + periods_val * 24 )); else TotalHours=999999999; fi
[ -n "${X_FILE_PER_X_WEEK}" ] && periods_val=$(echo "${X_FILE_PER_X_WEEK}" | awk -Fx '{print $2}') && if [[ "$periods_val" =~ ^[0-9]+$ ]]; then TotalHours=$(( TotalHours + periods_val * 168 )); else TotalHours=999999999; fi
[ -n "${X_FILE_PER_X_MONTH}" ] && periods_val=$(echo "${X_FILE_PER_X_MONTH}" | awk -Fx '{print $2}') && if [[ "$periods_val" =~ ^[0-9]+$ ]]; then TotalHours=$(( TotalHours + periods_val * 730 )); else TotalHours=999999999; fi
[ -n "${X_FILE_PER_X_YEAR}" ] && periods_val=$(echo "${X_FILE_PER_X_YEAR}" | awk -Fx '{print $2}') && if [[ "$periods_val" =~ ^[0-9]+$ ]]; then TotalHours=$(( TotalHours + periods_val * 8760 )); else TotalHours=999999999; fi

# Set PERIODS variables
PERIODS_H=""
PERIODS_D=""
PERIODS_W=""
PERIODS_M=""
PERIODS_Y=""
[ -n "${X_FILE_PER_X_HOURE}" ] && PERIODS_H=$(echo "${X_FILE_PER_X_HOURE}" | awk -Fx '{print $2}')
[ -n "${X_FILE_PER_X_DAY}" ] && PERIODS_D=$(echo "${X_FILE_PER_X_DAY}" | awk -Fx '{print $2}')
[ -n "${X_FILE_PER_X_WEEK}" ] && PERIODS_W=$(echo "${X_FILE_PER_X_WEEK}" | awk -Fx '{print $2}')
[ -n "${X_FILE_PER_X_MONTH}" ] && PERIODS_M=$(echo "${X_FILE_PER_X_MONTH}" | awk -Fx '{print $2}')
[ -n "${X_FILE_PER_X_YEAR}" ] && PERIODS_Y=$(echo "${X_FILE_PER_X_YEAR}" | awk -Fx '{print $2}')

WORKDIR=${WORKDIR%/}/

# TotalFileCount:
TotalFileCount=$(find "${WORKDIR}" ${recursive} -name "${SEARCHPATTERN}" -type f | grep -v "^$" | wc -l )

# TotalFileSize:
while IFS= read -r -d '' i; do
    [ -f "${i}" ] && TotalFileSize=$((TotalFileSize + $(stat -c %s "${i}") ))
done < <(find "${WORKDIR}" ${recursive} -type f -name "${SEARCHPATTERN}" -print0)

# task overview:
if [ $quiet = 0 ]; then
    echo "PATH                  = $WORKDIR"
    echo "SEARCHPATTERN         = $SEARCHPATTERN"
    [ "$verbose" = 1 ] && echo "VERBOSE               = yes"
    [ -n "$recursive" ] && echo "SEARCH IN SUB DIRS    = no"
    [ -z "$recursive" ] && echo "SEARCH IN SUB DIRS    = yes"
    [ "$purge" = 0 ] && echo "FILES OUT OF RANGE    = kept"
    [ "$purge" = 1 ] && echo "FILES OUT OF RANGE    = deleted"
    [ "$DryRun" = 1 ] && printf "\nINFO: A dry run is performed - no data is changed"
    echo -e
    [ -n "$X_FILE_PER_X_HOURE" ] && echo "  $(echo "$X_FILE_PER_X_HOURE" | awk -Fx '{print $1}') FILES PER HOURE [$(echo "$X_FILE_PER_X_HOURE" | awk -Fx '{print $2}')x]"
    [ -n "$X_FILE_PER_X_DAY" ] && echo "  $(echo "$X_FILE_PER_X_DAY" | awk -Fx '{print $1}') FILES PER DAY [$(echo "$X_FILE_PER_X_DAY" | awk -Fx '{print $2}')x]"
    [ -n "$X_FILE_PER_X_WEEK" ] && echo "  $(echo "$X_FILE_PER_X_WEEK" | awk -Fx '{print $1}') FILES PER WEEK [$(echo "$X_FILE_PER_X_WEEK" | awk -Fx '{print $2}')x]"
    [ -n "$X_FILE_PER_X_MONTH" ] && echo "  $(echo "$X_FILE_PER_X_MONTH" | awk -Fx '{print $1}') FILES PER MONTH [$(echo "$X_FILE_PER_X_MONTH" | awk -Fx '{print $2}')x]"
    [ -n "$X_FILE_PER_X_YEAR" ] && echo "  $(echo "$X_FILE_PER_X_YEAR" | awk -Fx '{print $1}') FILES PER YEAR [$(echo "$X_FILE_PER_X_YEAR" | awk -Fx '{print $2}')x]"
    printf "\n---------------------------------------------------------------------------"
fi

DateDiff () {
#################################################################################
#   this function returns the time difference of two passed data in hours       #
#################################################################################
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo $(( (d1 - d2) / 3600 ))
}

LoopFunction () {
#################################################################################
#   this function runs through the individual time periods and                  #
#   deletes the surplus number of files in each case                            #
#################################################################################

    if [[ "${FILES_PER_PERIOD}" != "*" ]] && [[ -n "${FILES_PER_PERIOD}" ]] ; then
        Loop1=0

        if [[ "${PERIODS}" = "*" ]] ; then
            OldestFile=$(find "${WORKDIR}" ${recursive} -name "${SEARCHPATTERN}" -type f -printf '%T+\n' | sort | head -n 1 | awk -F. '{print $1}' | sed -e 's/+/ /g')
            if [[ -n "$OldestFile" ]]; then
                AvailableHours=$(( $( DateDiff "$(date -d "-${BaseHours} hours" +"%Y-%m-%d %H:%M:%S")" "$OldestFile" ) ))
                PERIODS=$(( AvailableHours / $Factor + 1 ))
                [[ $PERIODS -lt 0 ]] && PERIODS=0
            else
                PERIODS=0
            fi
        fi

        while [ "${PERIODS}" -ne "${Loop1}" ]; do
            CheckPeriodMin=$(( BaseHours + ($PERIODS * $Factor) - ($Loop1 * $Factor) ))
            Loop1=$(( $Loop1 + 1 ))
            CheckPeriodMax=$(( BaseHours + ($PERIODS * $Factor) - ($Loop1 * $Factor) ))

            # Abrunden der Zeitstempel auf den Anfang des Zeitraums auf volle Stunden
            # https://chat.openai.com/share/c8db0e6c-e2e0-41b2-bbf5-70cc395d2ec2
            RoundedMin=$(date -d "-${CheckPeriodMin} hours" +"%Y-%m-%d %H:00:00")
            RoundedMax=$(date -d "-${CheckPeriodMax} hours" +"%Y-%m-%d %H:00:00")
        # IDEE: vielleicht sollte hier die Rundung nicht nur auf Stunden basieren, sondern auf die aktuelle Range
            FileList=$(find "${WORKDIR}" ${recursive} -name "${SEARCHPATTERN}" -type f -newermt "${RoundedMin}" ! -newermt "${RoundedMax}" -exec ls -1rt "{}" + | tac)

        # ohne Rundung (original):
        #   FileList=$(find "${WORKDIR}" ${recursive} -name "${SEARCHPATTERN}" -type f -newermt "$(date -d "-$(( ${CheckPeriodMin} + $TotalHours )) hours" +"%Y-%m-%d %H:%M:%S")" ! -newermt "$(date -d "-$(( ${CheckPeriodMax} + $TotalHours )) hours" +"%Y-%m-%d %H:%M:%S")" -exec ls -1rt "{}" + | tac ) # | head -n -"${PER_DAY}" )

            # finde alle Dateien mit einem bestimmten Suchstring (SEARCHPATTERN) neuer als Datum (-newermt) nicht neuer als Datum ( ! -newermt) nach Zeit sortiert (-exec ls -1rt "{}" +) in umgekehrter Reihenfolge ( tac)
            count=$(echo "${FileList}" | grep -v "^$" | wc -l )
            if [[ ${count} -gt "${FILES_PER_PERIOD}" ]] ; then
                IntervallSaveFile=$( echo | gawk "{print ${count}/${FILES_PER_PERIOD}}" )
                [ $verbose = 1 ] && echo "  ➜ ${Loop1}th ${Range} from ${PERIODS} (task: keep ${FILES_PER_PERIOD} from ${count} / intend keeping every ${IntervallSaveFile}th file)"
                Loop2=0
                while read -r line; do
                    if (( (Loop2 + 1) % IntervallSaveFile == 0 )); then
                        [ ${verbose} = 1 ] && echo "    kept ➜ $line"
                    else
                        [ ${verbose} = 1 ] && echo "    rm   ➜ $line"
                        DeletedBytes=$(($DeletedBytes+$(stat -c %s "${line}")))
                        [ ${DryRun} = 0 ] &&  rm -f "${line}"
                        TotalCountDel=$(($TotalCountDel + 1))
                    fi
                    Loop2=$(( $Loop2 + 1))
                done <<< "${FileList}"
            else
                [ ${verbose} = 1 ] && echo "  ➜ ${Loop1}th ${Range} from ${PERIODS} - existing files [${count}] under limit [${FILES_PER_PERIOD}] - nothing to do …"
            fi
        done

        [ ${abort} = 1 ] && [ ${verbose} = 1 ] && printf '\n         ➜ wildcard for %s (larger intervals are not considered - script is aborted)' "$Range"
    else
        [ ${verbose} = 1 ] && echo "         ➜ wildcard or not defined (keep all)"
    fi
}

if [ -n "${X_FILE_PER_X_YEAR}" ] ; then
    Range=year
    FILES_PER_PERIOD=$(echo "$X_FILE_PER_X_YEAR" | awk -Fx '{print $1}')
    PERIODS=$(echo "$X_FILE_PER_X_YEAR" | awk -Fx '{print $2}')
    Factor=$((24 * 365))
    BaseHours=$(( (PERIODS_H * 1) + (PERIODS_D * 24) + (PERIODS_W * 168) + (PERIODS_M * 730) ))
    [ $verbose = 1 ] && printf '\n\nrotated files of the last %s %ss with %s files each:\n\n' "$PERIODS" "$Range" "$FILES_PER_PERIOD"
    LoopFunction
fi

if [ -n "${X_FILE_PER_X_MONTH}" ] && [ $abort = 0 ] ; then
    Range=month
    FILES_PER_PERIOD=$(echo "$X_FILE_PER_X_MONTH" | awk -Fx '{print $1}')
    PERIODS=$(echo "$X_FILE_PER_X_MONTH" | awk -Fx '{print $2}')
    Factor=$((24 * 365 / 12))
    BaseHours=$(( (PERIODS_H * 1) + (PERIODS_D * 24) + (PERIODS_W * 168) ))
    [ $verbose = 1 ] && printf '\n\nrotated files of the last %s %ss with %s files each:\n\n' "$PERIODS" "$Range" "$FILES_PER_PERIOD"
    LoopFunction
fi

if [ -n "${X_FILE_PER_X_WEEK}" ] && [ $abort = 0 ] ; then
    Range=week
    FILES_PER_PERIOD=$(echo "$X_FILE_PER_X_WEEK" | awk -Fx '{print $1}')
    PERIODS=$(echo "$X_FILE_PER_X_WEEK" | awk -Fx '{print $2}')
    Factor=$((24 * 7))
    BaseHours=$(( (PERIODS_H * 1) + (PERIODS_D * 24) ))
    [ $verbose = 1 ] && printf '\n\nrotated files of the last %s %ss with %s files each:\n\n' "$PERIODS" "$Range" "$FILES_PER_PERIOD"
    LoopFunction
fi

if [ -n "${X_FILE_PER_X_DAY}" ] && [ $abort = 0 ] ; then
    Range=day
    FILES_PER_PERIOD=$(echo "$X_FILE_PER_X_DAY" | awk -Fx '{print $1}')
    PERIODS=$(echo "$X_FILE_PER_X_DAY" | awk -Fx '{print $2}')
    Factor=24
    BaseHours=$(( PERIODS_H * 1 ))
    [ $verbose = 1 ] && printf '\n\nrotated files of the last %s %ss with %s files each:\n\n' "$PERIODS" "$Range" "$FILES_PER_PERIOD"
    LoopFunction
fi

if [ -n "${X_FILE_PER_X_HOURE}" ] && [ $abort = 0 ] ; then
    Range=houre
    FILES_PER_PERIOD=$(echo "${X_FILE_PER_X_HOURE}" | awk -Fx '{print $1}')
    PERIODS=$(echo "${X_FILE_PER_X_HOURE}" | awk -Fx '{print $2}')
    Factor=1
    BaseHours=0
    [ $verbose = 1 ] && printf '\n\nrotated files of the last %s %ss with %s files each:\n\n' "$PERIODS" "$Range" "$FILES_PER_PERIOD"
    LoopFunction
fi

if [ "$purge" = 1 ] && [ $abort = 0 ] && [ $TotalHours -lt 100000 ] ; then
    [ $verbose = 1 ] && printf "\n\ndelete older files outside the defined period:\n\n"
    DelList=$(find "${WORKDIR}" ${recursive} -name "${SEARCHPATTERN}" -type f ! -newermt "$(date -d "-$TotalHours hours" +"%Y-%m-%d %H:%M:%S")" -exec ls -1rt "{}" + | tac)
    TotalCountDel=$(($TotalCountDel + $(echo "$DelList" | grep -v "^$" | wc -l )))
    while IFS= read -r line; do
        [ $verbose = 1 ] && echo "    rm   ➜ $line"
        [ $DryRun = 0 ] && rm -f "$line"
    done <<< "$DelList"
elif [ "$purge" = 1 ] && [ $abort = 0 ] ; then
    [ $verbose = 1 ] && printf "\n\nno delete of older files - unlimited period defined\n\n"
fi

[ $quiet = 0 ] && printf "\n\n%s files [%s] of %s files [%s] are removed%s.\n\nfinish :-)\n" "$TotalCountDel" "$(numfmt --to=si --suffix=B $DeletedBytes)" "$TotalFileCount" "$(numfmt --to=si --suffix=B $TotalFileSize)" "$([ $DryRun = 1 ] && echo " [dry run was performed - no files were deleted]")"

exit 0

# changelog:
# 1.0.0
#   - initial release
# 1.1.0
#   - implemented count of total size and deleted size
#   - implemented a function to create dummy files for testing
# 1.1.1
#   - Es wird immer die älteste Datei einer Range erhalten um die nächste Range zu füllen
#   - Zeit wird gerundet
# 1.2.0
#   - der Workarround aus Version 1.2.0 wurde entfernt
#   - die Zeiträume werden jetzt rückwärts abgearbeitet um die korrekte Funktionsweise zu gewährleisten
