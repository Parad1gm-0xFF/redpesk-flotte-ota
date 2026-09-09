# Spec RPM pour la flotte OTA redpesk.
#
# BUT : fournir à la factory l'artefact de tests (subpackage -redtest) exécuté
# sur cible QEMU/VM, et installer une arborescence de référence sur la cible
# (device type modèle, scripts de diagnostic).
#
# Adapté du pattern secure-telemetry-node (package principal + subpackage
# redtest au format TAP, installé dans %_libexecdir/redtest/).
#
# Build arche-types :
#   - aarch64 (cible RPi3B+)
#   - x86_64 (cible de test QEMU redpesk)

%global _enable_debug_packages 0
%global debug_package %{nil}

Name:           redpesk-flotte-ota
Version:        0.1.0
Release:        1%{?dist}
Summary:        Flotte RPi3B+ OTA (Mender) pour redpesk OS
License:        Apache-2.0
URL:            https://github.com/Parad1gm-0xFF/redpesk-flotte-ota
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  bash

%description
Flotte de capteurs Raspberry Pi 3B+ sous redpesk OS, provisionnee et mise a
jour en bout-en-bout par la redpesk factory (OTA Mender, partitions A/B).
Ce paquet installe la configuration de reference (device type) et les tests
d'integration (subpackage -redtest) executes par la plateforme.

%prep
%autosetup

%install
# Reference du device type de la flotte (le 02_... est applique a la volee par
# mender-init.sh ; ce fichier sert de source de verite pour les redtests).
install -D -m 0644 %{_builddir}/%{name}-%{version}/factory/models-board.yml \
    %{buildroot}%{_sysconfdir}/redpesk-flotte-ota/models-board.yml

# Scripts de diagnostic cotes cible
mkdir -p %{buildroot}%{_libexecdir}/redpesk-flotte-ota/
install -D -m 0755 %{_builddir}/%{name}-%{version}/scripts/target/check.sh \
    %{buildroot}%{_libexecdir}/redpesk-flotte-ota/check.sh

# --- Subpackage redtest ---
mkdir -p %{buildroot}%{_libexecdir}/redtest/%{name}/
cp -a %{_builddir}/%{name}-%{version}/redtests/. %{buildroot}%{_libexecdir}/redtest/%{name}/
chmod +x %{buildroot}%{_libexecdir}/redtest/%{name}/run-redtest

%check
# Tests statiques legers sur le tarball source (pas d'execution cible ici :
# les redtests reels sont executes par la factory sur la VM/QEMU).
cd %{_builddir}/%{name}-%{version}
test -f redtests/run-redtest && echo "redpesk-flotte-ota: run-redtest present"
test -f factory/models-board.yml && echo "redpesk-flotte-ota: models-board.yml present"

%files
%{_sysconfdir}/redpesk-flotte-ota/models-board.yml
%{_libexecdir}/redpesk-flotte-ota/check.sh

# --- Subpackage redtest : contenu du package -redtest ---
%package redtest
Summary:        Tests d'intégration (TAP) pour %{name}
Requires:       %{name} = %{version}-%{release}

%description redtest
Tests d'integration executes par la plateforme redpesk sur cible virtuelle :
verifie la presence du client Mender, l'activite des services, le device type
et le paquet redpesk-config. Sortie au format TAP.

%files redtest
%defattr(-,root,root)
%{_libexecdir}/redtest/%{name}/*

%changelog
* Wed Sep 09 2026 Parad1gm <parad1gm_0xFF@gmail.com> - 0.1.0-1
- Squelette initial : spec + redtests + config modele de flotte.