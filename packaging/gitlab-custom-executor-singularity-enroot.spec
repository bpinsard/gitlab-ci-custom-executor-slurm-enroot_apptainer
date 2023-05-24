#!/usr/bin/env rpm
Name:     gitlab-custom-executor-singularity-enroot
Version:  1.0
Release:  1
Source0:  rpmbuild.tar
Group:    Applications/Tools
Packager: Michele Mesiti <michele.mesiti@kit.edu>
License:  GPL
Summary:  GitLab-Runner custom executor using Slurm with Enroot or Singularity
Requires: git
Requires: git-lfs
Requires: gitlab-runner

%description
GitLab Runner offers the Custom Executor mechanism
for environments that are not natively suppported.
To run Docker containers on our HPC systems
using ENROOT or Singularity/Apptainer,
we provide such a custom executor
(which consists in a set of bash scripts)
and an associated script to ease the user configuration.

# Turn off creation of debuginfo packages on RHEL
%if 0%{?fedora} || 0%{?rhel} || 0%{?centos}
%global debug_package %{nil}
%endif

%prep
%setup -q -n %{name}

%install
make install \
    DESTDIR="${RPM_BUILD_ROOT}" \
    PREFIX="%{prefix}" \
    VERSION="v%{version}-%{release}"

%files
%defattr(-,root,root)
%{prefix}


%changelog
* Wed May 24 2023 Michele Mesiti <michele.mesiti@kit.edu> 1.0-1
- Initial version (inspired by Holger Obermaier's work)
