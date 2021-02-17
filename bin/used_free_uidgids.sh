#! /bin/bash
#
# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Author:  Jaco Kroon <jaco@uls.co.za>
# So that you can contact me if you need help with the below insanity.
#
# Configuration options:
# max => maximum value of uid/gid that we're interested in/willing to allocate
#	from.  Can be set to - to go maximum possible 32-bit value.
# debug => if non-zero outputs some cryptic debug output (will inherit from environment).
#
max=499
debug=${debug:+1} # set non-zero to enable debug output.

#
# Basic Design:
#
# There is nothing beautiful about this script, it's downright nasty and I
# (Jaco Kroon <jaco@uls.co.za>) will be the first to admit that.
#
# For each of the uid and gid ranges, we primarily keep two variables.
# ranges and reason.  reason is simply one of USED or RESERVED.  Free ranges
# are not mapped into these arrays.
# ranges_ maps a start index onto an end index.  So for example, let's say
# uid range 0..10 is USED (allocated, for whatever purposes):
#
# ranges_uid[0]=10
# reasons_uid[0]=USED
#
# The above says that UID 0 to 10 is USED.
#
# We start with an initially empty set, and then insert into, either merging or
# potentially splitting as we go, by way of the consume function, once completed
# we compact some things and then output.
#

ranges_uid=()
ranges_gid=()
reason_uid=()
reason_gid=()

# Colours to be used if output is a TTY.
colour_USED="\e[0;91m" # brightred
colour_FREE="\e[0;92m" # brightgreen
colour_RESERVED="\e[0;94m" # brightblue
colour_RESET="\e[0m" # reset all styles.

if ! [[ -t 1 ]]; then
	colour_USED=
	colour_FREE=
	colour_RESERVED=
	colour_RESET=
fi

# Find input file if not piped in on stdin, or show a warning about it on
# stderr if we can't find the file.
if [[ -t 0 ]]; then
	def_infile="$(dirname "$0")/../files/uid-gid.txt"
	if ! [[ -r "${def_infile}" ]] || ! exec <"${def_infile}"; then
		echo "Reading from stdin (which happens to be a tty, you should pipe input file to stdin)" >&2
	fi
fi

consume()
{
	# The basic principle here is that we can either add a new range, or split
	# an existing range.  Partial overlaps not dealt with, nor range
	# extensions.  Which would (I believe) negate the need for compact.
	# TODO:  deal with range merging here, eg, if we have 0..10, and adding 11, then
	# we can simply adjust the range to 0..11, for example.
	local variant="$1"
	local ids="$2"
	local type=$([[ "$3" == reserved ]] && echo RESERVED || echo USED)
	local range_start="${ids%..*}"
	local range_end="${ids#*..}"
	declare -n ranges="ranges_${variant}"
	declare -n reasons="reason_${variant}"

	[[ -z "${ids}" ]] && return
	[[ "${ids}" == - ]] && return

	for k in "${!ranges[@]}"; do
		# can the new range be inserted before the next range already in the set?
		[[ ${k} -gt ${range_end} ]] && break
		[[ ${ranges[k]} -lt ${range_start} ]] && continue
		if [[ ${k} -le ${range_start} && ${range_end} -le ${ranges[k]} ]]; then
			# new range is contained completely inside.
			[[ ${reasons[k]} == ${type} ]] && return # same type.
			[[ ${type} == RESERVED ]] && return # USED takes precedence over RESERVED.

			if [[ ${range_end} -lt ${ranges[k]} ]]; then
				ranges[range_end+1]=${ranges[k]}
				reasons[range_end+1]=${reasons[k]}
			fi
			[[ ${range_start} -gt ${k} ]] && ranges[k]=$(( range_start - 1 ))
			break
		else
			echo "${range_start}..${range_end} (${type}) overlaps with ${k}..${ranges[k]} (${reasons[k]}"
			echo "Cannot handle partial overlap."
			exit 1
		fi
	done

	ranges[range_start]="${range_end}"
	reasons[range_start]="${type}"
}

compact()
{
	# This simply coalesces ranges that follow directly on each other.  In
	# other words, if range ends at 10 and the next range starts at 11, just
	# merge the two by adjusting the end of the first range, and removing the
	# immediately following.
	# Param: uid or gid to determine which set we're working with.
	declare -n ranges="ranges_$1"
	declare -n reasons="reason_$1"
	local k e ne
	for k in "${ranges[@]}"; do
		[[ -n "${ranges[k]:+set}" ]] || continue
		e=${ranges[k]}
		while [[ -n "${ranges[e+1]:+set}" && "${reasons[k]}" == "${reasons[e+1]}" ]]; do
			ne=${ranges[e+1]}
			unset "ranges[e+1]"
			e=${ne}
		done
		ranges[k]=${e}
	done
}

output()
{
	# Outputs the raw list as provided (param:  uid or gid)
	declare -n ranges="ranges_$1"
	declare -n reasons="reason_$1"
	local k c=0

	echo "$1 list:"
	for k in "${!ranges[@]}"; do
		echo "$(( c++ )): ${k} => ${ranges[k]} / ${reasons[k]}"
	done
}

# Read the input file which is structured as "username uid gid provider and
# potentially more stuff" Lines starting with # are comments, thus we can
# filter those out.
while read un uid gid provider rest; do
	[[ "${un}" == \#* ]] && continue
	consume uid "${uid}" "${provider}"
	consume gid "${gid}" "${provider}"
done

compact uid
compact gid

# If we're debugging, just output both lists so we can inspect that everything is correct here.
if [[ -n "${debug}" ]]; then
	output uid
	output gid
fi

# Get the various range starts.
uids=("${!ranges_uid[@]}")
gids=("${!ranges_gid[@]}")

# Set max to 2^32-1 if set to -.
if [[ ${max} == - ]]; then
	max=$((2 ** 32 - 1))
fi

ui=0 # index into uids array.
gi=0 # index into gids array.
idbase=0 # "start" of range about to be output.
freeuid=0 # count number of free UIDs
freegid=0 # count number of free GIDs
freepair=0 # count number of free UID+GID pairs.

printf "%-*s%10s%10s\n" $(( ${#max} * 2 + 5 )) "#ID" UID GID

while [[ ${idbase} -le ${max} ]]; do
	# skip over uid and gid ranges that we're no longer interested in (end of range is
	# lower than start of output range).
	while [[ ${ui} -lt ${#uids[@]} && ${ranges_uid[uids[ui]]} -lt ${idbase} ]]; do
		(( ui++ ))
	done
	while [[ ${gi} -lt ${#gids[@]} && ${ranges_gid[gids[gi]]} -lt ${idbase} ]]; do
		(( gi++ ))
	done
	# Assume that range we're going to output is the remainder of the legal
	# space we're interested in, and then adjust downwards as needed.  For each
	# of the UID and GID space, if the start range is beyond the current output
	# start we're looking at a FREE range, so downward adjust re (range end) to
	# the next non-FREE range's start - 1, or if we're in the non-FREE range,
	# adjust downward to that range's end.
	re=${max}
	uid_start=-1
	gid_start=-1
	if [[ ${ui} -lt ${#uids[@]} ]]; then
		uid_start=${uids[ui]}
		if [[ ${uid_start} -gt ${idbase} && ${uid_start} -le ${re} ]]; then
			re=$(( ${uid_start} - 1 ))
		fi
		if [[ ${ranges_uid[uid_start]} -lt ${re} ]]; then
			re=${ranges_uid[uid_start]}
		fi
	fi
	if [[ ${gi} -lt ${#gids[@]} ]]; then
		gid_start=${gids[gi]}
		if [[ ${gid_start} -gt ${idbase} && ${gid_start} -le ${re} ]]; then
			re=$(( ${gid_start} - 1 ))
		fi
		if [[ ${ranges_gid[gid_start]} -lt ${re} ]]; then
			re=${ranges_gid[gid_start]}
		fi
	fi

	# If we're debugging, just dump various variables above, which allows
	# validating that the above logic works correctly.
	[[ -n "${debug}" ]] && echo "ui=${ui} (${uid_start}..${ranges_uid[uid_start]}), gi=${gi} (${gid_start}..${ranges_gid[gid_start]}), idbase=${idbase}, re=${re}"

	# Determine the state of the UID and GID ranges.
	if [[ ${ui} -lt ${#uids[@]} && ${uid_start} -le ${idbase} ]]; then
		uidstate="${reason_uid[uid_start]}"
	else
		uidstate=FREE
		freeuid=$(( freeuid + re - idbase + 1 ))
	fi

	if [[ ${gi} -lt ${#gids[@]} && ${gid_start} -le ${idbase} ]]; then
		gidstate="${reason_gid[gids[gi]]}"
	else
		gidstate=FREE
		freegid=$(( freegid + re - idbase + 1 ))
	fi

	# If the ranges are FREE (or at least one of), adjust selection recommendations
	# accordingly.
	if [[ "${gidstate}" == FREE ]]; then
		if [[ "${uidstate}" == FREE ]]; then
			uidgidboth=${re}
			freepair=$(( freepair + re - idbase + 1 ))
		else
			gidonly=${re}
		fi
	elif [[ "${uidstate}" == FREE ]]; then
		uidonly=${re}
	fi

	vn="colour_${uidstate}"
	colour_uid="${!vn}"
	vn="colour_${gidstate}"
	colour_gid="${!vn}"
	printf "%-*s${colour_uid}%10s${colour_gid}%10s${colour_RESET}\n" $(( ${#max} * 2 + 5 )) "${idbase}$([[ ${re} -gt ${idbase} ]] && echo "..${re}")" "${uidstate}" "${gidstate}"
	idbase=$(( re + 1 ))
done

echo "Recommended GID only: ${gidonly:-${uidgidboth:-none}}"
echo "Recommended UID only: ${uidonly:=${uidgidboth:-none}}"
echo "Recommended UID+GID pair: ${uidgidboth:-none}"
echo "Free UIDs: ${freeuid}"
echo "Free GIDs: ${freegid}"
echo "Free UID+GID pairs: ${freepair}"
