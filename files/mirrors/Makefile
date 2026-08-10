.%.expected-format.xml: %.xml
	XMLLINT_INDENT="  " xmllint --format $^ > $@

.%.expected-format.xml.ok: .%.expected-format.xml
	if ! cmp -s $*.xml $^; then \
		diff -u $*.xml $^; \
		exit 1; \
	fi; \
	touch $@

.PHONY: check format
check: .distfiles.expected-format.xml.ok .rsync.expected-format.xml.ok

format: .distfiles.expected-format.xml .rsync.expected-format.xml
	for FILE in distfiles rsync; do \
		if cmp -s "$${FILE}.xml" ".$${FILE}.expected-format.xml"; then \
			continue; \
		fi; \
		cp ".$${FILE}.expected-format.xml" "$${FILE}.xml" \
	done
