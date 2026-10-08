%define _tag version_3_6_0
# No -debuginfo: five small helpers, and EL9's toolchain errors on their
# empty debugsource list.
%define debug_package %{nil}

Name:           tigris
Version:        3.6.0
Release:        1%{?dist}
Summary:        Security auditor for Linux, descended from TIGER
License:        GPL-2.0-or-later
URL:            https://github.com/creativeheadz/tigris
Source0:        https://github.com/creativeheadz/tigris/archive/refs/tags/%{_tag}.tar.gz
BuildRequires:  gcc
BuildRequires:  make

%description
Tigris audits a Linux system against 63 checks and explains every
finding, with JSON output, offline auditing of images that are not
running, and per-finding compliance controls. It installs under its
own name and paths.

%prep
%setup -q -n %{name}-%{_tag}

%build
./configure --prefix=%{_prefix} --sysconfdir=%{_sysconfdir} \
  --localstatedir=%{_localstatedir} \
  --with-tigerhome=%{_libdir}/tigris \
  --with-tigerconfig=%{_sysconfdir}/tigris \
  --with-tigerwork=%{_localstatedir}/lib/tigris \
  --with-tigerlog=%{_localstatedir}/log/tigris \
  --with-tigerbin=%{_sbindir}
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}
sh packaging/stage.sh %{buildroot} %{_libdir}/tigris %{_sbindir}

%files
%license COPYING
%config(noreplace) %{_sysconfdir}/tigris/
%{_sbindir}/tigris
%{_sbindir}/tigris-diff
%{_sbindir}/tigris-accept
%{_libdir}/tigris/
%dir %{_localstatedir}/lib/tigris
%dir %{_localstatedir}/log/tigris
%{_mandir}/man8/tigris.8*
%{_mandir}/man8/tigris-diff.8*
%{_mandir}/man8/tigris-accept.8*

%changelog
* Thu Oct 08 2026 Andrei Trimbitas <a.trimbitas@oldforge.tech> - 3.6.0-1
- First package of the fork, co-installable beside tiger.
