# talos

Just some notes

when using talosctl, make calls directly to a master node, not the vip

gen secrets - talosctl gen secrets -o secrets.yaml

gen machine config - talosctl gen config --with-secrets secrets.yaml <cluster-name> <cluster-endpoint>

apply machine config - talosctl apply-config --insecure --nodes <node-ip> --file <config>.yaml

bootstrap the cluster - talosctl --talosconfig=talosconfig bootstrap --nodes <endpoint-ip>

shutdown - talosctl -n <node-ip> shutdown

Do these one node at a time.

upgrade os - talosctl -n <node> upgrade --image ghcr.io/siderolabs/installer:v1.4.5 

upgrade k8s - talosctl -n <node> upgrade-k8s --to 1.27.3 --dry-run
