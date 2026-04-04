grep '|' 1-IPA.md | sed 's/^|\s*//' | sort -n | grep -i '^[0-9]'
