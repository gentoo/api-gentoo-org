#!/usr/bin/env python3

"""
Copyright (C) 2022 Arthur Zamarin <arthurzam@gentoo.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

from http.client import HTTPSConnection
import sys
from typing import Iterator, Tuple
from urllib.parse import quote_plus
from lxml import etree


ok_flag = True


def output_xml_error(xml: etree._Element, title: str, content: str):
    start = xml.sourceline
    end = start + len(etree.tostring(xml).strip().split(b'\n')) - 1
    print(f'::error file={sys.argv[2]},line={start},endLine={end},title={title}::{content}')

    global ok_flag
    ok_flag = False


def output_xml_warning(xml: etree._Element, title: str, content: str):
    start = xml.sourceline
    end = start + len(etree.tostring(xml).strip().split())
    print(f'::warning file={sys.argv[2]},line={start},endLine={end},title={title}::{content}')


class Overlay:
    def __init__(self, xml: etree._Element):
        self.xml = xml

        if (repo_name := xml.find('./name')) is not None:
            self.repo_name = repo_name.text
        else:
            self.repo_name = ''
            output_xml_error(xml, 'Missing overlay name', 'Missing tag "name" for the overlay')

        if (owner_email := xml.find('./owner/email')) is not None:
            self.owner_email = owner_email.text
        else:
            output_xml_error(xml.find('./owner'), 'Missing owner email', 'Missing tag "email" for the overlay\'s owner')

    def check_details(self, client: HTTPSConnection):
        if not getattr(self, 'owner_email', None):
            return
        try:
            client.request("GET", f"/rest/user?names={quote_plus(self.owner_email)}")
            resp = client.getresponse()
            resp.read()
            if resp.status != 200:
                output_xml_error(self.xml.find('owner/email'), 'Unknown email', f'email address "{self.owner_email}" not found at bugzilla')
            else:
                print(f'\033[92m\u2713 repo="{self.repo_name}" <{self.owner_email}>\033[0m')
        except Exception:
            output_xml_warning(self.xml.find('owner/email'), 'Failed check against bugzilla',
                f'Checking for bugzilla email [{self.owner_email}] failed')

    def __hash__(self):
        return hash(self.repo_name)

    def __eq__(self, o) -> bool:
        return isinstance(o, Overlay) and o.repo_name == self.repo_name


def read_repositories(file: str) -> Iterator[Overlay]:
    return map(Overlay, etree.parse(file).findall('./repo'))


def check_maintainers(overlays: Iterator[Overlay]) -> Iterator[Overlay]:
    try:
        client = HTTPSConnection('bugs.gentoo.org')
        for m in overlays:
            m.check_details(client)
    finally:
        client.close()


def check_sorted(curr: Tuple[Overlay], adds: Iterator[Overlay]):
    for addition in adds:
        index = curr.index(addition)
        if index > 0 and curr[index - 1].repo_name >= addition.repo_name:
            output_xml_error(addition.xml, 'Unsorted overlay list', f'overlay "{addition.repo_name}" in wrong place')
        elif index < len(curr) and curr[index + 1].repo_name <= addition.repo_name:
            output_xml_error(addition.xml, 'Unsorted overlay list', f'overlay "{addition.repo_name}" in wrong place')


if __name__ == '__main__':
    base = tuple(read_repositories(sys.argv[1]))
    current = tuple(read_repositories(sys.argv[2]))
    additions = frozenset(current).difference(base)

    check_maintainers(additions)
    check_sorted(current, additions)
    sys.exit(int(not ok_flag))
