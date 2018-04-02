#! /usr/bin/env python
# Check entries in the files/repositories.xml with insecure links
# and report the elements. Next version - comment out the insecure
# links

try:
    from lxml import etree
except ImportError:
    import xml.etree.ElementTree as etree

from sys import argv

# Process the command line

if len(argv) == 1:
    repositoryFile = 'repositories.xml'
else:
    repositoryFile = argv[1]

RepositoryList = etree.parse(repositoryFile)

repos = RepositoryList.findall('repo')

for repo in repos:
    name = repo.find('name').text
    print(f"Overlay name: {name}")
    print("Sources: ")
    sources = repo.findall('source')
    for source in sources:
        print(f"    {source.text}")

        
    

