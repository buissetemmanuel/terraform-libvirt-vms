# terraform - libvirt - vms

## add bridge to allow local VMs to get ip from local DHCP
```
sudo brctl addbr br0
sudo brctl stp br0 on
sudo brctl addif br0 wlp4s0
sudo brctl addif br0 enp6s0
sudo nmcli con add ifname br0 type bridge con-name br0
sudo nmcli con add type bridge-slave ifname enp0s31f6 master br0
sudo nmcli con up br0
```

## get mac address from virt
```
for server in server0{2..5};do  sudo virsh dumpxml ${server} | grep "mac address" | awk -F\' '{ print $2}';done
```

## get ip link to mac address
```
arp -a | grep <mac address>
```
