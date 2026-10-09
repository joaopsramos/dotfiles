#!/usr/bin/env python3
import json, glob, os, re, shutil, subprocess, time

def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        return ""

def cpu_usage():
    def read():
        with open('/proc/stat') as f:
            vals=list(map(int, f.readline().split()[1:]))
        return sum(vals), vals[3] + (vals[4] if len(vals)>4 else 0)
    try:
        a=read(); time.sleep(.12); b=read()
        total=b[0]-a[0]; idle=b[1]-a[1]
        return round(100*(total-idle)/total) if total else 0
    except Exception:
        return 0

def battery():
    for path in glob.glob('/sys/class/power_supply/BAT*'):
        try:
            base=os.path.basename(path)
            cap=int(open(path+'/capacity').read())
            state=open(path+'/status').read().strip()
            return {'value':cap, 'charging':state in ('Charging','Full')}
        except Exception:
            pass
    return {'value':-1, 'charging':False}

def main():
    volume=run('pactl','get-sink-volume','@DEFAULT_SINK@')
    match=re.search(r'(\d+)%', volume)
    mute=run('pactl','get-sink-mute','@DEFAULT_SINK@').endswith('yes')
    sink=run('pactl','get-default-sink')
    sound='󰓃'
    for key, icon in [('analog-stereo','󰓃'),('Astro','󰋋'),('bluez','󰂯')]:
        if key.lower() in sink.lower(): sound=icon; break
    try:
        meminfo={}
        with open('/proc/meminfo') as f:
            for line in f:
                k,v=line.split(':',1); meminfo[k]=int(v.strip().split()[0])
        mem=round(100*(1-meminfo['MemAvailable']/meminfo['MemTotal']))
    except Exception: mem=0
    try: disk=shutil.disk_usage('/').used*100//shutil.disk_usage('/').total
    except Exception: disk=0
    dev=run('nmcli','-t','-f','TYPE,STATE,CONNECTION','device','status').splitlines()
    network={'kind':'down','name':''}
    for line in dev:
        fields=line.split(':',2)
        if len(fields)>=2 and fields[1]=='connected':
            kind=fields[0]
            network={'kind':'wifi' if kind=='wifi' else 'ethernet','name':fields[2] if len(fields)>2 else ''}
            break
    print(json.dumps({'cpu':cpu_usage(),'memory':mem,'disk':disk,'battery':battery(),
        'volume':int(match.group(1)) if match else 0,'muted':mute,'sound':sound,'network':network}))

main()
