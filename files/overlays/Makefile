.PHONY: check
check: .repositories-dtd-valid .repositories-xsd-valid .repositories-check-successful .repositories-style-ok

# Check repositories.xml against the Document Type Definition (DTD).
.repositories-dtd-valid: repositories.xml repositories.dtd
	xmllint --noout --dtdvalid repositories.dtd repositories.xml
	touch $@

repositories.dtd:
ifeq ($(OFFLINE), true)
	[ ! -f repositories.dtd ] && exit 1
else
	wget --timestamping https://www.gentoo.org/dtd/repositories.dtd
endif


# Check repositories.xml against the XML Schema Definition (XSD)
.repositories-xsd-valid: repositories.xsd repositories.xml
	xmllint --noout --schema $^
	touch $@

repositories.xsd:
ifeq ($(OFFLINE), true)
	[ ! -f repositories.xsd ] && exit 1
else
	wget --timestamping https://gitweb.gentoo.org/data/xml-schema.git/plain/repositories.xsd
endif


# Run a full check of repositories.xml via repositories-checker.py
.repositories-check-successful: repositories.xml
	../../bin/repositories-checker.py - $^
	touch $@

.PHONY: format
format: .repositories-expected-format.xml
	cmp -s repositories.xml $^ || cp $^ repositories.xml

.repositories-expected-format.xml: repositories.xml
	xmllint --format $^ > $@

.ONESHELL:
.repositories-style-ok: SHELL = /bin/bash
.repositories-style-ok: .repositories-expected-format.xml
	if ! cmp -s repositories.xml $^; then
		diff -u repositories.xml $^
		exit 1
	fi
	touch $@
