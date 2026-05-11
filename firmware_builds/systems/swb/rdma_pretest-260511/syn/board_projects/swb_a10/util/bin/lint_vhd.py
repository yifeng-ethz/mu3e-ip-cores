#!/usr/bin/env python3

import argparse
import pathlib
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("dir", nargs="?", default=".")
args = parser.parse_args()

# check `reset => reset` mappings
def check_resets(file : pathlib.Path, content : str) -> None :
    # find `port map` blocks
    blocks = re.findall('\\bport\\s+map\\s*\\((.*?)\\)\\s*;', content, flags=re.DOTALL)
    blocks = ',\n'.join(blocks) + ',\n'
    # remove balanced '(.*)' groups
    while re.search('\\([^()]*\\)', blocks) : blocks = re.sub('\\(\\s*[^()]*\\)', '', blocks)

    ports = re.findall('([^,=]*)=>([^,]*)?', blocks)
    for port in ports :
        port0 = re.sub('\\s+', ' ', port[0]).strip()
        port1 = re.sub('\\s+', ' ', port[1]).strip()
        # remove one level of '(.*)' groups
        #port0 = re.sub('\\(\\s*[^()]*\\)', '', port0)
        #port1 = re.sub('\\(\\s*[^()]*\\)', '', port1)

        if not re.search('(reset)', port0) : continue
        #if not re.search('(reset)', port1) : continue

        # skip `* => open`
        if re.search('^open$', port1) : continue
        # skip `*_n => '1'`
        if re.search('^[^ ]*_n$', port0) and re.search("^'1'$", port1) : continue
        # skip `*_n => *_n`
        if re.search('^[^ ]*_n$', port0) and re.search('^[^ ]*_n$', port1) : continue
        # skip `* => *`
        if re.search('^[^ ]*$', port0) and not re.search('_n$', port0) \
           and re.search('^[^ ]*$', port1) and not re.search('_n$', port1) : continue
        # skip `* => not *_n`
        if re.search('^[^ ]*$', port0) and not re.search('_n$', port0) \
           and re.search('^not [^ ]*_n$', port1) : continue
        # skip `*_n => not *`
        if re.search('^[^ ]*_n$', port0) \
           and re.search('^not [^ ]*$', port1) and not re.search('_n$', port1) : continue

        print(f'W [{file}] reset: `{port0} => {port1}`')
        #print(port)

# check port names
def check_ports(file : pathlib.Path, content : str) -> None :
    # find `port` block
    port_block = re.findall('\\bentity\\s+\\w+\\s+is\\b.*?\\bport\\s*\\((.*?)\\)\\s*;\\s*end\\s+entity', content, flags=re.DOTALL)
    port_block = ';\n'.join(port_block) + ';\n'
    ports = re.findall('(\\w+)\\s*:\\s*(\\w+).*?;', port_block)
    for port in ports :
        port_name = port[0]
        port_type = port[1]
        # check that `in`/`out`/`inout` ports start with `i_`/`o_`/`io_`
        if port_name.startswith('i_') and port_type == 'in' : continue
        if port_name.startswith('o_') and port_type == 'out' : continue
        if port_name.startswith('io_') and port_type == 'inout' : continue
        # report
        print(f'W [{file}] port: `{port_name} : {port_type}`')

def check_ends(file : pathlib.Path, content : str) -> None :
    # find assignments
    ends = re.findall('\\bend(\\s+\\w+)?(\\s+\\w+)?(\\s+\\w+)?\\s*;', content)
    for end in ends :
        if ' '.join(x.strip() for x in end).strip() in [
            'architecture', 'block', 'case', 'component',
            'entity', 'function', 'generate', 'if',
            'loop', 'package', 'package body', 'procedure',
            'process', 'protected', 'protected body', 'record',
        ] : continue
        print(f'W [{file}] `end {end}`')

#files = pathlib.Path(args.dir).glob('**/*.vhd')
files = subprocess.check_output([ '/usr/bin/git', 'ls-files', args.dir ], text=True).splitlines()
for file_path in files :
    file = pathlib.Path(file_path)
    if not file.exists() : continue
    #print(file)

    # process only *.vhd files
    if not re.search('.vhd$', file_path) : continue
    # ignore top files
    if re.search('(^|/)top.vhd$', file_path) : continue
    # ignore ips
    if re.search('(^|/)altgx_generic.vhd$', file_path) : continue
    # ignore dirs
    if re.search('/(clock_and_reset_box)/', file_path) : continue

    content = file.open().read()

    # skip quartus megafunction ips
    if content.startswith('-- megafunction wizard') : continue
    # skip quartus hw sources
    if content.startswith('-- QUARTUS_SYNTH') : continue

    content = content.lower()

    # remove comments
    content = re.sub('--.*', '', content)
    ## remove `signal` defs
    #content = re.sub('\\bsignal\\b.*?;', '', content, flags=re.DOTALL)
    ## remove `generic map` blocks
    #content = re.sub('\\bgeneric\\s+map\\b.*?\\bport\\s+map\\b', 'port map', content, flags=re.DOTALL)
    ## remove `case` blocks
    #content = re.sub('\\bcase\\b.*?\\bend\\s+case\\b', '', content, flags=re.DOTALL)

    check_ports(file, content)
    check_resets(file, content)
    check_ends(file, content)
