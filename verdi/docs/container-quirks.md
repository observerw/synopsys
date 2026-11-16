# Verdi container quirks

Shared by both built releases: `2025.06-SP1` and `2023.12-SP2` apply the same
two steps below, each with the release name of its own delivery.

## The supplementary package post-install wants VCS

The delivery contains `verdi` and `verdi_supp` (the supplementary package). A
single `batch_installer -allprods` run installs both trees, but
`verdi_supp/etc/post_install.sh` runs `vcs -id` to derive the VCS version, even
when `-verdi_home` is passed, and with no VCS in the image it aborts. The
installer therefore reports product `verdi_supp` as failed (`install_rc=1`)
after writing both trees correctly.

The hook's only actions are

```sh
mv $TARGET/verdi_supp $VERDI_HOME/platform/verdi_supp
ln -s ../../verdi_supp/X-2025.06-SP1 $VERDI_HOME/platform/linux64/lib/vcs
```

so `verdi/2025.06-SP1/Containerfile` and `verdi/2023.12-SP2/Containerfile` gate
on the installed trees, perform those two steps themselves (with the release
name of their own delivery) and then run `ValidationTool` over the combined
`VERDI_HOME`. The result is the same layout the hook produces on a host that
also has VCS installed.
