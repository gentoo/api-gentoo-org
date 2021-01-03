#!/usr/bin/awk -f
# Copyright 2019-2021 Gentoo Authors
# Distributed under the terms of the MIT license

BEGIN {
	print "<!-- DO NOT EDIT, generated automatically by uidgid2wiki.awk -->"
	print "{|class=\"wikitable sortable\""
	print "! Name"
	print "! data-sort-type=\"number\" | UID"
	print "! data-sort-type=\"number\" | GID"
	print "! Provider"
	print "! class=unsortable | Notes"
}

function md2wiki(str) {
	return gensub(/\[([^\]]+)\]\(([^)]+)\)/, "[\\2 \\1]", "g", str)
}

/^[^#]/ {
	print "|-"
	# name
	print "| " $1
	# uid
	print "| " $2
	# gid
	print "| " $3
	# provider
	switch ($4) {
		case "baselayout":
			print "| style=\"background: #cff;\" | baselayout (linux)"
			break
		case "baselayout-fbsd":
			print "| style=\"background: #ccf;\" | baselayout (fbsd)"
			break
		case "acct":
			printf "%s", "| style=\"background: #9fc;\" |"
			if ($2 != "-") printf " %s", "[https://gitweb.gentoo.org/repo/gentoo.git/tree/acct-user/" $1 " u:" $1 "]"
			if ($3 != "-") printf " %s", "[https://gitweb.gentoo.org/repo/gentoo.git/tree/acct-group/" $1 " g:" $1 "]"
			print ""
			break
		case "requested":
			print "| style=\"background: #ffe;\" | requested"
			break
		case "reserved":
			print "| style=\"background: #fcf;\" | reserved"
			break
		case "user.eclass":
			print "| style=\"background: #dca;\" | user.eclass"
			break
		case "historical":
			print "| style=\"background: #fee;\" | historical"
			break
		default:
			print "| " $4
	}
	# notes
	$1=$2=$3=$4=""
	print gensub(/[ \t]+$/, "", 1, "| " md2wiki(substr($0, 5)))
}

END {
	print "|}"
}
