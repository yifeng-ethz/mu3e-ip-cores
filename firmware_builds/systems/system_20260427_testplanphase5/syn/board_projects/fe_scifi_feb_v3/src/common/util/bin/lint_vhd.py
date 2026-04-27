#!/usr/bin/env python3

import argparse
import pathlib
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("dir", nargs="?", default=".")
args = parser.parse_args()

# check `reset => reset` mappings
def check_resets(file, content) :
    # find `port map` blocks
    content = re.findall('\\bport\\s+map\\s*\\((.*?)\\)\\s*;', content, flags=re.DOTALL)
    content = ',\n'.join(content) + ',\n'
    # remove balanced '(.*)' groups
    while re.search('\\([^()]*\\)', content) : content = re.sub('\\(\\s*[^()]*\\)', '', content)
    #print(content)

    ports = re.findall('([^,=]*)=>([^,]*)?', content)
    for port in ports :
        port0 = re.sub('\\s+', ' ', port[0]).strip()
        port1 = re.sub('\\s+', ' ', re.sub('\\)\\s*;', '', port[1])).strip()

        if not re.search('(reset)', port0) : continue

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

# check port names (in/out ports start with i_/o_)
def check_ports(file, content) :
    # find `port` block
    port_block = re.findall('\\bentity\\s+\\w+\\s+is\\b.*?\\bport\\s*\\((.*?)\\)\\s*;\\s*end\\s+entity', content, flags=re.DOTALL)
    port_block = ';\n'.join(port_block) + ';\n'
    ports = re.findall('(\\w+)\\s*:\\s*(\\w+).*?;', port_block)
    for port in ports :
        name = port[0]
        type = port[1]
        if name.startswith('i_') and type == 'in' : continue
        if name.startswith('o_') and type == 'out' : continue
        if name.startswith('io_') and type == 'inout' : continue
        print(f'W [{file}] port: `{name} : {type}`')



#files = pathlib.Path(args.dir).glob('**/*.vhd')
files = subprocess.check_output([ '/usr/bin/git', 'ls-files', args.dir ], text=True).splitlines()
for file in files :
    file = pathlib.Path(file)
    if not file.exists() : continue
    #print(file)

    # process only *.vhd files
    if not re.search('.vhd$', str(file)) : continue
    # ignore top files
    if re.search('(^|/)top.vhd$', str(file)) : continue
    # ignore ips
    if re.search('(^|/)altgx_generic.vhd$', str(file)) : continue
    # ignore dirs
    if re.search('/(clock_and_reset_box)/', str(file)) : continue

    content = file.open().read()
    content = content.lower()

    # remove comments
    content = re.sub('--.*?\\n', '\\n', content, flags=re.DOTALL)
    ## remove `signal` defs
    #content = re.sub('\\bsignal\\b.*?;', '', content, flags=re.DOTALL)
    ## remove `generic map` blocks
    #content = re.sub('\\bgeneric\\s+map\\b.*?\\bport\\s+map\\b', 'port map', content, flags=re.DOTALL)
    ## remove `case` blocks
    #content = re.sub('\\bcase\\b.*?\\bend\\s+case\\b', '', content, flags=re.DOTALL)

    check_resets(file, content)
    check_ports(file, content)
