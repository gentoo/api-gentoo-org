#!/usr/bin/env python3

import argparse
import os.path
import requests
import subprocess
import sys


def main(argv):
    default_api_url = 'https://wiki.gentoo.org/api.php'
    default_script_path = os.path.join(os.path.dirname(__file__),
                                       'uidgid2wiki.awk')
    default_title = 'UID_GID_Assignment_Table'

    argp = argparse.ArgumentParser(prog=argv[0])
    argp.add_argument('--api-url', default=default_api_url,
                      help='URL to MediaWiki API (default: {})'
                           .format(default_api_url))
    argp.add_argument('-p', '--password', required=True,
                      help='Bot password to log in with')
    argp.add_argument('--script', default=default_script_path,
                      help='Path to uidgid2wiki script')
    argp.add_argument('--title', default=default_title,
                      help='Title of page to edit (default: {})'
                           .format(default_title))
    argp.add_argument('-u', '--username', required=True,
                      help='Username to log in with')
    argp.add_argument('path', nargs=1, metavar='uid-gid.txt',
                      type=argparse.FileType('r', encoding='utf-8'),
                      help='UID/GID listing to process')
    args = argp.parse_args(argv[1:])

    # Get converted contents first.
    with subprocess.Popen([args.script],
                          stdin=args.path[0],
                          stdout=subprocess.PIPE) as s:
        page_data, _ = s.communicate()
        assert s.returncode == 0

    # MediaWiki API is just HORRIBLE!  Editing a page requires obtaining
    # a login token, logging in, obtaining a CSRF (!) token
    # and apparently preserving cookies as well!
    with requests.Session() as s:
        # get login token
        params = {
            'action': 'query',
            'meta': 'tokens',
            'type': 'login',
            'format': 'json',
        }
        with s.get(args.api_url, params=params) as r:
            token = r.json()['query']['tokens']['logintoken']

        # log in
        params = {
            'action': 'login',
            'lgname': args.username,
            'lgpassword': args.password,
            'lgtoken': token,
            'format': 'json',
        }
        with s.post(args.api_url, data=params) as r:
            assert r.json()['login']['result'] == 'Success', r.json()

        # get CSRF token (wtf?!)
        params = {
            'action': 'query',
            'meta': 'tokens',
            'format': 'json',
        }
        with s.get(args.api_url, params=params) as r:
            token = r.json()['query']['tokens']['csrftoken']

        # edit page (finally)
        params = {
            'action': 'edit',
            'title': args.title,
            'token': token,
            'format': 'json',
            'text': page_data,
            'summary': 'Automatic update from uid-gid.txt',
            'bot': True,
        }
        with s.post(args.api_url, data=params) as r:
            assert 'error' not in r.json(), r.json()
            print(r.json())

        # logout
        params = {
            'action': 'logout',
            'token': token,
        }
        with s.get(args.api_url, params=params) as r:
            pass

    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
