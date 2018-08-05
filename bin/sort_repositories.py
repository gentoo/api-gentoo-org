#!/usr/bin/env python3

# python version >= 3.5

import sys
import argparse
from lxml import etree
import typing

parser = argparse.ArgumentParser(
        "Sort overlay repos list by name")
parser.add_argument(
        "path",
        help="path to repositories.xml")


def find_repositories_node(
        etree: etree.ElementTree
    ) -> etree.Element:
    return repo_etree.xpath("/repositories")[0]


def find_repo_nodes(
        repositories_node: etree.Element
    ) -> typing.List[etree.Element]:
    """
    This function is designed to work
    on <repositories> node, returned
    by `find_repositories_node()` function.

    """

    return repositories_node.xpath("./repo")


name_xpath = etree.XPath("./name/text()")

def extract_repo_name(
        repo_node: etree.Element
    ) -> str:
    """
    Extract repo name from repo node.
    """

    return name_xpath(repo_node)[0]


def sort_repo_nodes(
        repo_nodes: typing.List[etree.Element]
        ) -> None:
    """
    Sort nodes list by name case insensitively.
    
    It does work in-place on the list provided.
    Python sorting algorithm is stable,
    so original order must be preserved
    if appropriate.
    """

    repo_nodes.sort(
            key=lambda node:
                extract_repo_name(node)
                    .lower())


def reinsert_repo_nodes(
        repositories_node: etree.Element,
        repo_nodes: typing.List[etree.Element]
    ) -> None:
    """
    Remove all <repo> node from <repositories>
    and reinsert them back in the order
    provided in the list.
    """

    for repo_node in repo_nodes:
        repositories_node.remove(repo_node)

    for repo_node in repo_nodes:
        repositories_node.append(repo_node)


def vim_modelines_fixup(
        repositories_node: etree.Element
    ) -> None:
    """
    Find, remove and reinsert modeline comment
    to the end of the file.
    """

    vim_comments = []
    for node in repositories_node:
        if (
            isinstance(node, etree._Comment)
            and node.text.startswith(" vim:")
            ):
            vim_comments.append(node)

    for vim_comment in vim_comments:
        repositories_node.remove(vim_comment)
        repositories_node.append(vim_comment)


def format_xml(
        repo_etree: etree.Element
    ) -> str:
    """
    Return text pretty-printed representation
    of chosen XML node.

    Works best on document root as it preserves <!DOCTYPE>.
    """

    return (
        etree.tostring(
            repo_etree,
            xml_declaration=True,
            encoding="utf-8",
            pretty_print=2)
                .decode())


if __name__ == "__main__":
    args = parser.parse_args()

    repo_file = open(args.path, "rb")
    repo_etree = etree.parse(
            repo_file,
            etree.XMLParser(remove_blank_text=True))

    repositories_node = find_repositories_node(repo_etree)
    repo_nodes = find_repo_nodes(repositories_node)

    sort_repo_nodes(repo_nodes)
    reinsert_repo_nodes(
            repositories_node,
            repo_nodes)

    vim_modelines_fixup(repositories_node)

    sys.stdout.write(
        format_xml(repo_etree))

