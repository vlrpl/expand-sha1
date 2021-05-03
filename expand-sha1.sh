#!/usr/bin/sh

# fixes-tag.sh
#
# sourced in commit-msg hook replaces all the occurrence
# of:
#
# ^Z<sha1>
#
# with:
#
# <sha1_12ch> ("commit message")
#
# works with multiple occurrence of "^Zsha1" on the same
# line.
# Note: ^Z is the control character "substitute" (\x1a)
#       it can be easily inserted with:
#         - emacs: C-q 032
#         - vim (in insert mode): Ctrl-Z
#
# Mostly useful for "Fixes:" tag
#

print_hook() {
	echo -n "[${hook_name:-commit-msg} hook] "
	echo $@
}

confirm() {
	local c ret=0

	print_hook -n "$1"

	while read c; do
		case $c in
			Y|y)
				break
				;;
			N|n|"")
				ret=1
				break
				;;
			*)
				print_hook "Please answer y or n";;
		esac
	done < /dev/tty

	return $ret
}

get_hash() {
	local sha1=${1%% *}

	[ -n "$sha1" ] && \
		[ "$(git cat-file -t $sha1 2>/dev/null)" = "commit" ] && eval $2="$sha1" || return 1

	return 0
}

f_path=$1

[ -f "${f_path}.new" ] && rm -f ${f_path}.new

while read line; do
	hash=
	r_line=

	# append lines starting with "#" to avoid
	# noise in the diff
	if [ -z "$line" -o -z "${line%%#*}" ]; then
		echo "$line" >> ${f_path}.new
		continue
	fi

	IFS=''
	set -- $line

	if [ $# -le 1 ]; then
		echo "$line" >> ${f_path}.new
		continue
	fi

	for f; do
		if ! get_hash "$f" hash; then
			r_line=${r_line:+$r_line }${f}
			continue
		fi

		expanded_hash=$(git show -s --abbrev=12 --format=format:'%h ("%s")' $hash)
		r_line=${r_line}${expanded_hash}${f##$hash}
	done
	unset IFS

	echo "$r_line" >> ${f_path}.new
done < $f_path


if ! diff -u --color $f_path ${f_path}.new; then
	echo
	confirm "Do you want to proceed with the replacement (y/N)? " && mv ${f_path}.new $f_path
fi
