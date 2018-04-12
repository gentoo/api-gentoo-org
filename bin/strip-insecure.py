#! /usr/bin/env python
# Identifies insecure source links in entries in the files/repositories.xml
# and deletes them.
#
# Insecure links have the form: git://github.com/...
#
# Usage: strip-insecure.py repositories.xml >repositories-secure.xml
#        The default file of repositories.xml will be selected if called
#        without a parameter
#
# Paul Jewell <paul@teulu.org>
#
# Copyright 2018 Gentoo Foundation
# Distributed under the terms of the GNU GPL version 2 or later

try:
    from lxml import etree
except ImportError:
    import xml.etree.ElementTree as etree
import sys
from sys import argv

# Process the command line

if len(argv) == 1:
    repositoryFile = 'repositories.xml'
else:
    repositoryFile = argv[1]

RepositoryList = etree.parse(repositoryFile)

repos = RepositoryList.findall('repo')

for repo in repos:
    sources = repo.findall('source')
    for source in sources:
        if source.text.startswith("git:"):
            repo.remove(source)

RepositoryList.write(sys.stdout.buffer, encoding='utf-8', xml_declaration=True)

