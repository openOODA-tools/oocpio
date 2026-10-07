Name:           oocpio
Version:        0.1.0
Release:        1%{?dist}
Summary:        Initramfs cpio format unpacker and archiver for Linux kernel boot images.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oocpio
Source0:        oocpio-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oocpio is a sovereign, capability-bounded CPIO PACKER written
in pure openOODA, featuring zero ambient authority, oote color themes,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oocpio
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oocpio-uninstall

%files
/usr/bin/oocpio
/usr/bin/oocpio-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign blueprint scaffolding
