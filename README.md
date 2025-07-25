# tofu/terraform
1. Install the provider
```
tofu init
```
2. Import secrets, if needed
```
tofu import talos_machine_secrets.this ~/.talos/secrets.yaml
```
3. Import bootstrap, if needed
```
tofu import talos_machine_bootstrap.this 1
```

## Notes
1. Changing the talos version variable doesn't upgrade cluster, apparently there is no way to update the cluster with the provisioner.
2. volume configs not really working

# Manual commands
gen secrets - talosctl gen secrets -o secrets.yaml

gen machine config - talosctl gen config --with-secrets secrets.yaml <cluster-name> <cluster-endpoint>

apply machine config - talosctl apply-config --insecure --nodes <node-ip> --file <config>.yaml

bootstrap the cluster - talosctl --talosconfig=talosconfig bootstrap --nodes <endpoint-ip>

shutdown - talosctl -n <node-ip> shutdown

Do these one node at a time.

upgrade os - talosctl -n <node> upgrade --image ghcr.io/siderolabs/installer:v1.4.5 --preserve

upgrade k8s - talosctl -n <node> upgrade-k8s --to 1.27.3 --dry-run

return to maintenance talosctl -n <node> reset --system-labels-to-wipe EPHEMERAL,STATE --reboot
